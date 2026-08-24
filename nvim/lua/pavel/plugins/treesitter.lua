local parsers = {
	"bash",
	"c",
	"css",
	"dockerfile",
	"go",
	"gomod",
	"gosum",
	"gowork",
	"graphql",
	"html",
	"javascript",
	"jsdoc",
	"json",
	"lua",
	"luadoc",
	"markdown",
	"markdown_inline",
	"prisma",
	"python",
	"query",
	"regex",
	"scss",
	"svelte",
	"terraform",
	"toml",
	"tsx",
	"typescript",
	"vim",
	"vimdoc",
	"yaml",
}

local configured_parsers = {}
for _, parser in ipairs(parsers) do
	configured_parsers[parser] = true
end

return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	lazy = false,
	build = ":TSUpdate",
	config = function()
		local treesitter = require("nvim-treesitter")
		treesitter.install(parsers)

		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("UserTreesitter", { clear = true }),
			callback = function(args)
				local language = vim.treesitter.language.get_lang(args.match) or args.match
				if not configured_parsers[language] then
					return
				end

				vim.treesitter.start(args.buf, language)
				vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
			end,
		})
	end,
}
