# CloudOps AWS DevOps Platform

This repository contains a staging-only AWS platform and a small Flask
application for a technical assignment. It has not been deployed to AWS and
contains no credentials or live endpoint.

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

## One CI/CD workflow

[`stage-deploy.yaml`](.github/workflows/stage-deploy.yaml) is the only GitHub
Actions workflow. It runs:

1. Install Python dependencies.
2. Run pytest.
3. Run Ruff.
4. Run `pip-audit`.
5. Build the Docker image.
6. Format and validate Terraform roots.
7. Assume the staging deployment role through GitHub OIDC.
8. Initialize staging remote state.
9. Wait for one protected `staging` environment approval.
10. Generate and display the base infrastructure plan, then apply it with zero
    EC2 capacity.
11. Read the real ECR repository URL from Terraform.
12. Build or safely reuse an immutable image tag.
13. Generate and apply the rollout plan in the same approved deployment job.

Pull requests run validation only. A push to `main` runs validation and then
pauses once at the protected `staging` environment. After one approval, the
workflow generates and displays the base plan, applies it with zero capacity,
builds or verifies the image, generates the rollout plan, and applies it.
Manual runs are also supported by starting `workflow_dispatch` with
`deploy=true`. The plan files are displayed in the approved deployment job and
can contain sensitive infrastructure values, so workflow access must be
controlled.

The workflow defines the fixed staging region, deployment role ARN, state
bucket, state region, and project name directly. This avoids failing because
non-secret values are missing from an Actions-variable scope. Keep the
`staging` Environment for required reviewers and deployment-branch restrictions.

Configure the `staging` Environment with required reviewers and restrict its
deployment branches to `main`. The single deployment job uses this Environment,
so GitHub pauses once before any AWS deployment steps run. The AWS OIDC trust
policy must allow the exact `staging` environment subject.

The OIDC trust policy must restrict the repository and approved branch or
environment. The deployment role must have a separately reviewed
least-privilege provisioning policy. No static AWS access keys are used.

The bootstrap OIDC role is optional and disabled by default. If you enable
`create_github_oidc_role`, set these bootstrap inputs to real values:

```hcl
create_github_oidc_role  = true
github_oidc_provider_arn = "arn:aws:iam::<account-id>:oidc-provider/token.actions.githubusercontent.com"
github_repository        = "OWNER/REPOSITORY"
github_branch            = "refs/heads/main"
github_environment       = "staging"
```

The bootstrap configuration creates the trust relationship only; it does not
create the deployment role's Terraform permissions. The OIDC provider itself
must also exist in the AWS account.

## First deployment

The state bucket must exist before staging can initialize its backend.

1. Copy `bootstrap/backend/bootstrap.tfvars.example` to a local tfvars file.
2. Choose a globally unique state bucket name and review the bootstrap plan.
3. Run the bootstrap apply only with explicit operator authorization:

```bash
terraform -chdir=bootstrap/backend init
terraform -chdir=bootstrap/backend plan -var-file=bootstrap.tfvars
terraform -chdir=bootstrap/backend apply -var-file=bootstrap.tfvars
```

4. Configure the repository variables and protected GitHub `staging`
   environment.
5. Push to `main`; validation runs automatically and then the workflow pauses
   for one staging approval. Alternatively, manually start `Stage deploy` with
   `deploy=true`.
6. Verify the resulting HTTP ALB URL and `/health`, `/ready`, and
   `/api/dashboard`.

The approved workflow performs the infrastructure and image sequence after the
environment gate. Do not use `terraform -target` as normal architecture.
Review every plan, and never commit backend configuration, credentials,
Terraform state, generated plans, or generated tfvars.

## Security design

- The ALB is the only public ingress point.
- EC2 and RDS are private and use security-group references.
- RDS and S3 are encrypted; S3 requires TLS and blocks public access.
- EC2 requires IMDSv2 and uses an encrypted EBS volume.
- ECR tags are immutable and scan on push. Re-running a commit deployment
  reuses an existing `sha-*` image only after pulling it and verifying its
  OCI revision label matches the workflow commit. A user-supplied rollback tag
  must already exist and have a revision label; it is never overwritten.
  `v*` release tags retain the 20
  newest images, `sha-*` deployment images expire after 30 days, and untagged
  images expire after 7 days. Keep a release tag for any rollback image that
  must outlive the SHA retention window.
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

Install Python dependencies and run:

```bash
python3 -m pip install -r app/requirements.txt
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
