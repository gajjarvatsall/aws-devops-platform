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
.github/workflows/           Single CI/CD workflow: stage-deploy.yaml
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

[`stage-deploy.yaml`](.github/workflows/stage-deploy.yaml) is the only
application deployment workflow. Pull requests and pushes to `main` run tests,
lint, dependency audit, a credential-pattern check, Docker build, Terraform
formatting, and Terraform validation without AWS credentials. Deployment is
started explicitly with `workflow_dispatch` from `main`; the `staging`
environment approval happens before AWS credentials are issued.

Normal deployments build or verify an immutable `sha-<commit>` ECR image, make
a Terraform plan, reject delete/replace changes by default, apply that exact
plan, wait for healthy ALB targets, and check `/health`. The plan binary stays
on the ephemeral runner; planned values are not printed or uploaded. The
deployment job does not temporarily scale a running service to zero.

For the first deployment only, use manual dispatch with `deploy=true` and
`bootstrap=true`. It creates the infrastructure with zero EC2 capacity, pushes
the application image, then applies the initial rollout. Do not use bootstrap
mode after the environment is running. For rollback, manually dispatch with
`deploy=true`, leave `bootstrap=false`, and provide an existing immutable ECR
`image_tag`. Destructive Terraform plans fail unless the manual run explicitly
sets `allow_destroy=true`.

The workflow targets these repository-specific values. Verify them against the
AWS account before deployment:

| Setting | Value |
|---|---|
| AWS account | `337909740274` |
| Region | `ap-south-1` |
| Deployment role | `cloudops-github-terraform-deploy` |
| Terraform state bucket | `aws-vg-cloudops-tf-state` |
| Terraform state key | `staging/terraform.tfstate` |
| Terraform project/environment | `cloudops-demo-staging` |
| Application URL | HTTP using the ALB generated hostname |

No AWS access keys or database credentials belong in GitHub variables or
secrets. Non-secret deployment configuration is stored in the workflow.

### 1. Verify the AWS GitHub OIDC provider

In AWS Console, open **IAM → Identity providers** and confirm this provider:

- URL: `https://token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`
- ARN: `arn:aws:iam::337909740274:oidc-provider/token.actions.githubusercontent.com`

If absent, create an OpenID Connect provider with that URL and audience in
account `337909740274`. The provider and deployment role must be in the same
account.

### 2. Set the deployment role trust policy

GitHub created this repository on October 12, 2026. Its OIDC subject includes
immutable owner and repository IDs: owner `82715470`, repository `1415557208`.
In **IAM → Roles → `cloudops-github-terraform-deploy` → Trust relationships →
Edit trust policy**, use this exact trust document:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "GitHubActionsOidcTrust",
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::337909740274:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:gajjarvatsall@82715470/aws-devops-platform@1415557208:environment:staging"
        }
      }
    }
  ]
}
```

The deploy job declares environment `staging`, so AWS must trust the exact
environment subject above. Name the environment exactly `staging`, restrict
deployments to `main`, and require a reviewer. The deployment job always uses
this protected environment.

### 3. Attach deployment permissions separately

The trust document permits role assumption; it does not grant AWS service
permissions. Inspect the role's **Permissions** tab and attach a separate,
reviewed least-privilege identity policy. It must cover the S3 state object and
lockfile, plus staging resources managed here: VPC, EC2 and launch templates,
Auto Scaling, ELB, RDS, ECR, S3, CloudWatch Logs, Secrets Manager, and the EC2
runtime IAM role/profile/policies. Scope `iam:PassRole` to that runtime role
and require `iam:PassedToService` to equal `ec2.amazonaws.com`. Do not attach
`AdministratorAccess` or put permissions in the trust document.

This repository does not contain the account's attached deployment policy,
and the latest failure occurs before AWS evaluates that policy. An AWS
administrator should inspect the existing role permissions before deployment.
For an auditable policy starting point, create a Terraform plan using approved
short-lived AWS admin/SSO access, render it to JSON in a private local folder,
and use IAM Policy Autopilot. Plans may contain secrets; do not print, upload,
or commit them:

```bash
umask 077
terraform -chdir=environments/staging init \
  -backend-config="bucket=aws-vg-cloudops-tf-state" \
  -backend-config="region=ap-south-1"
