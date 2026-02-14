#!/usr/bin/env bash
# Check that the restic-on-wake LaunchAgent and sleepwatcher are working.
# Run: restic-laptop-backup-status.sh

set -euo pipefail

PLIST="$HOME/Library/LaunchAgents/com.josip.restic-laptop-backup.plist"
LOG="$HOME/Library/Logs/restic-laptop-backup.log"
LAST_FILE="$HOME/.local/state/restic-laptop-last-backup"

ok()  { printf "  %s %s\n" "✓" "$1"; }
fail() { printf "  %s %s\n" "✗" "$1"; }

echo "Restic laptop backup (on-wake) status"
echo "─────────────────────────────────────"

# 1. Plist exists
if [[ -f "$PLIST" ]]; then
  ok "Plist installed: $PLIST"
else
  fail "Plist missing (not applied on this machine?)"
fi

# 2. LaunchAgent loaded and running
if launchctl list 2>/dev/null | grep -q "com.josip.restic-laptop-backup"; then
  line=$(launchctl list | grep "com.josip.restic-laptop-backup")
  pid=$(echo "$line" | awk '{print $1}')
  code=$(echo "$line" | awk '{print $2}')
  if [[ "$pid" != "-" ]]; then
    ok "LaunchAgent loaded, PID $pid"
  else
    fail "LaunchAgent loaded but not running (exit code $code). Run: launchctl unload $PLIST && launchctl load $PLIST"
  fi
else
  fail "LaunchAgent not loaded. Run: launchctl load $PLIST"
fi

# 3. sleepwatcher process
if pgrep -x sleepwatcher >/dev/null; then
  ok "sleepwatcher is running"
else
  fail "sleepwatcher not running (agent may have crashed)"
fi

# 4. Log file
if [[ -f "$LOG" ]]; then
  ok "Log file exists: $LOG"
  echo "  Last log lines:"
  tail -5 "$LOG" | sed 's/^/    /'
else
  fail "Log file missing (no wake has produced output yet)"
fi

# 5. Last backup
if [[ -f "$LAST_FILE" ]]; then
  last=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$LAST_FILE" 2>/dev/null || true)
  ok "Last successful backup: $last"
else
  echo "  (no successful backup yet)"
fi

echo ""
echo "To test on-wake logic (AC/throttle), run:"
echo "  $HOME/.local/bin/restic-laptop-backup-on-wake.sh"
echo "Output will appear in the terminal; a real wake writes to the log above."
