#!/usr/bin/env bash
# =====================================================
# Clean System-Wide Installation:
# tmux + TPM + fzf (from GitHub) + zoxide + fzf-tab
# Zsh already installed
# =====================================================

set -euo pipefail
trap 'echo "❌ Error on line $LINENO"; exit 1' ERR

echo "=== Requesting sudo privilege (once) ==="
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# -----------------------------------------------------
# CLEAN PREVIOUS INSTALLS
# -----------------------------------------------------
echo "=== Cleaning old installs ==="
sudo rm -rf /usr/share/tmux/plugins/tpm /etc/tmux.conf
for home_dir in /home/*; do
    [ -d "$home_dir" ] || continue
    sudo rm -f "$home_dir/.tmux.conf"
    sudo rm -rf "$home_dir/.tmux" "$home_dir/.zsh/fzf-tab" "$home_dir/.fzf"
done
sudo rm -rf /root/.tmux /root/.zsh/fzf-tab /root/.tmux.conf /root/.fzf

# -----------------------------------------------------
# INSTALL PACKAGES (except fzf)
# -----------------------------------------------------
echo "=== Installing required packages (git, tmux, zoxide) ==="
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
# FZF + ZOXIDE + FZF-TAB
# -----------------------------------------------------
echo "=== Setting up zoxide and fzf-tab ==="
for home_dir in /home/*; do
    [ -d "$home_dir" ] || continue
    user=$(basename "$home_dir")
    zshrc="$home_dir/.zshrc"

    sudo -u "$user" mkdir -p "$home_dir/.zsh"

    # Clone fzf-tab
    sudo -u "$user" git clone https://github.com/Aloxaf/fzf-tab "$home_dir/.zsh/fzf-tab"

    # Clone fzf from GitHub
    sudo -u "$user" git clone --depth 1 https://github.com/junegunn/fzf.git "$home_dir/.fzf"

    # Write zshrc
    sudo tee "$zshrc" >/dev/null <<'EOF'
# Load fzf (before zoxide)
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# zoxide
eval "$(zoxide init zsh)"
alias cd="z"

# fzf-tab (always-on interactive completion)
source ~/.zsh/fzf-tab/fzf-tab.plugin.zsh
EOF

    sudo chown "$user:$user" -R "$zshrc"

    # Run fzf install script interactively
    sudo -u "$user" bash -c "cd $home_dir/.fzf && ./install"
done

# Root config
sudo mkdir -p /root/.zsh
sudo git clone https://github.com/Aloxaf/fzf-tab /root/.zsh/fzf-tab
sudo git clone --depth 1 https://github.com/junegunn/fzf.git /root/.fzf

sudo tee /root/.zshrc >/dev/null <<'EOF'
# Load fzf (before zoxide)
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# zoxide
eval "$(zoxide init zsh)"
alias cd="z"

# fzf-tab (always-on interactive completion)
source ~/.zsh/fzf-tab/fzf-tab.plugin.zsh
EOF

# Run fzf install for root
sudo bash -c "cd /root/.fzf && ./install"

# -----------------------------------------------------
echo "=== ✅ Installation complete ==="
echo "Reload zsh with: source ~/.zshrc"
echo "Reload tmux with: tmux source ~/.tmux.conf"
echo "Open tmux and press Ctrl+b then I to install TPM plugins."
