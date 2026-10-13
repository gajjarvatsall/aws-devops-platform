# CloudOps AWS DevOps Platform

This repository contains a staging-only AWS platform and a small Flask
application. AWS account resources and credentials are external to this
repository; no AWS credentials or generated Terraform state belong in Git.

## Project structure

```text
app/                         Flask service, Dockerfile, and tests
modules/                     Reusable Terraform AWS modules
environments/staging/        Only deployable Terraform environment
bootstrap/backend/           Terraform state-bucket bootstrap
.github/workflows/           CI, Terraform plan/apply, and app release
scripts/                     Local validation helpers
Makefile                     Local command shortcuts
```

The `environments/prod` directory is intentionally empty. Dev was removed.
There is one project README; module and documentation README files are not
used.

## Application

The service is in [`app/app.py`](app/app.py) and runs in a non-root Gunicorn
container defined by [`app/Dockerfile`](app/Dockerfile).

Runtime endpoints:

| Endpoint | Purpose |
|---|---|
| `/` | Live-only staging dashboard |
| `/health` | Liveness check; does not require AWS or MySQL |
| `/ready` | Secrets Manager lookup followed by a real MySQL `SELECT 1` |
| `/api/status` | Application metadata and database connectivity |
| `/api/dashboard` | Live application, ALB, Auto Scaling, RDS, and ECR status |

The dashboard never invents infrastructure status. If AWS identifiers,
credentials, permissions, or a resource are unavailable, it displays
`Unavailable`.

Required runtime values include `AWS_REGION`, `DB_SECRET_ARN`,
`APP_ENVIRONMENT`, `APP_VERSION`, and `APP_PORT`. The staging EC2 bootstrap
also supplies `AWS_ASG_NAME`, `AWS_TARGET_GROUP_ARN`, `AWS_RDS_IDENTIFIER`, and
`AWS_ECR_REPOSITORY_NAME` for the live dashboard checks.

## Terraform modules

Every module contains Terraform resources in `main.tf`, inputs in
`variables.tf`, outputs in `outputs.tf`, and provider constraints in
`versions.tf`.

- `modules/vpc`: VPC, public/application/database subnets, routes, NAT, and
  Internet gateway.
- `modules/security-groups`: ALB, application, and database security groups,
  EC2 IAM role, and instance profile.
- `modules/rds`: private encrypted MySQL, subnet group, generated password,
  and Secrets Manager secret.
- `modules/s3`: private application and ALB log buckets, encryption,
  versioning, public-access blocking, policies, and lifecycle rules.
- `modules/ecr`: private ECR repository, immutable tags, scanning, and
  lifecycle policy.
- `modules/alb`: Application Load Balancer, target group, listeners, and
  access logging.
- `modules/autoscaling`: Amazon Linux launch template, Docker bootstrap,
  Auto Scaling Group, instance refresh, and target-group attachment.
- `modules/cloudwatch`: application log group.

The staging root composes these modules and passes outputs between them:

```text
VPC public subnets       -> ALB
VPC application subnets -> Auto Scaling
VPC database subnets     -> RDS
ECR repository           -> Auto Scaling image
S3 log bucket            -> ALB
CloudWatch log group     -> EC2 bootstrap
Security groups/IAM      -> ALB, EC2, RDS, and runtime access
RDS secret ARN           -> EC2 application
ALB target group ARN     -> Auto Scaling
```

Terraform creates ordering from these references. The only explicit
dependency is the secret-read IAM policy before application capacity starts.

## Staging Terraform

[`environments/staging`](environments/staging) is the only deployable
environment.

- `main.tf`: composes all modules and defines the staging runtime IAM policies.
- `variables.tf`: region, capacity, RDS, networking, and image
  settings.
- `providers.tf`: AWS provider configuration.
- `backend.tf`: encrypted remote S3 state with native S3 lockfiles.
- `outputs.tf`: VPC, ECR, RDS, ALB, target group, and log-group outputs.
- `terraform.tfvars.example`: safe example values; the real tfvars file is
  ignored.
- `versions.tf`: Terraform and provider constraints.

The backend uses the key `staging/terraform.tfstate`. Native S3 lockfiles
require Terraform 1.10 or newer. State can contain the generated database
password, so restrict state-bucket access and artifact access.

## CI/CD workflow and required AWS setup

The pipeline has three separate paths:

