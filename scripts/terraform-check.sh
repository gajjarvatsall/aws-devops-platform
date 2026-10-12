#!/usr/bin/env bash
set -euo pipefail
terraform fmt -check -recursive
for directory in bootstrap/backend environments/dev environments/staging environments/prod; do
  terraform -chdir="$directory" init -backend=false -input=false
  terraform -chdir="$directory" validate
done

