# Operations runbook

## Routine checks

Check ALB target health, 5xx/latency metrics, ASG activity, CloudWatch
application/bootstrap logs, RDS availability, backup status, and certificate
expiry. Test `/health` for liveness and `/ready` for database readiness.

## Release and rollback

Build and scan a new immutable ECR tag, run CI, review the Terraform plan, and
deploy through the manually initiated workflow. To roll back, set
`image_tag` to the last known-good immutable tag and perform the same reviewed
plan/apply flow. Do not mutate or reuse release tags.

## Recovery and teardown

For an unhealthy rollout, stop scaling changes, inspect instance refresh and
bootstrap logs, and restore the previous tag. Preserve RDS backups and state
versions. Teardown is a deliberate operator action: disable production
protection only after approval, snapshot data, and destroy environments before
the backend bucket. Never delete state as a shortcut.

