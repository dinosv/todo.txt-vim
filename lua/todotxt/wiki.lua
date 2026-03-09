local M = {}

local function config()
  return require("todotxt").config
end

function M.extract_tag(line)
  return line:match("%+(%S+)")
end

function M.goto_project()
  local line = vim.api.nvim_get_current_line()
  local tag = M.extract_tag(line)
  if not tag then
    vim.notify("No +tag found on this line", vim.log.levels.WARN)
    return
  end

  local cfg = config()
  local path = cfg.wiki_projects_dir .. tag .. cfg.wiki_ext

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

  local cfg = config()
  local path = cfg.wiki_projects_dir .. tag .. cfg.wiki_ext

  if vim.fn.filereadable(path) ~= 1 then
    local dir = cfg.wiki_projects_dir
    if vim.fn.isdirectory(dir) == 0 then
      vim.fn.mkdir(dir, "p")
    end

    local template = {
      "# " .. tag,
      "",
      "## Contexto",
      "Descripcion breve. Cliente, objetivo, alcance.",
      "",
      "## Acciones activas",
      "Ver: `grep '+" .. tag .. "' " .. cfg.todo_file .. "`",
      "",
      "## Notas y decisiones",
      "",
      "## Referencias",
    }
    vim.fn.writefile(template, path)
  end

  vim.cmd("tabedit " .. vim.fn.fnameescape(path))
end

function M.list_projects()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local tags = {}
  local seen = {}

  for _, line in ipairs(lines) do
    for tag in line:gmatch("%+(%S+)") do
      if not seen[tag] then
        seen[tag] = true
        table.insert(tags, tag)
      end
    end
  end

  table.sort(tags)

  if #tags == 0 then
    vim.notify("No +tags found in buffer", vim.log.levels.INFO)
    return
  end

  local cfg = config()
  local display = {}
  local max_len = 0
  for _, tag in ipairs(tags) do
    if #tag + 1 > max_len then
      max_len = #tag + 1
    end
  end

  for _, tag in ipairs(tags) do
    local path = cfg.wiki_projects_dir .. tag .. cfg.wiki_ext
    local status = vim.fn.filereadable(path) == 1 and "[wiki exists]" or "[no wiki]"
    local padded = "+" .. tag .. string.rep(" ", max_len - #tag) .. "  " .. status
    table.insert(display, padded)
  end

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
    title = " Project Wiki Status ",
    title_pos = "center",
  })

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  vim.keymap.set("n", "q", close, { buffer = buf })
  vim.keymap.set("n", "<Esc>", close, { buffer = buf })
  vim.keymap.set("n", "<CR>", function()
    local cur = vim.api.nvim_get_current_line()
    local tag = cur:match("^%+(%S+)")
    if not tag then return end
    close()
    local path = cfg.wiki_projects_dir .. tag .. cfg.wiki_ext
    if vim.fn.filereadable(path) ~= 1 then
      if vim.fn.isdirectory(cfg.wiki_projects_dir) == 0 then
        vim.fn.mkdir(cfg.wiki_projects_dir, "p")
      end
      local template = {
        "# " .. tag,
        "",
        "## Contexto",
        "Descripcion breve. Cliente, objetivo, alcance.",
        "",
        "## Acciones activas",
        "Ver: `grep '+" .. tag .. "' " .. cfg.todo_file .. "`",
        "",
        "## Notas y decisiones",
        "",
        "## Referencias",
      }
      vim.fn.writefile(template, path)
    end
    vim.cmd("tabedit " .. vim.fn.fnameescape(path))
  end, { buffer = buf })
end

return M
