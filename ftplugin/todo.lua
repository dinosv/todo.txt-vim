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

  vim.api.nvim_buf_set_lines(0, lnum - 1, lnum, false, { done })

  if new_task then
    vim.api.nvim_buf_set_lines(0, lnum, lnum, false, { new_task })
  end
end, { buffer = true, desc = "Mark todo as done" })

-- Visual mode mark done mapping
vim.keymap.set("v", "<localleader>x", function()
  local start_line = vim.fn.line("'<")
  local end_line = vim.fn.line("'>")

  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  local result = {}
  local new_tasks = {}

  for _, line in ipairs(lines) do
    local done, new_task = todotxt.mark_done(line)
    table.insert(result, done)
    if new_task then
      table.insert(new_tasks, new_task)
    end
  end

  vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, result)

  if #new_tasks > 0 then
    vim.api.nvim_buf_set_lines(0, end_line, end_line, false, new_tasks)
  end
end, { buffer = true, desc = "Mark selected todos as done" })

-- Mark all active todos as done (with recurrence)
vim.keymap.set("n", "<localleader>X", function()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local result = {}
  local new_tasks = {}

  for _, line in ipairs(lines) do
    if line:match("^[xX]%s") or line == "" then
      table.insert(result, line)
    else
      local done, new_task = todotxt.mark_done(line)
      table.insert(result, done)
      if new_task then
        table.insert(new_tasks, new_task)
      end
    end
  end

  for _, t in ipairs(new_tasks) do
    table.insert(result, t)
  end

  vim.api.nvim_buf_set_lines(0, 0, -1, false, result)
end, { buffer = true, desc = "Mark all todos as done" })

-- Define highlight groups
vim.api.nvim_set_hl(0, "TodoHidden", { link = "Comment" })
vim.api.nvim_set_hl(0, "TodoRecurring", { link = "Special" })
vim.api.nvim_set_hl(0, "TodoOverdue", { bg = "#592222", fg = "#ff6666", bold = true })

-- Namespace for our highlights
local ns = vim.api.nvim_create_namespace("todotxt")

local dates = require("todotxt.dates")

local function update_highlights()
  if not todotxt.config.threshold_highlight then
    return
  end

  vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)

  local today = dates.today()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  for i, line in ipairs(lines) do
    if threshold.is_hidden(line) then
      vim.api.nvim_buf_set_extmark(0, ns, i - 1, 0, {
        end_col = #line,
        hl_group = "TodoHidden",
      })
    elseif not line:match("^[xX]%s") then
      local col_start, col_end = line:find("due:%d%d%d%d%-%d%d%-%d%d")
      if col_start then
        local due_date = line:match("due:(%d%d%d%d%-%d%d%-%d%d)")
        if due_date and due_date < today then
          vim.api.nvim_buf_set_extmark(0, ns, i - 1, col_start - 1, {
            end_col = col_end,
            hl_group = "TodoOverdue",
            priority = 200,
          })
        end
      end
    end
  end
end

local global_group = vim.api.nvim_create_augroup("TodotxtGlobal", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", {
  group = global_group,
  callback = function()
    vim.api.nvim_set_hl(0, "TodoHidden", { link = "Comment" })
    vim.api.nvim_set_hl(0, "TodoRecurring", { link = "Special" })
    vim.api.nvim_set_hl(0, "TodoOverdue", { bg = "#592222", fg = "#ff6666", bold = true })
  end,
})

local bufnr = vim.api.nvim_get_current_buf()
local buf_group = vim.api.nvim_create_augroup("TodotxtBuf_" .. bufnr, { clear = true })
vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "TextChangedI" }, {
  group = buf_group,
  buffer = bufnr,
  callback = update_highlights,
})

update_highlights()

vim.opt_local.foldmethod = "expr"
vim.opt_local.foldexpr = "v:lua.require('todotxt').fold_expr(v:lnum)"
vim.opt_local.foldtext = "v:lua.require('todotxt').fold_text()"

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

-- Wiki navigation
local wiki = require("todotxt.wiki")
vim.keymap.set("n", "<localleader>wp", wiki.goto_project, { buffer = true, desc = "Go to project wiki" })
vim.keymap.set("n", "<localleader>wc", wiki.create_project, { buffer = true, desc = "Create project wiki" })
vim.keymap.set("n", "<localleader>wl", wiki.list_projects, { buffer = true, desc = "List project wiki status" })
