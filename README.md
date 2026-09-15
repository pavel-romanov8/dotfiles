# Dotfiles

Shared terminal/editor file setup.

## Included configs

- `nvim`
- `yazi`
- `wezterm`
- `tmux`
- `pi` (GitHub dark/light themes only; no extensions)

## Setup

Run:

```bash
./setup.sh
```

This script symlinks the terminal/editor folders into `~/.config/<name>`. Pi themes are linked individually into `~/.pi/agent/themes/` (or `$PI_CODING_AGENT_DIR/themes/`). Existing unrelated pi themes, settings, credentials, and sessions are left alone.

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

## Neovim theme mode

Neovim follows the detected system appearance by default. Use `<leader>ut` or `:Theme` to choose between Auto, Light, and Dark. The choice is saved per machine, so a manual override also survives restarts inside a VM.

For direct access, use `:ThemeAuto`, `:ThemeLight`, `:ThemeDark`, or `:ThemeToggle`. `:ThemeSyncSystem` remains an alias for returning to Auto. In Auto mode, `NVIM_THEME=light|dark` and `WEZTERM_APPEARANCE=light|dark` take priority over host OS detection.

## WezTerm notes

- Config path in this repo: `wezterm/wezterm.lua`
- Runtime path after setup: `~/.config/wezterm/wezterm.lua`
- Font used by config: `MesloLGS Nerd Font Mono`
- Both modes use custom GitHub Readable palettes coordinated with pi, with 95% background opacity, macOS blur radius 10, and modest window padding. Application-painted backgrounds remain opaque; use the opacity shortcut below to compare. Linux VMs need compositor support for transparency.
- Light mode uses the custom `GitHub Light Readable` scheme. To test another built-in light scheme, launch WezTerm with `WEZTERM_LIGHT_SCHEME="Catppuccin Latte" wezterm start`.

### Appearance shortcuts

| Shortcut | Action |
| --- | --- |
| `Ctrl+Shift+O` | Toggle subtle transparency / fully opaque (Opacity) |
| `Ctrl+Shift+D` | Toggle light / dark and pin that window to the chosen mode (Dark/light) |
| `Ctrl+Shift+A` | Clear the theme override and follow OS appearance again (Automatic) |

Overrides are per-window, survive config reloads, and disappear when the window closes. New windows follow OS appearance. Theme and opacity overrides are independent.

The theme shortcut works without host/VM appearance propagation when WezTerm runs inside the VM. If WezTerm runs on the host, it changes the host terminal palette, not independently themed applications inside a remote session. Pi still needs its manual theme selection on WezTerm versions without appearance notifications.

The selected mode is also published to the local tmux server as `WEZTERM_APPEARANCE` for cooperating tools. This server-global hint is last-writer-wins across windows; it does not update environment variables in existing processes or reach remote tmux servers.

If you already have `~/.wezterm.lua`, remove it after confirming WezTerm is loading `~/.config/wezterm/wezterm.lua`.

## Pi appearance

With Pi installed and `python3` available, run this from your dotfiles checkout for initial setup or updates (close Pi first to avoid concurrent settings writes):

```bash
git pull --ff-only
./setup.sh
```

Setup links the theme files and automatically merges `pi/settings.example.json` into `~/.pi/agent/settings.json` (or `$PI_CODING_AGENT_DIR/settings.json`). It manages **only `theme` and `editorPaddingX`**, reapplying them on each run—including restoring Automatic after a manual theme selection. All other settings are preserved; credentials and sessions are untouched. Changed settings get a uniquely named private backup; unchanged settings are not rewritten. Invalid JSON is rejected rather than overwritten.

No manual wiring is needed on another machine after cloning and running setup. Pi installation and provider login remain machine-local. `setup.sh` also installs the other dotfiles configs, as before.

Managed appearance settings:

```json
{
  "theme": "github-light/github-dark",
  "editorPaddingX": 1
}
```

The pair is **light first, dark second**. Pi detects terminal appearance at startup and follows live changes where terminal/multiplexer notifications are supported. Test both directly in WezTerm and inside tmux; restart pi if a live switch does not propagate. This requires a pi version supporting paired themes (tested with the installed 0.85.1 theme loader).

Restart pi after setup changes settings or adds themes. Once linked, changes to existing theme files arrive with `git pull`; Pi hot-reloads the active custom theme. For a single-run comparison without changing saved preferences:

```bash
pi --use-theme github-light
pi --use-theme github-dark
```

Theme sources: `pi/themes/github-{light,dark}.json`. Editing the active theme hot-reloads its colors. The palette uses readable secondary text, neutral tool panels, blue accents, and distinct red/green diff text. Neovim and OpenCode configuration are unchanged.

To revert pi's appearance, set `theme` to `light/dark` (built-in automatic pair) and `editorPaddingX` to `0`. WezTerm's light-scheme override is still available, but another palette may no longer match pi.

## tmux notes

- Config path in this repo: `tmux/tmux.conf`
- Runtime path after setup: `~/.config/tmux/tmux.conf`
- Compatibility symlink after setup: `~/.tmux.conf`
- Clipboard integration is enabled so apps inside tmux can copy back to the local machine when the terminal supports OSC52 passthrough
