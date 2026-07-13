# Two-Way Wiki Integration Implementation Plan

> For agentic workers: REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

Goal: Make the todo.txt ↔ VimWiki bridge two-way — from a wiki project page list/jump to the project's active tasks (`-wt`) and capture new tasks (`-wa`); journal completed `+project` tasks into the page's `## Registro` section; flag stalled projects in `-wl`.

Architecture: All logic lives in `lua/todotxt/wiki.lua` as small functions (pure list transforms tested directly, thin IO wrappers around them). A new `plugin/todotxt.lua` registers one path-scoped autocmd that attaches the wiki-side mappings. `ftplugin/todo.lua`'s three mark-done mappings gain a `pcall`ed journal call. `lua/todotxt/init.lua` gains a `wiki_journal` config flag and re-registers the autocmd on `setup()`.

Tech Stack: Lua (Neovim 0.7+), busted + plenary for testing.

Reference spec: `docs/superpowers/specs/2026-07-13-wiki-integration-design.md`.

## Global Constraints

- "Active task" = non-empty line not matching `^[xX]%s`. Hidden (`h:1`) and threshold (`t:`) tasks count as active.
- Project tag in a wiki buffer is the filename stem (`vim.fn.expand("%:t:r")`).
- `+tag` matching must reuse the existing `iter_tags` pattern so `rec:+1w` never matches.
- Journal failures must never block marking a task done (wrap in `pcall`, warn via `vim.notify`).
- Journal entry format: `- <date> x <task>`, newest first, directly under `## Registro`.
- No bold, no emojis in any user-facing text or docs.

## File Structure

- Modify: `lua/todotxt/wiki.lua` — all new functions: `collect_active_tags`, `active_tasks`, `tasks_for`, `format_tasks`, `show_tasks`, `build_capture_line`, `capture_task`, `journal_entry`, `insert_journal_entry`, `journal_done`, `status_rows`, `attach`, `register_autocmd`; extract shared `open_list_float` helper; `page_template` gains `## Registro`; `list_projects` gains stalled detection.
- Create: `plugin/todotxt.lua` — startup registration of the wiki autocmd.
- Modify: `lua/todotxt/init.lua` — `wiki_journal = true` config; `setup()` re-registers the autocmd.
- Modify: `ftplugin/todo.lua` — journal calls in the three mark-done mappings.
- Create: `test/lua/todotxt/wiki_integration_spec.lua` — all new specs (keeps `wiki_spec.lua` focused on the existing one-way features).
- Modify: `CLAUDE.md` — document new keybindings, config, and behaviour.

## Running tests

Single file:

```bash
nvim --headless -u test/minimal_init.lua -c "PlenaryBustedFile test/lua/todotxt/wiki_integration_spec.lua" -c qa
```

Whole suite:

```bash
nvim --headless -u test/minimal_init.lua -c "PlenaryBustedDirectory test/lua/todotxt {minimal_init = 'test/minimal_init.lua'}" -c qa
```

Expected output: `Success` with `0 failures / 0 errors`.

---

## Task 1: Extract the shared floating-window helper

Pure refactor of `lua/todotxt/wiki.lua`: `list_projects` currently builds its float inline; `show_tasks` (Task 5) needs the same UI. Extract `open_list_float`.

Files:
- Modify: `lua/todotxt/wiki.lua`

Interfaces:
- Produces: `local open_list_float(display, title)` → returns `buf, win, close` where `display` is a list of strings, `title` the float title; `q`/`<Esc>` close mappings are pre-installed. Callers add their own `<CR>` mapping on `buf`.

- [ ] Step 1: Add the helper above `M.list_projects` in `lua/todotxt/wiki.lua`

```lua
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
```

- [ ] Step 2: Rewrite the tail of `M.list_projects` to use it

Replace everything in `M.list_projects` from `local buf = vim.api.nvim_create_buf(false, true)` down to (and including) the `<Esc>` keymap with:

```lua
  local buf, _, close = open_list_float(display, " Project Wiki Status ")
```

Keep the existing `<CR>` mapping block that follows, unchanged (it already references `buf` and `close`). Also delete the now-unused `width`/`height`/`row`/`col` computation inside `list_projects` (it moved into the helper).

- [ ] Step 3: Run the existing wiki suite to verify nothing broke

Run: `nvim --headless -u test/minimal_init.lua -c "PlenaryBustedFile test/lua/todotxt/wiki_spec.lua" -c qa`
Expected: `Success`, 0 failures.

- [ ] Step 4: Commit

```bash
git add lua/todotxt/wiki.lua
git commit -m "refactor(wiki): extract open_list_float helper from list_projects"
```

---

## Task 2: Active-task queries

Files:
- Modify: `lua/todotxt/wiki.lua`
- Create: `test/lua/todotxt/wiki_integration_spec.lua`

Interfaces:
- Produces:
  - `M.collect_active_tags(lines)` → sorted unique list of tags appearing on active (non-`x`) lines.
  - `M.active_tasks(lines, tag)` → list of `{ lnum = i, text = line }` for active lines carrying `+tag`.
  - `M.tasks_for(tag)` → same list read from the loaded todo buffer if present, else from `config.todo_file` on disk; `nil` if neither exists.

