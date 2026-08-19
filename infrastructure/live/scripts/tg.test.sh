#!/usr/bin/env bash
# Deterministic tests for tg. Never touches a real Keychain entry or real
# OCI credentials -- each case builds an isolated PATH with stub
# `security`/`oci`/`terragrunt` executables (mirroring
# scripts/check-gpg-signing.test.sh's isolate-don't-mock pattern) so the
# wrapper's resolution/fail-closed logic is exercised for real, without
# ever handling a real secret value.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TG="$SCRIPT_DIR/tg"

PASS=0
FAIL=0
LAST_OUT=""
LAST_STATUS=0

# Builds an isolated stub bin/ dir. Args: dir, then any of
# "security:<0|1>:<value>" / "oci:<0|1>:<value>" to install a stub that
# exits with the given code and prints the given value on success.
# terragrunt is always stubbed to print a sentinel and exit 0, proving
# whether the wrapper actually reached `exec terragrunt "$@"`.
make_stub_bin() {
  local dir="$1"
  shift
  mkdir -p "$dir"
  cat >"$dir/terragrunt" <<'EOF'
#!/usr/bin/env bash
echo "TERRAGRUNT_INVOKED $*"
echo "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID"
echo "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY"
echo "OCI_OBJECT_STORAGE_NAMESPACE=$OCI_OBJECT_STORAGE_NAMESPACE"
EOF
  chmod +x "$dir/terragrunt"

  for spec in "$@"; do
    local name rest code value
    name="${spec%%:*}"
    rest="${spec#*:}"
    code="${rest%%:*}"
    value="${rest#*:}"
    cat >"$dir/$name" <<EOF
#!/usr/bin/env bash
if [[ $code -eq 0 ]]; then
  printf '%s' "$value"
  exit 0
else
  exit 1
fi
EOF
    chmod +x "$dir/$name"
  done
}

# Runs tg in an isolated env; sets LAST_OUT/LAST_STATUS. Does not assert --
# callers check LAST_OUT/LAST_STATUS themselves.
invoke_tg() {
  local dir="$1"
  shift
  LAST_OUT="$(env -i PATH="$dir:/usr/bin:/bin" HOME="$HOME" "$@" "$TG" plan 2>&1)"
  LAST_STATUS=$?
}

pass() {
  echo "PASS: $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "FAIL: $1"
  echo "$LAST_OUT"
  FAIL=$((FAIL + 1))
}

# 1. No env vars, no Keychain entries -> fails closed, never invokes terragrunt.
dir="$(mktemp -d)"
make_stub_bin "$dir" "security:1:"
invoke_tg "$dir"
rm -rf "$dir"
if [[ $LAST_STATUS -eq 1 && "$LAST_OUT" != *"TERRAGRUNT_INVOKED"* ]]; then
  pass "no credentials anywhere -> fail closed"
else
  fail "no credentials anywhere -> fail closed (expected exit 1, no invocation; got status=$LAST_STATUS)"
fi

# 2. Keychain has both Customer Secret Key halves + oci CLI resolves namespace -> succeeds, values flow through.
dir="$(mktemp -d)"
make_stub_bin "$dir" "security:0:fake-secret-value" "oci:0:ax4ugzw7dvvm"
invoke_tg "$dir"
rm -rf "$dir"
if [[ $LAST_STATUS -eq 0 && "$LAST_OUT" == *"TERRAGRUNT_INVOKED plan"* && "$LAST_OUT" == *"OCI_OBJECT_STORAGE_NAMESPACE=ax4ugzw7dvvm"* ]]; then
  pass "keychain + oci resolve everything -> success"
else
  fail "keychain + oci resolve everything -> success (status=$LAST_STATUS)"
fi

# 3. Keychain lookup fails (not found) -> fail closed, never invokes terragrunt.
dir="$(mktemp -d)"
make_stub_bin "$dir" "security:1:" "oci:0:ax4ugzw7dvvm"
invoke_tg "$dir"
rm -rf "$dir"
if [[ $LAST_STATUS -eq 1 && "$LAST_OUT" != *"TERRAGRUNT_INVOKED"* ]]; then
  pass "keychain entry missing -> fail closed"
