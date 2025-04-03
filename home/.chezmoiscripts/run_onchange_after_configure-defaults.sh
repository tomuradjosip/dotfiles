#!/bin/bash

set -eufo pipefail

# Configure Dock
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock orientation -string "left"

killall Dock

# Configure sleep
sudo pmset displaysleep 60

# Disable Spotlight shortcut
defaults write com.apple.symbolichotkeys.plist AppleSymbolicHotKeys -dict-add 64 "{ enabled = 0; value = { parameters = (32, 49, 1048576); type = standard; }; }"
