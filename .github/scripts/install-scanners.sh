#!/usr/bin/env bash
# Managed by repo-guardrails. Installs checksum-verified gitleaks + trufflehog (linux x64).
set -euo pipefail
: "${GITLEAKS_VERSION:?}" "${TRUFFLEHOG_VERSION:?}"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT; cd "$tmp"
fetch() { # repo name version asset
  local base="https://github.com/$1/releases/download/v$3"
  curl -fsSLO "$base/$4"
  curl -fsSL "$base/$2_$3_checksums.txt" | grep " $4\$" | sha256sum -c -
  tar -xzf "$4" "$2"
  sudo install -m 0755 "$2" /usr/local/bin/"$2"
}
fetch gitleaks/gitleaks gitleaks "$GITLEAKS_VERSION" "gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz"
fetch trufflesecurity/trufflehog trufflehog "$TRUFFLEHOG_VERSION" "trufflehog_${TRUFFLEHOG_VERSION}_linux_amd64.tar.gz"
gitleaks version; trufflehog --version
