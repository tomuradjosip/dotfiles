# ![chezmoi logo](https://github.com/twpayne/chezmoi/blob/master/assets/images/logo-144px.svg) chezmoi dotfiles

Managing my dotfiles and applications using [chezmoi](https://chezmoi.io).

## Prerequisites

- macOS (tested on Sonoma/Sequoia)
- The startup script will automatically install: Xcode CLI tools, Homebrew, oh-my-zsh, chezmoi

## Quick Start

Install everything on a new, empty machine with a single command:

```console
curl -sfL https://raw.githubusercontent.com/tomuradjosip/dotfiles/main/startup.sh | sudo bash
```

> **Note:** You may want to [review the script](https://raw.githubusercontent.com/tomuradjosip/dotfiles/main/startup.sh) before running it.

During setup, you'll be prompted to choose between **work** or **home** configuration, which determines email settings, GPG signing, and which packages get installed.

## Updating

```console
chezmoi update
```

If unsure about the changes, refresh the local git repo manually by running `git pull` followed by `chezmoi status` and `chezmoi diff`. If the changes are acceptable, run the update command.

## Features

**System**
- Homebrew, Cask, and App Store packages (with work/home variants)
- macOS settings (Dock, Finder, hot corners, Touch ID for sudo)
- Karabiner Elements keyboard remapping

**Editors**
- Cursor and VS Code settings, keybindings, and extensions

**Shell**
- Zsh configuration (aliases, functions, plugins, Oh My Posh theme)
- macOS Terminal profile and prompt theme

**Security & Credentials**
- SSH config and key generation
- Git config (with GPG signing for work)
- GPG agent configuration
- AWS CLI profiles (work)

## Repository Structure

```
home/
├── .chezmoiscripts/     # Scripts that run during chezmoi apply
├── .chezmoidata/        # Data files (packages.yaml)
├── dot_config/          # ~/.config files (git, zsh, terminal, karabiner)
├── dot_gnupg/           # GPG agent config
├── lib/                 # Editor configs (Cursor, VS Code)
├── private_dot_aws/     # AWS CLI config
├── private_dot_ssh/     # SSH config
└── private_Library/     # macOS Application Support symlinks
```
