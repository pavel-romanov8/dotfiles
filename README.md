# Dotfiles

Shared terminal/editor file setup.

## Included configs

- `nvim`
- `yazi`
- `wezterm`

## Setup

Run:

```bash
./setup.sh
```

This script symlinks each folder from this repo into `~/.config/<name>`.

## WezTerm notes

- Config path in this repo: `wezterm/wezterm.lua`
- Runtime path after setup: `~/.config/wezterm/wezterm.lua`
- Font used by config: `MesloLGS Nerd Font Mono`

If you already have `~/.wezterm.lua`, remove it after confirming WezTerm is loading `~/.config/wezterm/wezterm.lua`.
