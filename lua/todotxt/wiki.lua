local M = {}

local dates = require("todotxt.dates")

local function config()
  return require("todotxt").config
end

-- Normalised projects directory: ~ expanded, trailing slash guaranteed.
local function projects_dir()
  local dir = vim.fn.expand(config().wiki_projects_dir)
  if not dir:match("/$") then
    dir = dir .. "/"
  end
  return dir
end

local function project_path(tag)
  return projects_dir() .. tag .. config().wiki_ext
end

local function add_to_index(tag)
  local cfg = config()
  local wiki_root = vim.fn.fnamemodify(projects_dir():gsub("/$", ""), ":h")
  local index_path = wiki_root .. "/index" .. cfg.wiki_ext
  if vim.fn.filereadable(index_path) ~= 1 then return end

  local lines = vim.fn.readfile(index_path)
  local link_entry = "- [" .. tag .. "](projects/" .. tag .. ")"

  -- Check if already listed; the closing paren keeps a tag that is a
  -- prefix of an indexed tag (VRS vs VRS_GSK) from matching.
  for _, l in ipairs(lines) do
    if l:find("(projects/" .. tag .. ")", 1, true) then
      return
    end
  end

  -- Find end of ## Projects section (next --- after it)
  local in_projects = false
  local insert_at = nil
  for i, l in ipairs(lines) do
    if l:match("^## Projects") then
      in_projects = true
    elseif in_projects and l:match("^%-%-%-") then
      insert_at = i
      break
    end
  end

  if insert_at then
    table.insert(lines, insert_at, link_entry)
    vim.fn.writefile(lines, index_path)
    vim.notify("Added +" .. tag .. " to wiki index", vim.log.levels.INFO)
  end
end

-- A project tag is a whitespace-delimited word starting with '+', so
-- key:+value tags such as rec:+1w are not project tags. The prepended
-- space lets one pattern also cover tags at the start of the line.
local function iter_tags(line)
  return (" " .. line):gmatch("%s%+(%S+)")
end

function M.extract_tag(line)
  return iter_tags(line)()
end

function M.collect_tags(lines)
  local tags = {}
  local seen = {}
  for _, line in ipairs(lines) do
    for tag in iter_tags(line) do
      if not seen[tag] then
        seen[tag] = true
        table.insert(tags, tag)
      end
    end
  end
  table.sort(tags)
  return tags
end

local function is_completed(line)
  return line:match("^[xX]%s") ~= nil
end

function M.collect_active_tags(lines)
  local active_lines = {}
  for _, line in ipairs(lines) do
    if not is_completed(line) then
      table.insert(active_lines, line)
    end
  end
  return M.collect_tags(active_lines)
end

function M.active_tasks(lines, tag)
  local out = {}
  for i, line in ipairs(lines) do
    if not is_completed(line) then
      for t in iter_tags(line) do
        if t == tag then
          table.insert(out, { lnum = i, text = line })
          break
        end
      end
    end
  end
  return out
end

-- Lines of the todo file: the loaded buffer wins over the file on disk,
-- so unsaved edits are respected. Returns nil when neither exists.
local function todo_lines()
  local cfg = config()
  local bufnr = vim.fn.bufnr(cfg.todo_file)
  if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
    return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  end
  if vim.fn.filereadable(cfg.todo_file) == 1 then
    return vim.fn.readfile(cfg.todo_file)
  end
  return nil
end

function M.tasks_for(tag)
  local lines = todo_lines()
  if not lines then
    return nil
  end
  return M.active_tasks(lines, tag)
end

function M.journal_entry(done_line)
  local date, task = done_line:match("^[xX]%s+(%d%d%d%d%-%d%d%-%d%d)%s+(.*)")
  if not date then
    task = done_line:match("^[xX]%s+(.*)")
    if not task then
      return nil
    end
    date = dates.today()
  end
  return "- " .. date .. " x " .. task
end

function M.insert_journal_entry(page_lines, entry)
  local out = vim.deepcopy(page_lines)
  for i, line in ipairs(out) do
    if line:match("^## Registro") then
      table.insert(out, i + 1, entry)
      return out
    end
  end
  table.insert(out, "")
  table.insert(out, "## Registro")
  table.insert(out, entry)
  return out
end

