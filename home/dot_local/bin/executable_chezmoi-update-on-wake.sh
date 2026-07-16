#!/usr/bin/env bash
# Prompt for chezmoi update on wake (work + home), at most once per 5 days after a
# successful Update. Skip does not count toward the throttle.
#
# Invoked by launchd via sleepwatcher (-w). Do not run manually unless testing
# (manual runs print to the terminal, not the agent log).
#
# LaunchAgent: com.josip.chezmoi-update
# Log: ~/Library/Logs/chezmoi-update.log
# Throttle state: ~/.local/state/chezmoi-last-update
# Check loaded: launchctl list | grep chezmoi-update

set -euo pipefail

LAST_FILE="${HOME}/.local/state/chezmoi-last-update"
THROTTLE_SEC=$((5 * 24 * 3600))

# Log every wake so the log file exists and we can see why we skip or run.
echo "$(date '+%Y-%m-%d %H:%M:%S') On-wake: invoked."

if [[ -f "$LAST_FILE" ]]; then
  NOW=$(date +%s)
  LAST=$(stat -f %m "$LAST_FILE" 2>/dev/null || true)
  if [[ -n "$LAST" ]] && [[ $((NOW - LAST)) -lt $THROTTLE_SEC ]]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') On-wake: skipped (last successful update < 5 days ago)."
    exit 0
  fi
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') On-wake: showing update prompt."
exec "$(dirname "$0")/chezmoi-update-prompt.sh"
