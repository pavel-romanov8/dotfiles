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

## Updating another machine

Commit and push changes on the source machine, then run:

```bash
cd ~/dotfiles
git pull --ff-only
./setup.sh
```

Keep Neovim, Yazi, and `tree-sitter-cli` current. On macOS, use Homebrew. On Ubuntu, use `mise` rather than Ubuntu's older Neovim package:

```bash
mise use -g node@lts neovim@0.12.4 yazi@26.8.15 tree-sitter@0.26.12
```

For the one-time `nvim-treesitter` migration from `master` to `main`, remove the old generated state:

```bash
rm -rf \
  ~/.local/share/nvim/lazy/nvim-treesitter \
  ~/.local/share/nvim/site/parser \
  ~/.local/share/nvim/site/parser-info \
  ~/.local/share/nvim/site/queries \
  ~/.cache/nvim/tree-sitter-*
```

Open Neovim and run `:Lazy restore`, `:MasonToolsInstallSync`, and `:checkhealth nvim-treesitter`. Wait for parser installation to finish, then run `ya pkg install` in the shell.

## WezTerm notes

- Config path in this repo: `wezterm/wezterm.lua`
- Runtime path after setup: `~/.config/wezterm/wezterm.lua`
- Font used by config: `MesloLGS Nerd Font Mono`
- Light mode uses the custom `GitHub Light Readable` scheme. To test another built-in light scheme, launch WezTerm with `WEZTERM_LIGHT_SCHEME="Catppuccin Latte" wezterm start`.

If you already have `~/.wezterm.lua`, remove it after confirming WezTerm is loading `~/.config/wezterm/wezterm.lua`.

## tmux notes

- Config path in this repo: `tmux/tmux.conf`
- Runtime path after setup: `~/.config/tmux/tmux.conf`
- Compatibility symlink after setup: `~/.tmux.conf`
- Clipboard integration is enabled so apps inside tmux can copy back to the local machine when the terminal supports OSC52 passthrough
