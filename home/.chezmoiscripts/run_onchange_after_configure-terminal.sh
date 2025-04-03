#!/bin/bash

set -eufo pipefail

# Configure Terminal
open ~/.config/terminal/AppleTerminalProfile.terminal
defaults write com.apple.terminal "Default Window Settings" -string "AppleTerminalProfile"
defaults write com.apple.terminal "Startup Window Settings" -string "AppleTerminalProfile"
