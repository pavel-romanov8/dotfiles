#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$HOME/.config"

# Add config directory names here as you add more tools
CONFIGS=(nvim yazi wezterm tmux)

mkdir -p "$CONFIG_DIR"

for name in "${CONFIGS[@]}"; do
    src="$DOTFILES_DIR/$name"
    dest="$CONFIG_DIR/$name"

    if [ ! -d "$src" ]; then
        echo "skip: $src does not exist"
        continue
    fi

    # Already a correct symlink — nothing to do
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
        echo "ok:   $dest -> $src"
        continue
    fi

    # Back up existing config (directory or wrong symlink)
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        backup="$dest.bak"
        echo "backup: $dest -> $backup"
        mv "$dest" "$backup"
    fi

    ln -s "$src" "$dest"
    echo "link: $dest -> $src"
done

TMUX_CONF_SRC="$CONFIG_DIR/tmux/tmux.conf"
TMUX_CONF_DEST="$HOME/.tmux.conf"

if [ -f "$TMUX_CONF_SRC" ]; then
    if [ -L "$TMUX_CONF_DEST" ] && [ "$(readlink "$TMUX_CONF_DEST")" = "$TMUX_CONF_SRC" ]; then
        echo "ok:   $TMUX_CONF_DEST -> $TMUX_CONF_SRC"
    else
        if [ -e "$TMUX_CONF_DEST" ] || [ -L "$TMUX_CONF_DEST" ]; then
            backup="$TMUX_CONF_DEST.bak"
            echo "backup: $TMUX_CONF_DEST -> $backup"
            mv "$TMUX_CONF_DEST" "$backup"
        fi

        ln -s "$TMUX_CONF_SRC" "$TMUX_CONF_DEST"
        echo "link: $TMUX_CONF_DEST -> $TMUX_CONF_SRC"
    fi
fi
