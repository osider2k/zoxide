#!/usr/bin/env bash
set -e

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64) ARCH="x86_64" ;;
    aarch64|arm64) ARCH="aarch64" ;;
    *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

# Detect OS
OS=$(uname | tr '[:upper:]' '[:lower:]')

# Install dependencies
install_dependencies() {
    if command -v apt >/dev/null; then
        sudo apt update && sudo apt install -y curl tar git
    elif command -v dnf >/dev/null; then
        sudo dnf install -y curl tar git
    elif command -v yum >/dev/null; then
        sudo yum install -y curl tar git
    elif command -v pacman >/dev/null; then
        sudo pacman -Syu --noconfirm curl tar git
    elif command -v zypper >/dev/null; then
        sudo zypper install -y curl tar git
    else
        echo "Please install curl, tar, git manually."
    fi
}

install_dependencies

# Install latest zoxide
if ! command -v zoxide >/dev/null; then
    echo "Installing latest zoxide..."
    ZOX_RELEASE=$(curl -s https://api.github.com/repos/ajeetdsouza/zoxide/releases/latest | grep browser_download_url | grep "${OS}_${ARCH}" | cut -d '"' -f 4)
    curl -L "$ZOX_RELEASE" -o /tmp/zoxide.tar.gz
    sudo tar -C /usr/local/bin -xzf /tmp/zoxide.tar.gz
    rm /tmp/zoxide.tar.gz
else
    echo "zoxide already installed"
fi

# Install latest fzf
if ! command -v fzf >/dev/null; then
    echo "Installing latest fzf..."
    FZF_RELEASE=$(curl -s https://api.github.com/repos/junegunn/fzf/releases/latest | grep browser_download_url | grep "${OS}_${ARCH}" | cut -d '"' -f 4)
    curl -L "$FZF_RELEASE" -o /tmp/fzf.tar.gz
    tar -xzf /tmp/fzf.tar.gz -C /tmp
    sudo mv /tmp/fzf /usr/local/bin/
    rm /tmp/fzf.tar.gz
else
    echo "fzf already installed"
fi

echo "Installation complete!"
echo 'Add the following to your shell config:'
echo '  eval "$(zoxide init bash)"  # for bash'
echo '  eval "$(zoxide init zsh)"   # for zsh'
echo '  eval "$(zoxide init fish)"  # for fish'