else
  fail "keychain entry missing -> fail closed (status=$LAST_STATUS)"
fi

# 4. Credentials already in env -> wrapper must NOT call security at all (env vars win, no Keychain touch).
dir="$(mktemp -d)"
make_stub_bin "$dir" "oci:0:ax4ugzw7dvvm"
cat >"$dir/security" <<'EOF'
#!/usr/bin/env bash
echo "SECURITY_CALLED" >&2
exit 1
EOF
chmod +x "$dir/security"
invoke_tg "$dir" env AWS_ACCESS_KEY_ID=env-access AWS_SECRET_ACCESS_KEY=env-secret
rm -rf "$dir"
if [[ $LAST_STATUS -eq 0 && "$LAST_OUT" != *"SECURITY_CALLED"* && "$LAST_OUT" == *"AWS_ACCESS_KEY_ID=env-access"* ]]; then
  pass "env vars already set -> Keychain never consulted"
else
  fail "env vars already set -> Keychain never consulted (status=$LAST_STATUS)"
fi

# 5. Namespace already in env -> wrapper must NOT call oci CLI at all.
dir="$(mktemp -d)"
make_stub_bin "$dir" "security:0:fake-secret-value"
cat >"$dir/oci" <<'EOF'
#!/usr/bin/env bash
echo "OCI_CALLED" >&2
exit 1
EOF
chmod +x "$dir/oci"
invoke_tg "$dir" env OCI_OBJECT_STORAGE_NAMESPACE=preset-ns
rm -rf "$dir"
if [[ $LAST_STATUS -eq 0 && "$LAST_OUT" != *"OCI_CALLED"* && "$LAST_OUT" == *"OCI_OBJECT_STORAGE_NAMESPACE=preset-ns"* ]]; then
  pass "namespace already set -> oci CLI never consulted"
else
  fail "namespace already set -> oci CLI never consulted (status=$LAST_STATUS)"
fi

# 6. oci CLI present but returns empty namespace -> fails closed rather than generating a broken endpoint.
dir="$(mktemp -d)"
make_stub_bin "$dir" "security:0:fake-secret-value" "oci:0:"
invoke_tg "$dir"
rm -rf "$dir"
if [[ $LAST_STATUS -eq 1 && "$LAST_OUT" != *"TERRAGRUNT_INVOKED"* ]]; then
  pass "oci returns empty namespace -> fail closed"
else
  fail "oci returns empty namespace -> fail closed (status=$LAST_STATUS)"
fi

# 7. AWS_PROFILE set in ambient env, but no OCI credentials anywhere -> still fails closed
#    (wrapper does not consult AWS_PROFILE at all; root.hcl's backend config is the real
#    guard against that layer -- this just proves the wrapper itself doesn't special-case it).
dir="$(mktemp -d)"
make_stub_bin "$dir" "security:1:" "oci:0:ax4ugzw7dvvm"
invoke_tg "$dir" env AWS_PROFILE=some-unrelated-sso-profile
rm -rf "$dir"
if [[ $LAST_STATUS -eq 1 && "$LAST_OUT" != *"TERRAGRUNT_INVOKED"* ]]; then
  pass "unrelated AWS_PROFILE present -> still fails closed"
else
  fail "unrelated AWS_PROFILE present -> still fails closed (status=$LAST_STATUS)"
fi

# 8. Secret value itself never appears in the wrapper's own stderr output.
dir="$(mktemp -d)"
make_stub_bin "$dir" "security:0:super-secret-marker-value" "oci:0:ax4ugzw7dvvm"
LAST_OUT="$(env -i PATH="$dir:/usr/bin:/bin" HOME="$HOME" "$TG" plan 2>&1 >/dev/null)"
rm -rf "$dir"
if [[ "$LAST_OUT" != *"super-secret-marker-value"* ]]; then
  pass "secret value never printed to stderr"
else
  fail "secret value leaked to stderr"
fi

echo
echo "$PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
