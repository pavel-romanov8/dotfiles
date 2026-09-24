return {
	"williamboman/mason.nvim",
	dependencies = {
		"williamboman/mason-lspconfig.nvim",
		"WhoIsSethDaniel/mason-tool-installer.nvim",
	},
	config = function()
		-- import mason
		local mason = require("mason")

		-- import mason-lspconfig
		local mason_lspconfig = require("mason-lspconfig")

		local mason_tool_installer = require("mason-tool-installer")

		-- enable mason and configure icons
		mason.setup({
			ui = {
				icons = {
					package_installed = "✓",
					package_pending = "➜",
					package_uninstalled = "✗",
				},
			},
		})

		mason_lspconfig.setup({
			-- Keep installation deterministic and let lspconfig.lua decide what is enabled.
			-- rust-analyzer intentionally comes from rustup so it follows per-project toolchains.
			ensure_installed = {
				"angularls",
				"ansiblels",
				"ast_grep",
				"astro",
				"css_variables",
				"cssls",
				"cssmodules_ls",
				"docker_compose_language_service",
				"dockerls",
				"emmet_ls",
				"golangci_lint_ls",
				"gopls",
				"graphql",
				"html",
				"lua_ls",
				"mdx_analyzer",
				"prismals",
				"pyright",
				"ruff",
				"svelte",
				"tailwindcss",
				"taplo",
				"terraformls",
				"ts_ls",
			},
			automatic_enable = false,
		})

		mason_tool_installer.setup({
			ensure_installed = {
				"codelldb",
				"prettierd",
				"eslint_d",
				"stylua",
				"hadolint",
				"tfsec",
				"tflint",
				-- Go tools: install manually via :MasonInstall when needed
				-- goimports-reviser gofumpt delve golangci-lint revive golines nilaway iferr gomodifytags
			},
		})
	end,
}
