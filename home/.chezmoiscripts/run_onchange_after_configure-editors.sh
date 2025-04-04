#!/bin/bash

set -eufo pipefail

# Configure Cursor (doesn't work, install manually)
#cursor --install-extension "ms-azuretools.vscode-docker"
#cursor --install-extension "ms-vscode-remote.remote-containers"
#cursor --install-extension "ms-vscode-remote.remote-ssh"
#cursor --install-extension "ms-vscode-remote.remote-ssh-edit"
#cursor --install-extension "ms-vscode.remote-explorer"
#cursor --install-extension "tal7aouy.icons"
#cursor --install-extension "vscode-icons-team.vscode-icons"

# Configure VSCode
code --install-extension "ms-azuretools.vscode-docker"
code --install-extension "ms-vscode-remote.remote-containers"
code --install-extension "ms-vscode-remote.remote-ssh"
code --install-extension "ms-vscode-remote.remote-ssh-edit"
code --install-extension "ms-vscode.remote-explorer"
code --install-extension "tal7aouy.icons"
code --install-extension "vscode-icons-team.vscode-icons"
