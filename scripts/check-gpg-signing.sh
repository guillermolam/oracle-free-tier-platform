#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  printf '%s\n' "Configure signing, then commit with: git commit -s -S" >&2
  exit 1
}

[[ "$(git config --bool --get commit.gpgsign 2>/dev/null || true)" == "true" ]] ||
  fail "commit.gpgsign must be enabled. Run: git config --local commit.gpgsign true"

GPG_FORMAT="$(git config --get gpg.format 2>/dev/null || true)"
[[ -z "$GPG_FORMAT" || "$GPG_FORMAT" == "openpgp" ]] ||
  fail "gpg.format must be openpgp (found: $GPG_FORMAT)"

SIGNING_KEY="$(git config --get user.signingkey 2>/dev/null || true)"
[[ -n "$SIGNING_KEY" ]] ||
  fail "user.signingkey is not configured"

command -v gpg >/dev/null 2>&1 || fail "gpg is not installed or not on PATH"

printf 'GPG signing configured with key %s\n' "$SIGNING_KEY"
