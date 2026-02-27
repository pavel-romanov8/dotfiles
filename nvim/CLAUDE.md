# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a modular Neovim configuration written in Lua, using Lazy.nvim as the plugin manager. The configuration follows modern Neovim best practices with a focus on performance through lazy-loading and comprehensive language support via LSP.

## Architecture

The configuration follows this structure:
- `init.lua` - Entry point that loads core settings and plugin manager
- `lua/pavel/core/` - Core Vim settings (options, keymaps)
- `lua/pavel/plugins/` - Individual plugin configurations (one file per plugin)
- `lua/pavel/plugins/lsp/` - LSP-specific configurations
- `lazy-lock.json` - Plugin version lock file

Each plugin configuration file returns a Lazy.nvim plugin specification table.

## Common Commands

### Plugin Management
- `:Lazy` - Open Lazy.nvim UI for plugin management
- `:Lazy sync` - Update all plugins
- `:Lazy install` - Install missing plugins
- `:Lazy update` - Update plugins to latest versions

### LSP Management
- `:Mason` - Open Mason UI to install/manage LSP servers
- `:MasonInstall <server>` - Install specific LSP server
- `:LspInfo` - Show LSP status for current buffer

### Development Workflows
- `<leader>ff` - Find files (Telescope)
- `<leader>fs` - Live grep in files
- `<leader>lg` - Open LazyGit
- Format on save is enabled via conform.nvim
- Linting runs automatically via nvim-lint

## Key Architectural Decisions

1. **Lazy Loading**: Plugins are loaded on specific events (VeryLazy, BufReadPre) to optimize startup time
2. **Modular Plugin Configs**: Each plugin has its own file in `lua/pavel/plugins/`
3. **LSP via Mason**: Language servers are automatically installable through Mason.nvim

## Configured Language Support

### LSP Servers
- TypeScript/JavaScript: `ts_ls`
- Python: `pyright`
- Go: `gopls`, `golangci_lint_ls`
- Web: `html`, `cssls`, `tailwindcss`, `svelte`, `astro`
- Lua: `lua_ls`
- Infrastructure: `terraformls`, `ansiblels`, `dockerls`

### Formatters & Linters
- JavaScript/TypeScript: `prettierd`, `eslint_d`
- Python: `black`, `isort`, `pylint`
- Go: `goimports-reviser`, `gofumpt`, `golangci-lint`
- Lua: `stylua`

## Adding New Plugins

Create a new file in `lua/pavel/plugins/` that returns a plugin spec:

```lua
return {
  "plugin/name",
  event = "VeryLazy", -- or specific trigger
  config = function()
    -- plugin configuration
  end,
}
```

## Important Notes

- Leader key is set to `<Space>`
- Color scheme is Tokyo Night with custom modifications
- Format on save is enabled for all configured formatters
- Git integration includes gitsigns and lazygit
- AI assistants require API keys to be configured
