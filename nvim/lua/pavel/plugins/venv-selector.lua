return {
	"linux-cultist/venv-selector.nvim",
	dependencies = {
		"neovim/nvim-lspconfig",
		"ibhagwan/fzf-lua",
		"mfussenegger/nvim-dap-python",
	},
	opts = {
		options = {
			picker = "fzf-lua",
		},
	},
	ft = "python", -- Load only for Python buffers
	keys = {
		{ ",v", "<cmd>VenvSelect<cr>", desc = "Select Python virtualenv" },
		{ ",vc", "<cmd>VenvSelectCached<cr>", desc = "Select cached Python virtualenv" },
	},
}
