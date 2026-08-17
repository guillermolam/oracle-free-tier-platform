#!/usr/bin/env bash
# Deterministic tests for check-gpg-signing.sh. Exercises git-config
# combinations only — no real GPG key material is needed since the script
# under test never touches key material itself, only configuration.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$SCRIPT_DIR/check-gpg-signing.sh"

PASS=0
FAIL=0

# Runs check-gpg-signing.sh inside a scratch git repo with the given
# config, asserting it exits with $1 and stderr contains $2.
run_case() {
  local name="$1" expected_exit="$2" expected_stderr_substr="$3"
  shift 3
  local tmpdir real_home="$HOME"
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"; export HOME="$real_home"; unset XDG_CONFIG_HOME GIT_CONFIG_NOSYSTEM' RETURN

  # Isolate from the machine's real ~/.gitconfig and /etc/gitconfig —
  # otherwise a developer's own global signing config leaks into "unset"
  # test cases and produces false passes.
  local fake_home="$tmpdir/home"
  mkdir -p "$fake_home"
  export HOME="$fake_home" XDG_CONFIG_HOME="$fake_home/.config" GIT_CONFIG_NOSYSTEM=1

  git init --quiet "$tmpdir/repo"
  (
    cd "$tmpdir/repo"
    for kv in "$@"; do
      git config --local "${kv%%=*}" "${kv#*=}"
    done
  )

  local actual_exit=0
  local stderr_out
  stderr_out="$(cd "$tmpdir/repo" && "$CHECK" 2>&1 1>/dev/null)" || actual_exit=$?

  if [[ "$actual_exit" -ne "$expected_exit" ]]; then
    echo "FAIL: $name (expected exit $expected_exit, got $actual_exit)" >&2
    FAIL=$((FAIL + 1))
    return
  fi
  if [[ -n "$expected_stderr_substr" ]] && ! grep -qF "$expected_stderr_substr" <<<"$stderr_out"; then
    echo "FAIL: $name (stderr missing '$expected_stderr_substr'): $stderr_out" >&2
    FAIL=$((FAIL + 1))
    return
  fi
  echo "PASS: $name"
  PASS=$((PASS + 1))
}

# 1. No config at all -> fails on commit.gpgsign.
run_case "signing disabled (no config)" 1 "commit.gpgsign must be enabled"

# 2. gpgsign enabled but wrong format (ssh) -> fails on gpg.format.
run_case "wrong gpg.format (ssh)" 1 "gpg.format must be openpgp" \
  "commit.gpgsign=true" "gpg.format=ssh"

# 3. gpgsign enabled, format unset (implicit openpgp), no signing key -> fails on signingkey.
run_case "missing signing key" 1 "user.signingkey is not configured" \
  "commit.gpgsign=true"

# 4. Fully configured but gpg.program points at a nonexistent binary -> fails on binary check.
run_case "signing key missing usable gpg binary" 1 "not installed or not on PATH" \
  "commit.gpgsign=true" "user.signingkey=not-a-real-key-fixture" "gpg.program=definitely-not-a-real-binary-xyz"

# 5. Fully valid configuration (explicit openpgp format) -> succeeds.
run_case "valid configuration" 0 "" \
  "commit.gpgsign=true" "gpg.format=openpgp" "user.signingkey=not-a-real-key-fixture" "gpg.program=true"

echo ""
echo "$PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
