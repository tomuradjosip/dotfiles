#!/usr/bin/env bash
# Prompt to run chezmoi update (dotfiles pull + apply, including brew bundle upgrades).
# Used on work and home. Invoked by chezmoi-update-on-wake.sh, or run manually:
#   chezmoi-update-prompt.sh
#
# Skip: exits without updating; does not throttle (prompt can show again next wake).
# Update success: touches ~/.local/state/chezmoi-last-update (5-day on-wake throttle).
# Update failure: shows an alert and leaves the throttle alone, so the prompt returns.
# Agent log (when run via launchd): ~/Library/Logs/chezmoi-update.log
# LaunchAgent: com.josip.chezmoi-update

set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH}"

LAST_FILE="${HOME}/.local/state/chezmoi-last-update"
PACKAGES_FAILED_FILE="${HOME}/.local/state/chezmoi-packages-failed"
LOG="${HOME}/Library/Logs/chezmoi-update.log"

# Arguments are passed through argv so the message needs no AppleScript escaping.
# The alert gives up on its own so an unattended failure can't block the agent.
notify() {
  osascript \
    -e 'on run argv' \
    -e 'display alert "Chezmoi update" message (item 1 of argv) as critical giving up after 300' \
    -e 'end run' \
    "$1" >/dev/null 2>&1 || true
}

fail() {
  echo "$1"
  notify "$1"$'\n\n'"See $LOG"
  exit 1
}

answer="$(osascript <<'EOF'
try
  display dialog "Pull latest dotfiles and upgrade packages?" ¬
    with title "Chezmoi" ¬
    buttons {"Skip", "Update"} ¬
    default button "Update" ¬
    cancel button "Skip"
  return "yes"
on error
  return "no"
end try
EOF
)"

if [[ "$answer" != "yes" ]]; then
  echo "Skipped."
  exit 0
fi

echo "Updating Homebrew formulae..."
brew update || fail "Updating Homebrew formulae failed."

echo "Running chezmoi update..."
chezmoi update || fail "chezmoi update failed."

# Package failures don't abort the apply, so they're reported from a marker file
# instead. The update still counts as done: a broken package would otherwise
# bring the prompt back on every wake.
if [[ -f "$PACKAGES_FAILED_FILE" ]]; then
  notify "Some packages failed to install or upgrade."$'\n\n'"See $LOG"
fi

mkdir -p "$(dirname "$LAST_FILE")"
touch "$LAST_FILE"

echo "Done."
