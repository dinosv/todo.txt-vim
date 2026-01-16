-- lua/todotxt/init.lua
local M = {}

local dates = require("todotxt.dates")
local recurrence = require("todotxt.recurrence")

M.config = {
  auto_recur = true,
  threshold_fold = true,
  threshold_highlight = true,
}

function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", M.config, opts)
end

function M.mark_done(line)
  -- Strip existing priority
  local priority = line:match("^%((%a)%)")
  local task = line:gsub("^%(%a%)%s*", "")

  -- Mark as done
  local done = "x " .. dates.today() .. " " .. task

  -- Handle recurrence
  local new_task = nil
  if M.config.auto_recur then
    new_task = recurrence.advance_task(line)
    -- Restore priority to new task
    if new_task and priority then
      new_task = "(" .. priority .. ") " .. new_task:gsub("^%(%a%)%s*", "")
    end
  end

  return done, new_task
end

return M
