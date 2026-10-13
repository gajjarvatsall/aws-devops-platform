#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <plan-file> <allow-destroy:true|false>" >&2
  exit 2
fi

plan_file="$1"
allow_destroy="$2"

if [[ ! -f "$plan_file" ]]; then
  echo "Terraform plan file not found: $plan_file" >&2
  exit 2
fi

if [[ "$allow_destroy" != "true" && "$allow_destroy" != "false" ]]; then
  echo "allow-destroy must be true or false." >&2
  exit 2
fi

echo "Planned resource changes (addresses and actions only):"
terraform show -json "$plan_file" |
  jq -r '.resource_changes[]? | "\(.address): \(.change.actions | join(","))"'

delete_count="$(terraform show -json "$plan_file" |
  jq '[.resource_changes[]? | select(.change.actions | index("delete"))] | length')"

if (( delete_count > 0 )); then
  if [[ "$allow_destroy" != "true" ]]; then
    echo "Plan includes $delete_count delete/replace resource change(s)." >&2
    echo "Replacement reasons (resource addresses and changed attribute paths only):" >&2
    terraform show -json "$plan_file" |
      jq -r '
        .resource_changes[]?
        | select(.change.actions | index("delete"))
        | "- \(.address): \((.change.replace_paths // []) | map(map(tostring) | join(".")) | if length == 0 then "provider did not report attribute paths" else join(", ") end)"
      ' >&2
    echo "Review these replacement paths and correct the configuration/state mismatch before applying." >&2
    exit 1
  fi
  echo "Destructive changes explicitly allowed by workflow_dispatch input."
fi
