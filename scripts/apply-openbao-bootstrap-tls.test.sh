#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER="$SCRIPT_DIR/apply-openbao-bootstrap-tls.sh"
FIXTURE="$SCRIPT_DIR/tests/fixtures/openbao-bootstrap-tls.enc.yaml"

PASS=0
FAIL=0
LAST_OUT=""
LAST_STATUS=0

make_stub_bin() {
  local dir="$1"
  mkdir -p "$dir"

  cat >"$dir/pass-cli" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  info)
    [[ "${PASS_CLI_STUB_MODE:-ok}" != "not_authenticated" ]]
    exit $?
    ;;
  run)
    shift
    [[ "$1" == "--" ]] && shift
    if [[ "${PASS_CLI_STUB_MODE:-ok}" == "resolve_fail" ]]; then
      echo "Error: failed to resolve pass reference" >&2
      exit 1
    fi
    if [[ "${SOPS_AGE_KEY:-}" == pass://* ]]; then
      export SOPS_AGE_KEY="${PASS_CLI_STUB_SOPS_AGE_KEY:-AGE-SECRET-TEST-KEY}"
    fi
    exec "$@"
    ;;
  *)
    exit 1
    ;;
esac
EOF
  chmod +x "$dir/pass-cli"

  cat >"$dir/sops" <<'EOF'
#!/usr/bin/env bash
[[ -n "${SOPS_AGE_KEY:-}" ]] || {
  echo "missing SOPS_AGE_KEY" >&2
  exit 1
}
cat <<'YAML'
apiVersion: v1
kind: Secret
metadata:
  name: openbao-bootstrap-tls
  namespace: openbao
type: kubernetes.io/tls
data:
  tls.crt: ZmFrZS1jcnQ=
  tls.key: ZmFrZS1rZXk=
YAML
EOF
  chmod +x "$dir/sops"

  cat >"$dir/kubectl" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "config" && "$2" == "view" ]]; then
  printf '%s' "${KUBECTL_STUB_SERVER:-https://k8s.lab.internal:6443}"
  exit 0
fi

if [[ "$1" == "apply" ]]; then
  cat >"${KUBECTL_STUB_APPLY_CAPTURE:?}"
  echo "secret/openbao-bootstrap-tls configured"
  exit 0
fi

if [[ "$1" == "get" && "$2" == "secret" ]]; then
  if [[ "${KUBECTL_STUB_GET_MODE:-ok}" == "missing_keys" ]]; then
    printf '%s' "kubernetes.io/tls present "
  else
    printf '%s' "kubernetes.io/tls present present"
  fi
  exit 0
fi

echo "unexpected kubectl invocation: $*" >&2
exit 1
EOF
  chmod +x "$dir/kubectl"
}

invoke_case() {
  local stub_dir="$1"
  shift
  local capture
  capture="$(mktemp)"
  LAST_OUT="$(
    env -i \
      PATH="$stub_dir:/usr/bin:/bin" \
      HOME="$HOME" \
      KUBECTL_STUB_APPLY_CAPTURE="$capture" \
      M4_BOOTSTRAP_TLS_ARTIFACT="$FIXTURE" \
      M4_BOOTSTRAP_TLS_INNER="$SCRIPT_DIR/apply-openbao-bootstrap-tls-inner.sh" \
      "$@" "$WRAPPER" 2>&1
  )"
  LAST_STATUS=$?
  LAST_CAPTURE="$(cat "$capture" 2>/dev/null || true)"
  rm -f "$capture"
}

pass_case() {
  echo "PASS: $1"
  PASS=$((PASS + 1))
}

fail_case() {
  echo "FAIL: $1"
  echo "$LAST_OUT"
  FAIL=$((FAIL + 1))
}

stub_dir="$(mktemp -d)"
make_stub_bin "$stub_dir"
invoke_case "$stub_dir" env PASS_CLI_STUB_MODE=ok
rm -rf "$stub_dir"
if [[ $LAST_STATUS -eq 0 && "$LAST_OUT" == *"Applied openbao/openbao-bootstrap-tls"* && "$LAST_CAPTURE" == *"tls.crt:"* ]]; then
  pass_case "wrapper resolves SOPS age key and applies the decrypted Secret"
else
  fail_case "wrapper resolves SOPS age key and applies the decrypted Secret (status=$LAST_STATUS)"
fi

stub_dir="$(mktemp -d)"
make_stub_bin "$stub_dir"
invoke_case "$stub_dir" env PASS_CLI_STUB_MODE=not_authenticated
rm -rf "$stub_dir"
if [[ $LAST_STATUS -eq 1 && "$LAST_OUT" == *"Proton Pass is not authenticated"* ]]; then
  pass_case "wrapper fails closed when Proton Pass is not authenticated"
else
  fail_case "wrapper fails closed when Proton Pass is not authenticated (status=$LAST_STATUS)"
fi

stub_dir="$(mktemp -d)"
make_stub_bin "$stub_dir"
invoke_case "$stub_dir" env PASS_CLI_STUB_MODE=ok KUBECTL_STUB_SERVER=https://unexpected.example.invalid:6443
rm -rf "$stub_dir"
if [[ $LAST_STATUS -eq 1 && "$LAST_OUT" == *"current kubectl context points at"* ]]; then
  pass_case "inner helper rejects the wrong kubectl API server"
else
  fail_case "inner helper rejects the wrong kubectl API server (status=$LAST_STATUS)"
fi

bad_fixture="$(mktemp)"
cp "$FIXTURE" "$bad_fixture"
perl -0pi -e 's/tls\.key: ENC\[/tls.key: plaintext-/g' "$bad_fixture"
stub_dir="$(mktemp -d)"
make_stub_bin "$stub_dir"
LAST_OUT="$(
  env -i \
    PATH="$stub_dir:/usr/bin:/bin" \
    HOME="$HOME" \
    SOPS_AGE_KEY=AGE-SECRET-TEST-KEY \
    M4_BOOTSTRAP_TLS_ARTIFACT="$bad_fixture" \
    M4_KUBECTL_BIN=kubectl \
    M4_SOPS_BIN=sops \
    "$SCRIPT_DIR/apply-openbao-bootstrap-tls-inner.sh" 2>&1
)"
LAST_STATUS=$?
rm -rf "$stub_dir" "$bad_fixture"
if [[ $LAST_STATUS -eq 1 && "$LAST_OUT" == *"encrypted tls.key data"* ]]; then
  pass_case "inner helper rejects artifacts that are not fully encrypted"
else
  fail_case "inner helper rejects artifacts that are not fully encrypted (status=$LAST_STATUS)"
fi

stub_dir="$(mktemp -d)"
make_stub_bin "$stub_dir"
invoke_case "$stub_dir" env PASS_CLI_STUB_MODE=ok KUBECTL_STUB_GET_MODE=missing_keys
rm -rf "$stub_dir"
if [[ $LAST_STATUS -eq 1 && "$LAST_OUT" == *"applied Secret verification failed"* ]]; then
  pass_case "post-apply verification fails when the Secret keys are missing"
else
  fail_case "post-apply verification fails when the Secret keys are missing (status=$LAST_STATUS)"
fi

echo
echo "$PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
