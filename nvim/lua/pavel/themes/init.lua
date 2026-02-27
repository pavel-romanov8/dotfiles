local M = {}

local theme_by_mode = {
  dark = "github_dark",
  light = "github_light",
}

local function detect_macos_mode()
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
  local mode = detect_macos_mode()
  if mode then
    return mode
  end

  return vim.o.background == "light" and "light" or "dark"
end

function M.resolve_theme(mode)
  local resolved_mode = mode or M.detect_mode()
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

function M.setup()
  M.apply()

  if vim.fn.exists(":ThemeSyncSystem") == 0 then
    vim.api.nvim_create_user_command("ThemeSyncSystem", function()
      M.apply()
      vim.notify("Theme synced with system appearance", vim.log.levels.INFO)
    end, {})
  end
end

return M
