#!/usr/bin/env bash
# Run restic backup on wake, only on AC and at most once per 48 hours.
# Invoked by launchd via sleepwatcher (-w). Do not run manually unless testing.

set -euo pipefail

LAST_FILE="${HOME}/.local/state/restic-laptop-last-backup"
THROTTLE_SEC=$((48 * 3600))

# Log every wake so the log file exists and we can see why we skip or run.
echo "$(date '+%Y-%m-%d %H:%M:%S') On-wake: invoked."

# Only run when on AC power
if ! pmset -g batt | grep -q "AC Power"; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') On-wake: skipped (not on AC power)."
  exit 0
fi

# Skip if last backup was less than 48 hours ago
if [[ -f "$LAST_FILE" ]]; then
  NOW=$(date +%s)
  LAST=$(stat -f %m "$LAST_FILE" 2>/dev/null || true)
  if [[ -n "$LAST" ]] && [[ $((NOW - LAST)) -lt $THROTTLE_SEC ]]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') On-wake: skipped (last backup < 48h ago)."
    exit 0
  fi
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') On-wake: starting backup."
exec "$(dirname "$0")/restic-laptop-backup.sh"
