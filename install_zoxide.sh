#!/usr/bin/env bash
set -e

# Ask sudo once
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

ARCH=$(uname -m)
case $ARCH in
    x86_64) ARCH="x86_64" ;;
    aarch64|arm64) ARCH="aarch64" ;;
    *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

OS=linux

# Install minimal dependencies
sudo apt update
sudo apt install -y curl tar

# Function to install/update GitHub binary if missing or outdated
install_github_binary() {
    local repo=$1
    local binary=$2
    local url_pattern=$3    # e.g., Alpine binary name
    local version_check=$4  # command to get installed version

    # Get latest release
    LATEST=$(curl -s "https://api.github.com/repos/$repo/releases/latest" \
        | grep '"tag_name":' | head -1 | cut -d '"' -f 4)
    if [ -z "$LATEST" ]; then
        echo "Failed to fetch latest release for $repo"
        exit 1
    fi

    # Check installed version
    if command -v $binary >/dev/null 2>&1; then
        INSTALLED=$($version_check 2>/dev/null)
        if [ "$INSTALLED" == "$LATEST" ]; then
            echo "$binary is already the latest ($LATEST)"
            return
        fi
    fi

    echo "Installing/updating $binary to $LATEST..."

    # Remove old binary
    sudo rm -f "/usr/local/bin/$binary"
    rm -rf "$HOME/.$binary"

    # Download binary (Alpine/musl for zoxide)
    URL=$(echo "$url_pattern" | sed "s/{{LATEST}}/$LATEST/; s/{{ARCH}}/$ARCH/")
    curl -L "$URL" -o /tmp/$binary.tar.gz
    sudo tar -C /usr/local/bin -xzf /tmp/$binary.tar.gz
    rm /tmp/$binary.tar.gz

    echo "$binary $LATEST installed."
}

# Install zoxide (Alpine binary) and fzf
install_github_binary "ajeetdsouza/zoxide" "zoxide" \
    "https://github.com/ajeetdsouza/zoxide/releases/download/{{LATEST}}/zoxide-{{LATEST}}-{{ARCH}}-unknown-linux-musl.tar.gz" \
    "zoxide --version | grep -oE 'v[0-9\.]+'"

install_github_binary "junegunn/fzf" "fzf" \
    "https://github.com/junegunn/fzf/releases/download/{{LATEST}}/fzf-{{LATEST}}-{{ARCH}}.tar.gz" \
    "fzf --version | grep -oE '^[0-9\.]+'"

# Configure all normal users
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
        echo '    else' >> "$INIT'
        echo '      echo "No selection, staying in current directory"' >> "$INIT"
        echo '    fi' >> "$INIT"
        echo '  fi' >> "$INIT"
        echo '}' >> "$INIT"
    fi
done

echo "✅ zoxide + fzf with Ctrl+T, Ctrl+R, and interactive-only cd installed system-wide."
echo "Users may need to log out/in to apply changes."
