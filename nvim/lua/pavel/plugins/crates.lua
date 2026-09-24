return {
	"saecki/crates.nvim",
	tag = "stable",
	event = { "BufRead Cargo.toml", "BufNewFile Cargo.toml" },
	config = function()
		local crates = require("crates")

		crates.setup({
			lsp = {
				enabled = true,
				actions = true,
				completion = true,
				hover = true,
			},
		})

		local function set_keymaps(bufnr)
			if vim.fs.basename(vim.api.nvim_buf_get_name(bufnr)) ~= "Cargo.toml" then
				return
			end

			local function map(mode, lhs, rhs, desc)
				vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
			end

			map("n", "<leader>ct", crates.toggle, "Toggle crate information")
			map("n", "<leader>cv", crates.show_versions_popup, "Show crate versions")
			map("n", "<leader>cf", crates.show_features_popup, "Show crate features")
			map("n", "<leader>cd", crates.show_dependencies_popup, "Show crate dependencies")
			map("n", "<leader>cu", crates.update_crate, "Update crate")
			map("v", "<leader>cu", crates.update_crates, "Update selected crates")
			map("n", "<leader>cU", crates.upgrade_crate, "Upgrade crate")
			map("v", "<leader>cU", crates.upgrade_crates, "Upgrade selected crates")
			map("n", "<leader>cA", crates.upgrade_all_crates, "Upgrade all crates")
		end

		vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
			group = vim.api.nvim_create_augroup("UserCratesKeymaps", { clear = true }),
			pattern = "Cargo.toml",
			callback = function(args)
				set_keymaps(args.buf)
			end,
		})
		set_keymaps(vim.api.nvim_get_current_buf())
	end,
}