- [ ] Step 1: Write the failing tests

Create `test/lua/todotxt/wiki_integration_spec.lua`:

```lua
-- test/lua/todotxt/wiki_integration_spec.lua
-- Two-way wiki integration: reverse link, capture, journal, stalled detection.
describe("todotxt.wiki integration", function()
  local todotxt = require("todotxt")
  local wiki = require("todotxt.wiki")

  describe("collect_active_tags", function()
    it("ignores tags that only appear on completed lines", function()
      local tags = wiki.collect_active_tags({
        "task one +alpha",
        "x 2026-07-01 old task +beta",
        "task two +alpha h:1",
      })
      assert.same({ "alpha" }, tags)
    end)
  end)

  describe("active_tasks", function()
    local lines = {
      "(A) 2026-07-01 write report +VRS_GSK @UDD",
      "x 2026-07-02 done thing +VRS_GSK",
      "call client +VRS_GSK due:2026-07-20",
      "unrelated +other",
      "recurring rec:+1w @casa",
    }

    it("returns lnum and text for active lines with the tag", function()
      local tasks = wiki.active_tasks(lines, "VRS_GSK")
      assert.equals(2, #tasks)
      assert.equals(1, tasks[1].lnum)
      assert.equals("(A) 2026-07-01 write report +VRS_GSK @UDD", tasks[1].text)
      assert.equals(3, tasks[2].lnum)
    end)

    it("does not match rec:+1w style tags", function()
      assert.same({}, wiki.active_tasks(lines, "1w"))
    end)
  end)

  describe("tasks_for", function()
    local root

    before_each(function()
      root = vim.fn.tempname()
      vim.fn.mkdir(root, "p")
      todotxt.setup({ todo_file = root .. "/todo.txt" })
    end)

    after_each(function()
      vim.fn.delete(root, "rf")
    end)

    it("reads from the file on disk when no buffer is loaded", function()
      vim.fn.writefile({ "task +alpha", "x 2026-07-01 gone +alpha" }, root .. "/todo.txt")
      local tasks = wiki.tasks_for("alpha")
      assert.equals(1, #tasks)
      assert.equals("task +alpha", tasks[1].text)
    end)

    it("prefers the loaded todo buffer over the file", function()
      vim.fn.writefile({ "stale +alpha" }, root .. "/todo.txt")
      vim.cmd("edit " .. vim.fn.fnameescape(root .. "/todo.txt"))
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "fresh +alpha", "second +alpha" })
      local tasks = wiki.tasks_for("alpha")
      assert.equals(2, #tasks)
      assert.equals("fresh +alpha", tasks[1].text)
      vim.cmd("bwipeout!")
    end)

    it("returns nil when the todo file does not exist", function()
      assert.is_nil(wiki.tasks_for("alpha"))
    end)
  end)
end)
```

- [ ] Step 2: Run to verify failure

Run: `nvim --headless -u test/minimal_init.lua -c "PlenaryBustedFile test/lua/todotxt/wiki_integration_spec.lua" -c qa`
Expected: FAIL — `collect_active_tags` is nil (attempt to call a nil value).

- [ ] Step 3: Implement in `lua/todotxt/wiki.lua`

Add after `M.collect_tags`:

```lua
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
```

- [ ] Step 4: Run to verify pass

Run: `nvim --headless -u test/minimal_init.lua -c "PlenaryBustedFile test/lua/todotxt/wiki_integration_spec.lua" -c qa`
Expected: PASS, 0 failures.

- [ ] Step 5: Commit

```bash
git add lua/todotxt/wiki.lua test/lua/todotxt/wiki_integration_spec.lua
git commit -m "feat(wiki): active-task queries for reverse wiki-to-todo lookup"
```

---

## Task 3: Journal pure functions and template section

Files:
- Modify: `lua/todotxt/wiki.lua`
- Modify: `test/lua/todotxt/wiki_integration_spec.lua`

Interfaces:
- Consumes: nothing new.
- Produces:
  - `M.journal_entry(done_line)` → `"- <date> x <task>"` string, or `nil` for a line that is not completed. Missing completion date falls back to `dates.today()`.
  - `M.insert_journal_entry(page_lines, entry)` → new list with `entry` inserted directly under `## Registro` (heading appended at end of page when absent). Does not mutate its input.
  - `page_template` output now contains a `## Registro` section between `## Notas y decisiones` and `## Referencias`.

- [ ] Step 1: Write the failing tests

Append inside the top-level `describe` of `test/lua/todotxt/wiki_integration_spec.lua`:

