# Append zoxide + cd override + fuzzy cd setup
for shell_rc in ~/.zshrc ~/.bashrc; do
    cat << 'EOF' >> "$shell_rc"
# ---- zoxide + fzf integration ----
if command -v zoxide &>/dev/null; then
    eval "$(zoxide init $(basename $SHELL))"

    # Ask before overriding cd
    _original_cd() { builtin cd "$@"; }
    cd() {
        echo -n "Use zoxide to cd instead? [y/N]: "
        if ! read -r ans; then
            echo "Error: failed to read input." >&2
            return 1
        fi

        if [[ "$ans" =~ ^[Yy]$ ]]; then
            if [ "$#" -eq 0 ]; then
                zi || { echo "Error: zi failed"; return 1; }
            else
                z "$*" || { echo "Error: z command failed"; return 1; }
            fi
        elif [[ "$ans" =~ ^[Nn]$ ]] || [[ -z "$ans" ]]; then
            _original_cd "$@" || { echo "Error: cd failed"; return 1; }
        else
            echo "Error: invalid input '$ans', aborting cd." >&2
            return 1
        fi
    }

    # Fuzzy cd with Ctrl-J
    fcd() {
        local dir
        dir=$(zoxide query -ls | fzf --prompt="Jump to directory: ") || {
            echo "Error: fuzzy selection failed" >&2
            return 1
        }
        [ -n "$dir" ] && cd "$dir"
    }

    case $(basename $SHELL) in
        zsh)
            bindkey '^J' fcd
            ;;
        bash)
            bind '"\C-j": "\C-u fcd\C-m"'
            ;;
    esac
fi
EOF
done
