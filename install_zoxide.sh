#!/usr/bin/env bash
# ================================================================
# System-wide installer for tmux, fzf, zoxide, and tmux plugin manager (TPM)
# Clean install — removes old/corrupted installs automatically
# Works with: Debian/Ubuntu, Fedora/RHEL, Arch/Manjaro
# ================================================================

set -e

echo "=== Detecting package manager ==="

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

echo "=== Installing tmux, fzf, zoxide, git, and curl ==="
sudo bash -c "$INSTALL_CMD tmux fzf zoxide git curl"

# ---------------------------------------------------------------
# Clean + fresh install of tmux plugin manager (TPM)
# ---------------------------------------------------------------
TPM_DIR="/usr/share/tmux/plugins/tpm"

echo "=== Cleaning old TPM installation ==="
if [ -d "$TPM_DIR" ]; then
    sudo rm -rf "$TPM_DIR"
    echo "🧹 Removed old TPM at $TPM_DIR"
fi

echo "=== Installing new TPM ==="
sudo mkdir -p /usr/share/tmux/plugins
sudo git clone --depth=1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
sudo chmod -R 755 "$TPM_DIR"
echo "✔ Fresh TPM installed at $TPM_DIR"

# ---------------------------------------------------------------
# Always rewrite a clean global tmux.conf with TPM setup
# ---------------------------------------------------------------
GLOBAL_TMUX_CONF="/etc/tmux.conf"

echo "=== Writing clean global tmux.conf ==="
sudo tee "$GLOBAL_TMUX_CONF" >/dev/null <<'EOF'
# ===============================================================
# System-wide tmux configuration with TPM support
# ===============================================================

# Sensible defaults
set -g mouse on
set -g history-limit 10000
setw -g mode-keys vi

# TPM (Tmux Plugin Manager)
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'

# Initialize TPM (keep this line at the bottom)
run-shell /usr/share/tmux/plugins/tpm/tpm
EOF

sudo chmod 644 "$GLOBAL_TMUX_CONF"
echo "✔ Global tmux.conf refreshed"

# ---------------------------------------------------------------
# Global zoxide + fzf shell integration
# ---------------------------------------------------------------
GLOBAL_BASHRC="/etc/bash.bashrc"
GLOBAL_ZSHRC="/etc/zsh/zshrc"

SETUP_BLOCK="
# >>> system-wide zoxide + fzf setup >>>
if command -v zoxide &>/dev/null; then
    if [ -n \"\$BASH_VERSION\" ]; then
        eval \"\$(zoxide init bash)\"
    elif [ -n \"\$ZSH_VERSION\" ]; then
        eval \"\$(zoxide init zsh)\"
    fi
fi

if command -v fzf &>/dev/null; then
    [ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && source /usr/share/doc/fzf/examples/key-bindings.bash
    [ -f /usr/share/doc/fzf/examples/completion.bash ] && source /usr/share/doc/fzf/examples/completion.bash
fi
# <<< system-wide zoxide + fzf setup <<<
"

echo "=== Ensuring clean zoxide + fzf integration ==="
for rc in "$GLOBAL_BASHRC" "$GLOBAL_ZSHRC"; do
    if [ -f "$rc" ]; then
        sudo sed -i '/system-wide zoxide + fzf setup/,+10d' "$rc" || true
        echo "$SETUP_BLOCK" | sudo tee -a "$rc" >/dev/null
        echo "✔ Replaced integration block in $rc"
    fi
done

# ---------------------------------------------------------------
# Verification
# ---------------------------------------------------------------
echo "=== Verifying installations ==="
command -v tmux >/dev/null && echo "✔ tmux OK"
command -v fzf >/dev/null && echo "✔ fzf OK"
command -v zoxide >/dev/null && echo "✔ zoxide OK"
[ -d "$TPM_DIR" ] && echo "✔ TPM OK"

# ---------------------------------------------------------------
# Done
# ---------------------------------------------------------------
echo
echo "=== ✅ Clean Installation Complete ==="
echo "Installed:"
echo "  • tmux   - terminal multiplexer"
echo "  • fzf    - fuzzy finder"
echo "  • zoxide - smarter cd command"
echo "  • TPM    - tmux plugin manager"
echo
echo "🧩 To enable tmux plugins:"
echo "      Start tmux and press  Ctrl + b then I  (capital i)"
echo
echo "💡 To apply zoxide + fzf setup now:"
echo "      source /etc/bash.bashrc   # for bash"
echo "      source /etc/zsh/zshrc     # for zsh"
echo
echo "📁 TPM directory:   /usr/share/tmux/plugins/tpm"
echo "⚙️  Global tmux.conf: /etc/tmux.conf"