terraform -chdir=environments/staging plan -out=/private/tmp/staging-plan.tfplan
terraform -chdir=environments/staging show -json \
  /private/tmp/staging-plan.tfplan > /private/tmp/staging-plan.json
uvx iam-policy-autopilot@latest generate-policies \
  /private/tmp/staging-plan.json --region ap-south-1 --account 337909740274 --pretty
rm -f /private/tmp/staging-plan.tfplan /private/tmp/staging-plan.json
```

Review and scope the generated policy before attachment. It does not replace
the explicit state-bucket permissions or prove least privilege by itself.

The EC2 runtime role is a different identity. To produce a candidate runtime
policy from the app's actual boto3 calls and the staging Terraform directory,
run this separately and review the output before changing the policy in
`modules/security-groups/main.tf`:

```bash
uvx iam-policy-autopilot@latest generate-policies \
  /Users/vatsalgajjar/Documents/aws-devops-platform/app/app.py \
  --region ap-south-1 --account 337909740274 \
  --service-hints secretsmanager autoscaling elasticloadbalancing rds ecr \
  --tf-dir /Users/vatsalgajjar/Documents/aws-devops-platform/environments/staging \
  --pretty
```

### 4. Configure GitHub deployment protection

In **Repository Settings → Environments**, create `staging`, add required
reviewers, and restrict deployment branches to `main`. AWS access keys and
database credentials are not needed as environment secrets.

### 5. Prepare remote Terraform state

The workflow requires the S3 bucket `aws-vg-cloudops-tf-state` in
`ap-south-1`. The backend uses encryption, versioning, and S3 native lockfiles.
Confirm public access is blocked and the deployment role can read/write
`staging/terraform.tfstate` and its `.tflock` object. If the bucket does not
exist, copy the example, review the bucket name and region, then create it with
the one-time AWS SSO/operator identity:

```bash
cp bootstrap/backend/bootstrap.tfvars.example bootstrap/backend/bootstrap.tfvars
terraform -chdir=bootstrap/backend init
terraform -chdir=bootstrap/backend plan -var-file=bootstrap.tfvars
terraform -chdir=bootstrap/backend apply -var-file=bootstrap.tfvars
```

Only apply if the plan creates the intended bucket and security settings. If
the bucket already exists but is not in bootstrap Terraform state, import its
resources before applying; do not attempt to create a duplicate or replace it.
Keep bootstrap state private and backed up. Never delete a lock while a run may
be active.

### 6. Start deployment

For a new empty staging state, open **Actions → Stage deploy → Run workflow**,
select `main`, set `deploy=true` and `bootstrap=true`, leave `image_tag` blank,
and keep `allow_destroy=false`. Approve the `staging` environment when GitHub
requests it. Later pushes to `main` run validation only. Start each deployment
manually from `main` with `deploy=true`; the protected environment approval is
still required. For a rollback, manually dispatch with `deploy=true`,
`bootstrap=false`, and an existing immutable `image_tag`. Only set
`allow_destroy=true` for an intentional, reviewed destructive change.

The ALB serves HTTP because this setup has no domain name or ACM certificate.
Use `/health` to check the app; `/ready` also requires a working database path.

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
- The GitHub deployment role is external to this repository and must grant
  only the Terraform actions and resources required by staging. It needs
  access to the encrypted/versioned state bucket and its native lockfile,
  plus permissions for the VPC, ALB, Auto Scaling, EC2, RDS, ECR, S3,
  CloudWatch, IAM pass-role, and Secrets Manager resources managed here.
- The bootstrap identity must be allowed to create and secure the state
  bucket. The EC2 runtime role is separate and only needs ECR pull,
  CloudWatch publish, application-bucket access, database-secret read, and
  read-only dashboard describe permissions.
- Terraform state is encrypted, versioned, locked, and sensitive.

The project uses separate identities for distinct jobs:

| Role | Trust principal | Purpose | Managed by |
|---|---|---|---|
| `cloudops-github-terraform-deploy` | GitHub OIDC provider, restricted to this repository's `staging` environment | Terraform provisioning, remote state, ECR publish, health checks | AWS account administrator / optional bootstrap root |
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

Rollback uses the previous immutable ECR tag through the same reviewed staging
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
