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

config.macos_window_background_blur = 10

local color_schemes = {
  ["GitHub Light Readable"] = {
    foreground = "#24292f",
    background = "#f6f8fa",
    cursor_bg = "#0969da",
    cursor_fg = "#ffffff",
    cursor_border = "#0969da",
    selection_fg = "#24292f",
    selection_bg = "#d0d7de",
    scrollbar_thumb = "#afb8c1",
    split = "#d0d7de",
    ansi = {
      "#24292f",
      "#cf222e",
      "#116329",
      "#9a6700",
      "#0550ae",
      "#8250df",
      "#1b7c83",
      "#6e7781",
    },
    brights = {
      "#57606a",
      "#a40e26",
      "#1a7f37",
      "#9a6700",
      "#0969da",
      "#8250df",
      "#1b7c83",
      "#24292f",
    },
    indexed = {
      [16] = "#bc4c00",
      [17] = "#953800",
    },
  },
}

config.color_schemes = color_schemes

local function color_scheme_exists(name)
  if color_schemes[name] then
    return true
  end

  if wezterm.color and wezterm.color.get_builtin_schemes then
    local ok, schemes = pcall(wezterm.color.get_builtin_schemes)
    return ok and schemes[name] ~= nil
  end

  return true
end

local function scheme_for_appearance(appearance)
  if mode_for_appearance(appearance) == "dark" then
    return "GitHub Dark"
  end

  local scheme = os.getenv("WEZTERM_LIGHT_SCHEME") or "GitHub Light Readable"
  if color_scheme_exists(scheme) then
    return scheme
  end

  wezterm.log_warn("Unknown WEZTERM_LIGHT_SCHEME: " .. scheme .. "; using GitHub Light Readable")
  return "GitHub Light Readable"
end

wezterm.on("gui-attached", function()
  sync_tmux_appearance(get_appearance())
end)

wezterm.on("window-config-reloaded", function(window)
  sync_tmux_appearance(get_appearance(window))
end)

local appearance = get_appearance()
config.color_scheme = scheme_for_appearance(appearance)
config.window_background_opacity = mode_for_appearance(appearance) == "dark" and 0.8 or 0.95

return config