```lua
  describe("journal_entry", function()
    it("reorders a done line into '- date x task'", function()
      assert.equals(
        "- 2026-07-13 x enviar informe final +VRS_GSK",
        wiki.journal_entry("x 2026-07-13 enviar informe final +VRS_GSK")
      )
    end)

    it("returns nil for a line that is not completed", function()
      assert.is_nil(wiki.journal_entry("(A) still active +VRS_GSK"))
    end)

    it("falls back to today when the done line has no date", function()
      local dates = require("todotxt.dates")
      assert.equals(
        "- " .. dates.today() .. " x undated task +tag",
        wiki.journal_entry("x undated task +tag")
      )
    end)
  end)

  describe("insert_journal_entry", function()
    it("inserts directly under an existing Registro heading, newest first", function()
      local page = {
        "# VRS_GSK",
        "",
        "## Registro",
        "- 2026-07-10 x reunion kickoff +VRS_GSK",
      }
      local out = wiki.insert_journal_entry(page, "- 2026-07-13 x enviar informe +VRS_GSK")
      assert.same({
        "# VRS_GSK",
        "",
        "## Registro",
        "- 2026-07-13 x enviar informe +VRS_GSK",
        "- 2026-07-10 x reunion kickoff +VRS_GSK",
      }, out)
      -- input not mutated
      assert.equals(4, #page)
    end)

    it("appends the section when the page has no Registro heading", function()
      local out = wiki.insert_journal_entry({ "# VRS_GSK" }, "- 2026-07-13 x tarea +VRS_GSK")
      assert.same({
        "# VRS_GSK",
        "",
        "## Registro",
        "- 2026-07-13 x tarea +VRS_GSK",
      }, out)
    end)
  end)

  describe("page template", function()
    local root

    before_each(function()
      root = vim.fn.tempname()
      vim.fn.mkdir(root .. "/wiki/projects", "p")
      todotxt.setup({ wiki_projects_dir = root .. "/wiki/projects/", wiki_ext = ".md" })
      vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(false, true))
    end)

    after_each(function()
      vim.fn.delete(root, "rf")
    end)

    it("includes a Registro section in newly created pages", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "+VRS_GSK write report" })
      wiki.create_project()
      local page = table.concat(vim.fn.readfile(root .. "/wiki/projects/VRS_GSK.md"), "\n")
      assert.matches("## Registro", page)
    end)
  end)
```

- [ ] Step 2: Run to verify failure

Run: `nvim --headless -u test/minimal_init.lua -c "PlenaryBustedFile test/lua/todotxt/wiki_integration_spec.lua" -c qa`
Expected: FAIL — `journal_entry` is a nil value.

- [ ] Step 3: Implement

At the top of `lua/todotxt/wiki.lua`, after `local M = {}`, add:

```lua
local dates = require("todotxt.dates")
```

Add the two functions after `M.tasks_for`:

```lua
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
```

In `page_template`, insert two lines between `"## Notas y decisiones",` / `"",` and `"## Referencias",`:

```lua
    "## Notas y decisiones",
    "",
    "## Registro",
    "",
    "## Referencias",
```

- [ ] Step 4: Run to verify pass

Run: `nvim --headless -u test/minimal_init.lua -c "PlenaryBustedFile test/lua/todotxt/wiki_integration_spec.lua" -c qa`
Expected: PASS. Also run the full suite (`PlenaryBustedDirectory`) — `wiki_spec.lua` must still pass.

- [ ] Step 5: Commit

```bash
git add lua/todotxt/wiki.lua test/lua/todotxt/wiki_integration_spec.lua
git commit -m "feat(wiki): journal entry formatting and Registro template section"
```

---

## Task 4: journal_done IO and wiki_journal config flag

Files:
- Modify: `lua/todotxt/init.lua`
- Modify: `lua/todotxt/wiki.lua`
- Modify: `test/lua/todotxt/wiki_integration_spec.lua`

Interfaces:
- Consumes: `M.journal_entry`, `M.insert_journal_entry`, `M.extract_tag`, `project_path` (Task 3 and existing).
- Produces: `M.journal_done(done_line)` — writes the entry to the project page; silent no-op when `config.wiki_journal` is false, the line has no `+tag`, or the page does not exist. Write failures warn via `vim.notify`, never raise.

- [ ] Step 1: Write the failing tests

Append inside the top-level `describe`:

```lua
  describe("journal_done", function()
    local root

    before_each(function()
      root = vim.fn.tempname()
      vim.fn.mkdir(root .. "/wiki/projects", "p")
      todotxt.setup({
        wiki_projects_dir = root .. "/wiki/projects/",
        wiki_ext = ".md",
        wiki_journal = true,
      })
    end)

    after_each(function()
      vim.fn.delete(root, "rf")
      todotxt.setup({ wiki_journal = true })
    end)

    it("writes the entry under Registro in the project page", function()
      vim.fn.writefile({ "# VRS_GSK", "", "## Registro" }, root .. "/wiki/projects/VRS_GSK.md")
      wiki.journal_done("x 2026-07-13 enviar informe +VRS_GSK")
      local page = vim.fn.readfile(root .. "/wiki/projects/VRS_GSK.md")
      assert.equals("- 2026-07-13 x enviar informe +VRS_GSK", page[4])
    end)

    it("does nothing when the project has no wiki page", function()
      wiki.journal_done("x 2026-07-13 tarea +nopage")
      assert.equals(0, vim.fn.filereadable(root .. "/wiki/projects/nopage.md"))
    end)

    it("does nothing when wiki_journal is false", function()
      vim.fn.writefile({ "# VRS_GSK" }, root .. "/wiki/projects/VRS_GSK.md")
      todotxt.setup({ wiki_journal = false })
      wiki.journal_done("x 2026-07-13 tarea +VRS_GSK")
      assert.same({ "# VRS_GSK" }, vim.fn.readfile(root .. "/wiki/projects/VRS_GSK.md"))
    end)

    it("does nothing for a line without a project tag", function()
      wiki.journal_done("x 2026-07-13 tarea sin proyecto")
      -- nothing to assert beyond not erroring and no file appearing
      assert.same({}, vim.fn.glob(root .. "/wiki/projects/*", false, true))
    end)
  end)
```

