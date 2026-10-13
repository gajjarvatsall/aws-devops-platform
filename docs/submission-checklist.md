# Practical task submission checklist

## Implemented in the repository

- [x] Flask application source, container image, and automated application tests.
- [x] Terraform for a two-AZ VPC, public/private/isolated subnets, routes, IGW,
  and NAT gateways.
- [x] Private application Auto Scaling Group and launch template.
- [x] Public ALB with health checks and S3 access logging.
- [x] Private, encrypted, Multi-AZ MySQL RDS and generated Secrets Manager
  credentials.
- [x] Dedicated runtime and GitHub OIDC IAM roles; scoped security-group
  ingress to the ALB, app, and database paths.
- [x] Encrypted private app/log S3 buckets and immutable, scanned ECR images.
- [x] Separate CI, Terraform plan/apply, and application release workflows.
- [x] Architecture diagram in [`architecture.mmd`](architecture.mmd).
- [x] Deployment and AWS setup instructions in the root README.

## Requires AWS account setup and deployment

- [ ] Verify/create GitHub OIDC provider, scoped Terraform bootstrap role, and
  encrypted/versioned remote state bucket as described in the README.
- [ ] Configure protected GitHub `staging` and `staging-app` environments and
  repository branch protections.
- [ ] Review a Terraform plan and run the manual staging apply.
- [ ] Run the application release workflow and confirm two healthy ALB targets,
  `/health`, `/ready`, and the dashboard.
- [ ] Capture real GitHub Actions success screenshots, AWS resource screenshots,
  and the deployed application page for submission.
- [ ] Provide the generated application URL from the application release run.

## Intentional domain-related omission

The assignment asks for HTTPS with ACM and a working HTTPS URL. This project
uses the ALB's generated hostname over HTTP because no domain is available.
ACM certificate and DNS validation are intentionally omitted. To meet the
HTTPS requirement later, obtain a domain, create/validate an ACM certificate in
the ALB's region, add an HTTPS listener, and redirect HTTP to HTTPS.

## Important deployment boundary

Terraform changes are reviewed with a plan and applied only by the explicit
Terraform apply workflow after its environment approval. Application changes
are tested, built, and deployed by the application release workflow without
changing Terraform infrastructure.
