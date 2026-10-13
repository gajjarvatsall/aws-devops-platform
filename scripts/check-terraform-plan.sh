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
    echo "Replacement differences (resource addresses and attribute paths only; values are not printed):" >&2
    terraform show -json "$plan_file" |
      jq -r '
        def changed_paths($before; $after; $path):
          if (($before | type) == "object" and ($after | type) == "object") then
            ((($before | keys) + ($after | keys)) | unique) as $keys
            | [$keys[] as $key | changed_paths($before[$key]; $after[$key]; $path + [$key])[]]
          elif $before == $after then
            []
          else
            [($path | join("."))]
          end;
        .resource_changes[]?
        | select(.change.actions | index("delete"))
        | . as $resource
        | ($resource.change.replace_paths // [] | map(map(tostring) | join("."))) as $replace_paths
        | if ($replace_paths | length) > 0 then
            "- \($resource.address): \($replace_paths | join(", "))"
          else
            (changed_paths($resource.change.before; $resource.change.after; []) | unique | join(", ")) as $changed_paths
            | "- \($resource.address): \(if $changed_paths == "" then "no attribute paths available" else $changed_paths end)"
          end
      ' >&2
    echo "Review these replacement paths and correct the configuration/state mismatch before applying." >&2
    exit 1
  fi
  echo "Destructive changes explicitly allowed by workflow_dispatch input."
fi