- [ ] Step 2: Run to verify failure

Run: `nvim --headless -u test/minimal_init.lua -c "PlenaryBustedFile test/lua/todotxt/wiki_integration_spec.lua" -c qa`
Expected: FAIL — `journal_done` is a nil value.

- [ ] Step 3: Implement

In `lua/todotxt/init.lua`, add to `M.config`:

```lua
  wiki_journal = true,
```

In `lua/todotxt/wiki.lua`, add after `M.insert_journal_entry`:

```lua
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
  local page = vim.fn.readfile(path)
  local ok, err = pcall(vim.fn.writefile, M.insert_journal_entry(page, entry), path)
  if not ok then
    vim.notify("todotxt: journal failed: " .. tostring(err), vim.log.levels.WARN)
  end
end
```

- [ ] Step 4: Run to verify pass

Run: `nvim --headless -u test/minimal_init.lua -c "PlenaryBustedFile test/lua/todotxt/wiki_integration_spec.lua" -c qa`
Expected: PASS.

- [ ] Step 5: Commit

```bash
git add lua/todotxt/init.lua lua/todotxt/wiki.lua test/lua/todotxt/wiki_integration_spec.lua
git commit -m "feat(wiki): journal_done writes completed tasks to the project page"
```

---

## Task 5: Wire the journal into the mark-done mappings

Files:
- Modify: `ftplugin/todo.lua`
- Modify: `test/lua/todotxt/wiki_integration_spec.lua`

Interfaces:
- Consumes: `wiki.journal_done(done_line)` (Task 4); `todotxt.mark_done(line)` returns the line unchanged when it was already done — that identity check is the journal guard.

- [ ] Step 1: Write the failing tests

Append inside the top-level `describe`:

```lua
  describe("journal wiring in ftplugin mappings", function()
    local root

    local function feed(keys)
      local termcodes = vim.api.nvim_replace_termcodes(keys, true, false, true)
      vim.api.nvim_feedkeys(termcodes, "x", false)
    end

    local function setup_todo_buffer(lines)
      vim.g.maplocalleader = "-"
      local buf = vim.api.nvim_create_buf(false, false)
      vim.api.nvim_set_current_buf(buf)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      vim.bo[buf].filetype = "todo"
      return buf
    end

    before_each(function()
      root = vim.fn.tempname()
      vim.fn.mkdir(root .. "/wiki/projects", "p")
      todotxt.setup({
        wiki_projects_dir = root .. "/wiki/projects/",
        wiki_ext = ".md",
        wiki_journal = true,
      })
    end)

    after_each(function()
      vim.fn.delete(root, "rf")
    end)

    it("journals a task completed with normal -x", function()
      vim.fn.writefile({ "# VRS_GSK", "", "## Registro" }, root .. "/wiki/projects/VRS_GSK.md")
      setup_todo_buffer({ "enviar informe +VRS_GSK" })
      feed("gg-x")
      local page = vim.fn.readfile(root .. "/wiki/projects/VRS_GSK.md")
      assert.matches("^%- %d%d%d%d%-%d%d%-%d%d x enviar informe %+VRS_GSK$", page[4])
    end)

    it("does not journal an already-completed line", function()
      vim.fn.writefile({ "# VRS_GSK", "", "## Registro" }, root .. "/wiki/projects/VRS_GSK.md")
      setup_todo_buffer({ "x 2026-07-01 ya hecho +VRS_GSK" })
      feed("gg-x")
      assert.equals(3, #vim.fn.readfile(root .. "/wiki/projects/VRS_GSK.md"))
    end)

    it("journals every task completed with -X", function()
      vim.fn.writefile({ "# alpha", "", "## Registro" }, root .. "/wiki/projects/alpha.md")
      setup_todo_buffer({ "uno +alpha", "dos +alpha" })
      feed("-X")
      assert.equals(5, #vim.fn.readfile(root .. "/wiki/projects/alpha.md"))
    end)

    it("journals tasks completed with visual -x", function()
      vim.fn.writefile({ "# alpha", "", "## Registro" }, root .. "/wiki/projects/alpha.md")
      setup_todo_buffer({ "uno +alpha", "dos +alpha" })
      feed("ggVj-x")
      assert.equals(5, #vim.fn.readfile(root .. "/wiki/projects/alpha.md"))
    end)
  end)
```

