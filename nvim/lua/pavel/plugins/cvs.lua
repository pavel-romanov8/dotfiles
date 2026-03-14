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
  commit = "f1182bccae24d41661b6afb19c30f4ea68acb76d",
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
