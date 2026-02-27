return {
  "nvim-telescope/telescope.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    "nvim-tree/nvim-web-devicons",
    "folke/todo-comments.nvim",
  },
  config = function()
    local telescope = require("telescope")
    local actions = require("telescope.actions")
    local telescope_config = require("telescope.config")
    local vimgrep_arguments = vim.deepcopy(telescope_config.values.vimgrep_arguments)

    local ignore_globs = {
      "!**/.git/**",
      "!**/node_modules/**",
      "!**/build*/**",
      "!**/dist/**",
      "!**/.next/**",
      "!**/coverage/**",
      "!**/target/**",
      "!**/out/**",
    }

    for _, glob in ipairs(ignore_globs) do
      table.insert(vimgrep_arguments, "--glob")
      table.insert(vimgrep_arguments, glob)
    end

    telescope.setup({
      defaults = {
        path_display = { "smart" },
        file_ignore_patterns = {
          "^%.git/",
          "node_modules/",
          "build/",
          "build[^/]*/",
          "dist/",
          "^%.next/",
          "coverage/",
          "target/",
          "out/",
        },
        vimgrep_arguments = vimgrep_arguments,
        mappings = {
          i = {
            ["<C-k>"] = actions.move_selection_previous, -- move to prev result
            ["<C-j>"] = actions.move_selection_next, -- move to next result
            ["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
          },
        },
      },
    })

    telescope.load_extension("fzf")

    -- set keymaps
    local keymap = vim.keymap -- for conciseness

    keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Fuzzy find files in cwd" })
    keymap.set("n", "<leader>fr", "<cmd>Telescope oldfiles<cr>", { desc = "Fuzzy find recent files" })
    keymap.set("n", "<leader>fs", "<cmd>Telescope live_grep<cr>", { desc = "Find string in cwd" })
    keymap.set("n", "<leader>fc", "<cmd>Telescope grep_string<cr>", { desc = "Find string under cursor in cwd" })
    keymap.set("n", "<leader>ft", "<cmd>TodoTelescope<cr>", { desc = "Find todos" })
  end,
}
