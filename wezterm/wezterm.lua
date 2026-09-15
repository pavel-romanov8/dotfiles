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

local function sync_tmux_appearance(mode)
  if not wezterm.gui then
    return
  end

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

-- Subtle translucency; leave application-painted backgrounds opaque for contrast.
-- Ctrl+Shift+O toggles back to a fully solid background for comparison.
config.window_background_opacity = 0.95
config.macos_window_background_blur = 10
config.window_padding = { left = 10, right = 10, top = 6, bottom = 6 }

local color_schemes = {
  ["GitHub Dark Readable"] = {
    foreground = "#c9d1d9",
    background = "#24292e",
    cursor_bg = "#58a6ff",
    cursor_fg = "#24292e",
    cursor_border = "#58a6ff",
    selection_fg = "#dde5ed",
    selection_bg = "#383d42",
    scrollbar_thumb = "#59636e",
    split = "#59636e",
    ansi = {
      "#1f2428",
      "#ff7f8d",
      "#56d364",
      "#ffdf5d",
      "#58a6ff",
      "#d2a8ff",
      "#56d4dd",
      "#c9d1d9",
    },
    brights = {
      "#929da8",
      "#ffa198",
      "#85e89d",
      "#ffea7f",
      "#79c0ff",
      "#bc8cff",
      "#83caff",
      "#dde5ed",
    },
    indexed = { [16] = "#ffab70", [17] = "#ffa198" },
  },
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
    return "GitHub Dark Readable"
  end

  local scheme = os.getenv("WEZTERM_LIGHT_SCHEME") or "GitHub Light Readable"
  if color_scheme_exists(scheme) then
    return scheme
  end

  wezterm.log_warn("Unknown WEZTERM_LIGHT_SCHEME: " .. scheme .. "; using GitHub Light Readable")
  return "GitHub Light Readable"
end

local function effective_mode(window)
  local overrides = window:get_config_overrides() or {}
  if overrides.color_scheme then
    return overrides.color_scheme == "GitHub Dark Readable" and "dark" or "light"
  end
  return mode_for_appearance(get_appearance(window))
end

wezterm.on("toggle-theme", function(window)
  local overrides = window:get_config_overrides() or {}
  local appearance = effective_mode(window) == "dark" and "Light" or "Dark"
  overrides.color_scheme = scheme_for_appearance(appearance)
  window:set_config_overrides(overrides)
end)

wezterm.on("auto-theme", function(window)
  local overrides = window:get_config_overrides() or {}
  overrides.color_scheme = nil
  window:set_config_overrides(overrides)
end)

wezterm.on("toggle-opacity", function(window)
  local overrides = window:get_config_overrides() or {}
  if overrides.window_background_opacity == 1.0 then
    overrides.window_background_opacity = nil
  else
    overrides.window_background_opacity = 1.0
  end
  window:set_config_overrides(overrides)
end)

config.keys = {
  { key = "O", mods = "CTRL|SHIFT", action = wezterm.action.EmitEvent("toggle-opacity") },
  { key = "D", mods = "CTRL|SHIFT", action = wezterm.action.EmitEvent("toggle-theme") },
  { key = "A", mods = "CTRL|SHIFT", action = wezterm.action.EmitEvent("auto-theme") },
}

wezterm.on("gui-attached", function()
  sync_tmux_appearance(mode_for_appearance(get_appearance()))
end)

wezterm.on("window-config-reloaded", function(window)
  -- set_config_overrides triggers this too; publish the chosen mode, not just the OS mode.
  sync_tmux_appearance(effective_mode(window))
end)

local appearance = get_appearance()
config.color_scheme = scheme_for_appearance(appearance)

return config
