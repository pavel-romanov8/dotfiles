#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$HOME/.config"

if ! command -v python3 >/dev/null 2>&1; then
    echo 'error: python3 is required to safely merge Pi appearance settings.' >&2
    exit 1
fi

# Add config directory names here as you add more tools
CONFIGS=(nvim yazi wezterm tmux fzf)

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

# Expose only the unified fzf launcher. Internal workflow modules stay out of
# PATH so there are no per-workflow commands to remember.
LOCAL_BIN_DIR="$HOME/.local/bin"
FF_SRC="$CONFIG_DIR/fzf/bin/ff"
FF_DEST="$LOCAL_BIN_DIR/ff"
mkdir -p "$LOCAL_BIN_DIR"
if [ -L "$FF_DEST" ] && [ "$(readlink "$FF_DEST")" = "$FF_SRC" ]; then
    echo "ok:   $FF_DEST -> $FF_SRC"
else
    if [ -e "$FF_DEST" ] || [ -L "$FF_DEST" ]; then
        backup="$(mktemp "$FF_DEST.bak.XXXXXX")"
        mv "$FF_DEST" "$backup"
        echo "backup: $FF_DEST -> $backup"
    fi
    ln -s "$FF_SRC" "$FF_DEST"
    echo "link: $FF_DEST -> $FF_SRC"
fi

# Pi stores private settings, credentials, and sessions outside ~/.config.
# Link only our theme files; preserve other themes and all machine-local state.
PI_AGENT_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
mkdir -p "$PI_AGENT_DIR/themes"
for src in "$DOTFILES_DIR"/pi/themes/*.json; do
    dest="$PI_AGENT_DIR/themes/$(basename "$src")"
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
        echo "ok:   $dest -> $src"
        continue
    fi
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        backup="$(mktemp "$dest.bak.XXXXXX")"
        mv "$dest" "$backup"
        echo "backup: $dest -> $backup"
    fi
    ln -s "$src" "$dest"
    echo "link: $dest -> $src"
done
python3 "$DOTFILES_DIR/pi/setup_settings.py" "$PI_AGENT_DIR"
echo 'Pi: appearance configured. Restart Pi to pick up settings changes.'

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
