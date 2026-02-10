return {
	"neovim/nvim-lspconfig",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"hrsh7th/cmp-nvim-lsp",
		{ "antosha417/nvim-lsp-file-operations", config = true },
		{ "folke/neodev.nvim", opts = {} },
	},
	config = function()
		-- import cmp-nvim-lsp plugin for autocompletion capabilities
		local cmp_nvim_lsp = require("cmp_nvim_lsp")

		local keymap = vim.keymap -- for conciseness

		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("UserLspConfig", {}),
			callback = function(ev)
				-- Buffer local mappings.
				-- See `:help vim.lsp.*` for documentation on any of the below functions
				local opts = { buffer = ev.buf, silent = true }

				-- set keybinds
				opts.desc = "Show LSP references"
				keymap.set("n", "gR", "<cmd>Telescope lsp_references<CR>", opts) -- show definition, references

				opts.desc = "Go to declaration"
				keymap.set("n", "gD", vim.lsp.buf.declaration, opts) -- go to declaration

				opts.desc = "Show LSP definitions"
				keymap.set("n", "gd", "<cmd>Telescope lsp_definitions<CR>", opts) -- show lsp definitions

				opts.desc = "Show LSP implementations"
				keymap.set("n", "gi", "<cmd>Telescope lsp_implementations<CR>", opts) -- show lsp implementations

				opts.desc = "Show LSP type definitions"
				keymap.set("n", "gt", "<cmd>Telescope lsp_type_definitions<CR>", opts) -- show lsp type definitions

				opts.desc = "See available code actions"
				keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts) -- see available code actions, in visual mode will apply to selection

				opts.desc = "Smart rename"
				keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts) -- smart rename

				opts.desc = "Show buffer diagnostics"
				keymap.set("n", "<leader>D", "<cmd>Telescope diagnostics bufnr=0<CR>", opts) -- show  diagnostics for file

				opts.desc = "Show line diagnostics"
				keymap.set("n", "<leader>d", vim.diagnostic.open_float, opts) -- show diagnostics for line

				opts.desc = "Show documentation for what is under cursor"
				keymap.set("n", "K", vim.lsp.buf.hover, opts) -- show documentation for what is under cursor

				opts.desc = "Restart LSP"
				keymap.set("n", "<leader>rs", ":LspRestart<CR>", opts) -- mapping to restart lsp if necessary

				opts.desc = "Organize imports"
				-- Set for Normal mode ('n') is usually sufficient
				keymap.set("n", "<leader>oi", function()
					local params = {
						context = {
							only = { "source.organizeImports", "source.removeUnusedImports" },
						},
						-- apply = true goes here, outside context
						apply = true,
					}
					-- Use the buffer-specific function
					vim.lsp.buf.code_action(params)
					-- Optional feedback to confirm it ran
					vim.notify("Imports organized!", vim.log.levels.INFO, { title = "LSP" })
				end, opts) -- IMPORTANT: Pass the 'opts' table here
			end,
		})

		-- used to enable autocompletion (assign to every lsp server config)
		local capabilities = cmp_nvim_lsp.default_capabilities()

		-- Change the Diagnostic symbols in the sign column (gutter)
		-- (not in youtube nvim video)
		local signs = { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
		for type, icon in pairs(signs) do
			local hl = "DiagnosticSign" .. type
			vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
		end

		-- Configure LSP servers using Neovim 0.11+ native API
		-- Note: vim.lsp.config merges with defaults from lspconfig

		-- Svelte server with file change notifications
		vim.lsp.config("svelte", {
			capabilities = capabilities,
			on_attach = function(client, bufnr)
				vim.api.nvim_create_autocmd("BufWritePost", {
					pattern = { "*.js", "*.ts" },
					callback = function(ctx)
						client.notify("$/onDidChangeTsOrJsFile", { uri = ctx.match })
					end,
				})
			end,
		})

		-- Go language server
		vim.lsp.config("gopls", {
			capabilities = capabilities,
			cmd = { "gopls" },
			filetypes = { "go", "gomod", "gowork", "gotmpl" },
			settings = {
				gopls = {
					completeUnimported = true,
					usePlaceholders = true,
				},
			},
		})

		-- Angular language server
		vim.lsp.config("angularls", {
			capabilities = capabilities,
			filetypes = { "typescript", "javascript", "html", "htmlangular" },
			root_markers = { "angular.json", "nx.json" },
		})

		-- GraphQL language server
		vim.lsp.config("graphql", {
			capabilities = capabilities,
			filetypes = { "graphql", "gql", "svelte", "typescriptreact", "javascriptreact" },
		})

		-- Emmet language server
		vim.lsp.config("emmet_ls", {
			capabilities = capabilities,
			filetypes = {
				"html",
				"typescriptreact",
				"javascriptreact",
				"css",
				"sass",
				"scss",
				"less",
				"svelte",
			},
		})

		-- Lua language server
		vim.lsp.config("lua_ls", {
			capabilities = capabilities,
			settings = {
				Lua = {
					diagnostics = {
						globals = { "vim" },
					},
					completion = {
						callSnippet = "Replace",
					},
				},
			},
		})

		-- Ruff (Python linting/formatting) - disable hover in favor of ty
		vim.lsp.config("ruff", {
			capabilities = capabilities,
			on_attach = function(client, bufnr)
				client.server_capabilities.hoverProvider = false
			end,
		})

		-- ty (Python type checker) - requires Neovim 0.11+
		vim.lsp.config("ty", {
			cmd = { "ty", "server" },
			filetypes = { "python" },
			root_markers = { "pyproject.toml", ".git" },
			settings = {
				ty = {
					experimental = {
						autoImport = true,
						rename = true,
					},
				},
			},
		})

		-- Servers with default config (just need capabilities)
		local default_servers = {
			"ts_ls",
			"html",
			"cssls",
			"css_variables",
			"cssmodules_ls",
			"tailwindcss",
			"prismals",
			"ast_grep",
			"astro",
			"mdx_analyzer",
			"ansiblels",
			"terraformls",
			"docker_compose_language_service",
			"dockerls",
			"golangci_lint_ls",
		}

		for _, server in ipairs(default_servers) do
			vim.lsp.config(server, {
				capabilities = capabilities,
			})
		end

		-- Enable all configured servers
		vim.lsp.enable({
			-- Python
			"ruff",
			"ty",
			-- TypeScript/JavaScript
			"ts_ls",
			-- Web
			"html",
			"cssls",
			"css_variables",
			"cssmodules_ls",
			"tailwindcss",
			"svelte",
			"astro",
			"emmet_ls",
			-- Angular
			"angularls",
			-- GraphQL/MDX
			"graphql",
			"mdx_analyzer",
			-- Go
			"gopls",
			"golangci_lint_ls",
			-- Lua
			"lua_ls",
			-- Infrastructure
			"ansiblels",
			"terraformls",
			"docker_compose_language_service",
			"dockerls",
			-- Other
			"prismals",
			"ast_grep",
		})
	end,
}
