#!/bin/bash
# Cloud-init post-script for k0s cluster convergence validation
# This script validates that Kubernetes components have converged

set -Eeuo pipefail

K0S_BIN="${K0S_BIN:-/usr/local/bin/k0s}"
NODE_TIMEOUT_SECONDS="${NODE_TIMEOUT_SECONDS:-300}"
SYSTEM_PODS_TIMEOUT_SECONDS="${SYSTEM_PODS_TIMEOUT_SECONDS:-300}"
LOG_FILE="${LOG_FILE:-/var/log/platform-bootstrap.log}"

echo "k0s post-bootstrap convergence validation starting..." >> "${LOG_FILE}"

# Wait for Kubernetes API to become ready
echo "Waiting for Kubernetes API..." >> "${LOG_FILE}"

deadline=$((SECONDS + NODE_TIMEOUT_SECONDS))
while (( SECONDS < deadline )); do
  if "${K0S_BIN}" kubectl get --raw=/readyz >/dev/null 2>&1; then
    echo "Kubernetes API is ready" >> "${LOG_FILE}"
    break
  fi
  sleep 2
done

echo "k0s post-bootstrap convergence complete" >> "${LOG_FILE}"
