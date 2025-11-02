#!/usr/bin/env bash
set -e

echo "=== System-wide installer: tmux + TPM + fzf + zoxide ==="

# -----------------------------
# Detect package manager
# -----------------------------
if command -v apt &>/dev/null; then
    PKG_MANAGER="apt"
    UPDATE_CMD="apt update -y"
    INSTALL_CMD="apt install -y"
elif command -v dnf &>/dev/null; then
    PKG_MANAGER="dnf"
    UPDATE_CMD="dnf -y update"
    INSTALL_CMD="dnf -y install"
elif command -v pacman &>/dev/null; then
    PKG_MANAGER="pacman"
    UPDATE_CMD="pacman -Sy --noconfirm"
    INSTALL_CMD="pacman -S --noconfirm"
else
    echo "❌ No supported package manager found (apt, dnf, pacman)."
    exit 1
fi

echo "Detected: $PKG_MANAGER"
echo "=== Updating system package list ==="
sudo bash -c "$UPDATE_CMD"

# -----------------------------
# Install packages
# -----------------------------
echo "=== Installing tmux, fzf, zoxide, git, curl ==="
sudo bash -c "$INSTALL_CMD tmux fzf zoxide git curl"

# -----------------------------
# Clean TPM and reinstall
# -----------------------------
TPM_DIR="/usr/share/tmux/plugins/tpm"
echo "=== Installing Tmux Plugin Manager (TPM) ==="
if [ -d "$TPM_DIR" ]; then
    sudo rm -rf "$TPM_DIR"
    echo "🧹 Removed old TPM at $TPM_DIR"
fi
sudo mkdir -p /usr/share/tmux/plugins
sudo git clone --depth=1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
sudo chmod -R 755 "$TPM_DIR"
echo "✔ Fresh TPM installed at $TPM_DIR"

# -----------------------------
# Write clean global tmux.conf
# -----------------------------
GLOBAL_TMUX_CONF="/etc/tmux.conf"
echo "=== Writing clean global tmux.conf ==="
sudo tee "$GLOBAL_TMUX_CONF" >/dev/null <<'EOF'
# ===============================================================
# System-wide tmux configuration with TPM support
# ===============================================================
set -g mouse on
set -g history-limit 10000
setw -g mode-keys vi

set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'

run-shell /usr/share/tmux/plugins/tpm/tpm
EOF
sudo chmod 644 "$GLOBAL_TMUX_CONF"

# -----------------------------
# Interactive zoxide options
# -----------------------------
while true; do
    echo
    echo "=== zoxide system-wide setup ==="
    read -rp "Enable auto-tracking of directories (--hook)? [y/n]: " ENABLE_HOOK
    read -rp "Enable fuzzy search with fzf (--fzf)? [y/n]: " ENABLE_FZF
    read -rp "Override normal cd with zoxide (--cmd cd)? [y/n]: " OVERRIDE_CD
    read -rp "Set user-specific database location (ZO_DATA)? [y/n]: " SET_DB

    echo
    echo "You selected:"
    echo "  Auto-tracking (--hook): $ENABLE_HOOK"
    echo "  Fuzzy search (--fzf): $ENABLE_FZF"
    echo "  Override cd (--cmd cd): $OVERRIDE_CD"
    echo "  User-specific database (ZO_DATA): $SET_DB"
    echo

    read -rp "Apply these options? [y/n/r for restart]: " CONFIRM
    case "$CONFIRM" in
        [Yy]* ) break ;;
        [Rr]* ) echo "Restarting option selection..."; continue ;;
        [Nn]* ) echo "Exiting without applying zoxide options."; exit 0 ;;
        * ) echo "Please answer y, n, or r." ;;
    esac
done

# -----------------------------
# Determine zoxide flags
# -----------------------------
HOOK_OPTION=""
if [[ "$ENABLE_HOOK" =~ ^[Yy]$ ]]; then HOOK_OPTION="--hook"; fi
FZF_OPTION=""
if [[ "$ENABLE_FZF" =~ ^[Yy]$ ]]; then FZF_OPTION="--fzf"; fi
CMD_OPTION=""
if [[ "$OVERRIDE_CD" =~ ^[Yy]$ ]]; then CMD_OPTION="--cmd cd"; else CMD_OPTION="--cmd z"; fi

# -----------------------------
# Apply system-wide integration
# -----------------------------
GLOBAL_BASHRC="/etc/bash.bashrc"
GLOBAL_ZSHRC="/etc/zsh/zshrc"
SETUP_BLOCK="
# >>> system-wide zoxide setup >>>
if command -v zoxide &>/dev/null; then
    if [ -n \"\$BASH_VERSION\" ]; then
        eval \"\$(zoxide init bash $HOOK_OPTION $FZF_OPTION $CMD_OPTION)\"
    elif [ -n \"\$ZSH_VERSION\" ]; then
        eval \"\$(zoxide init zsh $HOOK_OPTION $FZF_OPTION $CMD_OPTION)\"
    fi
fi
# <<< system-wide zoxide setup <<<
"

for rc in "$GLOBAL_BASHRC" "$GLOBAL_ZSHRC"; do
    if [ -f "$rc" ]; then
        sudo sed -i '/system-wide zoxide setup/,+10d' "$rc" || true
        echo "$SETUP_BLOCK" | sudo tee -a "$rc" >/dev/null
        echo "✔ Applied zoxide integration to $rc"
    fi
done

# -----------------------------
# User-specific ZO_DATA
# -----------------------------
if [[ "$SET_DB" =~ ^[Yy]$ ]]; then
    USER_DB="$HOME/.local/share/zoxide/db.zo"
    if [ -f "$USER_DB" ]; then
        rm -f "$USER_DB"
        echo "🧹 Removed old user ZO_DATA at $USER_DB"
    fi
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ -f "$rc" ]; then
            grep -q "export ZO_DATA" "$rc" || echo "export ZO_DATA=\"\$HOME/.local/share/zoxide/db.zo\"" >> "$rc"
        fi
    done
    echo "✔ User-specific ZO_DATA set at $USER_DB"
fi

# -----------------------------
# Complete
# -----------------------------
echo
echo "=== ✅ Clean Installation Complete ==="
echo "Installed:"
echo "  • tmux + TPM"
echo "  • fzf"
echo "  • zoxide with selected options"
echo
echo "💡 Restart your terminal or run:"
echo "   source /etc/bash.bashrc   # for bash"
echo "   source /etc/zsh/zshrc     # for zsh"
echo
echo "🧩 To enable tmux plugins, start tmux and press Ctrl+b then I (capital i)"
