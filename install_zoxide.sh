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

# Install minimal dependencies
sudo apt update
sudo apt install -y curl tar

# Function to fetch latest GitHub release tag
get_latest_release() {
    local repo="$1"
    curl -s "https://api.github.com/repos/$repo/releases/latest" \
        | grep '"tag_name":' | head -1 | cut -d '"' -f 4
}

# ------------------------------
# Install or update zoxide
# ------------------------------
ZOX_LATEST=$(get_latest_release "ajeetdsouza/zoxide")
if ! command -v zoxide >/dev/null 2>&1 || [ "$(zoxide --version | grep -oE 'v[0-9\.]+')" != "$ZOX_LATEST" ]; then
    echo "Installing/updating zoxide $ZOX_LATEST..."
    URL="https://github.com/ajeetdsouza/zoxide/releases/download/$ZOX_LATEST/zoxide-$ZOX_LATEST-$ARCH-unknown-linux-musl.tar.gz"
    curl -L "$URL" -o /tmp/zoxide.tar.gz
    sudo tar -C /usr/local/bin -xzf /tmp/zoxide.tar.gz
    rm /tmp/zoxide.tar.gz
    echo "zoxide $ZOX_LATEST installed."
else
    echo "zoxide is already the latest ($ZOX_LATEST)"
fi

# ------------------------------
# Install or update fzf
# ------------------------------
FZF_LATEST=$(get_latest_release "junegunn/fzf")
if ! command -v fzf >/dev/null 2>&1 || [ "$(fzf --version | grep -oE '^[0-9\.]+')" != "$FZF_LATEST" ]; then
    echo "Installing/updating fzf $FZF_LATEST..."
    URL="https://github.com/junegunn/fzf/releases/download/$FZF_LATEST/fzf-$FZF_LATEST-$ARCH.tar.gz"
    curl -L "$URL" -o /tmp/fzf.tar.gz
    sudo tar -C /usr/local/bin -xzf /tmp/fzf.tar.gz
    rm /tmp/fzf.tar.gz
    echo "fzf $FZF_LATEST installed."
else
    echo "fzf is already the latest ($FZF_LATEST)"
fi

# ------------------------------
# Configure all normal users
# ------------------------------
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
