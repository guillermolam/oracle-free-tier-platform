#!/usr/bin/env bash
# PreToolUse hook on Bash. DEFENSE-IN-DEPTH ONLY — the hard boundary is
# .claude/settings.json's permissions.deny list. Claude Code's own docs
# document the hook "if" matcher as best-effort and fails open on
# unparseable commands, so this script parses tool_input.command itself
# (not the matcher's "if" field) rather than relying on that. If this
# script is ever removed, misconfigured, or fails to run, the deny rules
# in settings.json still block every pattern below on their own — this
# script only adds a clearer explanation than the default permission
# denial message. Keep REQUIRED_DENY_PATTERNS below in sync by hand with
# .claude/settings.json's permissions.deny and
# .claude/tests/settings-permissions.test.sh's REQUIRED_DENY array.
set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

INPUT="$(cat)"
COMMAND="$(jq -r '.tool_input.command // empty' <<<"$INPUT" 2>/dev/null || true)"
[[ -n "$COMMAND" ]] || exit 0

# Extended-regex patterns mirroring settings.json's permissions.deny Bash
# rules. Anchored loosely (not to command start) because commands can be
# wrapped (e.g. "cd x && tofu apply ...", "env FOO=bar terragrunt destroy").
DENY_PATTERNS=(
  'tofu[[:space:]]+apply'
  'tofu[[:space:]]+destroy'
  'tofu[[:space:]]+import'
  'tofu[[:space:]]+state[[:space:]]'
  'tofu[[:space:]]+force-unlock'
  'terragrunt[[:space:]]+apply'
  'terragrunt[[:space:]]+destroy'
  'terragrunt[[:space:]]+run-all[[:space:]]+apply'
  'terragrunt[[:space:]]+run-all[[:space:]]+destroy'
  'git[[:space:]]+push[[:space:]].*(--force|-f)([[:space:]]|$)'
  'git[[:space:]]+reset[[:space:]]+--hard'
  'git[[:space:]]+clean[[:space:]]+-f'
  'git[[:space:]]+branch[[:space:]]+-D'
  'pass-cli[[:space:]]+run'
)

for pattern in "${DENY_PATTERNS[@]}"; do
  if [[ "$COMMAND" =~ $pattern ]]; then
    jq -n \
      --arg reason "Blocked by .claude/hooks/block-destructive-commands.sh: this repo requires state-mutating tofu/terragrunt commands, destructive git history rewrites, and direct pass-cli invocation to be run by a human, not an agent. Terraform/OCI applies go through infrastructure/live/scripts/tg manually — see infrastructure/README.md. This is a defense-in-depth message; the actual boundary is .claude/settings.json's permissions.deny list." \
      '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
    exit 0
  fi
done

exit 0
