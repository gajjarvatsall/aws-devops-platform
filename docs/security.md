# Security design

Public ingress is limited to ALB TCP 443 and optional TCP 80 redirect traffic.
EC2 and RDS have no public addresses or public ingress rules. Internal traffic
uses security-group references. RDS and all S3 buckets are encrypted, S3
requires TLS, IMDSv2 is required, and release ECR tags are immutable.

The EC2 role is scoped to the repository, application log group, application
bucket, and database secret. ECR authorization-token retrieval is the one
required account-level action. GitHub Actions must assume a dedicated OIDC
role whose trust policy is restricted to this repository and approved branch or
environment; never use static keys.

Terraform state can contain the generated database password and secret value.
Use the encrypted, versioned bootstrap bucket, native S3 lockfile, restricted
IAM access, short-lived plans, and no public artifacts. Production requires a
protected GitHub environment with reviewers and deletion protection.

