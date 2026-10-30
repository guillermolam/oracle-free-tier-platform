#!/usr/bin/env bash
# Managed by repo-guardrails. trufflehog with .trufflehog-exclude applied reliably.
#   trufflehog-scan.sh files <file>...   scan given files (pre-commit)
#   trufflehog-scan.sh history           scan all git history (pre-push / CI)
set -euo pipefail
mode=${1:?usage: trufflehog-scan.sh files|history [files...]}; shift
patterns=$(grep -vE '^[[:space:]]*(#|$)' .trufflehog-exclude 2>/dev/null || true)
# shellcheck disable=SC2054 # comma is part of the flag value
common=(--no-update --fail --results=verified,unknown --log-level=-1)
case $mode in
  files)
    keep=()
    for f in "$@"; do
      if [ -n "$patterns" ] && printf '%s\n' "$f" | grep -qE -f <(printf '%s\n' "$patterns"); then continue; fi
      keep+=("$f")
    done
    [ ${#keep[@]} -eq 0 ] && exit 0
    exec trufflehog filesystem "${common[@]}" "${keep[@]}" ;;
  history)
    excl=$(mktemp); trap 'rm -f "$excl"' EXIT
    printf '%s\n' "$patterns" | grep -v '^$' >"$excl" || true
    args=("${common[@]}")
    [ -s "$excl" ] && args+=(--exclude-paths="$excl")
    trufflehog git "file://$PWD" "${args[@]}" ;;
  *) echo "unknown mode: $mode" >&2; exit 2 ;;
esac
