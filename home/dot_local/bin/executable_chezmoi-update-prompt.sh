#!/usr/bin/env bash
# Prompt to run chezmoi update (dotfiles pull + apply, including brew bundle upgrades).
# Used on work and home. Invoked by chezmoi-update-on-wake.sh, or run manually:
#   chezmoi-update-prompt.sh
#
# Skip: exits without updating; does not throttle (prompt can show again next wake).
# Update success: touches ~/.local/state/chezmoi-last-update (5-day on-wake throttle).
# Agent log (when run via launchd): ~/Library/Logs/chezmoi-update.log
# LaunchAgent: com.josip.chezmoi-update

set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH}"

LAST_FILE="${HOME}/.local/state/chezmoi-last-update"

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
brew update

echo "Running chezmoi update..."
chezmoi update

mkdir -p "$(dirname "$LAST_FILE")"
touch "$LAST_FILE"

echo "Done."
