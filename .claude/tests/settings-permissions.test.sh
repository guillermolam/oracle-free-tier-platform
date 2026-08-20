#!/usr/bin/env bash
# Regression guard for the hard security boundary in ../settings.json:
# permissions.deny. This is deliberately a hardcoded copy of the required
# pattern list, not something derived cleverly from the file under test —
# a diff in this list is meant to be a visible, reviewable event. See
# .claude/agents/*.md and docs/02-decisions/ADR-0007/ADR-0008 for why each
# pattern is here: state-mutating tofu/terragrunt subcommands, destructive
# git history rewrites, and bare pass-cli invocation (secret resolution
# must stay inside infrastructure/live/scripts/tg's own exec chain).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_SETTINGS="$SCRIPT_DIR/../settings.json"

command -v jq >/dev/null 2>&1 || {
  echo "ERROR: jq is required to run this test" >&2
  exit 1
}

# The exact deny patterns settings.json must contain. Kept in sync by hand
# with .claude/settings.json and (once it exists) the pattern list parsed
# by .claude/hooks/block-destructive-commands.sh — see TODO(consistency)
# in the design plan for automating that second cross-check.
REQUIRED_DENY=(
  "Bash(tofu apply*)"
  "Bash(tofu destroy*)"
  "Bash(tofu import*)"
  "Bash(tofu state *)"
  "Bash(tofu force-unlock*)"
  "Bash(terragrunt apply*)"
  "Bash(terragrunt destroy*)"
  "Bash(terragrunt run-all apply*)"
  "Bash(terragrunt run-all destroy*)"
  "Bash(git push --force*)"
  "Bash(git push -f*)"
  "Bash(git reset --hard*)"
  "Bash(git clean -f*)"
  "Bash(git branch -D*)"
  "Bash(pass-cli run*)"
  "Read(**/.oci/**)"
  "Read(**/*.kubeconfig)"
  "Read(**/kubeconfig*)"
  "Read(**/*.env)"
  "Read(**/*.env.*)"
  "Read(**/id_rsa*)"
  "Read(**/id_ed25519*)"
  "Read(**/*talos*secret*)"
)

PASS=0
FAIL=0

# Prints (to stdout) the count of REQUIRED_DENY patterns missing from
# $1's permissions.deny array.
count_missing_deny() {
  local settings_file="$1" pattern missing=0
  for pattern in "${REQUIRED_DENY[@]}"; do
    jq -e --arg p "$pattern" '.permissions.deny // [] | index($p) != null' \
      "$settings_file" >/dev/null 2>&1 || missing=$((missing + 1))
  done
  echo "$missing"
}

# Prints (to stdout) the count of REQUIRED_DENY patterns that also appear
# verbatim in $1's permissions.allow array (a pasted-in-the-wrong-list bug).
count_allow_deny_overlap() {
  local settings_file="$1" pattern overlap=0
  for pattern in "${REQUIRED_DENY[@]}"; do
    jq -e --arg p "$pattern" '.permissions.allow // [] | index($p) != null' \
      "$settings_file" >/dev/null 2>&1 && overlap=$((overlap + 1))
  done
  echo "$overlap"
}

check() {
  local name="$1" actual="$2" expected="$3"
  if [[ "$actual" -eq "$expected" ]]; then
    echo "PASS: $name (got $actual, expected $expected)"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name (got $actual, expected $expected)" >&2
    FAIL=$((FAIL + 1))
  fi
}

# String-equality counterpart to check() — check() uses -eq (numeric) and
# must not be reused for string values like a permissionDecision.
check_str() {
  local name="$1" actual="$2" expected="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "PASS: $name (got '$actual', expected '$expected')"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name (got '$actual', expected '$expected')" >&2
    FAIL=$((FAIL + 1))
  fi
}

echo "--- known-good fixture: full deny coverage, no overlap ---"
check "good fixture has zero missing deny patterns" \
  "$(count_missing_deny "$SCRIPT_DIR/fixtures/settings-good.json")" 0
