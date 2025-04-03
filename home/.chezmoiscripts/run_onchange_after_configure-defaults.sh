#!/bin/bash

set -eufo pipefail

# Configure Dock
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock orientation -string "left"

killall Dock
