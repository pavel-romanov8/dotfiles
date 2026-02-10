#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$HOME/.config"

# Add config directory names here as you add more tools
CONFIGS=(nvim yazi)

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
