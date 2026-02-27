local M = {}

M.background = "light"
M.colorscheme = "github_light"

M.github_theme = {
  options = {
    styles = {
      comments = "italic",
      keywords = "italic",
    },
    darken = {
      floats = false,
      sidebars = {
        enable = false,
      },
    },
  },
  palettes = {
    github_light = {
      black = { base = "#ffffff", bright = "#edeff1" },
      gray = { base = "#c7c9cb", bright = "#a6a8aa" },
      blue = { base = "#0366d6", bright = "#0D7FDD" },
      green = { base = "#18654B", bright = "#28a745" },
      magenta = { base = "#8263EB", bright = "#5a32a3" },
      pink = { base = "#b93a86", bright = "#ea4aaa" },
      red = { base = "#DE2C2E", bright = "#ea5a5c" },
      white = { base = "#24292e", bright = "#2e3338" },
      yellow = { base = "#dbab09", bright = "#f9c513" },
      cyan = { base = "#0598bc", bright = "#22839b" },

      bg0 = "#f3f5f7",
      bg1 = "#ffffff",
      bg2 = "#edeff1",
      bg3 = "#eaecee",
      bg4 = "#e1e3e5",
      fg0 = "#24292e",
      fg1 = "#383d42",
      fg2 = "#2e3338",
      fg3 = "#c7c9cb",
      sel0 = "#e1e3e5",
      sel1 = "#edeff1",
      comment = "#d7d9db",
    },
  },
  groups = {
    github_light = {
      ["@punctuation.bracket"] = { fg = "#0D7FDD" },
      ["@constructor"] = { fg = "#28a745" },
      ["@operator"] = { fg = "#d15704" },
      Constant = { fg = "#24292e" },
      Tag = { fg = "#28a745" },
    },
  },
}

return M
