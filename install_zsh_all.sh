#!/usr/bin/env bash
set -e

# --- Retry helper ---
retry() {
    local -r -i max_attempts="$1"; shift
    local -r cmd=("$@")
    local -i attempt_num=1
    until "${cmd[@]}"; do
        if (( attempt_num == max_attempts )); then
            echo "Error: '${cmd[*]}' failed after $attempt_num attempts." >&2
            return 1
        else
            echo "Warning: '${cmd[*]}' failed. Retrying in 5s... ($attempt_num/$max_attempts)"
            sleep 5
            ((attempt_num++))
        fi
    done
}

echo "=== Detecting package manager ==="
if command -v apt &>/dev/null; then
    PKG_MANAGER="apt"
elif command -v dnf &>/dev/null; then
    PKG_MANAGER="dnf"
elif command -v pacman &>/dev/null; then
    PKG_MANAGER="pacman"
elif command -v zypper &>/dev/null; then
    PKG_MANAGER="zypper"
else
    echo "Unsupported Linux distribution." >&2
    exit 1
fi
echo "Detected package manager: $PKG_MANAGER"

# --- Ask sudo once and keep alive ---
if sudo -v; then
    echo "Sudo access granted, keeping session alive..."
    while true; do
        sudo -n true
        sleep 60
        kill -0 "$$" || exit
    done 2>/dev/null &
else
    echo "Sudo is required. Aborting."
    exit 1
fi

# --- Install basic packages per distro ---
case $PKG_MANAGER in
    apt)
        sudo apt update
        sudo apt install -y curl git make gcc libncurses5-dev libncursesw5-dev libssl-dev libbz2-dev libreadline-dev zlib1g-dev
        ;;
    dnf)
        sudo dnf install -y curl git make gcc ncurses-devel openssl-devel bzip2 bzip2-devel readline-devel zlib-devel
        ;;
    pacman)
        sudo pacman -Sy --noconfirm curl git make gcc ncurses openssl bzip2 zlib
        ;;
    zypper)
        sudo zypper install -y curl git make gcc ncurses-devel libopenssl-devel bzip2 bzip2-devel readline-devel zlib-devel
        ;;
esac

# --- Clean previous installations ---
[ -d "$HOME/.fzf" ] && rm -rf "$HOME/.fzf"
[ -d "$HOME/.powerlevel10k" ] && rm -rf "$HOME/.powerlevel10k"
command -v zoxide &>/dev/null && cargo uninstall zoxide || true

# --- Install latest Zsh ---
MIN_VERSION="5.9"
INSTALLED_VERSION=$(zsh --version 2>/dev/null | awk '{print $2}' || echo "0")

vercomp () {
    [ "$1" = "$2" ] && return 0
    local IFS=.
    local i ver1=($1) ver2=($2)
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do ver1[i]=0; done
    for ((i=0; i<${#ver1[@]}; i++)); do
        if [[ -z ${ver2[i]} ]]; then ver2[i]=0; fi
        if ((10#${ver1[i]} > 10#${ver2[i]})); then return 1; fi
        if ((10#${ver1[i]} < 10#${ver2[i]})); then return 2; fi
    done
    return 0
}

vercomp "$INSTALLED_VERSION" "$MIN_VERSION"
COMP_RESULT=$?

if [[ ! $(command -v zsh) ]] || [[ $COMP_RESULT -ne 1 ]]; then
    echo "Installing latest Zsh from source..."
    tmpdir=$(mktemp -d)
    git clone https://github.com/zsh-users/zsh.git "$tmpdir/zsh"
    cd "$tmpdir/zsh"
    ./Util/preconfig
    ./configure --prefix=$HOME/.local
    make -j$(nproc)
    make install
    export PATH="$HOME/.local/bin:$PATH"
    cd -
    rm -rf "$tmpdir"
fi

# --- Install Powerlevel10k ---
if [ ! -d "$HOME/.powerlevel10k" ]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$HOME/.powerlevel10k"
fi
grep -q "powerlevel10k.zsh-theme" ~/.zshrc 2>/dev/null || \
    echo "source $HOME/.powerlevel10k/powerlevel10k.zsh-theme" >> ~/.zshrc

# --- Install Rust + zoxide ---
if ! command -v cargo &>/dev/null; then
    retry 3 curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
    export PATH="$HOME/.cargo/bin:$PATH"
fi
retry 3 cargo install --force zoxide

# --- Install fzf ---
retry 3 git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
retry 3 "$HOME/.fzf/install" --all --no-bash --no-fish

# --- Setup shell configuration ---
for shell_rc in ~/.zshrc ~/.bashrc; do
    [ -f "$shell_rc" ] && cp "$shell_rc" "$shell_rc.backup.$(date +%Y%m%d%H%M%S)"
done

for shell_rc in ~/.zshrc ~/.bashrc; do
    cat << 'EOF' >> "$shell_rc"
# zoxide + fzf integration
if command -v zoxide &>/dev/null; then
    eval "$(zoxide init $(basename $SHELL))"

    _original_cd() { builtin cd "$@"; }
    cd() {
        echo -n "Use zoxide to cd instead? [y/N]: "
        if ! read -r ans; then
            echo "Error: failed to read input." >&2
            return 1
        fi
        if [[ "$ans" =~ ^[Yy]$ ]]; then
            if [ "$#" -eq 0 ]; then
                zi || { echo "Error: zi failed" >&2; return 1; }
            else
                z "$*" || { echo "Error: z command failed" >&2; return 1; }
            fi
        else
            _original_cd "$@" || { echo "Error: cd failed" >&2; return 1; }
        fi
    }

    fcd() {
        local dir
        dir=$(zoxide query -ls | fzf --prompt="Jump to directory: ") || {
            echo "Error: fuzzy selection failed" >&2
            return 1
        }
        [ -n "$dir" ] && cd "$dir"
    }

    case $(basename $SHELL) in
        zsh) bindkey '^J' fcd ;;
        bash) bind '"\C-j": "\C-u fcd\C-m"' ;;
    esac

    fssh() {
        local host
        host=$(awk '/^Host / {print $2}' ~/.ssh/config 2>/dev/null; \
               awk '{print $1}' ~/.ssh/known_hosts 2>/dev/null | sed 's/,.*//' | sort -u | \
               fzf --prompt="Select SSH host: ") || {
                   echo "Error: no host selected" >&2
                   return 1
               }
        [ -n "$host" ] && ssh "$host"
    }
fi
EOF
done

echo "=== Installation complete! Restart your shell to see Powerlevel10k, zoxide, and fzf features ==="
