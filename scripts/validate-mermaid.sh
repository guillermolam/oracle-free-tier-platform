#!/usr/bin/env bash
# Validate Mermaid diagrams with mmdc (mirrors `npm run validate:mermaid` in CI).
# Usage: scripts/validate-mermaid.sh <file.mmd> [file2.mmd ...]
set -euo pipefail

MMDC="node_modules/.bin/mmdc"
PUPPETEER_CONFIG="docs/mermaid-puppeteer-config.json"

if [[ ! -x "$MMDC" ]]; then
  echo "ERROR - @mermaid-js/mermaid-cli not installed. Run - npm ci" >&2
  exit 1
fi

exit_code=0
for f in "$@"; do
  echo "validating $f"
  if ! "$MMDC" -p "$PUPPETEER_CONFIG" -i "$f" -o /tmp/mmdc-precommit.svg >/dev/null; then
    echo "FAILED - $f" >&2
    exit_code=1
  fi
done
exit "$exit_code"