- [ ] Step 2: Run to verify failure

Run: `nvim --headless -u test/minimal_init.lua -c "PlenaryBustedFile test/lua/todotxt/wiki_integration_spec.lua" -c qa`
Expected: FAIL — the page files keep only 3 lines (no journal entries yet).

- [ ] Step 3: Implement in `ftplugin/todo.lua`

Move the wiki require to the top: at the require block (after `local dependency = require("todotxt.dependency")`), add:

```lua
local wiki = require("todotxt.wiki")
```

and delete the later line `local wiki = require("todotxt.wiki")` above the wiki keymaps (keep the `-- Wiki navigation` comment and the three keymaps).

Normal-mode `-x` mapping — after `local done, new_task = todotxt.mark_done(line)`, add:

```lua
  if done ~= line then
    pcall(wiki.journal_done, done)
  end
```

Visual `-x` mapping — inside its `for _, line in ipairs(lines) do` loop, after `table.insert(result, done)`, add:

```lua
    if done ~= line then
      pcall(wiki.journal_done, done)
    end
```

`-X` mapping — in its `else` branch, after `table.insert(result, done)`, add:

```lua
      pcall(wiki.journal_done, done)
```

(The `-X` loop only calls `mark_done` on lines that are not yet completed, so no identity check is needed there.)

- [ ] Step 4: Run to verify pass

Run the file spec, then the whole suite:

```bash
nvim --headless -u test/minimal_init.lua -c "PlenaryBustedFile test/lua/todotxt/wiki_integration_spec.lua" -c qa
nvim --headless -u test/minimal_init.lua -c "PlenaryBustedDirectory test/lua/todotxt {minimal_init = 'test/minimal_init.lua'}" -c qa
```

Expected: PASS everywhere (existing ftplugin_spec must stay green).

- [ ] Step 5: Commit

```bash
git add ftplugin/todo.lua test/lua/todotxt/wiki_integration_spec.lua
git commit -m "feat(wiki): journal completed project tasks from -x, visual -x and -X"
```

---

## Task 6: show_tasks (-wt behaviour)

Files:
- Modify: `lua/todotxt/wiki.lua`
- Modify: `test/lua/todotxt/wiki_integration_spec.lua`

Interfaces:
- Consumes: `M.tasks_for` (Task 2), `open_list_float` (Task 1).
- Produces:
  - `M.format_tasks(tasks)` → display rows `"%4d  %s"` (lnum, text).
  - `M.show_tasks()` — reads the tag from the current buffer's filename stem; floating list; `<CR>` opens `config.todo_file` in a new tab at the task's line.

- [ ] Step 1: Write the failing tests

Append inside the top-level `describe`:

```lua
  describe("show_tasks", function()
    local root

    before_each(function()
      root = vim.fn.tempname()
      vim.fn.mkdir(root .. "/wiki/projects", "p")
      todotxt.setup({
        wiki_projects_dir = root .. "/wiki/projects/",
        wiki_ext = ".md",
        todo_file = root .. "/todo.txt",
      })
    end)

    after_each(function()
      vim.fn.delete(root, "rf")
      vim.cmd("silent! tabonly!")
    end)

    it("formats tasks with their line numbers", function()
      local rows = wiki.format_tasks({
        { lnum = 3, text = "call client +alpha" },
        { lnum = 12, text = "(A) report +alpha" },
      })
      assert.same({ "   3  call client +alpha", "  12  (A) report +alpha" }, rows)
    end)

    it("opens a float listing the project's active tasks", function()
      vim.fn.writefile({ "uno +VRS_GSK", "x 2026-07-01 done +VRS_GSK" }, root .. "/todo.txt")
      vim.fn.writefile({ "# VRS_GSK" }, root .. "/wiki/projects/VRS_GSK.md")
      vim.cmd("edit " .. vim.fn.fnameescape(root .. "/wiki/projects/VRS_GSK.md"))

      wiki.show_tasks()

      local float_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.equals(1, #float_lines)
      assert.matches("uno %+VRS_GSK", float_lines[1])
      -- close the float
      vim.api.nvim_win_close(0, true)
    end)

    it("jumps to the task line in todo.txt on <CR>", function()
      vim.fn.writefile({ "uno +VRS_GSK", "dos +VRS_GSK" }, root .. "/todo.txt")
      vim.fn.writefile({ "# VRS_GSK" }, root .. "/wiki/projects/VRS_GSK.md")
      vim.cmd("edit " .. vim.fn.fnameescape(root .. "/wiki/projects/VRS_GSK.md"))

      wiki.show_tasks()
      vim.cmd("normal! j")
      local termcodes = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
      vim.api.nvim_feedkeys(termcodes, "x", false)

      assert.equals(root .. "/todo.txt", vim.api.nvim_buf_get_name(0))
      assert.equals(2, vim.api.nvim_win_get_cursor(0)[1])
    end)
  end)
```

