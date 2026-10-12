#!/usr/bin/env bash
set -euo pipefail
if grep -RInE '(AKIA[0-9A-Z]{16}|BEGIN (RSA|OPENSSH) PRIVATE KEY|password[[:space:]]*=[[:space:]]*["'\''][^"'\'']+)' \
  --exclude-dir=.git --exclude-dir=.venv --exclude='*.tfstate*' --exclude='*.lock.hcl' .; then
  echo "Potential credential material detected." >&2
  exit 1
fi
echo "No obvious credential patterns found."