-- Record a completed task in its project page. Never raises: journal
-- failures must not block marking a task done.
function M.journal_done(done_line)
  if not config().wiki_journal then
    return
  end
  local tag = M.extract_tag(done_line)
  if not tag then
    return
  end
  local path = project_path(tag)
  if vim.fn.filereadable(path) ~= 1 then
    return
  end
  local entry = M.journal_entry(done_line)
  if not entry then
    return
  end
  local ok, err = pcall(vim.fn.readfile, path)
  if not ok then
    vim.notify("todotxt: journal failed: " .. tostring(err), vim.log.levels.WARN)
    return
  end
  local page = err
  local ok_write, write_err = pcall(vim.fn.writefile, M.insert_journal_entry(page, entry), path)
  if not ok_write then
    vim.notify("todotxt: journal failed: " .. tostring(write_err), vim.log.levels.WARN)
  end
end

local function page_template(tag)
  return {
    "# " .. tag,
    "",
    "## Contexto",
    "Descripcion breve. Cliente, objetivo, alcance.",
    "",
    "## Acciones activas",
    "Ver: `grep '+" .. tag .. "' " .. config().todo_file .. "`",
    "",
    "## Notas y decisiones",
    "",
    "## Registro",
    "",
    "## Referencias",
  }
end

-- Create the wiki page for tag if missing, then return its path.
local function ensure_page(tag)
  local path = project_path(tag)
  if vim.fn.filereadable(path) ~= 1 then
    local dir = projects_dir()
    if vim.fn.isdirectory(dir) == 0 then
      vim.fn.mkdir(dir, "p")
    end
    vim.fn.writefile(page_template(tag), path)
    add_to_index(tag)
  end
  return path
end

function M.goto_project()
  local line = vim.api.nvim_get_current_line()
  local tag = M.extract_tag(line)
  if not tag then
    vim.notify("No +tag found on this line", vim.log.levels.WARN)
    return
  end

  local path = project_path(tag)

  if vim.fn.filereadable(path) == 1 then
    vim.cmd("tabedit " .. vim.fn.fnameescape(path))
  else
    vim.notify("No wiki page for +" .. tag .. ". Use -wc to create.", vim.log.levels.INFO)
  end
end

function M.create_project()
  local line = vim.api.nvim_get_current_line()
  local tag = M.extract_tag(line)
  if not tag then
    vim.notify("No +tag found on this line", vim.log.levels.WARN)
    return
  end

  local path = ensure_page(tag)
  vim.cmd("tabedit " .. vim.fn.fnameescape(path))
end

-- Shared centred floating list. Callers add their own <CR> mapping.
local function open_list_float(display, title)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, display)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  local width = 0
  for _, line in ipairs(display) do
    if #line > width then width = #line end
  end
  width = math.min(width + 4, vim.o.columns - 4)
  local height = math.min(#display, vim.o.lines - 6)

  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = title,
    title_pos = "center",
  })

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  vim.keymap.set("n", "q", close, { buffer = buf })
  vim.keymap.set("n", "<Esc>", close, { buffer = buf })

  return buf, win, close
end

function M.format_tasks(tasks)
  local rows = {}
  for _, t in ipairs(tasks) do
    table.insert(rows, string.format("%4d  %s", t.lnum, t.text))
  end
  return rows
end

-- -wt in a wiki project page: list this project's active tasks.
function M.show_tasks()
  local tag = vim.fn.expand("%:t:r")
  if tag == "" then
    vim.notify("Not in a project page", vim.log.levels.WARN)
    return
  end

  local tasks = M.tasks_for(tag)
  if not tasks then
    vim.notify("todo file not found: " .. config().todo_file, vim.log.levels.WARN)
    return
  end
  if #tasks == 0 then
    vim.notify("No active tasks for +" .. tag, vim.log.levels.INFO)
    return
  end

  local buf, _, close = open_list_float(M.format_tasks(tasks), " +" .. tag .. " tasks ")
  vim.keymap.set("n", "<CR>", function()
    local lnum = tonumber(vim.api.nvim_get_current_line():match("^%s*(%d+)"))
    if not lnum then
      return
    end
    close()
    vim.cmd("tabedit " .. vim.fn.fnameescape(config().todo_file))
    vim.api.nvim_win_set_cursor(0, { math.min(lnum, vim.api.nvim_buf_line_count(0)), 0 })
  end, { buffer = buf })
