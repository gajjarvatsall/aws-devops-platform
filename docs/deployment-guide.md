# Deployment guide

## Prerequisites

Install Terraform 1.6+, Docker, Python 3.12, and configure an AWS identity
only when you are ready to deploy. Supply a public domain and either a
DNS-validated ACM certificate ARN or the certificate validation resources you
operate separately. The regional ALB account ID must match AWS's current
documentation.

## Ordered first deployment

1. Copy `bootstrap/backend/bootstrap.tfvars.example`, choose a globally unique
   bucket name, and review the bootstrap plan. Apply it only with explicit
   operator authorization.
2. Create a local `backend-config.hcl` containing `bucket`, `region`, and
   optionally `profile`; do not commit it.
3. Initialize and validate `environments/dev`. Copy
   `terraform.tfvars.example` to `terraform.tfvars`, fill the certificate ARN
   and region values, and keep `desired_capacity = 0`.
4. Apply the base configuration. This creates ECR, networking, RDS, security,
   logging, and the zero-capacity ASG.
5. Authenticate Docker to the output ECR repository, build `app/`, and push an
   immutable version tag.
6. Set `image_tag` and desired/minimum capacity in local variables and apply
   again. Verify target health before using the ALB URL.

Do not use `terraform -target` as normal architecture. Staging and production
are intentionally manual and should use separate accounts/state access and
GitHub environment approvals.

