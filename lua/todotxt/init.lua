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

local threshold = require("todotxt.threshold")

function M.fold_expr(lnum)
  if not M.config.threshold_fold then
    -- Fall back to original fold (completed tasks)
    local line = vim.fn.getline(lnum)
    if line:match("^[xX]%s") then
      return 1
    end
    return 0
  end

  local line = vim.fn.getline(lnum)

  -- Completed tasks
  if line:match("^[xX]%s") then
    return 1
  end

  -- Hidden tasks
  if threshold.is_hidden(line) then
    return 1
  end

  return 0
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
