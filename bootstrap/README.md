# State backend bootstrap

This configuration is deliberately separate from the environment roots and
does not configure an S3 backend. Run it with local state once, review the
plan, and then protect that state file. After the bucket exists, copy its name
and region into a local partial backend configuration (never commit secrets or
state) and initialize each environment with its own key:

```bash
terraform -chdir=backend init
terraform -chdir=backend plan -var-file=bootstrap.tfvars
terraform -chdir=backend apply -var-file=bootstrap.tfvars # operator-authorized step
terraform -chdir=environments/dev init -backend-config=backend-config.hcl
```

Terraform 1.6+ native S3 lockfiles (`use_lockfile = true`) are used; no
DynamoDB table is required. Backend bucket versioning and encryption protect
recovery, but access to the state bucket must still be tightly restricted.

The optional `github-oidc.tf` resource creates only a tightly scoped trust
relationship for `repo:ORG/REPOSITORY` on one branch. Attach a separately
reviewed least-privilege provisioning policy before enabling it; the example
intentionally grants no permissions by itself.
