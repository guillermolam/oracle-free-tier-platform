#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MODE="${1:-readiness}"
ARTIFACT_PATH="${M4_BOOTSTRAP_TLS_ARTIFACT:-$REPO_ROOT/bootstrap/sops/lab/openbao-bootstrap-tls.enc.yaml}"

usage() {
  cat <<'EOF'
Usage: scripts/verify-m4.sh [ci|readiness]

ci         Run deterministic local checks for the M4 bootstrap-TLS slice.
readiness  Verify the local bootstrap artifact gate without decrypting it.
EOF
}

verify_encrypted_artifact() {
  local failures=0

  if [[ ! -r "$ARTIFACT_PATH" ]]; then
    echo "FAIL bootstrap artifact missing: $ARTIFACT_PATH"
    return 1
  fi

  for check in \
    '^[[:space:]]*kind:[[:space:]]*Secret[[:space:]]*$' \
    '^[[:space:]]*namespace:[[:space:]]*openbao[[:space:]]*$' \
    '^[[:space:]]*name:[[:space:]]*openbao-bootstrap-tls[[:space:]]*$' \
    '^[[:space:]]*type:[[:space:]]*kubernetes\.io/tls[[:space:]]*$' \
    '^[[:space:]]*tls\.crt:[[:space:]]*ENC\[' \
    '^[[:space:]]*tls\.key:[[:space:]]*ENC\[' \
    '^[[:space:]]*sops:[[:space:]]*$'
  do
    if ! grep -Eq "$check" "$ARTIFACT_PATH"; then
      failures=$((failures + 1))
    fi
  done

  if [[ "$failures" -ne 0 ]]; then
    echo "FAIL bootstrap artifact metadata/encryption markers are incomplete"
    return 1
  fi

  echo "PASS bootstrap artifact exists and remains encrypted in Git"
}

case "$MODE" in
  ci)
    "$SCRIPT_DIR/apply-openbao-bootstrap-tls.test.sh"
    ;;
  readiness)
    verify_encrypted_artifact
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    echo "error: unknown mode '$MODE'" >&2
    usage >&2
    exit 1
    ;;
esac
