return {
	"linux-cultist/venv-selector.nvim",
	dependencies = {
		"neovim/nvim-lspconfig",
		"nvim-telescope/telescope.nvim",
		"mfussenegger/nvim-dap-python",
	},
	opts = {
		-- Auto select single venv in workspace
		auto_refresh = true,
	},
	ft = "python", -- Load only for Python buffers
	keys = {
		{ ",v", "<cmd>VenvSelect<cr>", desc = "Select Python virtualenv" },
		{ ",vc", "<cmd>VenvSelectCached<cr>", desc = "Select cached Python virtualenv" },
	},
}
