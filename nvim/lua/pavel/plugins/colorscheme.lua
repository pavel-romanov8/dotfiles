return {
	{
		"projekt0n/github-nvim-theme",
		name = "github-theme",
		lazy = false,
		priority = 1000,
		config = function()
			require("pavel.themes").setup()
		end,
	},
	{
		"f-person/auto-dark-mode.nvim",
		lazy = false,
		opts = {
			update_interval = 1500,
			fallback = "dark",
			set_dark_mode = function()
				require("pavel.themes").apply("dark")
			end,
			set_light_mode = function()
				require("pavel.themes").apply("light")
			end,
		},
	},
}
