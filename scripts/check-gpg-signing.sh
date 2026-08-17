#!/usr/bin/env bash
# Verifies commit signing is *configured*. Cannot verify a commit's actual
# signature — this runs pre-commit, before the commit object exists (see
# .githooks/post-commit for that check). This repo requires OpenPGP
# signing specifically (gpg.format=ssh/x509 rejected below) — SSH commit
# signing is not currently supported here.
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

GPG_PROGRAM="$(git config --get gpg.program 2>/dev/null || echo gpg)"
command -v "$GPG_PROGRAM" >/dev/null 2>&1 || fail "$GPG_PROGRAM is not installed or not on PATH"

printf 'GPG signing configured with key %s\n' "$SIGNING_KEY"
