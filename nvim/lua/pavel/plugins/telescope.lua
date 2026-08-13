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

    local find_command = { "fd", "--type", "f", "--color", "never" }

    for _, directory in ipairs(ignored_directories) do
      table.insert(find_command, "--exclude")
      table.insert(find_command, directory)

      table.insert(vimgrep_arguments, "--glob")
      table.insert(vimgrep_arguments, "!**/" .. directory .. "/**")
    end

    telescope.setup({
      defaults = {
        path_display = { "smart" },
        vimgrep_arguments = vimgrep_arguments,
        mappings = {
          i = {
            ["<C-k>"] = actions.move_selection_previous, -- move to prev result
            ["<C-j>"] = actions.move_selection_next, -- move to next result
            ["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
          },
        },
      },
      pickers = {
        find_files = {
          find_command = find_command,
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
