# Troubleshooting

* **Unhealthy target:** inspect target health, ALB security group, application
  port, `/health`, and `docker logs` through the instance session.
* **Failed bootstrap or missing image:** inspect `/var/log/cloud-init-output.log`,
  instance role ECR permissions, region, repository URL, and immutable tag.
* **Secrets or RDS failures:** confirm the secret ARN, role policy, DB
  security-group reference, subnet routes, and RDS status without printing the
  secret.
* **Certificate failure:** confirm the ACM certificate is in the ALB region,
  domain ownership validation completed, and DNS records are correct.
* **State lock failure:** inspect the lockfile owner and wait for the active
  run; do not delete a lock without confirming the process is gone.

Useful read-only checks include `aws elbv2 describe-target-health`,
`aws autoscaling describe-auto-scaling-groups`, `aws logs tail`, and
`aws rds describe-db-instances`. These commands are documentation only and are
not run by local validation.