- [ ] Step 2: Run to verify failure

Run: `nvim --headless -u test/minimal_init.lua -c "PlenaryBustedFile test/lua/todotxt/wiki_integration_spec.lua" -c qa`
Expected: FAIL — `format_tasks` is a nil value.

- [ ] Step 3: Implement in `lua/todotxt/wiki.lua`

```lua
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
```

- [ ] Step 4: Run to verify pass

Run: `nvim --headless -u test/minimal_init.lua -c "PlenaryBustedFile test/lua/todotxt/wiki_integration_spec.lua" -c qa`
Expected: PASS.

- [ ] Step 5: Commit

```bash
git add lua/todotxt/wiki.lua test/lua/todotxt/wiki_integration_spec.lua
git commit -m "feat(wiki): show_tasks lists a project's active tasks from its page"
```

---

## Task 7: capture_task (-wa behaviour)

Files:
- Modify: `lua/todotxt/wiki.lua`
- Modify: `test/lua/todotxt/wiki_integration_spec.lua`

Interfaces:
- Consumes: `dates.today()` (required in Task 3).
- Produces:
  - `M.build_capture_line(text, tag)` → `"<today> <text> +<tag>"`.
  - `M.capture_task()` — prompts via `vim.ui.input`; appends to the loaded todo buffer if present (left unsaved), else to the file on disk (created if missing via the `"a"` flag); notifies the destination; empty or cancelled input is a no-op.

- [ ] Step 1: Write the failing tests

Append inside the top-level `describe`:

```lua
  describe("capture_task", function()
    local root
    local orig_input

    -- Stub vim.ui.input to immediately answer with `reply`.
    local function stub_input(reply)
      vim.ui.input = function(_, cb)
        cb(reply)
      end
    end

    before_each(function()
      root = vim.fn.tempname()
      vim.fn.mkdir(root .. "/wiki/projects", "p")
      vim.fn.writefile({ "# alpha" }, root .. "/wiki/projects/alpha.md")
      todotxt.setup({
        wiki_projects_dir = root .. "/wiki/projects/",
        wiki_ext = ".md",
        todo_file = root .. "/todo.txt",
      })
      vim.cmd("edit " .. vim.fn.fnameescape(root .. "/wiki/projects/alpha.md"))
      orig_input = vim.ui.input
    end)

    after_each(function()
      vim.ui.input = orig_input
      vim.fn.delete(root, "rf")
    end)

    it("builds the line as date, text, tag", function()
      local dates = require("todotxt.dates")
      assert.equals(
        dates.today() .. " llamar al cliente +alpha",
        wiki.build_capture_line("llamar al cliente", "alpha")
      )
    end)

    it("appends to the file on disk when no todo buffer is loaded", function()
      vim.fn.writefile({ "existing task" }, root .. "/todo.txt")
      stub_input("nueva tarea")
      wiki.capture_task()
      local lines = vim.fn.readfile(root .. "/todo.txt")
      assert.equals(2, #lines)
      assert.matches("nueva tarea %+alpha$", lines[2])
    end)

    it("creates the todo file when it does not exist", function()
      stub_input("primera tarea")
      wiki.capture_task()
      assert.matches("primera tarea %+alpha$", vim.fn.readfile(root .. "/todo.txt")[1])
    end)

    it("appends to the loaded todo buffer and leaves it unsaved", function()
      vim.fn.writefile({ "existing task" }, root .. "/todo.txt")
      vim.cmd("edit " .. vim.fn.fnameescape(root .. "/todo.txt"))
      local todo_buf = vim.api.nvim_get_current_buf()
      vim.cmd("edit " .. vim.fn.fnameescape(root .. "/wiki/projects/alpha.md"))

      stub_input("desde el buffer")
      wiki.capture_task()

      local lines = vim.api.nvim_buf_get_lines(todo_buf, 0, -1, false)
      assert.matches("desde el buffer %+alpha$", lines[#lines])
      assert.is_true(vim.bo[todo_buf].modified)
      -- file on disk untouched
      assert.equals(1, #vim.fn.readfile(root .. "/todo.txt"))
      vim.cmd("bwipeout! " .. todo_buf)
    end)

    it("does nothing on empty or cancelled input", function()
      stub_input("")
      wiki.capture_task()
      stub_input(nil)
      wiki.capture_task()
      assert.equals(0, vim.fn.filereadable(root .. "/todo.txt"))
    end)
  end)
```

- [ ] Step 2: Run to verify failure

Run: `nvim --headless -u test/minimal_init.lua -c "PlenaryBustedFile test/lua/todotxt/wiki_integration_spec.lua" -c qa`
Expected: FAIL — `build_capture_line` is a nil value.

- [ ] Step 3: Implement in `lua/todotxt/wiki.lua`

```lua
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
```

- [ ] Step 4: Run to verify pass

Run: `nvim --headless -u test/minimal_init.lua -c "PlenaryBustedFile test/lua/todotxt/wiki_integration_spec.lua" -c qa`
Expected: PASS.

- [ ] Step 5: Commit

