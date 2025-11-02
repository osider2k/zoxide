#!/usr/bin/env bash
# =====================================================
# Safe System-Wide Installation:
# tmux + TPM + zoxide + fzf-tab + fzf
# Preserves existing Zsh settings
# =====================================================

set -euo pipefail
trap 'echo "❌ Error on line $LINENO"; exit 1' ERR

echo "=== Requesting sudo privilege (once) ==="
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# -----------------------------------------------------
# CLEAN PREVIOUS INSTALLS (tmux, plugins, fzf-tab, fzf)
# -----------------------------------------------------
echo "=== Cleaning old tmux/fzf installs (optional) ==="
sudo rm -rf /usr/share/tmux/plugins/tpm /etc/tmux.conf
for home_dir in /home/*; do
    [ -d "$home_dir" ] || continue
    sudo rm -f "$home_dir/.tmux.conf"
    sudo rm -rf "$home_dir/.tmux" "$home_dir/.zsh/fzf-tab" "$home_dir/.fzf"
done
sudo rm -rf /root/.tmux /root/.zsh/fzf-tab /root/.tmux.conf /root/.fzf

# -----------------------------------------------------
# INSTALL PACKAGES
# -----------------------------------------------------
echo "=== Installing required packages ==="
sudo apt update -y
sudo apt install -y git tmux zoxide

# -----------------------------------------------------
# TMUX + TPM
# -----------------------------------------------------
echo "=== Installing TPM (Tmux Plugin Manager) ==="
sudo git clone https://github.com/tmux-plugins/tpm /usr/share/tmux/plugins/tpm

sudo tee /etc/tmux.conf >/dev/null <<'EOF'
# ===============================================
# Global Tmux Configuration with TPM
# ===============================================
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'

# Initialize TPM
run '/usr/share/tmux/plugins/tpm/tpm'
EOF

for home_dir in /home/*; do
    [ -d "$home_dir" ] || continue
    user=$(basename "$home_dir")
    sudo -u "$user" ln -sf /etc/tmux.conf "$home_dir/.tmux.conf"
done
sudo ln -sf /etc/tmux.conf /root/.tmux.conf

# -----------------------------------------------------
# FZF-TAB + zoxide
# -----------------------------------------------------
echo "=== Setting up zoxide and fzf-tab ==="
for home_dir in /home/*; do
    [ -d "$home_dir" ] || continue
    user=$(basename "$home_dir")
    zsh_dir="$home_dir/.zsh"
    zshrc="$home_dir/.zshrc"

    sudo -u "$user" mkdir -p "$zsh_dir"

    # Clone fzf-tab
    sudo -u "$user" git clone https://github.com/Aloxaf/fzf-tab "$zsh_dir/fzf-tab"

    # Clone fzf from GitHub (manual install later)
    sudo -u "$user" git clone --depth 1 https://github.com/junegunn/fzf.git "$home_dir/.fzf"

    # Backup existing zshrc if it exists
    if [ -f "$zshrc" ]; then
        sudo cp "$zshrc" "$zshrc.backup.$(date +%s)"
        echo "Backed up $zshrc"
    else
        sudo touch "$zshrc"
        sudo chown "$user:$user" "$zshrc"
    fi

    # Append fzf-tab and zoxide config safely
    sudo tee -a "$zshrc" >/dev/null <<'EOF'
# ===== fzf-tab & zoxide =====
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
eval "$(zoxide init zsh)"
alias cd="z"
source ~/.zsh/fzf-tab/fzf-tab.plugin.zsh
EOF

    sudo chown "$user:$user" -R "$zsh_dir" "$zshrc" "$home_dir/.fzf"
done

# Root config
sudo mkdir -p /root/.zsh
sudo git clone https://github.com/Aloxaf/fzf-tab /root/.zsh/fzf-tab
sudo git clone --depth 1 https://github.com/junegunn/fzf.git /root/.fzf

# Backup root .zshrc and append configuration
if [ -f /root/.zshrc ]; then
    sudo cp /root/.zshrc /root/.zshrc.backup.$(date +%s)
fi

sudo tee -a /root/.zshrc >/dev/null <<'EOF'
# ===== fzf-tab & zoxide =====
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
eval "$(zoxide init zsh)"
alias cd="z"
source ~/.zsh/fzf-tab/fzf-tab.plugin.zsh
EOF

# -----------------------------------------------------
# FZF manual install reminder
# -----------------------------------------------------
echo ""
echo "=== FZF interactive install required ==="
echo "To enable key bindings and shell completion, run:"
echo ""
echo "For each user:"
echo "  ~/.fzf/install"
echo "Example for current user:"
echo "  ~/.fzf/install"
echo ""
echo "For root:"
echo "  sudo /root/.fzf/install"
echo ""

# -----------------------------------------------------
echo "=== ✅ Installation complete ==="
echo "Reload Zsh: source ~/.zshrc"
echo "Reload tmux: tmux source ~/.tmux.conf"
echo "Open tmux and press Ctrl+b then I to install TPM plugins."
