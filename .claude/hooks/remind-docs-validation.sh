#!/usr/bin/env bash
# PostToolUse hook on Edit|Write. Pure convenience — cannot block (the
# tool already ran) and has zero security consequence if removed or
# misconfigured. Nudges toward the matching validator immediately, instead
# of only discovering a validator failure at commit time via pre-commit.
set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

INPUT="$(cat)"
FILE_PATH="$(jq -r '.tool_input.file_path // empty' <<<"$INPUT" 2>/dev/null || true)"
[[ -n "$FILE_PATH" ]] || exit 0

MESSAGE=""
if [[ "$FILE_PATH" == *.mmd ]]; then
  MESSAGE="You just edited a Mermaid diagram ($FILE_PATH). Run: npm run validate:mermaid — before considering this edit done."
elif [[ "$FILE_PATH" == *docs/03-threat-model/model/* ]]; then
  MESSAGE="You just edited the threat-model corpus ($FILE_PATH). Run: npm run validate:threat-model — before considering this edit done."
fi

[[ -n "$MESSAGE" ]] || exit 0

jq -n --arg msg "$MESSAGE" '{systemMessage: $msg}'
exit 0
