-- ftplugin/todo.lua
-- Only load in Neovim
if vim.fn.has("nvim-0.7") ~= 1 then
  return
end

local todotxt = require("todotxt")
local threshold = require("todotxt.threshold")

-- Mark done mapping
vim.keymap.set("n", "<localleader>x", function()
  local line = vim.api.nvim_get_current_line()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]

  local done, new_task = todotxt.mark_done(line)

  -- Replace current line with done task
  vim.api.nvim_buf_set_lines(0, lnum - 1, lnum, false, { done })

  -- Insert new recurring task below if exists
  if new_task then
    vim.api.nvim_buf_set_lines(0, lnum, lnum, false, { new_task })
  end
end, { buffer = true, desc = "Mark todo as done" })
