local M = {}

local theme_by_mode = {
  dark = "github_dark",
  light = "github_light",
}

local valid_preferences = {
  auto = true,
  dark = true,
  light = true,
}

local preference_path = vim.fn.stdpath("state") .. "/theme-mode"
local preference
local last_automatic_mode

local function read_preference()
  if vim.fn.filereadable(preference_path) == 0 then
    return "auto"
  end

  local ok, lines = pcall(vim.fn.readfile, preference_path)
  local saved = ok and lines[1] or nil
  return valid_preferences[saved] and saved or "auto"
end

local function save_preference(mode)
  vim.fn.mkdir(vim.fs.dirname(preference_path), "p")
  if vim.fn.writefile({ mode }, preference_path) ~= 0 then
    vim.notify("Could not save theme preference", vim.log.levels.WARN)
  end
end

local function create_command(name, callback, description)
  if vim.fn.exists(":" .. name) == 0 then
    vim.api.nvim_create_user_command(name, callback, { desc = description })
  end
end

local function detect_macos_mode()
  if vim.uv.os_uname().sysname ~= "Darwin" then
    return nil
  end

  local handle = io.popen("defaults read -g AppleInterfaceStyle 2>/dev/null")
  if not handle then
    return nil
  end

  local output = handle:read("*a")
  handle:close()

  if output:match("Dark") then
    return "dark"
  end

  return "light"
end

function M.detect_mode()
  for _, variable in ipairs({ "NVIM_THEME", "WEZTERM_APPEARANCE" }) do
    local mode = vim.env[variable]
    if mode == "dark" or mode == "light" then
      return mode
    end
  end

  local mode = detect_macos_mode()
  if mode then
    return mode
  end

  return vim.o.background == "light" and "light" or "dark"
end

function M.get_preference()
  if not preference then
    preference = read_preference()
  end

  return preference
end

function M.get_mode()
  local saved = M.get_preference()
  if saved == "auto" then
    return last_automatic_mode or M.detect_mode()
  end

  return saved
end

function M.resolve_theme(mode)
  local resolved_mode = mode or M.get_mode()
  local theme_name = theme_by_mode[resolved_mode] or theme_by_mode.dark
  return require("pavel.themes." .. theme_name)
end

function M.apply(mode)
  local theme = M.resolve_theme(mode)
  vim.o.background = theme.background

  local ok, github_theme = pcall(require, "github-theme")
  if not ok then
    return
  end

  github_theme.setup(theme.github_theme)
  vim.cmd.colorscheme(theme.colorscheme)

  local ok, lualine = pcall(require, "lualine")
  if ok then
    lualine.refresh({ place = { "statusline", "winbar", "tabline" } })
  end
end

function M.apply_automatic(mode)
  if mode ~= "dark" and mode ~= "light" then
    return
  end

  last_automatic_mode = mode
  if M.get_preference() == "auto" then
    M.apply(mode)
  end
end

function M.set_preference(mode)
  if not valid_preferences[mode] then
    vim.notify("Unknown theme mode: " .. tostring(mode), vim.log.levels.ERROR)
    return
  end

  preference = mode
  save_preference(mode)
  M.apply(mode == "auto" and (last_automatic_mode or M.detect_mode()) or mode)

  local label = mode == "auto" and ("Auto (currently " .. M.get_mode() .. ")") or mode:gsub("^%l", string.upper)
  vim.notify("Theme mode: " .. label, vim.log.levels.INFO)
end

function M.toggle()
  M.set_preference(vim.o.background == "dark" and "light" or "dark")
end

function M.select()
  local current = M.get_preference()
  vim.ui.select({ "auto", "light", "dark" }, {
    prompt = "Theme mode",
    format_item = function(mode)
      local label = mode == "auto" and "Auto (system)" or mode:gsub("^%l", string.upper)
      return mode == current and (label .. "  ✓") or label
    end,
  }, function(mode)
    if mode then
      M.set_preference(mode)
    end
  end)
end

function M.setup()
  M.apply()

  create_command("Theme", M.select, "Choose automatic, light, or dark theme mode")
  create_command("ThemeAuto", function()
    M.set_preference("auto")
  end, "Follow the detected system theme")
  create_command("ThemeLight", function()
    M.set_preference("light")
  end, "Use and remember the light theme")
  create_command("ThemeDark", function()
    M.set_preference("dark")
  end, "Use and remember the dark theme")
  create_command("ThemeToggle", M.toggle, "Toggle between light and dark themes")
  create_command("ThemeSyncSystem", function()
    M.set_preference("auto")
  end, "Follow the detected system theme")

  vim.keymap.set("n", "<leader>ut", M.select, { desc = "Choose theme mode" })
end

return M
