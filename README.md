# ![chezmoi logo](https://github.com/twpayne/chezmoi/blob/master/assets/images/logo-144px.svg) chezmoi dotfiles

Managing my dotfiles and applications using [chezmoi](https://chezmoi.io).

Install everything on a new, empty machine with a single command:

```console
sudo curl -sfL https://raw.githubusercontent.com/tomuradjosip/dotfiles/main/startup.sh | bash
```

Update dotfiles:

```console
$ chezmoi update
```

If unsure about the changes refresh the local git repo manually by running `git pull` followed by `chezmoi status` and `chezmoi diff`. If the changes are acceptable run the update command.

## Features

This repo handles the following:
- Homebrew and App store packages
- some MacOS settings
- Cursor and VS Code installation
- configs and keybindings
- Zsh settings
- MacOS terminal settings
- ssh settings and key generation
- git settings
