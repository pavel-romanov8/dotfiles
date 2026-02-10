-- lua/pavel/plugins/fugitive.lua
return {
  "tpope/vim-fugitive",
  dependencies = {
    "tpope/vim-rhubarb", -- GitHub integration for :GBrowse
  },
  cmd = { "Git", "G", "Gdiffsplit", "Gread", "Gwrite", "Ggrep", "GMove", "GDelete", "GBrowse" },
  keys = {
    { "<leader>gs", "<cmd>Git<cr>", desc = "Git status" },
    { "<leader>gb", "<cmd>Git blame<cr>", desc = "Git blame" },
    { "<leader>gd", "<cmd>Gdiffsplit<cr>", desc = "Git diff" },
    { "<leader>gw", "<cmd>Gwrite<cr>", desc = "Git stage file" },
    { "<leader>gr", "<cmd>Gread<cr>", desc = "Git revert file" },
    { "<leader>gl", "<cmd>Git log --oneline<cr>", desc = "Git log" },
    { "<leader>gB", "<cmd>GBrowse<cr>", desc = "Open in browser" },
  },
}
