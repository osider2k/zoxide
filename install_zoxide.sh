#!/usr/bin/env bash
set -e

# Ask for sudo once
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Detect OS and architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64) ARCH="x86_64" ;;
    aarch64|arm64) ARCH="aarch64" ;;
    *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

OS=$(uname | tr '[:upper:]' '[:lower:]')
if [[ "$OS" != "linux" && "$OS" != "darwin" ]]; then
    echo "Unsupported OS: $OS"
    exit 1
fi

# Minimal dependencies
if command -v apt >/dev/null; then
    sudo apt update && sudo apt install -y curl tar
elif command -v dnf >/dev/null; then
    sudo dnf install -y curl tar
elif command -v yum >/dev/null; then
    sudo yum install -y curl tar
elif command -v pacman >/dev/null; then
    sudo pacman -Syu --noconfirm curl tar
elif command -v zypper >/dev/null; then
    sudo zypper install -y curl tar
else
    echo "Please install curl and tar manually."
    exit 1
fi

# Helper to install GitHub latest release
install_github_binary() {
    local repo=$1
    local binary=$2
    local os=$3
    local arch=$4

    LATEST=$(curl -s "https://api.github.com/repos/$repo/releases/latest" | grep '"tag_name":' | head -1 | cut -d '"' -f 4)
    if [ -z "$LATEST" ]; then
        echo "Failed to fetch latest release for $repo"
        exit 1
    fi

    # Remove old binary
    sudo rm -f "/usr/local/bin/$binary"
    rm -rf "$HOME/.$binary"

    # Build download URL
    URL="https://github.com/$repo/releases/download/$LATEST/$binary-$LATEST-$os-$arch.tar.gz"
    echo "Downloading $binary $LATEST..."
    curl -L "$URL" -o /tmp/$binary.tar.gz

    # Extract binary
    sudo tar -C /usr/local/bin -xzf /tmp/$binary.tar.gz
    rm /tmp/$binary.tar.gz
}

# Install latest zoxide and fzf
install_github_binary "ajeetdsouza/zoxide" "zoxide" "$OS" "$ARCH"
install_github_binary "junegunn/fzf" "fzf" "$OS" "$ARCH"

# Configure all users
for user in $(cut -f1 -d: /etc/passwd); do
    UID=$(id -u "$user")
    [ "$UID" -lt 1000 ] && continue  # skip system users

    HOME_DIR=$(eval echo "~$user")
    SHELL_PATH=$(getent passwd "$user" | cut -d: -f7)
    case "$SHELL_PATH" in
        */bash) INIT="$HOME_DIR/.bashrc" ;;
        */zsh) INIT="$HOME_DIR/.zshrc" ;;
        */fish) INIT="$HOME_DIR/.config/fish/config.fish" ;;
        *) INIT="$HOME_DIR/.bashrc" ;;
    esac

    # zoxide init
    if ! grep -q "zoxide init" "$INIT" 2>/dev/null; then
        if [[ "$SHELL_PATH" == */fish ]]; then
            echo 'zoxide init fish | source' >> "$INIT"
        else
            echo 'eval "$(zoxide init '"${SHELL_PATH##*/}"')" ' >> "$INIT"
        fi
    fi

    # fzf key bindings + Ctrl+R
    if [[ "$SHELL_PATH" == */bash || "$SHELL_PATH" == */zsh ]]; then
        if ! grep -q "fzf key bindings" "$INIT" 2>/dev/null; then
            echo 'if [ -f /usr/local/bin/fzf ]; then' >> "$INIT"
            echo '  source /usr/local/bin/fzf 2>/dev/null' >> "$INIT"
            echo '  export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border"' >> "$INIT"
            echo '  bind '"'"'"\C-r": "\C-a\C-k$(history | fzf --tac --no-sort --preview '\''echo {}'\'')\e\C-e\C-y\C-m"'"'" >> "$INIT"
            echo 'fi' >> "$INIT"
        fi
    fi

    # interactive-only cd using zoxide + fzf
    if ! grep -q "cd() {" "$INIT" 2>/dev/null; then
        echo '' >> "$INIT"
        echo '# Override cd for interactive fuzzy selection only' >> "$INIT"
        echo 'cd() {' >> "$INIT"
        echo '  if [ "$#" -eq 0 ]; then' >> "$INIT"
        echo '    builtin cd ~' >> "$INIT"
        echo '  else' >> "$INIT"
        echo '    target=$(zoxide query "$1" --interactive 2>/dev/null)' >> "$INIT"
        echo '    if [ -n "$target" ]; then' >> "$INIT"
        echo '      builtin cd "$target"' >> "$INIT"
        echo '    else' >> "$INIT"
        echo '      echo "No selection, staying in current directory"' >> "$INIT"
        echo '    fi' >> "$INIT"
        echo '  fi' >> "$INIT"
        echo '}' >> "$INIT"
    fi
done

echo "✅ zoxide + fzf with Ctrl+T, Ctrl+R, and interactive-only cd installed for all users."
echo "Users may need to log out/in to apply changes."
