#!/usr/bin/env bash
# Managed by repo-guardrails. Non-blocking report of outdated actions (job summary).
set -euo pipefail
ACTIONS_UP_VERSION=2.0.0 # kept current by auto-update.sh
out=${GITHUB_STEP_SUMMARY:-/dev/stdout}
report=$(npx --yes "actions-up@${ACTIONS_UP_VERSION}" --json --style sha) || { echo "::warning::actions-up report failed"; exit 0; }
n=$(jq '.summary.totalUpdates // 0' <<<"$report")
{
  echo "## Outdated GitHub Actions (actions-up ${ACTIONS_UP_VERSION})"
  if [ "$n" = 0 ]; then echo "All actions are up to date."; else
    echo "$n update(s) pending; the daily **auto-update** workflow applies them."
    echo
    echo "| Action | Current | Latest | Breaking | Where |"
    echo "|---|---|---|---|---|"
    jq -r '.updates[] | select(.hasUpdate) | "| `\(.action.name)` | \(.currentVersion) | \(.latestVersion) | \(if .isBreaking then "yes" else "" end) | `\(.action.file):\(.action.line)` |"' <<<"$report"
  fi
  jq -r '.summary | "\nHeld back: \(.totalBlockedByAge) by 1-day cool-down, \(.totalBlockedByTrust) by trust checks, \(.totalSkipped) skipped. Runner image updates: \(.totalRunnerUpdates)."' <<<"$report"
} >>"$out"
[ "$n" = 0 ] || echo "::notice::$n outdated action(s); auto-update will apply them"
