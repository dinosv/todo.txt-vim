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

-- Define highlight group
vim.api.nvim_set_hl(0, "TodoHidden", { link = "Comment", default = true })
vim.api.nvim_set_hl(0, "TodoRecurring", { link = "Special", default = true })

-- Namespace for our highlights
local ns = vim.api.nvim_create_namespace("todotxt")

local function update_highlights()
  if not todotxt.config.threshold_highlight then
    return
  end

  vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)

  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  for i, line in ipairs(lines) do
    if threshold.is_hidden(line) then
      vim.api.nvim_buf_add_highlight(0, ns, "TodoHidden", i - 1, 0, -1)
    end
  end
end

-- Update on buffer changes
vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "TextChangedI" }, {
  buffer = 0,
  callback = update_highlights,
})

-- Initial highlight
update_highlights()
