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
	dockutil --no-restart --remove "${label}" || true
done

# Configure sleep
sudo pmset displaysleep 60

# Disable Spotlight shortcut
defaults write com.apple.symbolichotkeys.plist AppleSymbolicHotKeys -dict-add 64 "{ enabled = 0; value = { parameters = (32, 49, 1048576); type = standard; }; }"
