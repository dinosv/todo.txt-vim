local M = {}

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

function M.list_projects()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local tags = M.collect_tags(lines)

  if #tags == 0 then
    vim.notify("No +tags found in buffer", vim.log.levels.INFO)
    return
  end

  local display = {}
  local max_len = 0
  for _, tag in ipairs(tags) do
    if #tag + 1 > max_len then
      max_len = #tag + 1
    end
  end

  for _, tag in ipairs(tags) do
    local status = vim.fn.filereadable(project_path(tag)) == 1 and "[wiki exists]" or "[no wiki]"
    local padded = "+" .. tag .. string.rep(" ", max_len - #tag) .. "  " .. status
    table.insert(display, padded)
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

return M
