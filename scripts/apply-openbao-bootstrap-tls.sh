#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INNER_SCRIPT="${M4_BOOTSTRAP_TLS_INNER:-$SCRIPT_DIR/apply-openbao-bootstrap-tls-inner.sh}"
ARTIFACT_PATH="${M4_BOOTSTRAP_TLS_ARTIFACT:-$REPO_ROOT/bootstrap/sops/lab/openbao-bootstrap-tls.enc.yaml}"
SOPS_AGE_KEY_REF="${M4_SOPS_AGE_KEY_REF:-pass://Personal/M4 SOPS Age Identity/password}"
EXPECTED_KUBE_API="${M4_EXPECTED_KUBE_API:-https://k8s.lab.internal:6443}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: required command not found: $1" >&2
    exit 1
  }
}

require_cmd pass-cli

if [[ ! -x "$INNER_SCRIPT" ]]; then
  echo "error: bootstrap helper is missing or not executable: $INNER_SCRIPT" >&2
  exit 1
fi

if [[ ! -r "$ARTIFACT_PATH" ]]; then
  echo "error: encrypted bootstrap artifact not found: $ARTIFACT_PATH" >&2
  exit 1
fi

export PROTON_PASS_KEY_PROVIDER=fs

if ! pass-cli info >/dev/null 2>&1; then
  echo "error: Proton Pass is not authenticated; run 'pass-cli login' with PROTON_PASS_KEY_PROVIDER=fs first" >&2
  exit 1
fi

SOPS_AGE_KEY="$SOPS_AGE_KEY_REF" \
M4_BOOTSTRAP_TLS_ARTIFACT="$ARTIFACT_PATH" \
M4_EXPECTED_KUBE_API="$EXPECTED_KUBE_API" \
M4_KUBECTL_BIN="${M4_KUBECTL_BIN:-kubectl}" \
M4_SOPS_BIN="${M4_SOPS_BIN:-sops}" \
pass-cli run -- "$INNER_SCRIPT"
