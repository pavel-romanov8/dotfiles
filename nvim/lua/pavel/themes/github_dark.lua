local M = {}

M.background = "dark"
M.colorscheme = "github_dark"

M.github_theme = {
  options = {
    styles = {
      comments = "italic",
      keywords = "italic",
    },
    darken = {
      floats = true,
      sidebars = {
        enable = true,
      },
    },
  },
  palettes = {
    github_dark = {
      black = { base = "#24292E", bright = "#33383d" },
      gray = { base = "#4c5156", bright = "#6a6f74" },
      blue = { base = "#58a6ff", bright = "#79c0ff" },
      green = { base = "#56d364", bright = "#85e89d" },
      magenta = { base = "#d2a8ff", bright = "#bc8cff" },
      pink = { base = "#ec6cb9", bright = "#ffa198" },
      red = { base = "#ff7f8d", bright = "#ffa198" },
      white = { base = "#c9d1d9", bright = "#d3dbe3" },
      yellow = { base = "#ffdf5d", bright = "#ffea7f" },
      cyan = { base = "#56d4dd", bright = "#83caff" },

      bg0 = "#1F2428",
      bg1 = "#24292E",
      bg2 = "#2e3338",
      bg3 = "#33383d",
      bg4 = "#383d42",
      fg0 = "#dde5ed",
      fg1 = "#c9d1d9",
      fg2 = "#d3dbe3",
      fg3 = "#4c5156",
      sel0 = "#383d42",
      sel1 = "#33383d",
      comment = "#42474c",
    },
  },
  groups = {
    github_dark = {
      ["@punctuation.bracket"] = { fg = "#ffab70" },
      ["@constructor"] = { fg = "#85e89d" },
      ["@tag.attribute"] = { link = "@function.method" },
    },
  },
}

return M
