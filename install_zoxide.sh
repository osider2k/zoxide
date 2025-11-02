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

echo "=== System-wide installer: tmux + TPM + fzf + latest zoxide with auto-fuzzy ==="

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
export PATH="/usr/local/bin:$PATH"

# -----------------------------
# Clean TPM and reinstall
# -----------------------------
TPM_DIR="/usr/share/tmux/plugins/tpm"
[ -d "$TPM_DIR" ] && sudo rm -rf "$TPM_DIR"
sudo mkdir -p /usr/share/tmux/plugins
sudo git clone --depth=1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
sudo chmod -R 755 "$TPM_DIR"

# Minimal global tmux.conf
sudo tee /etc/tmux.conf >/dev/null <<'EOF'
set -g mouse on
set -g history-limit 10000
setw -g mode-keys vi

# TPM plugins
set -g @tpm_silent true
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
run-shell /usr/share/tmux/plugins/tpm/tpm
EOF

# -----------------------------
# Zoxide options
# -----------------------------
HOOK_OPTION="--hook"
CMD_OPTION="--cmd cd"
SET_DB=true
ENABLE_FZF=false

# Check if zoxide supports --fzf
if zoxide init zsh --help 2>&1 | grep -q -- '--fzf'; then
    ENABLE_FZF=true
fi
if $ENABLE_FZF; then
    FZF_OPTION="--fzf"
else
    FZF_OPTION=""
fi

echo
echo "Zoxide options enabled:"
echo "  • Auto-tracking (--hook)"
echo "  • Override cd (--cmd cd)"
[ $ENABLE_FZF = true ] && echo "  • Interactive fuzzy search (--fzf)"
echo "  • User-specific database (ZO_DATA)"
echo

# -----------------------------
# Clean previous system-wide zoxide setup
# -----------------------------
GLOBAL_BASHRC="/etc/bash.bashrc"
GLOBAL_ZSHRC="/etc/zsh/zshrc"

for rc in "$GLOBAL_BASHRC" "$GLOBAL_ZSHRC"; do
    [ -f "$rc" ] && sudo sed -i '/system-wide zoxide setup/,+15d' "$rc" || true
done

# -----------------------------
# Add fresh system-wide zoxide block
# -----------------------------
SETUP_BLOCK="
# >>> system-wide zoxide setup >>>
if command -v zoxide &>/dev/null; then
    if [ -n \"\$BASH_VERSION\" ]; then
        eval \"\$(zoxide init bash $HOOK_OPTION $FZF_OPTION $CMD_OPTION)\"
    elif [ -n \"\$ZSH_VERSION\" ]; then
        # Source fzf keybindings if available
        [ -f /usr/share/doc/fzf/examples/completion.zsh ] && source /usr/share/doc/fzf/examples/completion.zsh
        eval \"\$(zoxide init zsh $HOOK_OPTION $FZF_OPTION $CMD_OPTION)\"
    fi
fi
# <<< system-wide zoxide setup <<<
"

for rc in "$GLOBAL_BASHRC" "$GLOBAL_ZSHRC"; do
    [ -f "$rc" ] && echo "$SETUP_BLOCK" | sudo tee -a "$rc" >/dev/null
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
# Reload shell configuration
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
echo "=== ✅ Installation complete ==="
echo "Restart your terminal or run the appropriate source command for your shell:"
echo "  source /etc/bash.bashrc  # bash"
echo "  source /etc/zsh/zshrc    # zsh"
echo "Usage:"
echo "  z <partial>  → auto fuzzy jump with interactive window"
echo "  cd <path>    → also overridden by zoxide"
echo "  tmux         → plugins installed and silent"
echo "Press Ctrl+b then I in tmux to install TPM plugins if needed"
