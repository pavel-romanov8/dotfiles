return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	build = ":TSUpdate",
	lazy = false,
	config = function()
		require("nvim-treesitter").setup({})

		-- Install parsers (replaces ensure_installed)
		local parsers = {
			"json",
			"javascript",
			"typescript",
			"tsx",
			"yaml",
			"html",
			"css",
			"prisma",
			"markdown",
			"markdown_inline",
			"svelte",
			"graphql",
			"bash",
			"lua",
			"vim",
			"dockerfile",
			"query",
			"vimdoc",
			"c",
			"angular",
			"vue",
			"go",
			"terraform",
			"toml",
			"astro",
		}
		vim.schedule(function()
			require("nvim-treesitter").install(parsers)
		end)

		-- Enable treesitter highlighting (replaces highlight.enable)
		vim.api.nvim_create_autocmd("FileType", {
			callback = function(args)
				pcall(vim.treesitter.start, args.buf)
			end,
		})

		-- Enable treesitter indentation (replaces indent.enable)
		vim.api.nvim_create_autocmd("FileType", {
			callback = function()
				vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
			end,
		})
	end,
}
