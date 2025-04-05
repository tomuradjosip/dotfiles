#!/bin/bash

set -eufo pipefail

# Configure Dock
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock orientation -string "left"

trap 'killall Dock' EXIT

declare -a remove_labels=(
	Launchpad
	Safari
	Messages
	Mail
	Maps
	Photos
	FaceTime
	Calendar
	Contacts
	Reminders
	Notes
	Freeform
	TV
	Music
	Keynote
	Numbers
	Pages
	"App Store"
    Downloads
    "System Settings"
)

for label in "${remove_labels[@]}"; do
	dockutil --no-restart --remove "${label}" 2>/dev/null || true
done

# Configure hot corners
defaults write com.apple.dock wvous-tr-corner -int 12
defaults write com.apple.dock wvous-br-corner -int 2
defaults write com.apple.dock wvous-bl-corner -int 5
defaults write com.apple.dock wvous-tl-corner -int 4

# Configure sleep
display_sleep_current=$(pmset -g | grep displaysleep | awk '{print $2}')
if [ "${display_sleep_current}" != "25" ]; then
	sudo pmset displaysleep 25
fi

# Configure Finder
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder NewWindowTarget -string "PfHm"
killall Finder