end

function M.build_capture_line(text, tag)
  return dates.today() .. " " .. text .. " +" .. tag
end

-- -wa in a wiki project page: capture a task into todo.txt with the
-- creation date and project tag added automatically.
function M.capture_task()
  local tag = vim.fn.expand("%:t:r")
  if tag == "" then
    vim.notify("Not in a project page", vim.log.levels.WARN)
    return
  end

  vim.ui.input({ prompt = "New task for +" .. tag .. ": " }, function(input)
    if not input or input:match("^%s*$") then
      return
    end
    local line = M.build_capture_line(vim.trim(input), tag)
    local cfg = config()
    local bufnr = vim.fn.bufnr(cfg.todo_file)
    if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
      vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { line })
      vim.notify("Added to todo buffer (unsaved): " .. line, vim.log.levels.INFO)
    else
      local ok, err = pcall(vim.fn.writefile, { line }, cfg.todo_file, "a")
      if ok then
        vim.notify("Appended to " .. cfg.todo_file .. ": " .. line, vim.log.levels.INFO)
      else
        vim.notify("todotxt: capture failed: " .. tostring(err), vim.log.levels.WARN)
      end
    end
  end)
end

function M.status_rows(buffer_lines, page_stems)
  local active = {}
  for _, t in ipairs(M.collect_active_tags(buffer_lines)) do
    active[t] = true
  end

  local has_page = {}
  for _, s in ipairs(page_stems) do
    has_page[s] = true
  end

  local union = M.collect_tags(buffer_lines)
  local seen = {}
  for _, t in ipairs(union) do
    seen[t] = true
  end
  for _, s in ipairs(page_stems) do
    if not seen[s] then
      table.insert(union, s)
    end
  end
  table.sort(union)

  local rows = {}
  for _, t in ipairs(union) do
    table.insert(rows, {
      tag = t,
      wiki = has_page[t] == true,
      stalled = active[t] ~= true,
    })
  end
  return rows
end

function M.list_projects()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  local stems = {}
  for _, f in ipairs(vim.fn.glob(projects_dir() .. "*" .. config().wiki_ext, false, true)) do
    table.insert(stems, vim.fn.fnamemodify(f, ":t:r"))
  end

  local rows = M.status_rows(lines, stems)
  if #rows == 0 then
    vim.notify("No +tags found in buffer", vim.log.levels.INFO)
    return
  end

  local max_len = 0
  for _, r in ipairs(rows) do
    if #r.tag + 1 > max_len then
      max_len = #r.tag + 1
    end
  end

  local display = {}
  for _, r in ipairs(rows) do
    local status = r.wiki and "[wiki exists]" or "[no wiki]"
    if r.stalled then
      status = status .. " [stalled]"
    end
    table.insert(display, "+" .. r.tag .. string.rep(" ", max_len - #r.tag) .. "  " .. status)
  end

  local buf, _, close = open_list_float(display, " Project Wiki Status ")

  vim.keymap.set("n", "<CR>", function()
    local cur = vim.api.nvim_get_current_line()
    local tag = cur:match("^%+(%S+)")
    if not tag then return end
    close()
    local path = ensure_page(tag)
    vim.cmd("tabedit " .. vim.fn.fnameescape(path))
  end, { buffer = buf })
end

-- Buffer-local mappings for wiki project pages. Idempotent.
function M.attach(buf)
  vim.keymap.set("n", "<localleader>wt", M.show_tasks,
    { buffer = buf, desc = "Show this project's tasks from todo.txt" })
  vim.keymap.set("n", "<localleader>wa", M.capture_task,
    { buffer = buf, desc = "Add a task to todo.txt for this project" })
end

-- Path-scoped autocmd attaching the wiki-side mappings. Called at startup
-- from plugin/todotxt.lua and again from setup() so a customised
-- wiki_projects_dir takes effect.
function M.register_autocmd()
  local group = vim.api.nvim_create_augroup("TodotxtWiki", { clear = true })
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    pattern = projects_dir() .. "*" .. config().wiki_ext,
    callback = function(ev)
      M.attach(ev.buf)
    end,
  })
end

return M
