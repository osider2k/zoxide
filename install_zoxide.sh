#!/usr/bin/env bash
set -e

# -----------------------------
# Request sudo upfront
# -----------------------------
if [ "$EUID" -ne 0 ]; then
    echo "This script requires sudo privileges."
    sudo -v
fi
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

echo "=== System-wide installer: tmux + TPM + fzf + latest zoxide ==="

# -----------------------------
# Detect package manager
# -----------------------------
if command -v apt &>/dev/null; then
    sudo apt update -y
    sudo apt install -y tmux fzf git curl
elif command -v dnf &>/dev/null; then
    sudo dnf -y update
    sudo dnf -y install tmux fzf git curl
elif command -v pacman &>/dev/null; then
    sudo pacman -Sy --noconfirm tmux fzf git curl
else
    echo "❌ No supported package manager found."
    exit 1
fi

# -----------------------------
# Install latest zoxide from GitHub
# -----------------------------
echo "Installing latest zoxide..."
curl -fsSL https://github.com/ajeetdsouza/zoxide/releases/latest/download/install.sh | bash

# Ensure /usr/local/bin is in PATH
export PATH="/usr/local/bin:$PATH"

# -----------------------------
# Clean TPM and reinstall
# -----------------------------
TPM_DIR="/usr/share/tmux/plugins/tpm"
[ -d "$TPM_DIR" ] && sudo rm -rf "$TPM_DIR"
sudo mkdir -p /usr/share/tmux/plugins
sudo git clone --depth=1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
sudo chmod -R 755 "$TPM_DIR"

# Global tmux.conf
sudo tee /etc/tmux.conf >/dev/null <<'EOF'
set -g mouse on
set -g history-limit 10000
setw -g mode-keys vi
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
run-shell /usr/share/tmux/plugins/tpm/tpm
EOF

# -----------------------------
# Zoxide default options (without --fzf)
# -----------------------------
HOOK_OPTION="--hook"
CMD_OPTION="--cmd cd"
SET_DB=true

echo
echo "All zoxide options are automatically enabled:"
echo "  • Auto-tracking (--hook)"
echo "  • Override cd (--cmd cd)"
echo "  • User-specific database (ZO_DATA)"
echo

# -----------------------------
# Clean previous system-wide zoxide setup
# -----------------------------
GLOBAL_BASHRC="/etc/bash.bashrc"
GLOBAL_ZSHRC="/etc/zsh/zshrc"

for rc in "$GLOBAL_BASHRC" "$GLOBAL_ZSHRC"; do
    if [ -f "$rc" ]; then
        sudo sed -i '/system-wide zoxide setup/,+10d' "$rc" || true
    fi
done

# -----------------------------
# Add fresh system-wide zoxide block
# -----------------------------
SETUP_BLOCK="
# >>> system-wide zoxide setup >>>
if command -v zoxide &>/dev/null; then
    if [ -n \"\$BASH_VERSION\" ]; then
        eval \"\$(zoxide init bash $HOOK_OPTION $CMD_OPTION)\"
    elif [ -n \"\$ZSH_VERSION\" ]; then
        eval \"\$(zoxide init zsh $HOOK_OPTION $CMD_OPTION)\"
    fi
fi
# <<< system-wide zoxide setup <<<
"

for rc in "$GLOBAL_BASHRC" "$GLOBAL_ZSHRC"; do
    if [ -f "$rc" ]; then
        echo "$SETUP_BLOCK" | sudo tee -a "$rc" >/dev/null
    fi
done

# -----------------------------
# User-specific ZO_DATA
# -----------------------------
if [[ "$SET_DB" = true ]]; then
    USER_DB="$HOME/.local/share/zoxide/db.zo"
    [ -f "$USER_DB" ] && rm -f "$USER_DB"
    mkdir -p "$(dirname "$USER_DB")"
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        [ -f "$rc" ] && grep -q "export ZO_DATA" "$rc" || echo "export ZO_DATA=\"\$HOME/.local/share/zoxide/db.zo\"" >> "$rc"
    done
fi

# -----------------------------
# Reload shell configuration for current shell
# -----------------------------
CURRENT_SHELL=$(basename "$SHELL")
case "$CURRENT_SHELL" in
    bash)
        source /etc/bash.bashrc || true
        ;;
    zsh)
        source /etc/zsh/zshrc || true
        ;;
esac

# -----------------------------
# Verify cd override
# -----------------------------
if type cd | grep -q 'zoxide'; then
    echo "✔ cd is successfully overridden by zoxide"
else
    echo "⚠ cd is still the shell builtin. Restart your shell to apply."
fi

echo
echo "=== ✅ Clean installation complete ==="
echo "Restart your terminal or run the appropriate source command for your shell:"
echo "  source /etc/bash.bashrc  # bash"
echo "  source /etc/zsh/zshrc    # zsh"
echo "To enable tmux plugins, start tmux and press Ctrl+b then I (capital i)"
