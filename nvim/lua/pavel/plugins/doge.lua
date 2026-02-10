return {
	{
		"kkoomen/vim-doge",
		dependencies = { "nvim-treesitter/nvim-treesitter" }, -- Required for code parsing
		keys = {
			{
				"<leader><leader>d", -- Your desired keybinding (<leader> is often '\' or 'space')
				"<Plug>(doge-generate)", -- Triggers nvim-doge's default generation function
				mode = { "n", "v" }, -- Works in Normal and Visual modes
				desc = "Generate Docstring (nvim-doge)", -- Optional description for which-key etc.
			},
		},
	},
}