- [ci.yaml](.github/workflows/ci.yaml) runs tests, lint, dependency and credential checks, Docker build, Terraform format, and configuration validation on PRs and pushes. It has no AWS credentials.
- [terraform-plan.yaml](.github/workflows/terraform-plan.yaml) runs a read-only speculative Terraform plan for infrastructure PRs. It summarizes resource actions, never uploads plan files, and never applies.
- [terraform-apply.yaml](.github/workflows/terraform-apply.yaml) is started manually from `main` after infrastructure changes merge. It waits for the protected `staging` environment, plans again against current state, rejects deletes/replacements, and applies that exact saved plan.
- [app-release.yaml](.github/workflows/app-release.yaml) runs when app changes merge to `main` (or can be dispatched for rollback). It builds an immutable `sha-<commit>` ECR image, updates one SSM image-tag parameter, activates or refreshes the EC2 Auto Scaling Group, and checks ALB health. It never runs Terraform.

Terraform creates the infrastructure with the ASG at zero capacity. The first app release publishes its image and activates the ASG. EC2 reads the current immutable image tag from Parameter Store at boot, so app releases do not change infrastructure. Terraform ignores runtime ASG min/desired capacity and the SSM parameter value; after creation, the application release flow owns those values.

| Setting | Value |
|---|---|
| AWS account | `337909740274` |
| Region | `ap-south-1` |
| Terraform apply role | `cloudops-github-terraform-deploy` |
| Terraform PR plan role | `cloudops-github-terraform-plan` |
| App release role | `cloudops-github-app-deploy` |
| Terraform state bucket/key | `aws-vg-cloudops-tf-state` / `staging/terraform.tfstate` |
| Terraform project/environment | `cloudops-demo-staging` |
| Application URL | HTTP using the ALB generated hostname |

### AWS roles and GitHub OIDC

Confirm the IAM OIDC provider exists in account `337909740274`:

- URL: `https://token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`
- ARN: `arn:aws:iam::337909740274:oidc-provider/token.actions.githubusercontent.com`

The existing `cloudops-github-terraform-deploy` role must trust only the `staging` GitHub environment subject, with `aud` equal to `sts.amazonaws.com`:

```text
repo:gajjarvatsall@82715470/aws-devops-platform@1415557208:environment:staging
```

Its existing permission policy must allow Terraform to manage this staging environment, create/update the two dedicated GitHub roles and inline policies (`iam:CreateRole`, `iam:PutRolePolicy`, `iam:UpdateAssumeRolePolicy`, and role tagging), and access the S3 state object and lockfile. Scope `iam:PassRole` to the EC2 runtime role and require `iam:PassedToService=ec2.amazonaws.com`. Do not attach `AdministratorAccess`.

The first successful Terraform apply creates two dedicated roles:

- `cloudops-github-terraform-plan`, trusted for `repo:gajjarvatsall@82715470/aws-devops-platform@1415557208:pull_request`. It has resource read permissions and only the S3 write access Terraform needs to manage its lockfile. It cannot apply AWS changes or call Secrets Manager to retrieve values. It can read Terraform state, which contains sensitive data, so only trusted repository collaborators should be allowed to open same-repository PRs or change workflow files.
- `cloudops-github-app-deploy`, trusted for `repo:gajjarvatsall@82715470/aws-devops-platform@1415557208:environment:staging-app`. It can publish to the staging ECR repository, update the staging image parameter, change capacity, and refresh the staging ASG.

In **Repository Settings → Environments**, configure `staging` to restrict deployment to `main` and require an infrastructure reviewer. Create `staging-app` and restrict it to `main`; app deployments run automatically unless you add a reviewer gate. No AWS access keys or database credentials are needed as GitHub secrets.

### Remote Terraform state

The S3 bucket `aws-vg-cloudops-tf-state` in `ap-south-1` must exist before workflows can use it. The backend uses encryption and native S3 lockfiles. If it does not exist, create it once using the separately documented bootstrap in `bootstrap/backend`; review its plan and use an authorized AWS operator identity. Do not create a duplicate bucket or delete a lock while a run may be active. State contains sensitive database data, so keep access restricted and never upload a Terraform plan or state as an Actions artifact.

### First deployment and routine changes

For initial setup, merge the infrastructure PR, then manually run **Actions → Terraform apply → Run workflow** from `main` and approve the protected `staging` environment. It creates the ECR repository, SSM image parameter, ASG at zero capacity, and the dedicated plan/app roles. The plan role becomes available after this first apply, so the initial infrastructure PR needs a human-reviewed bootstrap exception if branch protection requires every check to pass. After bootstrap, infrastructure PRs receive the AWS-backed speculative plan. To start the app the first time, manually run **Actions → Application release → Run workflow** from `main` with `image_tag` blank. Later pushes changing `app/**` build and deploy automatically. To roll back, use that same manual workflow with an existing immutable ECR tag such as `sha-<commit>`.

The ALB serves HTTP because this setup has no domain name or ACM certificate. Use `/health` for the application liveness check; `/ready` also requires the database path to work.

