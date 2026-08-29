local ignored_directories = {
  ".git",
  "CVS",
  "node_modules",
  "build*",
  "dist",
  ".next",
  "coverage",
  "target",
  "out",
}

local fd_opts = { "--color=never", "--type", "f" }
local rg_opts = {
  "--column",
  "--line-number",
  "--no-heading",
  "--color=always",
  "--smart-case",
  "--max-columns=4096",
}

for _, directory in ipairs(ignored_directories) do
  vim.list_extend(fd_opts, { "--exclude", vim.fn.shellescape(directory) })
  vim.list_extend(rg_opts, { "--glob", vim.fn.shellescape("!**/" .. directory .. "/**") })
end

table.insert(rg_opts, "-e")

return {
  "ibhagwan/fzf-lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  cmd = "FzfLua",
  opts = {
    files = {
      fd_opts = table.concat(fd_opts, " "),
      hidden = false,
    },
    grep = {
      rg_opts = table.concat(rg_opts, " "),
    },
  },
  keys = {
    { "<leader>fb", function() require("fzf-lua").buffers() end, desc = "Find open buffers" },
    { "<leader>ff", function() require("fzf-lua").files() end, desc = "Fuzzy find files in cwd" },
    { "<leader>fr", function() require("fzf-lua").oldfiles() end, desc = "Fuzzy find recent files" },
    { "<leader>fs", function() require("fzf-lua").live_grep_native() end, desc = "Find string in cwd" },
    { "<leader>fc", function() require("fzf-lua").grep_cword() end, desc = "Find string under cursor in cwd" },
    { "<leader>ft", function() require("fzf-lua").treesitter() end, desc = "Find symbols in current file" },
  },
}
