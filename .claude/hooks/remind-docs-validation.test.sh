#!/usr/bin/env bash
# Deterministic tests for remind-docs-validation.sh — fixture tool_input
# paths in, assert the reminder fires only for the intended path shapes.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/remind-docs-validation.sh"

command -v jq >/dev/null 2>&1 || {
  echo "ERROR: jq is required to run this test" >&2
  exit 1
}

PASS=0
FAIL=0

# run_case NAME FILE_PATH EXPECT_MESSAGE(0/1) [SUBSTRING]
run_case() {
  local name="$1" file_path="$2" expect="$3" substr="${4:-}"
  local input output msg
  input="$(jq -n --arg fp "$file_path" '{tool_name:"Edit", tool_input:{file_path:$fp}}')"
  output="$("$HOOK" <<<"$input")"
  msg="$(jq -r '.systemMessage // empty' <<<"$output" 2>/dev/null || true)"

  if [[ "$expect" == "1" ]]; then
    if [[ -n "$msg" ]] && { [[ -z "$substr" ]] || grep -qF "$substr" <<<"$msg"; }; then
      echo "PASS: $name (message present)"
      PASS=$((PASS + 1))
    else
      echo "FAIL: $name (expected a message containing '$substr', got: '$msg')" >&2
      FAIL=$((FAIL + 1))
    fi
  else
    if [[ -z "$msg" ]]; then
      echo "PASS: $name (no message, as expected)"
      PASS=$((PASS + 1))
    else
      echo "FAIL: $name (expected no message, got: '$msg')" >&2
      FAIL=$((FAIL + 1))
    fi
  fi
}

run_case "mermaid diagram edited" \
  "docs/01-architecture/network/l2-vcn.mmd" 1 "validate:mermaid"
run_case "threat-model instance edited" \
  "docs/03-threat-model/model/instances/network.yaml" 1 "validate:threat-model"
run_case "unrelated docs file edited" \
  "docs/00-overview/roadmap.md" 0
run_case "infrastructure file edited" \
  "infrastructure/modules/network/gateways.tf" 0
run_case "mmd file outside docs/01-architecture (legacy docs/arch/)" \
  "docs/arch/cloud-deployment.mmd" 1 "validate:mermaid"

echo ""
echo "$PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
