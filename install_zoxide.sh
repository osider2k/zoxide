#!/usr/bin/env bash
# =====================================================
# Full Clean System-Wide Installer:
# Zsh + Oh My Zsh + Powerlevel10k + tmux + TPM + zoxide + fzf-tab + fzf
# Completely removes old configs before install
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
    sudo rm -rf "$home_dir/.oh-my-zsh" "$home_dir/.zsh" "$home_dir/.zshrc" "$home_dir/.p10k.zsh"
    sudo rm -rf "$home_dir/.tmux.conf" "$home_dir/.tmux" "$home_dir/.fzf"
done

# -----------------------------------------------------
# 1) Install required packages
# -----------------------------------------------------
echo "=== Installing required packages ==="
export DEBIAN_FRONTEND=noninteractive
sudo apt update -y
sudo apt install -y git zsh tmux ca-certificates curl

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
# 5) Install zoxide + fzf-tab + fzf (non-interactive)
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

    # fzf (non-interactive install)
    FZF_DIR="$home_dir/.fzf"
    sudo -u "$user" git clone --depth 1 https://github.com/junegunn/fzf.git "$FZF_DIR"

    # Ensure ownership (fix permission issues)
    sudo chown -R "$user:$user" "$FZF_DIR"

    # Run non-interactive install as user
    sudo -u "$user" "$FZF_DIR/install" --all --no-bash --no-fish

    # Backup existing zshrc
    [ -f "$zshrc" ] && sudo cp "$zshrc" "$zshrc.backup.$(date +%s)" || sudo touch "$zshrc"

    # Append interactive-safe block for fzf-tab & zoxide
    sudo tee -a "$zshrc" >/dev/null <<'EOF'
# === fzf-tab & zoxide (interactive only) ===
if [[ $- == *i* ]]; then
  [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
  eval "$(zoxide init zsh)"
  alias cd="z"
  FZF_TAB_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/fzf-tab"
  [[ -d "$FZF_TAB_DIR" ]] && source "$FZF_TAB_DIR/fzf-tab.plugin.zsh"
fi
EOF

    sudo chown -R "$user:$user" "$zsh_dir" "$zshrc" "$FZF_DIR"
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
echo ""
echo "=== ✅ Full Clean Installation Complete ==="
echo "Reload Zsh: source ~/.zshrc"
echo "Reload tmux: tmux source ~/.tmux.conf"
echo "Open tmux and press Ctrl+b then I to install TPM plugins"
echo "All users now have Zsh + Powerlevel10k + tmux + fzf-tab + zoxide + FZF fully set up"
