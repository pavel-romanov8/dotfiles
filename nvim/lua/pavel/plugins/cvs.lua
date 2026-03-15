local function has_cvs_project()
  if vim.fn.executable("cvs") ~= 1 then
    return false
  end

  local root_markers = vim.fs.find("CVS", {
    path = vim.fn.getcwd(),
    type = "directory",
    upward = true,
  })

  return #root_markers > 0
end

return {
  "pavel-romanov8/cvs-nvim",
  branch = "main",
  cond = has_cvs_project,
  cmd = {
    "CvsStatus",
    "CvsUpdate",
    "CvsCommit",
    "CvsDiff",
    "CvsLog",
    "CvsAnnotate",
    "CvsConflicts",
  },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
  },
}
