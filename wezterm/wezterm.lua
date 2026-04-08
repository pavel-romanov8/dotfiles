local wezterm = require("wezterm")

local config = wezterm.config_builder()

local function resolve_tmux_binary()
  local candidates = {
    "/opt/homebrew/bin/tmux",
    "/usr/local/bin/tmux",
  }

  for _, candidate in ipairs(candidates) do
    local file = io.open(candidate, "r")
    if file then
      file:close()
      return candidate
    end
  end

  return "tmux"
end

local tmux_binary = resolve_tmux_binary()

local function get_appearance(window)
  if window then
    return window:get_appearance()
  end

  if wezterm.gui then
    return wezterm.gui.get_appearance()
  end

  return "Dark"
end

local function mode_for_appearance(appearance)
  if appearance:find("Dark") then
    return "dark"
  end

  return "light"
end

local function sync_tmux_appearance(appearance)
  if not wezterm.gui then
    return
  end

  local mode = mode_for_appearance(appearance)
  wezterm.background_child_process({
    tmux_binary,
    "set-environment",
    "-g",
    "WEZTERM_APPEARANCE",
    mode,
  })
end

config.font = wezterm.font("MesloLGS Nerd Font Mono")
config.font_size = 16

config.enable_tab_bar = false

config.window_decorations = "RESIZE"

config.window_background_opacity = 0.8
config.macos_window_background_blur = 10

local function scheme_for_appearance(appearance)
  if mode_for_appearance(appearance) == "dark" then
    return "GitHub Dark"
  end

  return "Github"
end

wezterm.on("gui-attached", function()
  sync_tmux_appearance(get_appearance())
end)

wezterm.on("window-config-reloaded", function(window)
  sync_tmux_appearance(get_appearance(window))
end)

local appearance = get_appearance()
config.color_scheme = scheme_for_appearance(appearance)

return config
