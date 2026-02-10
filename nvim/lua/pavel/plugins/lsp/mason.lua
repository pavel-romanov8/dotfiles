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
			-- list of servers for mason to install
			ensure_installed = {
				"ts_ls",
				"html",
				"cssls",
				"css_variables",
				"cssmodules_ls",
				"tailwindcss",
				"svelte",
				"lua_ls",
				"graphql",
				"emmet_ls",
				"prismals",
				"ruff",

				"ast_grep",

				"angularls",
				"astro",
				"mdx_analyzer",

				"ansiblels",
				"terraformls",

				"docker_compose_language_service",
				"dockerls",

				"gopls",
				"golangci_lint_ls",
			},
		})

		mason_tool_installer.setup({
			-- list of tools for mason to install
			ensure_installed = {
				"prettierd",
				"eslint_d",

				"stylua",

				"hadolint",

				"tfsec",
				"tflint",

				"goimports-reviser",
				"gofumpt",
				"delve",
				"golangci-lint",
				"revive",
				"golines",
				"nilaway",
				"iferr",
				"gomodifytags",
			},
		})
	end,
}
