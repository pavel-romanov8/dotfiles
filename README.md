# Dotfiles

Shared terminal/editor file setup.

## Included configs

- `nvim`
- `yazi`
- `wezterm`
- `tmux`

## Setup

Run:

```bash
./setup.sh
```

This script symlinks each folder from this repo into `~/.config/<name>`.

For tmux, it also creates `~/.tmux.conf` as a symlink to `~/.config/tmux/tmux.conf` so the config works on machines that still expect the legacy path.

## WezTerm notes

- Config path in this repo: `wezterm/wezterm.lua`
- Runtime path after setup: `~/.config/wezterm/wezterm.lua`
- Font used by config: `MesloLGS Nerd Font Mono`

If you already have `~/.wezterm.lua`, remove it after confirming WezTerm is loading `~/.config/wezterm/wezterm.lua`.

## tmux notes

- Config path in this repo: `tmux/tmux.conf`
- Runtime path after setup: `~/.config/tmux/tmux.conf`
- Compatibility symlink after setup: `~/.tmux.conf`
- Clipboard integration is enabled so apps inside tmux can copy back to the local machine when the terminal supports OSC52 passthrough
