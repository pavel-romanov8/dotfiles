local wezterm = require("wezterm")

local config = wezterm.config_builder()

config.font = wezterm.font("MesloLGS Nerd Font Mono")
config.font_size = 16

config.enable_tab_bar = false

config.window_decorations = "RESIZE"

config.window_background_opacity = 0.8
config.macos_window_background_blur = 10

local function scheme_for_appearance(appearance)
  if appearance:find("Dark") then
    return "Catppuccin Mocha"
  end

  return "Catppuccin Latte"
end

local appearance = wezterm.gui and wezterm.gui.get_appearance() or "Dark"
config.color_scheme = scheme_for_appearance(appearance)

return config
