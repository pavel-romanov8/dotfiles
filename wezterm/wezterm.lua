local wezterm = require("wezterm")

local config = wezterm.config_builder()

config.font = wezterm.font("MesloLGS Nerd Font Mono")
config.font_size = 16

config.enable_tab_bar = false

config.window_decorations = "RESIZE"

config.window_background_opacity = 0.8
config.macos_window_background_blur = 10

config.color_schemes = {
  github_dark = {
    foreground = "#c9d1d9",
    background = "#1f2428",
    cursor_bg = "#58a6ff",
    cursor_fg = "#1f2428",
    cursor_border = "#58a6ff",
    selection_fg = "#c9d1d9",
    selection_bg = "#383d42",
    ansi = {
      "#24292e",
      "#ff7f8d",
      "#56d364",
      "#ffdf5d",
      "#58a6ff",
      "#d2a8ff",
      "#56d4dd",
      "#c9d1d9",
    },
    brights = {
      "#4c5156",
      "#ffa198",
      "#85e89d",
      "#ffea7f",
      "#79c0ff",
      "#bc8cff",
      "#83caff",
      "#d3dbe3",
    },
  },
  github_light = {
    foreground = "#383d42",
    background = "#f3f5f7",
    cursor_bg = "#0366d6",
    cursor_fg = "#f3f5f7",
    cursor_border = "#0366d6",
    selection_fg = "#24292e",
    selection_bg = "#e1e3e5",
    ansi = {
      "#ffffff",
      "#de2c2e",
      "#18654b",
      "#dbab09",
      "#0366d6",
      "#8263eb",
      "#0598bc",
      "#24292e",
    },
    brights = {
      "#c7c9cb",
      "#ea5a5c",
      "#28a745",
      "#f9c513",
      "#0d7fdd",
      "#5a32a3",
      "#22839b",
      "#2e3338",
    },
  },
}

local function scheme_for_appearance(appearance)
  if appearance:find("Dark") then
    return "github_dark"
  end

  return "github_light"
end

local appearance = wezterm.gui and wezterm.gui.get_appearance() or "Dark"
config.color_scheme = scheme_for_appearance(appearance)

return config