```bash
git add lua/todotxt/wiki.lua test/lua/todotxt/wiki_integration_spec.lua
git commit -m "feat(wiki): capture_task adds a dated, tagged task from the wiki page"
```

---

## Task 8: attach, plugin autocmd, setup() re-registration

Files:
- Create: `plugin/todotxt.lua`
- Modify: `lua/todotxt/wiki.lua`
- Modify: `lua/todotxt/init.lua`
- Modify: `test/lua/todotxt/wiki_integration_spec.lua`

Interfaces:
- Consumes: `M.show_tasks` (Task 6), `M.capture_task` (Task 7).
- Produces:
  - `M.attach(buf)` — buffer-local `n` mappings `<localleader>wt` → `show_tasks`, `<localleader>wa` → `capture_task`. Idempotent (`vim.keymap.set` overwrites).
  - `M.register_autocmd()` — augroup `TodotxtWiki` (cleared on every call, so re-registration replaces), `BufEnter` with pattern `projects_dir() .. "*" .. wiki_ext` calling `attach`.
  - `require("todotxt").setup(opts)` now ends with `pcall(function() require("todotxt.wiki").register_autocmd() end)`.

- [ ] Step 1: Write the failing tests

Append inside the top-level `describe`:

```lua
  describe("wiki-side mappings", function()
    local root

    before_each(function()
      vim.g.maplocalleader = "-"
      root = vim.fn.tempname()
      vim.fn.mkdir(root .. "/wiki/projects", "p")
      vim.fn.writefile({ "# alpha" }, root .. "/wiki/projects/alpha.md")
      -- setup() re-registers the autocmd against the temp dir
      todotxt.setup({ wiki_projects_dir = root .. "/wiki/projects/", wiki_ext = ".md" })
    end)

    after_each(function()
      vim.fn.delete(root, "rf")
    end)

    it("attach sets buffer-local -wt and -wa mappings", function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(buf)
      wiki.attach(buf)
      assert.equals(1, vim.fn.maparg("-wt", "n", false, true).buffer)
      assert.equals(1, vim.fn.maparg("-wa", "n", false, true).buffer)
    end)

    it("entering a project page attaches the mappings via autocmd", function()
      vim.cmd("edit " .. vim.fn.fnameescape(root .. "/wiki/projects/alpha.md"))
      assert.equals(1, vim.fn.maparg("-wt", "n", false, true).buffer)
    end)

    it("does not attach outside the projects dir", function()
      vim.fn.writefile({ "# other" }, root .. "/other.md")
      vim.cmd("edit " .. vim.fn.fnameescape(root .. "/other.md"))
      assert.same({}, vim.fn.maparg("-wt", "n", false, true))
    end)
  end)
```

- [ ] Step 2: Run to verify failure

Run: `nvim --headless -u test/minimal_init.lua -c "PlenaryBustedFile test/lua/todotxt/wiki_integration_spec.lua" -c qa`
Expected: FAIL — `attach` is a nil value.

- [ ] Step 3: Implement

In `lua/todotxt/wiki.lua`, add before `return M`:

```lua
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
```

In `lua/todotxt/init.lua`, extend `setup`:

```lua
function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", M.config, opts)
  pcall(function()
    require("todotxt.wiki").register_autocmd()
  end)
end
```

Create `plugin/todotxt.lua`:

```lua
-- plugin/todotxt.lua
-- Wiki-side mappings (-wt, -wa) for project pages need an autocmd that
-- exists before any project page is opened, hence plugin/ not ftplugin/.
if vim.fn.has("nvim-0.7") ~= 1 then
  return
end

require("todotxt.wiki").register_autocmd()
```

- [ ] Step 4: Run to verify pass

Run the file spec, then the whole suite:

```bash
nvim --headless -u test/minimal_init.lua -c "PlenaryBustedFile test/lua/todotxt/wiki_integration_spec.lua" -c qa
nvim --headless -u test/minimal_init.lua -c "PlenaryBustedDirectory test/lua/todotxt {minimal_init = 'test/minimal_init.lua'}" -c qa
```

Expected: PASS everywhere.

- [ ] Step 5: Commit

```bash
git add plugin/todotxt.lua lua/todotxt/wiki.lua lua/todotxt/init.lua test/lua/todotxt/wiki_integration_spec.lua
git commit -m "feat(wiki): attach -wt/-wa in project pages via path-scoped autocmd"
```

---

## Task 9: Stalled-project detection in -wl

Files:
- Modify: `lua/todotxt/wiki.lua`
- Modify: `test/lua/todotxt/wiki_integration_spec.lua`

Interfaces:
- Consumes: `M.collect_tags`, `M.collect_active_tags` (Task 2), `open_list_float` (Task 1).
- Produces: `M.status_rows(buffer_lines, page_stems)` → sorted list of `{ tag = string, wiki = boolean, stalled = boolean }` over the union of buffer tags and wiki page stems. `M.list_projects` renders `[stalled]` after the wiki status and includes orphan pages.

- [ ] Step 1: Write the failing tests

Append inside the top-level `describe`:

