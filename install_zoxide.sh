#!/usr/bin/env bash
# =====================================================
# Clean System-Wide Installation Script:
# tmux + TPM + fzf + zoxide + fzf-tab (Zsh)
# =====================================================

set -euo pipefail
trap 'echo "Error occurred on line $LINENO"; exit 1' ERR

echo "=== Requesting sudo privilege (will ask once) ==="
sudo -v
# Keep sudo alive
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

echo "=== Cleaning previous installations ==="
sudo rm -rf /usr/share/tmux/plugins/tpm
sudo rm -f /etc/tmux.conf
for user_home in /home/*; do
    [ -d "$user_home" ] || continue
    rm -f "$user_home/.tmux.conf"
    rm -rf "$user_home/.tmux"
    rm -rf "$user_home/.fzf"
    rm -rf "$user_home/.zsh/fzf-tab"
done
sudo rm -rf /root/.tmux /root/.fzf /root/.zsh/fzf-tab /root/.tmux.conf

echo "=== Installing required packages ==="
sudo apt update -y
sudo apt install -y git tmux fzf zoxide

# -----------------------------------------------------
# TMUX + TPM SETUP
# -----------------------------------------------------
echo "=== Installing TPM (Tmux Plugin Manager) ==="
sudo git clone https://github.com/tmux-plugins/tpm /usr/share/tmux/plugins/tpm

echo "=== Creating global tmux configuration ==="
sudo tee /etc/tmux.conf >/dev/null <<'EOF'
# ===============================================
# Global Tmux Configuration with TPM
# ===============================================

# List of plugins
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'

# Initialize TPM (keep this line at the very bottom)
run '/usr/share/tmux/plugins/tpm/tpm'
EOF

echo "=== Linking global tmux.conf for all users ==="
for user_home in /home/*; do
    [ -d "$user_home" ] || continue
    sudo -u "$(basename "$user_home")" ln -sf /etc/tmux.conf "$user_home/.tmux.conf"
done
sudo ln -sf /etc/tmux.conf /root/.tmux.conf

# -----------------------------------------------------
# FZF + ZOXIDE + FZF-TAB CONFIGURATION
# -----------------------------------------------------
echo "=== Configuring Zsh integrations (fzf, zoxide, fzf-tab) ==="
for user_home in /home/*; do
    [ -d "$user_home" ] || continue
    user_name=$(basename "$user_home")
    zshrc="$user_home/.zshrc"

    echo "--- Cleaning and setting up ~/.zshrc for $user_name ---"
    sudo -u "$user_name" bash -c "rm -f $zshrc && touch $zshrc"

    sudo -u "$user_name" bash -c "mkdir -p $user_home/.zsh"
    sudo -u "$user_name" git clone https://github.com/Aloxaf/fzf-tab "$user_home/.zsh/fzf-tab"

    sudo tee "$zshrc" >/dev/null <<'EOF'
# =====================================================
# Zsh Configuration with fzf, zoxide, fzf-tab
# =====================================================

# Load fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# zoxide setup
eval "$(zoxide init zsh)"
alias cd="z"

# Enable fzf-tab for always-on interactive completion
source ~/.zsh/fzf-tab/fzf-tab.plugin.zsh
EOF

    sudo chown "$user_name:$user_name" "$zshrc"
done

# Also configure root user
mkdir -p /root/.zsh
git clone https://github.com/Aloxaf/fzf-tab /root/.zsh/fzf-tab
cat <<'EOF' > /root/.zshrc
# =====================================================
# Root Zsh Configuration with fzf, zoxide, fzf-tab
# =====================================================
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
eval "$(zoxide init zsh)"
alias cd="z"
source ~/.zsh/fzf-tab/fzf-tab.plugin.zsh
EOF

echo "=== All installations and configurations complete! ==="
echo "Reload zsh with: source ~/.zshrc"
echo "Reload tmux with: tmux source ~/.tmux.conf"
echo "Open tmux and press Ctrl+b then I to install TPM plugins."
