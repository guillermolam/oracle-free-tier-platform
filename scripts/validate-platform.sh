#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLATFORM_ROOT="$REPO_ROOT/platform"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: required command not found: $1" >&2
    exit 1
  }
}

require_cmd kubectl
require_cmd helm
require_cmd rg

run_with_retry() {
  local attempts="$1"
  shift
  local attempt rc

  for attempt in $(seq 1 "$attempts"); do
    if "$@"; then
      rc=0
    else
      rc=$?
    fi
    if [[ "$rc" -eq 0 ]]; then
      return 0
    fi
    if [[ "$attempt" -eq "$attempts" ]]; then
      return "$rc"
    fi
    sleep 2
  done
}

assert_not_found() {
  local pattern="$1" target="$2" message="$3"
  if rg -n "$pattern" "$target" >/dev/null 2>&1; then
    echo "error: ${message}" >&2
    rg -n "$pattern" "$target" >&2 || true
    exit 1
  fi
}

kubectl kustomize "$PLATFORM_ROOT/clusters/lab" >/dev/null
run_with_retry 3 helm template argocd argo-cd \
  --repo https://argoproj.github.io/argo-helm \
  --version 10.4.0 \
  --namespace argocd \
  --values "$PLATFORM_ROOT/gitops/argocd/values.yaml" >/dev/null
run_with_retry 3 helm template cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --version v1.21.1 \
  --namespace cert-manager \
  --values "$PLATFORM_ROOT/gitops/cert-manager/values.yaml" >/dev/null
run_with_retry 3 helm template dex dex \
  --repo https://charts.dexidp.io \
  --version 0.24.1 \
  --namespace dex \
  --values "$PLATFORM_ROOT/gitops/dex/values.yaml" >/dev/null
run_with_retry 3 helm template external-secrets external-secrets \
  --repo https://charts.external-secrets.io \
  --version 2.9.0 \
  --namespace external-secrets \
  --values "$PLATFORM_ROOT/gitops/external-secrets/values.yaml" >/dev/null
run_with_retry 3 helm template openbao openbao \
  --repo https://openbao.github.io/openbao-helm \
  --version 0.29.2 \
  --namespace openbao \
  --values "$PLATFORM_ROOT/gitops/openbao/values.yaml" >/dev/null
run_with_retry 3 helm template spire-crds spire-crds \
  --repo https://spiffe.github.io/helm-charts-hardened/ \
  --version 0.6.0 \
  --namespace spire-system >/dev/null
run_with_retry 3 helm template spire spire \
  --repo https://spiffe.github.io/helm-charts-hardened/ \
  --version 0.30.0 \
  --namespace spire-server \
  --values "$PLATFORM_ROOT/gitops/spire/values.yaml" >/dev/null
run_with_retry 3 helm template ziti-controller ziti-controller \
  --repo https://docs.openziti.io/helm-charts/ \
  --version 3.2.1 \
  --namespace openziti \
  --values "$PLATFORM_ROOT/gitops/openziti-controller/values.yaml" >/dev/null

assert_not_found 'image:[[:space:]]*[^[:space:]]+:latest([[:space:]]|$)' "$PLATFORM_ROOT" "mutable image ':latest' references are not allowed in platform manifests"
assert_not_found '(^|[[:space:]])tag:[[:space:]]*"?latest"?([[:space:]]|$)' "$PLATFORM_ROOT" "mutable image tag 'latest' references are not allowed in platform manifests"
assert_not_found '(^|[[:space:]])version:[[:space:]]*"?latest"?([[:space:]]|$)' "$PLATFORM_ROOT" "mutable chart or image version 'latest' references are not allowed in platform manifests"
assert_not_found 'ref=main' "$PLATFORM_ROOT" "mutable ref=main inputs are not allowed in platform manifests"
assert_not_found 'chart:[[:space:]]*(\./|\.\./|/)' "$PLATFORM_ROOT/gitops" "local Helm chart paths are not allowed in platform manifests"

echo "platform manifests render successfully"
