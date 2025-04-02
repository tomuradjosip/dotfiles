#!/bin/bash

set -e

# This script installs everything from scratch. It is meant to be used through a curl to bash command.

# Install XCode Command Line Tools if necessary
xcode-select --install || echo "XCode already installed"

# Install Homebrew if necessary
if which -s brew; then
    echo 'Homebrew is already installed'
else
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    (
        echo
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"'
    ) >>$HOME/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Install oh-my-zsh if necessary
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# Install chezmoi if necessary
if ! which -s chezmoi; then
    brew install chezmoi
fi

# Initialize chezmoi
chezmoi init tomuradjosip

# Change the remote to ssh
chezmoi git remote set-url origin git@github.com:tomuradjosip/dotfiles.git

# Apply chezmoi
chezmoi apply

# Create ssh key if necessary
if [ ! -f "$HOME/.ssh/id_github" ]; then
    ssh-keygen -t ed25519 -C "$HOST" -f "$HOME/.ssh/id_github" -N ""
fi