check "good fixture has zero allow/deny overlaps" \
  "$(count_allow_deny_overlap "$SCRIPT_DIR/fixtures/settings-good.json")" 0

echo ""
echo "--- known-bad fixture: self-test must actually detect the break ---"
BAD_MISSING="$(count_missing_deny "$SCRIPT_DIR/fixtures/settings-bad-missing-deny.json")"
if [[ "$BAD_MISSING" -gt 0 ]]; then
  echo "PASS: bad fixture's missing 'tofu apply' deny was detected ($BAD_MISSING missing)"
  PASS=$((PASS + 1))
else
  echo "FAIL: bad fixture should be missing at least one deny pattern but wasn't detected" >&2
  FAIL=$((FAIL + 1))
fi

echo ""
echo "--- real .claude/settings.json: the actual security boundary ---"
check "real settings.json has zero missing deny patterns" \
  "$(count_missing_deny "$REAL_SETTINGS")" 0
check "real settings.json has zero allow/deny overlaps" \
  "$(count_allow_deny_overlap "$REAL_SETTINGS")" 0

# TODO(consistency), resolved: cross-check that
# hooks/block-destructive-commands.sh (defense-in-depth) actually denies a
# representative command for every settings.json deny pattern, so the two
# independently-maintained layers can't silently drift apart. This is a
# behavioral check (run the hook, read its decision), not a textual diff,
# so it survives the hook script's regex being phrased differently from
# settings.json's glob syntax.
HOOK="$SCRIPT_DIR/../hooks/block-destructive-commands.sh"
if [[ -x "$HOOK" ]] && command -v jq >/dev/null 2>&1; then
  echo ""
  echo "--- hook/settings.json cross-check: every Bash deny pattern is also caught by the hook ---"
  # One representative real command per Bash deny pattern (Read(...) deny
  # patterns aren't Bash commands, so they're out of scope for this hook).
  declare -A REPRESENTATIVE_COMMAND=(
    ["Bash(tofu apply*)"]="tofu apply -auto-approve"
    ["Bash(tofu destroy*)"]="tofu destroy"
    ["Bash(tofu import*)"]="tofu import oci_core_drg.this ocid1.drg.oc1..xxx"
    ["Bash(tofu state *)"]="tofu state rm oci_core_drg.this"
    ["Bash(tofu force-unlock*)"]="tofu force-unlock 12345"
    ["Bash(terragrunt apply*)"]="terragrunt apply"
    ["Bash(terragrunt destroy*)"]="terragrunt destroy"
    ["Bash(terragrunt run-all apply*)"]="terragrunt run-all apply"
    ["Bash(terragrunt run-all destroy*)"]="terragrunt run-all destroy"
    ["Bash(git push --force*)"]="git push --force origin main"
    ["Bash(git push -f*)"]="git push -f origin main"
    ["Bash(git reset --hard*)"]="git reset --hard HEAD~1"
    ["Bash(git clean -f*)"]="git clean -f -d"
    ["Bash(git branch -D*)"]="git branch -D old-branch"
    ["Bash(pass-cli run*)"]="pass-cli run -- terragrunt plan"
  )
  for pattern in "${REQUIRED_DENY[@]}"; do
    [[ "$pattern" == Bash\(* ]] || continue
    cmd="${REPRESENTATIVE_COMMAND[$pattern]:-}"
    if [[ -z "$cmd" ]]; then
      echo "FAIL: no representative command registered for deny pattern: $pattern" >&2
      FAIL=$((FAIL + 1))
      continue
    fi
    hook_input="$(jq -n --arg cmd "$cmd" '{tool_name:"Bash", tool_input:{command:$cmd}}')"
    hook_output="$("$HOOK" <<<"$hook_input")"
    decision="$(jq -r '.hookSpecificOutput.permissionDecision // empty' <<<"$hook_output" 2>/dev/null || true)"
    check_str "hook denies representative command for $pattern" "$decision" "deny"
  done
else
  echo ""
  echo "SKIP: hooks/block-destructive-commands.sh not present yet or jq missing — cross-check skipped"
fi

echo ""
echo "$PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
