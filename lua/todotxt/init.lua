-- lua/todotxt/init.lua
local M = {}

M.config = {
  auto_recur = true,
  threshold_fold = true,
  threshold_highlight = true,
}

function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", M.config, opts)
end

return M
