return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	build = ":TSUpdate",
	event = { "BufReadPost", "BufNewFile" },
	config = function()
		local treesitter = require("nvim-treesitter")
		treesitter.setup({})

		local installing = {}
		local function ensure_parser(lang)
			if lang == "" or pcall(vim.treesitter.language.add, lang) or installing[lang] then
				return
			end

			installing[lang] = true
			vim.schedule(function()
				local ok = pcall(treesitter.install, lang)
				if not ok then
					vim.notify("Failed to install treesitter parser: " .. lang, vim.log.levels.WARN)
				end
				installing[lang] = nil
			end)
		end

		-- Enable treesitter highlighting (replaces highlight.enable)
		vim.api.nvim_create_autocmd("FileType", {
			callback = function(args)
				local lang = vim.treesitter.language.get_lang(args.match) or args.match
				ensure_parser(lang)
				pcall(vim.treesitter.start, args.buf, lang)
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
