#!/usr/bin/env bash
# Deterministic tests for block-destructive-commands.sh. Feeds fixture
# tool_input.command strings on stdin and asserts the JSON decision —
# no real Bash execution, no real tool calls, following the same
# self-test pattern as scripts/check-gpg-signing.test.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/block-destructive-commands.sh"

command -v jq >/dev/null 2>&1 || {
  echo "ERROR: jq is required to run this test" >&2
  exit 1
}

PASS=0
FAIL=0

# run_case NAME COMMAND EXPECTED_DECISION
# EXPECTED_DECISION is "deny" or "none" (no hookSpecificOutput at all).
run_case() {
  local name="$1" command="$2" expected="$3"
  local input output decision
  input="$(jq -n --arg cmd "$command" '{tool_name:"Bash", tool_input:{command:$cmd}}')"
  output="$("$HOOK" <<<"$input")"

  if [[ "$expected" == "none" ]]; then
    if [[ -z "$output" ]] || ! jq -e '.hookSpecificOutput' <<<"$output" >/dev/null 2>&1; then
      echo "PASS: $name (no deny, as expected)"
      PASS=$((PASS + 1))
    else
      echo "FAIL: $name (expected no deny, got: $output)" >&2
      FAIL=$((FAIL + 1))
    fi
    return
  fi

  decision="$(jq -r '.hookSpecificOutput.permissionDecision // empty' <<<"$output" 2>/dev/null || true)"
  if [[ "$decision" == "$expected" ]]; then
    echo "PASS: $name (decision=$decision)"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name (expected decision=$expected, got '$decision', output: $output)" >&2
    FAIL=$((FAIL + 1))
  fi
}

# Destructive commands — must all be denied.
run_case "tofu apply" "tofu apply -auto-approve" "deny"
run_case "tofu destroy" "tofu destroy" "deny"
run_case "tofu import" "tofu import oci_core_drg.this ocid1.drg.oc1..xxx" "deny"
run_case "tofu state rm" "tofu state rm oci_core_drg.this" "deny"
run_case "tofu force-unlock" "tofu force-unlock 12345" "deny"
run_case "terragrunt apply" "terragrunt apply" "deny"
run_case "terragrunt destroy" "terragrunt destroy" "deny"
run_case "terragrunt run-all apply" "terragrunt run-all apply" "deny"
run_case "git push --force" "git push --force origin main" "deny"
run_case "git push -f short flag" "git push -f origin main" "deny"
run_case "git reset --hard" "git reset --hard HEAD~1" "deny"
run_case "git clean -f" "git clean -f -d" "deny"
run_case "git branch -D" "git branch -D old-branch" "deny"
run_case "pass-cli run" "pass-cli run -- terragrunt plan" "deny"
run_case "wrapped destructive command" "cd infrastructure && tofu apply -auto-approve" "deny"

# Safe commands — must not be denied.
run_case "tofu plan" "tofu plan" "none"
run_case "tofu validate" "tofu validate" "none"
run_case "tofu fmt check" "tofu fmt -check -recursive" "none"
run_case "terragrunt plan" "terragrunt plan" "none"
run_case "git status" "git status" "none"
run_case "git push non-force" "git push origin feature-branch" "none"
run_case "unrelated command mentioning apply in a string" "echo 'do not run tofu apply here'" "deny"

echo ""
echo "$PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
