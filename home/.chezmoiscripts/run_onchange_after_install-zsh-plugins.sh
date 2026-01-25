#!/bin/bash

set -eufo pipefail

ZSH_PLUGINS_DIR="$HOME/.local/share/zsh/plugins"
mkdir -p "$ZSH_PLUGINS_DIR"

# Install zsh-navigation-tools (standalone version)
if [[ ! -d "$ZSH_PLUGINS_DIR/zsh-navigation-tools" ]]; then
    git clone --depth=1 https://github.com/z-shell/zsh-navigation-tools.git "$ZSH_PLUGINS_DIR/zsh-navigation-tools"
fi

# Install zsh-interactive-cd (from oh-my-zsh)
if [[ ! -f "$ZSH_PLUGINS_DIR/zsh-interactive-cd/zsh-interactive-cd.plugin.zsh" ]]; then
    mkdir -p "$ZSH_PLUGINS_DIR/zsh-interactive-cd"
    curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/plugins/zsh-interactive-cd/zsh-interactive-cd.plugin.zsh \
        -o "$ZSH_PLUGINS_DIR/zsh-interactive-cd/zsh-interactive-cd.plugin.zsh"
fi
