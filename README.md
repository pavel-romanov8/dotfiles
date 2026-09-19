# Dotfiles

Shared terminal/editor file setup.

## Included configs

- `nvim`
- `yazi`
- `wezterm`
- `tmux`
- `fzf` (one `ff` launcher for environment variables, SSH hosts, and Docker containers)
- `pi` (GitHub dark/light themes; optional MCP adapter and permission rules)

## Setup

Run:

```bash
./setup.sh
```

This script symlinks the terminal/editor folders into `~/.config/<name>`. Pi themes are linked individually into `~/.pi/agent/themes/` (or `$PI_CODING_AGENT_DIR/themes/`). Existing unrelated pi themes, settings, credentials, and sessions are left alone.

For tmux, it also creates `~/.tmux.conf` as a symlink to `~/.config/tmux/tmux.conf` so the config works on machines that still expect the legacy path. For fzf, it links the single public launcher at `~/.local/bin/ff`; internal workflow modules are not added to `PATH`.

## fzf workflow launcher

Run the single entry point:

```bash
ff
```

Inside tmux it opens in a centered popup; outside tmux it uses an inline window. The initial menu contains only:

- **Environment variables** — browses exported names, masks sensitive-looking values, and copies `${NAME}` references. Use `Alt+V` to reveal a selected value explicitly and `Alt+M` to mask it again.
- **SSH hosts** — collects aliases from recursive SSH `Include` files, `known_hosts`, and `/etc/hosts`; previews the resolved `ssh -G` configuration and connects on Enter.
- **Docker containers** — lists running and stopped containers, previews recent logs, opens a shell on Enter, and supports start/stop with `Ctrl+S`.

All views use `Ctrl+/` to toggle the preview and `Ctrl+Y` to copy the relevant identifier. Docker also uses `Ctrl+R` to reload. Destructive Docker actions are intentionally absent.

`fzf`, `python3`, and the selected workflow's command (`ssh` or `docker`) must be installed. Unavailable workflows remain visible with an explanation. The existing generic fzf shell shortcuts such as `Ctrl+R`, `Ctrl+T`, and `Alt+C` are unchanged.

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

## Pi MCP trial

Optional setup, separate from `./setup.sh` (which still manages appearance only):

```bash
./pi/setup-mcp.sh
```

This installs **`pi-mcp-adapter@2.34.0`** and seeds `~/.pi/agent/mcp.json`
(or `$PI_CODING_AGENT_DIR/mcp.json`) from `pi/mcp.example.json` only when absent.
Existing MCP configuration is preserved, not merged or overwritten. If already
configured, add the example's servers manually or use `/mcp setup`. Close Pi
before setup to avoid concurrent settings writes; restart afterward.

The template copies both enabled servers found in this machine's OpenCode config:

- **Playwright**: local stdio via `npx -y @playwright/mcp@0.0.81`. Pinned instead
  of OpenCode's `latest`; starts on demand and does not inherit arbitrary host
  environment variables (not an OS sandbox).
- **GitHub**: `https://api.githubcopilot.com/mcp/`, using
  `GITHUB_PERSONAL_ACCESS_TOKEN` from Pi's environment. Supply the token through
  your preferred local credential mechanism before launching Pi; never store it
  in this repository.

OpenCode is untouched. This is a snapshot, not automatic synchronization; broad
host-config discovery is off. Use `/mcp setup` to add servers later and `/mcp` to
inspect status, reconnect, or enable/disable servers. Lazy servers may initially
show as not connected; connecting discovers their tools without executing them.
Playwright may need its browser installed on a new machine.

Without the permission extension below, MCP tool calls ask **Allow once / Allow
for session / Deny** through the adapter. Calls requiring approval fail closed
without a UI. Scripting and model sampling are disabled for this initial trial.
The optional permission extension unifies Bash and MCP decisions; otherwise shell
execution retains Pi's existing behavior. Approval gates are not a sandbox and
do not gate server startup. Only load trusted extensions and MCP configurations.

To remove the adapter, run `pi remove npm:pi-mcp-adapter`. Its machine-local MCP
configuration remains available if you reinstall. Normal `./setup.sh` will not
reinstall it.

## Pi permission rules

Opt-in, dotfiles-owned OpenCode-style `allow` / `ask` / `deny` rules:

```bash
python3 pi/setup_permissions.py
```

Restart Pi or run `/reload`, then `/permissions`. Setup links the extension and
seeds a private `~/.pi/agent/permissions.json` (or `$PI_CODING_AGENT_DIR`) only
when absent; your existing rules and other extensions are preserved.

Unmatched actions are allowed by default, so policies only list exceptions. The
seed policy asks before destructive file/Git operations such as `rm`,
`git reset --hard`, and `git push`, denies direct `sudo` commands, and asks for
GitHub/Playwright calls (`GitHub/get_me` is allowed). Other MCP/custom-tool calls
run without prompting. Compound shell calls are checked command by command, so
normal quoting, pipes, and redirections do not trigger approvals by themselves.
MCP uses the adapter's per-call approval hook, without duplicate prompts.
`/permissions clear` revokes exact-action session grants.

See **[pi/permissions.md](pi/permissions.md)** for configuration, precedence,
installation, tests, MCP coverage, and limitations. Global policy only; no
sandboxing or new npm dependencies. `./setup.sh` remains appearance-only.

## tmux notes

- Config path in this repo: `tmux/tmux.conf`
- Runtime path after setup: `~/.config/tmux/tmux.conf`
- Compatibility symlink after setup: `~/.tmux.conf`
- Clipboard integration is enabled so apps inside tmux can copy back to the local machine when the terminal supports OSC52 passthrough
