#!/usr/bin/env bash
# =====================================================
# Full Clean System-Wide Installer:
# TPM + zoxide + fzf-tab
# FZF repo is cloned, but interactive install must be run manually
# =====================================================

set -euo pipefail
trap 'echo "❌ Error on line $LINENO"; exit 1' ERR

echo "=== Requesting sudo privilege (once) ==="
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# -----------------------------------------------------
# 0) Remove all old configurations
# -----------------------------------------------------
echo "=== Removing old configurations ==="
sudo rm -rf /usr/share/oh-my-zsh /usr/share/tmux/plugins/tpm /etc/tmux.conf
for home_dir in /home/* /root; do
    [ -d "$home_dir" ] || continue    
    sudo rm -rf "$home_dir/.tmux.conf" "$home_dir/.tmux" "$home_dir/.fzf"
done

# -----------------------------------------------------
# 1) Install required packages
# -----------------------------------------------------
echo "=== Installing required packages ==="
export DEBIAN_FRONTEND=noninteractive
sudo apt update -y

# Don't need zsh install together
sudo apt install -y git tmux ca-certificates curl

# -----------------------------------------------------
# 2) Install Oh My Zsh system-wide
# -----------------------------------------------------
ZSH_DIR="/usr/share/oh-my-zsh"
echo "Installing Oh My Zsh..."
sudo git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$ZSH_DIR"

# Skeleton .zshrc for new users
sudo cp "$ZSH_DIR/templates/zshrc.zsh-template" /etc/skel/.zshrc
sudo sed -i "s|ZSH=.*|ZSH=$ZSH_DIR|" /etc/skel/.zshrc

# -----------------------------------------------------
# 3) Install Powerlevel10k
# -----------------------------------------------------
P10K_DIR="$ZSH_DIR/custom/themes/powerlevel10k"
echo "Installing Powerlevel10k..."
sudo git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
sudo sed -i 's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' /etc/skel/.zshrc

# -----------------------------------------------------
# 4) Install tmux + TPM
# -----------------------------------------------------
TPM_DIR="/usr/share/tmux/plugins/tpm"
echo "Installing TPM..."
sudo git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"

sudo tee /etc/tmux.conf >/dev/null <<'EOF'
# === tmux configuration ===
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",xterm-256color:Tc"
set-option -g default-command "exec zsh -l"

set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'

run '/usr/share/tmux/plugins/tpm/tpm'
EOF

# Link /etc/tmux.conf to all users
for home_dir in /home/* /root; do
    [ -d "$home_dir" ] || continue
    user=$(basename "$home_dir")
    sudo -u "$user" ln -sf /etc/tmux.conf "$home_dir/.tmux.conf"
done

# -----------------------------------------------------
# 5) Install zoxide + fzf-tab + clone FZF repo
# -----------------------------------------------------
for home_dir in /home/* /root; do
    [ -d "$home_dir" ] || continue
    user=$(basename "$home_dir")
    zsh_dir="$home_dir/.zsh"
    zshrc="$home_dir/.zshrc"

    sudo -u "$user" mkdir -p "$zsh_dir"

    # fzf-tab
    FZF_TAB_DIR="$zsh_dir/fzf-tab"
    sudo -u "$user" git clone https://github.com/Aloxaf/fzf-tab "$FZF_TAB_DIR"

    # fzf repo (interactive install deferred)
    FZF_DIR="$home_dir/.fzf"
    sudo -u "$user" git clone --depth 1 https://github.com/junegunn/fzf.git "$FZF_DIR"
    sudo chown -R "$user:$user" "$FZF_DIR"

    # Backup existing zshrc
    [ -f "$zshrc" ] && sudo cp "$zshrc" "$zshrc.backup.$(date +%s)" || sudo touch "$zshrc"

    # Append interactive-safe block for zoxide & fzf-tab
    sudo tee -a "$zshrc" >/dev/null <<'EOF'
# === fzf-tab & zoxide ===
if [[ $- == *i* ]]; then
  [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
  eval "$(zoxide init zsh)"
  alias cd="z"
  FZF_TAB_DIR="$HOME/.zsh/fzf-tab"
  [[ -d "$FZF_TAB_DIR" ]] && source "$FZF_TAB_DIR/fzf-tab.plugin.zsh"
fi
EOF

    sudo chown -R "$user:$user" "$zsh_dir" "$zshrc"
done

# -----------------------------------------------------
# 6) Set Zsh as default shell for all users
# -----------------------------------------------------
ZSH_BIN="$(command -v zsh)"
if ! grep -q "$ZSH_BIN" /etc/shells; then
    echo "$ZSH_BIN" | sudo tee -a /etc/shells >/dev/null
fi
for uhome in /home/* /root; do
    [ -d "$uhome" ] || continue
    sudo chsh -s "$ZSH_BIN" "$(basename "$uhome")"
done

# -----------------------------------------------------
# 7) Instructions for FZF
# -----------------------------------------------------
echo ""
echo "=== FZF setup remaining ==="
echo "The FZF repository has been cloned, but interactive install must be run manually."
for uhome in /home/* /root; do
    [ -d "$uhome/.fzf" ] || continue
    echo "User '$(basename "$uhome")' run:"
    echo "  $uhome/.fzf/install"
done

# -----------------------------------------------------
echo ""
echo "=== ✅ Full Clean Installation Complete ==="
echo "Reload Zsh: source ~/.zshrc"
echo "Reload tmux: tmux source ~/.tmux.conf"
echo "Open tmux and press Ctrl+b then I to install TPM plugins"
echo "FZF setup must be completed manually per user"
