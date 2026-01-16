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

-- Set fold options
vim.opt_local.foldmethod = "expr"
vim.opt_local.foldexpr = "v:lua.require('todotxt').fold_expr(v:lnum)"

-- Sort and move hidden to bottom
local function sort_with_hidden(sort_cmd)
  return function()
    -- Execute original sort
    vim.cmd(sort_cmd)
    -- Move hidden to bottom
    todotxt.sort_hidden_to_bottom(1, vim.fn.line("$"))
  end
end

vim.keymap.set("n", "<localleader>s", sort_with_hidden(":%sort"), { buffer = true })
vim.keymap.set("n", "<localleader>s@", sort_with_hidden(":%call todo#txt#sort_by_context()"), { buffer = true })
vim.keymap.set("n", "<localleader>s+", sort_with_hidden(":%call todo#txt#sort_by_project()"), { buffer = true })
vim.keymap.set("n", "<localleader>sd", sort_with_hidden(":%call todo#txt#sort_by_date()"), { buffer = true })
vim.keymap.set("n", "<localleader>sdd", sort_with_hidden(":%call todo#txt#sort_by_due_date()"), { buffer = true })

-- Visual mode sort and move hidden to bottom within selection
local function visual_sort_with_hidden(sort_cmd)
  return function()
    local start_line = vim.fn.line("'<")
    local end_line = vim.fn.line("'>")

    -- Execute original sort on range
    vim.cmd(start_line .. "," .. end_line .. sort_cmd:gsub("^:%%", ""))

    -- Move hidden to bottom within range
    todotxt.sort_hidden_to_bottom(start_line, end_line)
  end
end

vim.keymap.set("v", "<localleader>s", visual_sort_with_hidden(":sort"), { buffer = true })
vim.keymap.set("v", "<localleader>s@", visual_sort_with_hidden(":call todo#txt#sort_by_context()"), { buffer = true })
vim.keymap.set("v", "<localleader>s+", visual_sort_with_hidden(":call todo#txt#sort_by_project()"), { buffer = true })
vim.keymap.set("v", "<localleader>sd", visual_sort_with_hidden(":call todo#txt#sort_by_date()"), { buffer = true })
vim.keymap.set("v", "<localleader>sdd", visual_sort_with_hidden(":call todo#txt#sort_by_due_date()"), { buffer = true })
