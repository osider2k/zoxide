#!/usr/bin/env bash
# =====================================================
# Safe System-Wide Installer:
# Zsh + Oh My Zsh + Powerlevel10k + tmux + TPM + zoxide + fzf-tab + fzf
# =====================================================

set -euo pipefail
trap 'echo "❌ Error on line $LINENO"; exit 1' ERR

echo "=== Requesting sudo privilege (once) ==="
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# -----------------------------------------------------
# 1) Install packages
# -----------------------------------------------------
echo "=== Installing required packages ==="
export DEBIAN_FRONTEND=noninteractive
sudo apt update -y
sudo apt install -y git zsh tmux ca-certificates curl

# -----------------------------------------------------
# 2) Install Oh My Zsh system-wide
# -----------------------------------------------------
ZSH_DIR="/usr/share/oh-my-zsh"
if [[ ! -d "$ZSH_DIR" ]]; then
    echo "Installing Oh My Zsh..."
    sudo git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$ZSH_DIR"
fi

# Copy default skeleton .zshrc if not exists
if [[ ! -f /etc/skel/.zshrc ]]; then
    sudo cp "$ZSH_DIR/templates/zshrc.zsh-template" /etc/skel/.zshrc
    sudo sed -i "s|ZSH=.*|ZSH=$ZSH_DIR|" /etc/skel/.zshrc
fi

# -----------------------------------------------------
# 3) Install Powerlevel10k
# -----------------------------------------------------
P10K_DIR="$ZSH_DIR/custom/themes/powerlevel10k"
if [[ ! -d "$P10K_DIR" ]]; then
    echo "Installing Powerlevel10k..."
    sudo git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
fi

sudo sed -i 's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' /etc/skel/.zshrc

# -----------------------------------------------------
# 4) tmux + TPM
# -----------------------------------------------------
echo "Installing TPM..."
sudo git clone https://github.com/tmux-plugins/tpm /usr/share/tmux/plugins/tpm || true

sudo tee /etc/tmux.conf >/dev/null <<'EOF'
# === tmux configuration ===
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",xterm-256color:Tc"
set-option -g default-command "exec zsh -l"

set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'

run '/usr/share/tmux/plugins/tpm/tpm'
EOF

# Link /etc/tmux.conf to all home directories
for home_dir in /home/*; do
    [ -d "$home_dir" ] || continue
    user=$(basename "$home_dir")
    sudo -u "$user" ln -sf /etc/tmux.conf "$home_dir/.tmux.conf"
done
sudo ln -sf /etc/tmux.conf /root/.tmux.conf

# -----------------------------------------------------
# 5) zoxide + fzf-tab + fzf
# -----------------------------------------------------
for home_dir in /home/* /root; do
    [ -d "$home_dir" ] || continue
    user=$(basename "$home_dir")
    zsh_dir="$home_dir/.zsh"
    zshrc="$home_dir/.zshrc"

    sudo -u "$user" mkdir -p "$zsh_dir"

    # Clone fzf-tab
    sudo -u "$user" git clone https://github.com/Aloxaf/fzf-tab "$zsh_dir/fzf-tab"

    # Clone fzf (manual install)
    sudo -u "$user" git clone --depth 1 https://github.com/junegunn/fzf.git "$home_dir/.fzf"

    # Backup existing zshrc
    [ -f "$zshrc" ] && sudo cp "$zshrc" "$zshrc.backup.$(date +%s)" || sudo touch "$zshrc"

    # Append interactive-safe block
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

    sudo chown -R "$user:$user" "$zsh_dir" "$zshrc" "$home_dir/.fzf"
done

# -----------------------------------------------------
# 6) Set Zsh as default shell for all users
# -----------------------------------------------------
ZSH_BIN="$(command -v zsh)"
if ! grep -q "$ZSH_BIN" /etc/shells; then
    echo "$ZSH_BIN" | sudo tee -a /etc/shells >/dev/null
fi
sudo chsh -s "$ZSH_BIN" root
for uhome in /home/*; do
    [ -d "$uhome" ] || continue
    sudo chsh -s "$ZSH_BIN" "$(basename "$uhome")"
done

# -----------------------------------------------------
echo ""
echo "=== ✅ Installation complete ==="
echo "Reload Zsh: source ~/.zshrc"
echo "Reload tmux: tmux source ~/.tmux.conf"
echo "Open tmux and press Ctrl+b then I to install TPM plugins"
echo "To enable fzf key bindings, run: ~/.fzf/install for each user"