## Security design

- The ALB is the only public ingress point.
- EC2 and RDS are private and use security-group references.
- RDS and S3 are encrypted; S3 requires TLS and blocks public access.
- EC2 requires IMDSv2 and uses an encrypted EBS volume.
- ECR tags are immutable and scan on push. Re-running a commit deployment
  reuses an existing `sha-*` image only after pulling it and verifying its
  OCI revision label matches the workflow commit. A rollback tag must already
  exist and have a revision label; it is never overwritten. Tagged images are
  retained so an Auto Scaling replacement can still pull the version named in
  its launch template. Untagged images expire after 7 days; clean up old tagged
  images only after confirming no launch template or rollback process uses them.
- The runtime role is limited to the ECR repository, CloudWatch log group,
  application bucket, database secret, and read-only live dashboard APIs.
- GitHub uses short-lived OIDC credentials instead of static keys.
- The Terraform apply role is an existing AWS identity; inspect and scope its
  state access, infrastructure permissions, and EC2-only `iam:PassRole` access.
  Terraform creates separate plan and application release roles with narrower
  policies.
- The bootstrap identity must be allowed to create and secure the state
  bucket. The EC2 runtime role is separate and only needs ECR pull,
  CloudWatch publish, application-bucket access, database-secret read, and
  read-only dashboard describe permissions.
- Terraform state is encrypted, versioned, locked, and sensitive.

The project uses separate identities for distinct jobs:

| Role | Trust principal | Purpose | Managed by |
|---|---|---|---|
| `cloudops-github-terraform-deploy` | GitHub OIDC provider, restricted to this repository's `staging` environment | Manually approved Terraform provisioning | AWS account administrator / optional bootstrap root |
| `cloudops-github-terraform-plan` | GitHub OIDC provider, restricted to this repository's `pull_request` subject | Read-only infrastructure plan and state locking | Staging Terraform after first apply |
| `cloudops-github-app-deploy` | GitHub OIDC provider, restricted to this repository's `staging-app` environment | ECR push, image pointer update, and ASG refresh | Staging Terraform after first apply |
| `cloudops-demo-staging-ec2-runtime` | `ec2.amazonaws.com` | App image pull, logs, app bucket, DB secret, read-only dashboard status | Staging Terraform |
| Auto Scaling service-linked role | AWS service-linked role | EC2 Auto Scaling operations | AWS creates/manages it when Auto Scaling is first used |

The first role needs both a trust policy and an identity permissions policy.
The EC2 role is created by Terraform and must never be reused by GitHub
Actions. The account's one-time operator identity (prefer AWS IAM Identity
Center/SSO) creates or verifies the OIDC provider, state bucket, and GitHub
deployment role; it is not stored in GitHub Actions.

Do not report credentials, private keys, state, or sensitive logs in issues.
Use a private channel for security reports.

## Operations and troubleshooting

Routine checks include ALB target health, 5xx/latency, Auto Scaling activity,
CloudWatch application/bootstrap logs, RDS availability/backups, `/health`,
`/ready`, and `/api/dashboard`.

For an unhealthy target, inspect the target group, ALB security group,
application port, `/health`, and container logs. For bootstrap or image
failures, inspect `/var/log/cloud-init-output.log`, ECR permissions, region,
repository URL, and the immutable image tag. For database failures, verify
the secret ARN, IAM policy, security-group reference, routes, and RDS status
without printing the secret. For state-lock failures, identify the active run;
never delete a lock blindly.

Rollback uses the previous immutable ECR tag through the application release
workflow. Do not reuse or mutate release tags. Preserve RDS backups and state
versions. Teardown is an explicit operator action and must protect data before
removing infrastructure.

## Local validation

Install development dependencies and run:

```bash
python3 -m pip install -r app/requirements-dev.txt
make test
make lint
make docker-build
make terraform-fmt
make terraform-validate
make security-scan
```

Or use:

```bash
./scripts/local-test.sh
./scripts/terraform-check.sh
./scripts/validate-config.sh
```

Local checks do not run AWS provisioning, `terraform apply`, or
`terraform destroy`. Without AWS credentials and a real database,
`/health` should be healthy while `/ready` and AWS dashboard fields should be
unavailable.

## Cost and design notes

Main cost drivers are NAT gateways, ALB hours and LCUs, EC2, RDS class/storage
and backups, CloudWatch ingestion/retention, ECR storage, S3 requests/storage,
and public IPv4 addresses. Use the AWS Pricing Calculator for the selected
region and traffic profile. A single NAT gateway is cheaper; one per AZ
improves availability. Expire logs and images deliberately while retaining
required backups and state.

## License

See [`LICENSE`](LICENSE).
