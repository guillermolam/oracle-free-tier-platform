#!/usr/bin/env bash
set -euo pipefail

ARTIFACT_PATH="${M4_BOOTSTRAP_TLS_ARTIFACT:?M4_BOOTSTRAP_TLS_ARTIFACT is required}"
EXPECTED_KUBE_API="${M4_EXPECTED_KUBE_API:-https://k8s.lab.internal:6443}"
KUBECTL_BIN="${M4_KUBECTL_BIN:-kubectl}"
SOPS_BIN="${M4_SOPS_BIN:-sops}"
SECRET_NAMESPACE="${M4_BOOTSTRAP_TLS_NAMESPACE:-openbao}"
SECRET_NAME="${M4_BOOTSTRAP_TLS_NAME:-openbao-bootstrap-tls}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: required command not found: $1" >&2
    exit 1
  }
}

require_grep() {
  local pattern="$1" description="$2"
  if ! grep -Eq "$pattern" "$ARTIFACT_PATH"; then
    echo "error: bootstrap artifact does not contain expected ${description}" >&2
    exit 1
  fi
}

require_cmd "$KUBECTL_BIN"
require_cmd "$SOPS_BIN"

[[ -r "$ARTIFACT_PATH" ]] || {
  echo "error: encrypted bootstrap artifact not readable: $ARTIFACT_PATH" >&2
  exit 1
}

[[ -n "${SOPS_AGE_KEY:-}" ]] || {
  echo "error: SOPS_AGE_KEY is not set; use the Proton Pass wrapper script" >&2
  exit 1
}

require_grep '^[[:space:]]*kind:[[:space:]]*Secret[[:space:]]*$' "kind: Secret"
require_grep '^[[:space:]]*namespace:[[:space:]]*openbao[[:space:]]*$' "metadata.namespace: openbao"
require_grep '^[[:space:]]*name:[[:space:]]*openbao-bootstrap-tls[[:space:]]*$' "metadata.name: openbao-bootstrap-tls"
require_grep '^[[:space:]]*type:[[:space:]]*kubernetes\.io/tls[[:space:]]*$' "type: kubernetes.io/tls"
require_grep '^[[:space:]]*tls\.crt:[[:space:]]*ENC\[' "encrypted tls.crt data"
require_grep '^[[:space:]]*tls\.key:[[:space:]]*ENC\[' "encrypted tls.key data"
require_grep '^[[:space:]]*sops:[[:space:]]*$' "sops metadata block"

current_server="$("$KUBECTL_BIN" config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
if [[ "$current_server" != "$EXPECTED_KUBE_API" ]]; then
  echo "error: current kubectl context points at '$current_server', expected '$EXPECTED_KUBE_API'" >&2
  exit 1
fi

"$SOPS_BIN" --decrypt --input-type yaml --output-type yaml "$ARTIFACT_PATH" \
  | "$KUBECTL_BIN" apply --server-side --field-manager=m4-bootstrap -f -

verification="$(
  "$KUBECTL_BIN" get secret "$SECRET_NAME" -n "$SECRET_NAMESPACE" \
    -o go-template='{{.type}} {{if index .data "tls.crt"}}present{{end}} {{if index .data "tls.key"}}present{{end}}'
)"
if [[ "$verification" != "kubernetes.io/tls present present" ]]; then
  echo "error: applied Secret verification failed for ${SECRET_NAMESPACE}/${SECRET_NAME}" >&2
  exit 1
fi

echo "Applied ${SECRET_NAMESPACE}/${SECRET_NAME} from encrypted artifact via server-side apply."
