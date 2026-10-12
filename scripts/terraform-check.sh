#!/usr/bin/env bash
set -euo pipefail
terraform fmt -check -recursive
for directory in bootstrap/backend environments/staging; do
  terraform -chdir="$directory" init -backend=false -input=false
  terraform -chdir="$directory" validate
done
for directory in modules/*; do
  [ -d "$directory" ] || continue
  terraform -chdir="$directory" init -backend=false -input=false
  terraform -chdir="$directory" validate
done
