return {
	"mrcjkb/rustaceanvim",
	version = "^9",
	lazy = false,
	dependencies = {
		"hrsh7th/cmp-nvim-lsp",
		"mfussenegger/nvim-dap",
	},
	init = function()
		local function rust_lsp(command)
			return function()
				vim.cmd.RustLsp(command)
			end
		end

		vim.g.rustaceanvim = {
			tools = {
				-- Use neotest for testables and cargo-nextest when it is available.
				test_executor = "neotest",
				crate_test_executor = "neotest",
				enable_clippy = true,
				code_actions = {
					ui_select_fallback = true,
				},
			},
			server = {
				capabilities = require("cmp_nvim_lsp").default_capabilities(),
				on_attach = function(_, bufnr)
					local opts = { buffer = bufnr, silent = true }
					local function map(lhs, rhs, desc, mode)
						vim.keymap.set(mode or "n", lhs, rhs, vim.tbl_extend("force", opts, { desc = desc }))
					end

					map("K", rust_lsp({ "hover", "actions" }), "Rust hover actions")
					map("<leader>ca", rust_lsp("codeAction"), "Rust code actions", { "n", "v" })
					map("<leader>rr", rust_lsp("runnables"), "Rust runnables")
					map("<leader>rt", rust_lsp("testables"), "Rust testables")
					map("<leader>rd", rust_lsp("debuggables"), "Rust debuggables")
					map("<leader>re", rust_lsp("explainError"), "Explain Rust error")
					map("<leader>rm", rust_lsp("expandMacro"), "Expand Rust macro")
					map("<leader>rc", rust_lsp("openCargo"), "Open Cargo.toml")
					map("<leader>ro", rust_lsp("openDocs"), "Open Rust documentation")
					map("<leader>rp", rust_lsp("parentModule"), "Go to parent Rust module")
					map("<leader>rR", rust_lsp("reloadWorkspace"), "Reload Cargo workspace")
					map("<leader>ri", function()
						local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
						vim.lsp.inlay_hint.enable(not enabled, { bufnr = bufnr })
					end, "Toggle Rust inlay hints")

					vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
				end,
				default_settings = {
					["rust-analyzer"] = {
						cargo = {
							allTargets = true,
						},
						procMacro = {
							enable = true,
						},
					},
				},
			},
		}
	end,
}
