#!/usr/bin/env bash
# Deterministic tests for propose-system-updates.sh's one-shot guard.
# Uses a scratch TMPDIR so this never touches a real session's marker
# file, and never depends on an actual session transcript.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/propose-system-updates.sh"

command -v jq >/dev/null 2>&1 || {
  echo "ERROR: jq is required to run this test" >&2
  exit 1
}

PASS=0
FAIL=0
SCRATCH_TMPDIR="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_TMPDIR"' EXIT

check() {
  local name="$1" actual="$2" expected="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name (expected '$expected', got '$actual')" >&2
    FAIL=$((FAIL + 1))
  fi
}

SESSION_ID="test-session-$$"
INPUT="$(jq -n --arg sid "$SESSION_ID" '{session_id:$sid, hook_event_name:"Stop"}')"

# 1. First Stop this session: must block with continue:false and a reason.
OUTPUT_1="$(TMPDIR="$SCRATCH_TMPDIR" "$HOOK" <<<"$INPUT")"
CONTINUE_1="$(jq -r '.continue' <<<"$OUTPUT_1" 2>/dev/null || echo "MISSING")"
REASON_1="$(jq -r '.stopReason // empty' <<<"$OUTPUT_1" 2>/dev/null || true)"
check "first Stop blocks (continue=false)" "$CONTINUE_1" "false"
[[ -n "$REASON_1" ]] && { echo "PASS: first Stop includes a stopReason"; PASS=$((PASS + 1)); } || {
  echo "FAIL: first Stop missing stopReason" >&2
  FAIL=$((FAIL + 1))
}

# 2. Second Stop, same session: must allow (no continue:false).
OUTPUT_2="$(TMPDIR="$SCRATCH_TMPDIR" "$HOOK" <<<"$INPUT")"
if [[ -z "$OUTPUT_2" ]]; then
  echo "PASS: second Stop in same session produces no output (allows stop)"
  PASS=$((PASS + 1))
else
  CONTINUE_2="$(jq -r '.continue // "true"' <<<"$OUTPUT_2" 2>/dev/null || echo "true")"
  check "second Stop in same session allows (continue != false)" "$CONTINUE_2" "true"
fi

# 3. A different session_id: must block again (independent marker).
OTHER_SESSION_ID="test-session-other-$$"
OTHER_INPUT="$(jq -n --arg sid "$OTHER_SESSION_ID" '{session_id:$sid, hook_event_name:"Stop"}')"
OUTPUT_3="$(TMPDIR="$SCRATCH_TMPDIR" "$HOOK" <<<"$OTHER_INPUT")"
CONTINUE_3="$(jq -r '.continue' <<<"$OUTPUT_3" 2>/dev/null || echo "MISSING")"
check "different session gets its own first-Stop block" "$CONTINUE_3" "false"

# 4. Missing session_id: must no-op (exit 0, no output) rather than error.
NO_SID_INPUT='{"hook_event_name":"Stop"}'
OUTPUT_4="$(TMPDIR="$SCRATCH_TMPDIR" "$HOOK" <<<"$NO_SID_INPUT")"
if [[ -z "$OUTPUT_4" ]]; then
  echo "PASS: missing session_id no-ops safely"
  PASS=$((PASS + 1))
else
  echo "FAIL: missing session_id should no-op, got: $OUTPUT_4" >&2
  FAIL=$((FAIL + 1))
fi

echo ""
echo "$PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
