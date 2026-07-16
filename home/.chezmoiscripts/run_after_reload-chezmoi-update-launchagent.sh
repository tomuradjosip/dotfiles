#!/usr/bin/env bash
# Reload com.josip.chezmoi-update so launchd picks up the current plist.
# Rotates ~/Library/Logs/chezmoi-update.log if it exceeds LOG_ROTATE_MB.

set -euo pipefail

PLIST="$HOME/Library/LaunchAgents/com.josip.chezmoi-update.plist"
LOG="$HOME/Library/Logs/chezmoi-update.log"
LOG_ROTATE_MB=1
LOG_KEEP=2

if [[ ! -f "$PLIST" ]]; then
	exit 0
fi

# Rotate log if it exists and is over LOG_ROTATE_MB (must unload first so the file isn't held open)
if [[ -f "$LOG" ]] && [[ $(stat -f %z "$LOG" 2>/dev/null || echo 0) -gt $((LOG_ROTATE_MB * 1024 * 1024)) ]]; then
	launchctl unload "$PLIST" 2>/dev/null || true
	for ((i=LOG_KEEP; i>=1; i--)); do
		[[ -f "${LOG}.${i}" ]] && mv -f "${LOG}.${i}" "${LOG}.$((i+1))"
	done
	[[ -f "$LOG" ]] && mv -f "$LOG" "${LOG}.1"
	launchctl load "$PLIST"
else
	launchctl unload "$PLIST" 2>/dev/null || true
	launchctl load "$PLIST"
fi
