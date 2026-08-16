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

# Unique per-run output dir: a fixed /tmp path would collide across
# concurrent pre-commit runs and doesn't get cleaned up.
outdir="$(mktemp -d)"
trap 'rm -rf "$outdir"' EXIT

exit_code=0
for f in "$@"; do
  echo "validating $f"
  # --no-sandbox/--disable-setuid-sandbox (in $PUPPETEER_CONFIG) is required
  # for mmdc's headless Chromium to launch in most CI and containerized dev
  # environments (this repo's own GitHub Actions job needs it too — see
  # .github/workflows/docs.yml). Local machines with a working Chromium
  # sandbox lose a little defense-in-depth here; there's no per-environment
  # config in this repo, so this trade-off applies everywhere mmdc runs.
  if ! "$MMDC" -p "$PUPPETEER_CONFIG" -i "$f" -o "$outdir/$(basename "$f" .mmd).svg" >/dev/null; then
    echo "FAILED - $f" >&2
    exit_code=1
  fi
done
exit "$exit_code"
