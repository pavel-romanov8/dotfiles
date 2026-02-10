return {
	{
		"folke/tokyonight.nvim",
		priority = 1000, -- make sure to load this before all the other start plugins
		config = function()
			-- Function to check macOS appearance
			local function get_appearance()
				local handle = io.popen("defaults read -g AppleInterfaceStyle 2>/dev/null")
				local result = handle:read("*a")
				handle:close()
				return result:match("Dark") and "dark" or "light"
			end

			-- Function to set colorscheme based on appearance
			local function set_theme()
				local appearance = get_appearance()

				-- Clear highlights to ensure fresh state
				vim.cmd("hi clear")

				if appearance == "dark" then
					vim.opt.background = "dark"
					require("tokyonight").setup({
						style = "storm",
						light_style = "day",
						transparent = false,
						terminal_colors = true,
						styles = {
							comments = { italic = true },
							keywords = { italic = true },
							functions = {},
							variables = {},
							sidebars = "dark",
							floats = "dark",
						},
						sidebars = { "qf", "help", "vista_kind", "terminal", "packer" },
						day_brightness = 0.3,
						hide_inactive_statusline = false,
						dim_inactive = false,
						lualine_bold = false,
						on_colors = function(colors)
							-- Custom dark theme colors
							colors.bg = "#011628"
							colors.bg_dark = "#011423"
							colors.bg_float = "#011423"
							colors.bg_highlight = "#143652"
							colors.bg_popup = "#011423"
							colors.bg_search = "#0A64AC"
							colors.bg_sidebar = "#011423"
							colors.bg_statusline = "#011423"
							colors.bg_visual = "#275378"
							colors.border = "#547998"
							colors.fg = "#CBE0F0"
							colors.fg_dark = "#B4D0E9"
							colors.fg_float = "#CBE0F0"
							colors.fg_gutter = "#627E97"
							colors.fg_sidebar = "#B4D0E9"
						end,
					})
				else
					vim.opt.background = "light"
					require("tokyonight").setup({
						style = "day",
						light_style = "day",
						transparent = false,
						terminal_colors = true,
						styles = {
							comments = { italic = true },
							keywords = { italic = true },
							functions = {},
							variables = {},
							sidebars = "normal",
							floats = "normal",
						},
						sidebars = { "qf", "help", "vista_kind", "terminal", "packer" },
						day_brightness = 0.3,
						hide_inactive_statusline = false,
						dim_inactive = false,
						lualine_bold = false,
					})
				end
				
				vim.cmd("colorscheme tokyonight")

				-- Refresh lualine if loaded to pick up new theme colors
				local ok, lualine = pcall(require, "lualine")
				if ok then
					lualine.refresh()
				end
			end

			-- Set theme on startup
			set_theme()

			-- Update theme when Neovim gains focus
			vim.api.nvim_create_autocmd("FocusGained", {
				callback = function()
					set_theme()
				end,
			})

			-- Create user command to manually check appearance
			vim.api.nvim_create_user_command("CheckAppearance", function()
				set_theme()
				vim.notify("Theme updated based on system appearance", vim.log.levels.INFO)
			end, {})
		end,
	},
}