```lua
  describe("status_rows", function()
    it("marks tags with no active task as stalled and includes orphan pages", function()
      local rows = wiki.status_rows(
        {
          "task +alive",
          "x 2026-07-01 finished +finished_project",
        },
        { "alive", "orphan_page" }
      )
      assert.same({
        { tag = "alive", wiki = true, stalled = false },
        { tag = "finished_project", wiki = false, stalled = true },
        { tag = "orphan_page", wiki = true, stalled = true },
      }, rows)
    end)
  end)

  describe("list_projects with stalled detection", function()
    local root

    before_each(function()
      root = vim.fn.tempname()
      vim.fn.mkdir(root .. "/wiki/projects", "p")
      todotxt.setup({ wiki_projects_dir = root .. "/wiki/projects/", wiki_ext = ".md" })
      vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(false, true))
    end)

    after_each(function()
      vim.fn.delete(root, "rf")
    end)

    it("shows [stalled] for an orphan wiki page", function()
      vim.fn.writefile({ "# ghost" }, root .. "/wiki/projects/ghost.md")
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "task +alive" })

      wiki.list_projects()

      local float_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      local joined = table.concat(float_lines, "\n")
      assert.matches("%+ghost%s+%[wiki exists%] %[stalled%]", joined)
      assert.matches("%+alive%s+%[no wiki%]\n", joined .. "\n")
      vim.api.nvim_win_close(0, true)
    end)
  end)
```

- [ ] Step 2: Run to verify failure

Run: `nvim --headless -u test/minimal_init.lua -c "PlenaryBustedFile test/lua/todotxt/wiki_integration_spec.lua" -c qa`
Expected: FAIL — `status_rows` is a nil value.

- [ ] Step 3: Implement in `lua/todotxt/wiki.lua`

Add before `M.list_projects`:

```lua
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
```

Rewrite the top half of `M.list_projects` (everything before the float is opened) to:

```lua
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
```

The rest of the function (the `open_list_float` call and `<CR>` mapping from Task 1) stays as is. Delete the old `collect_tags`-based listing code that this replaces.

- [ ] Step 4: Run to verify pass

Run the file spec, then the whole suite (the `wiki_spec.lua` file-operations tests exercise `list_projects` indirectly via `create_project` only, but run everything to be sure):

```bash
nvim --headless -u test/minimal_init.lua -c "PlenaryBustedDirectory test/lua/todotxt {minimal_init = 'test/minimal_init.lua'}" -c qa
```

Expected: PASS, 0 failures.

- [ ] Step 5: Commit

```bash
git add lua/todotxt/wiki.lua test/lua/todotxt/wiki_integration_spec.lua
git commit -m "feat(wiki): -wl flags stalled projects and lists orphan wiki pages"
```

---

## Task 10: Documentation

Files:
- Modify: `CLAUDE.md`
- Modify: `docs/superpowers/specs/2026-07-13-wiki-integration-design.md` (status line only)

- [ ] Step 1: Update CLAUDE.md

In the keybindings table (localleader section), the wiki rows become:

```markdown
| `-wp` | Go to project wiki (todo.txt) |
| `-wc` | Create project wiki (todo.txt) |
| `-wl` | List project wiki status, `[stalled]` = no active task (todo.txt) |
| `-wt` | Show this project's active tasks (wiki project pages) |
| `-wa` | Capture a task for this project into todo.txt (wiki project pages) |
```

Add to the wiki section of CLAUDE.md (after the existing `-wl` behaviour description):

```markdown
### Two-way integration

- `-wt`/`-wa` are attached to buffers under `wiki_projects_dir` by a
  `BufEnter` autocmd registered in `plugin/todotxt.lua` (re-registered by
  `setup()`). The project tag is the filename stem.
- `-wa` appends `<today> <text> +tag` to the loaded todo buffer if one
  exists (left unsaved), else to the file on disk.
- Completing a `+project` task (`-x`, visual `-x`, `-X`) appends
  `- <date> x <task>` newest-first under `## Registro` in the project's
  page. No page, no journal — pages are never auto-created. Disable with
  `require("todotxt").setup({ wiki_journal = false })`.
- `-wl` lists the union of buffer tags and wiki pages; `[stalled]` marks
  projects with no active task (hidden/threshold tasks count as active).
```

Also update the Architecture tree in CLAUDE.md to include `plugin/todotxt.lua`.

- [ ] Step 2: Update the spec status

In `docs/superpowers/specs/2026-07-13-wiki-integration-design.md`, change `Status: design approved, pending spec review` to `Status: implemented`.

- [ ] Step 3: Run the full suite one final time

```bash
nvim --headless -u test/minimal_init.lua -c "PlenaryBustedDirectory test/lua/todotxt {minimal_init = 'test/minimal_init.lua'}" -c qa
```

Expected: PASS, 0 failures.

- [ ] Step 4: Commit

```bash
git add CLAUDE.md docs/superpowers/specs/2026-07-13-wiki-integration-design.md
git commit -m "docs: document two-way wiki integration keybindings and journal"
```
