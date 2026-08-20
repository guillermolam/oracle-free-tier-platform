#!/usr/bin/env bash
# Stop hook. Implements the "system evolution" practice: one reflection
# pass per session on whether anything that happened reveals a gap in
# AGENTS.md, an agent's MUST/MUST NOT list, or a skill. Advisory only —
# this script has no Write/Edit capability and never touches
# AGENTS.md/.claude/** itself; it only asks Claude to propose a change,
# which a human then accepts or discards.
#
# Claude Code's own hooks docs do not document a "stop_hook_active" field
# or any built-in repeat-call guard for Stop hooks (confirmed against
# code.claude.com/docs/en/hooks at authoring time — see TODO(system-
# evolution) in the design plan). This script implements its own one-shot
# guard with a session_id-keyed marker file so it fires exactly once per
# session instead of blocking every Stop attempt forever.
set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

INPUT="$(cat)"
SESSION_ID="$(jq -r '.session_id // empty' <<<"$INPUT" 2>/dev/null || true)"
[[ -n "$SESSION_ID" ]] || exit 0

MARKER_DIR="${TMPDIR:-/tmp}/claude-system-evolution"
MARKER="$MARKER_DIR/$SESSION_ID"
mkdir -p "$MARKER_DIR"

if [[ -e "$MARKER" ]]; then
  # Already reflected once this session — let the stop proceed.
  exit 0
fi

touch "$MARKER"

REASON='Before this session ends: did anything happen that reveals a gap in AGENTS.md, an agent'"'"'s MUST/MUST NOT list, or a skill — a correction from the user, a repeated mistake, a validation step run too late? If so, propose (do not apply) one specific, concrete addition: quote the exact wording and name the target file. If nothing qualifies, say so in one sentence and finish. This reflection runs once per session — do not repeat it.'

jq -n --arg reason "$REASON" '{continue: false, stopReason: $reason}'
exit 0
