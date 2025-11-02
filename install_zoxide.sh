#!/usr/bin/env bash
# ================================================================
# System-wide installer for tmux, fzf, zoxide, and tmux plugin manager (TPM)
# Works with Debian/Ubuntu, Fedora/RHEL, and Arch/Manjaro
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

echo "=== Installing tmux, fzf, and zoxide system-wide ==="
sudo bash -c "$INSTALL_CMD tmux fzf zoxide git curl"

# ---------------------------------------------------------------
# Install tmux plugin manager (TPM)
# ---------------------------------------------------------------
TPM_DIR="/usr/share/tmux/plugins/tpm"

echo "=== Installing Tmux Plugin Manager (TPM) ==="

if [ ! -d "$TPM_DIR" ]; then
    sudo mkdir -p /usr/share/tmux/plugins
    sudo git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
    sudo chmod -R 755 "$TPM_DIR"
    echo "✔ Installed TPM to $TPM_DIR"
else
    echo "↺ TPM already installed at $TPM_DIR"
fi

# ---------------------------------------------------------------
# Add global tmux configuration with TPM support
# ---------------------------------------------------------------
GLOBAL_TMUX_CONF="/etc/tmux.conf"

if [ ! -f "$GLOBAL_TMUX_CONF" ]; then
    sudo tee "$GLOBAL_TMUX_CONF" >/dev/null <<'EOF'
# ===============================================================
# System-wide tmux configuration with TPM support
# ===============================================================

# Use TPM (Tmux Plugin Manager)
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'

# Initialize TPM (keep this line at the bottom)
run-shell /usr/share/tmux/plugins/tpm/tpm
EOF
    echo "✔ Created global tmux config with TPM enabled at $GLOBAL_TMUX_CONF"
else
    echo "↺ Global tmux.conf already exists; skipped creation."
fi

# ---------------------------------------------------------------
# Setup global shell integration for zoxide + fzf
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

echo "=== Configuring global shell integration ==="

for rc in "$GLOBAL_BASHRC" "$GLOBAL_ZSHRC"; do
    if [ -f "$rc" ]; then
        if ! grep -q "system-wide zoxide + fzf setup" "$rc"; then
            echo "$SETUP_BLOCK" | sudo tee -a "$rc" >/dev/null
            echo "✔ Added zoxide + fzf setup to $rc"
        else
            echo "↺ Integration already present in $rc"
        fi
    fi
done

# ---------------------------------------------------------------
# Completion
# ---------------------------------------------------------------
echo
echo "=== ✅ Installation Complete ==="
echo "Installed:"
echo "  • tmux   - terminal multiplexer"
echo "  • fzf    - fuzzy finder"
echo "  • zoxide - smarter cd command"
echo "  • TPM    - tmux plugin manager"
echo
echo "🧩 To enable tmux plugins, start tmux and press:"
echo "      Ctrl + b then I  (capital i)"
echo
echo "💡 Restart your terminal or run:"
echo "   source /etc/bash.bashrc   # for bash"
echo "   source /etc/zsh/zshrc     # for zsh"
echo
echo "📂 Global tmux config: /etc/tmux.conf"
echo "📦 TPM directory:      /usr/share/tmux/plugins/tpm"
