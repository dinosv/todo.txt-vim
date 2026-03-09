-- lua/todotxt/init.lua
local M = {}

local dates = require("todotxt.dates")
local recurrence = require("todotxt.recurrence")

M.config = {
  auto_recur = true,
  threshold_fold = true,
  threshold_highlight = true,
  wiki_projects_dir = vim.fn.expand("~/00000_DATA/00000_GITHUB/00000_SYNC/020_VIMWIKI/wiki/projects/"),
  wiki_ext = ".md",
  todo_file = vim.fn.expand("~/00000_DATA/00000_GITHUB/00000_SYNC/010_TODOTXT/todo.txt"),
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

function M.sort_hidden_to_bottom(first_line, last_line)
  local lines = vim.api.nvim_buf_get_lines(0, first_line - 1, last_line, false)

  local visible = {}
  local hidden = {}

  for _, line in ipairs(lines) do
    if threshold.is_hidden(line) then
      table.insert(hidden, line)
    else
      table.insert(visible, line)
    end
  end

  -- Combine: visible first, then hidden
  local result = {}
  for _, line in ipairs(visible) do
    table.insert(result, line)
  end
  for _, line in ipairs(hidden) do
    table.insert(result, line)
  end

  vim.api.nvim_buf_set_lines(0, first_line - 1, last_line, false, result)
end

return M
