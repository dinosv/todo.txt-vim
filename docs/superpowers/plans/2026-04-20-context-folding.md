# Context Folding Implementation Plan

> For agentic workers: REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

Goal: Extend the existing `foldexpr` so contiguous same-`@context` tasks form a single level-1 fold (toggleable with stock `za`) while completed and hidden tasks sit at level 2 (folded on open, as today).

Architecture: All logic lives inside `lua/todotxt/init.lua`. A new pure helper `M.category(line)` classifies each line into `(key, level)`. `M.fold_expr` uses it to emit fold levels, starting a new fold (`>level`) whenever the category key changes from the previous line. A second pure helper `M.fold_header` renders category-aware fold text. The ftplugin adds one line to set `vim.opt_local.foldlevel = 1` so level-1 context folds open on entry while level-2 completed/hidden folds stay closed.

Tech Stack: Lua (Neovim 0.7+), busted + plenary for testing.

Reference spec: `docs/superpowers/specs/2026-04-20-context-folding-design.md`.

---

## File Structure

- Modify: `lua/todotxt/init.lua` — add `M.category`, rewrite `M.fold_expr`, add `M.fold_header`, rewrite `M.fold_text`.
- Modify: `ftplugin/todo.lua` — add `vim.opt_local.foldlevel = 1`.
- Modify: `test/lua/todotxt/init_spec.lua` — add `describe` blocks for `category`, `fold_expr`, `fold_header`.

No new modules. No changes to `threshold.lua`, `dependency.lua`, `recurrence.lua`, `syntax/todo.vim`, or the autoload VimScript.

Why `M.category` and `M.fold_header` are public (not local as the spec hints): exposing them on `M` makes them unit-testable. The spec's "local helper" phrasing is not load-bearing — keeping the glue (`fold_expr`, `fold_text`) thin over public pure helpers is the cleaner path and matches how `sort_hidden_to_bottom` is already a public method on the init module.

## Running tests

From the project root:

```bash
nvim --headless -u test/minimal_init.lua -c "PlenaryBustedFile test/lua/todotxt/init_spec.lua" -c qa
```

For the whole suite:

```bash
nvim --headless -u test/minimal_init.lua -c "PlenaryBustedDirectory test/lua/todotxt {minimal_init = 'test/minimal_init.lua'}" -c qa
```

Expected: `Success || N successes / 0 failures / 0 errors / 0 pending`.

---

## Task 1: Add `M.category` helper

Files:
- Modify: `lua/todotxt/init.lua`
- Modify: `test/lua/todotxt/init_spec.lua`

- [ ] Step 1: Write the failing tests

Add the following `describe` block to `test/lua/todotxt/init_spec.lua` immediately after the `describe("setup", ...)` block, still inside the outer `describe("todotxt", function()`:

```lua
  describe("category", function()
    local dates = require("todotxt.dates")

    before_each(function()
      dates._original_today = dates.today
      dates.today = function() return "2026-04-20" end
    end)

    after_each(function()
      dates.today = dates._original_today
    end)

    it("returns nil key and level 0 for active task with no context", function()
      local key, level = todotxt.category("(A) 2026-04-20 plain task")
      assert.is_nil(key)
      assert.equals(0, level)
    end)

    it("returns @context key and level 1 for active task with one context", function()
      local key, level = todotxt.category("(A) 2026-04-20 task @UDD")
      assert.equals("@UDD", key)
      assert.equals(1, level)
    end)

    it("returns first @context when several are present", function()
      local key, level = todotxt.category("task @casa @work")
      assert.equals("@casa", key)
      assert.equals(1, level)
    end)

    it("returns completed key and level 2 for x-prefixed line", function()
      local key, level = todotxt.category("x 2026-04-19 done task @UDD")
      assert.equals("completed", key)
      assert.equals(2, level)
    end)

    it("returns hidden key and level 2 for h:1", function()
      local key, level = todotxt.category("(A) 2026-04-20 task @UDD h:1")
      assert.equals("hidden", key)
      assert.equals(2, level)
    end)

    it("returns hidden key and level 2 for future threshold", function()
      local key, level = todotxt.category("(A) 2026-04-20 task t:2026-05-01")
      assert.equals("hidden", key)
      assert.equals(2, level)
    end)

    it("treats t: in the past as not hidden", function()
      local key, level = todotxt.category("(A) 2026-04-20 task @UDD t:2026-04-01")
      assert.equals("@UDD", key)
      assert.equals(1, level)
    end)

    it("returns nil key and level 0 for empty line", function()
      local key, level = todotxt.category("")
      assert.is_nil(key)
      assert.equals(0, level)
    end)
  end)
```

- [ ] Step 2: Run the test and confirm it fails

```bash
nvim --headless -u test/minimal_init.lua -c "PlenaryBustedFile test/lua/todotxt/init_spec.lua" -c qa
```

Expected: failures with `attempt to call a nil value (method 'category')` or similar.

- [ ] Step 3: Implement `M.category`

Edit `lua/todotxt/init.lua`. Add the following function between `M.setup` and `M.fold_text`:

```lua
function M.category(line)
  if type(line) ~= "string" or line == "" then
    return nil, 0
  end

  if line:match("^[xX]%s") then
    return "completed", 2
  end

  if threshold.is_hidden(line) then
    return "hidden", 2
  end

  local ctx = line:match("%s@(%S+)") or line:match("^@(%S+)")
  if ctx then
    return "@" .. ctx, 1
  end

  return nil, 0
end
```

The `%s@` / `^@` split avoids matching `t:foo@bar`-style garbage inside other tag values.

- [ ] Step 4: Run the tests and confirm they pass

```bash
nvim --headless -u test/minimal_init.lua -c "PlenaryBustedFile test/lua/todotxt/init_spec.lua" -c qa
```

Expected: all `todotxt > category` specs pass; existing `mark_done` and `setup` specs still pass.

- [ ] Step 5: Commit

```bash
git add lua/todotxt/init.lua test/lua/todotxt/init_spec.lua
git commit -m "feat(fold): add category() helper for fold classification"
```

---

## Task 2: Rewrite `M.fold_expr` to use `category`

Files:
- Modify: `lua/todotxt/init.lua` — replace the existing `M.fold_expr` function (locate it by name; line numbers will have shifted after Task 1)
- Modify: `test/lua/todotxt/init_spec.lua`

Context: today's `fold_expr` returns `1` for every completed or hidden line and `0` for everything else. We rewrite it so the returned value depends on the current line's category AND whether that category key differs from the previous line's. When the key differs (or `lnum == 1`), return `">"..level` to start a new fold; otherwise return `level`. Active no-context tasks (`level == 0`) always return `0`.

- [ ] Step 1: Write the failing tests

Add this `describe` block after the `category` block, still inside the outer `describe("todotxt", ...)`:

```lua
  describe("fold_expr", function()
    local dates = require("todotxt.dates")
    local bufnr

    local function set_buffer(lines)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    end

    before_each(function()
      dates._original_today = dates.today
      dates.today = function() return "2026-04-20" end
      bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(bufnr)
      todotxt.setup({})
    end)

    after_each(function()
      dates.today = dates._original_today
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("returns 0 for a line with no category", function()
      set_buffer({ "(A) 2026-04-20 plain task" })
      assert.equals(0, todotxt.fold_expr(1))
    end)

    it("starts a level-1 fold on the first @context line", function()
      set_buffer({ "(A) task @UDD" })
      assert.equals(">1", todotxt.fold_expr(1))
    end)

    it("stays at level 1 for contiguous same-@context lines", function()
      set_buffer({
        "(A) task one @UDD",
        "(B) task two @UDD",
      })
      assert.equals(">1", todotxt.fold_expr(1))
      assert.equals(1,    todotxt.fold_expr(2))
    end)

    it("starts a new level-1 fold when @context changes", function()
      set_buffer({
        "(A) task one @UDD",
        "(B) task two @casa",
      })
      assert.equals(">1", todotxt.fold_expr(1))
      assert.equals(">1", todotxt.fold_expr(2))
    end)

    it("starts a level-2 fold for a completed line", function()
      set_buffer({ "x 2026-04-19 done task" })
      assert.equals(">2", todotxt.fold_expr(1))
    end)

    it("keeps contiguous completed lines in one level-2 fold", function()
      set_buffer({
        "x 2026-04-19 done one",
        "x 2026-04-18 done two",
      })
      assert.equals(">2", todotxt.fold_expr(1))
      assert.equals(2,    todotxt.fold_expr(2))
    end)

    it("separates completed and hidden into different level-2 folds", function()
      set_buffer({
        "x 2026-04-19 done one",
        "(A) 2026-04-20 task @UDD h:1",
      })
      assert.equals(">2", todotxt.fold_expr(1))
      assert.equals(">2", todotxt.fold_expr(2))
    end)

    it("drops to level 0 for a no-context line after a context fold", function()
      set_buffer({
        "(A) task @UDD",
        "(B) plain task",
      })
      assert.equals(">1", todotxt.fold_expr(1))
      assert.equals(0,    todotxt.fold_expr(2))
    end)

    it("falls back to completed-only folding when threshold_fold is false", function()
      todotxt.setup({ threshold_fold = false })
      set_buffer({
        "(A) task @UDD",
        "x 2026-04-19 done",
      })
      assert.equals(0, todotxt.fold_expr(1))
      assert.equals(1, todotxt.fold_expr(2))
    end)
  end)
```

- [ ] Step 2: Run the tests and confirm they fail

```bash
nvim --headless -u test/minimal_init.lua -c "PlenaryBustedFile test/lua/todotxt/init_spec.lua" -c qa
```

Expected: the context-aware specs fail (current `fold_expr` still returns `0` or `1` with no `>` prefix).

- [ ] Step 3: Rewrite `M.fold_expr`

Replace the existing `M.fold_expr` function in `lua/todotxt/init.lua` (locate by name) with:

```lua
function M.fold_expr(lnum)
  local line = vim.fn.getline(lnum)

  if not M.config.threshold_fold then
    -- Legacy fallback: only completed tasks fold, at level 1.
    if line:match("^[xX]%s") then
      return 1
    end
    return 0
  end

  local key, level = M.category(line)

  if level == 0 then
    return 0
  end

  if lnum == 1 then
    return ">" .. level
  end

  local prev_key, _ = M.category(vim.fn.getline(lnum - 1))
  if key ~= prev_key then
    return ">" .. level
  end

  return level
end
```

- [ ] Step 4: Run the tests and confirm they pass

```bash
nvim --headless -u test/minimal_init.lua -c "PlenaryBustedFile test/lua/todotxt/init_spec.lua" -c qa
```

Expected: every `fold_expr` spec passes; category and earlier specs still pass.

- [ ] Step 5: Commit

```bash
git add lua/todotxt/init.lua test/lua/todotxt/init_spec.lua
git commit -m "feat(fold): fold @context blocks at level 1, completed/hidden at level 2"
```

---

## Task 3: Add `M.fold_header` and rewrite `M.fold_text`

Files:
- Modify: `lua/todotxt/init.lua` — replace `M.fold_text` and add `M.fold_header` (locate by name)
- Modify: `test/lua/todotxt/init_spec.lua`

Context: today's `fold_text` hard-codes `"Completed tasks"` for every fold, which is already misleading for hidden folds. We factor the formatting into a pure `M.fold_header(first_line, count, dashes)` and keep `M.fold_text` as a thin adapter that reads `vim.v.foldstart / foldend / folddashes` and calls it.

- [ ] Step 1: Write the failing tests

Add this `describe` block after the `fold_expr` block:

```lua
  describe("fold_header", function()
    local dates = require("todotxt.dates")

    before_each(function()
      dates._original_today = dates.today
      dates.today = function() return "2026-04-20" end
    end)

    after_each(function()
      dates.today = dates._original_today
    end)

    it("formats a context fold with the @tag and count", function()
      local header = todotxt.fold_header("(A) task @UDD", 5, "--")
      assert.matches("^%+%-%- @UDD  5 tasks ", header)
    end)

    it("formats a completed fold", function()
      local header = todotxt.fold_header("x 2026-04-19 done", 3, "-")
      assert.equals("+- 3 completed tasks ", header)
    end)

    it("formats a hidden fold", function()
      local header = todotxt.fold_header("(A) task h:1", 2, "--")
      assert.equals("+-- 2 hidden tasks ", header)
    end)

    it("handles missing dashes gracefully", function()
      local header = todotxt.fold_header("(A) task @casa", 1, nil)
      assert.matches("@casa", header)
      assert.matches("1 tasks", header)
    end)
  end)
```

- [ ] Step 2: Run the tests and confirm they fail

```bash
nvim --headless -u test/minimal_init.lua -c "PlenaryBustedFile test/lua/todotxt/init_spec.lua" -c qa
```

Expected: `attempt to call a nil value (method 'fold_header')` failures.

- [ ] Step 3: Implement `M.fold_header` and rewrite `M.fold_text`

Replace the existing `M.fold_text` function in `lua/todotxt/init.lua` (lines 23-26) with:

```lua
function M.fold_header(first_line, count, dashes)
  dashes = dashes or ""
  local key, _ = M.category(first_line)

  if key == "completed" then
    return "+" .. dashes .. " " .. count .. " completed tasks "
  elseif key == "hidden" then
    return "+" .. dashes .. " " .. count .. " hidden tasks "
  elseif key and key:sub(1, 1) == "@" then
    return "+" .. dashes .. " " .. key .. "  " .. count .. " tasks "
  end

  return "+" .. dashes .. " " .. count .. " tasks "
end

function M.fold_text()
  local first_line = vim.fn.getline(vim.v.foldstart)
  local count = vim.v.foldend - vim.v.foldstart + 1
  return M.fold_header(first_line, count, vim.v.folddashes)
end
```

Note: the order matters. `M.fold_header` must be defined before `M.fold_text` references it, and both must appear after `M.category` (since `fold_header` calls `M.category`). If `M.category` is not yet defined in the file at this point (it should be, from Task 1), move the order so `M.category` → `M.fold_header` → `M.fold_text`.

- [ ] Step 4: Run the tests and confirm they pass

```bash
nvim --headless -u test/minimal_init.lua -c "PlenaryBustedFile test/lua/todotxt/init_spec.lua" -c qa
```

Expected: every `fold_header` spec passes; category and fold_expr specs still pass.

- [ ] Step 5: Commit

```bash
git add lua/todotxt/init.lua test/lua/todotxt/init_spec.lua
git commit -m "feat(fold): category-aware fold header text"
```

---

## Task 4: Wire `foldlevel = 1` in the ftplugin

Files:
- Modify: `ftplugin/todo.lua` — append `foldlevel` next to the existing `foldmethod` / `foldexpr` / `foldtext` block (locate those three lines)

Context: without this, level-1 context folds are closed on file open (users would see everything hidden). Setting buffer-local `foldlevel = 1` keeps level-1 open while level-2 (completed/hidden) stays folded — matching today's behaviour for completed/hidden and giving users the on-demand `za` for contexts.

- [ ] Step 1: Add the option

Edit `ftplugin/todo.lua`. Find the block:

```lua
vim.opt_local.foldmethod = "expr"
vim.opt_local.foldexpr = "v:lua.require('todotxt').fold_expr(v:lnum)"
vim.opt_local.foldtext = "v:lua.require('todotxt').fold_text()"
```

Add one line immediately after `foldtext`:

```lua
vim.opt_local.foldmethod = "expr"
vim.opt_local.foldexpr = "v:lua.require('todotxt').fold_expr(v:lnum)"
vim.opt_local.foldtext = "v:lua.require('todotxt').fold_text()"
vim.opt_local.foldlevel = 1
```

We deliberately do NOT set `foldlevelstart` here — it is a global option and setting it from an ftplugin would leak to every other buffer.

- [ ] Step 2: Manual smoke test in Neovim

Open `~/00000_DATA/00000_GITHUB/00000_SYNC/010_TODOTXT/todo.txt` in Neovim and verify:

1. On open, `@context` blocks are visible; completed and hidden blocks are folded (shown as collapsed lines with the fold header).
2. Run `-s@` to sort by context.
3. Place the cursor on any line inside a `@UDD` block. Press `za`. Only that block folds; other contexts stay open.
4. Press `za` again on the folded header — it reopens.
5. Press `zM` → all context blocks fold. Press `zr` once → contexts reopen, completed/hidden stay folded. Press `zR` → everything opens, including completed/hidden.
6. Fold headers show `+-- @UDD  N tasks`, `+-- N completed tasks`, `+-- N hidden tasks` as appropriate.
7. Lines without any `@context` (active) are never folded.
8. Temporarily add `require("todotxt").setup({ threshold_fold = false })` somewhere in your init, reopen — only completed lines fold, contexts don't. Revert the change.

Report any discrepancy; if all pass, continue.

- [ ] Step 3: Run the full test suite to confirm no regressions

```bash
nvim --headless -u test/minimal_init.lua -c "PlenaryBustedDirectory test/lua/todotxt {minimal_init = 'test/minimal_init.lua'}" -c qa
```

Expected: `Success || N successes / 0 failures / 0 errors / 0 pending` across every spec file.

- [ ] Step 4: Commit

```bash
git add ftplugin/todo.lua
git commit -m "feat(fold): open level-1 context folds on buffer entry"
```

---

## Task 5: Update CLAUDE.md to document the new fold behaviour

Files:
- Modify: `CLAUDE.md`

Context: the project-level `CLAUDE.md` describes the plugin's behaviour. The folding section currently only mentions completed/hidden folding indirectly. Adding a short note keeps future maintainers oriented.

- [ ] Step 1: Locate the folding description

In `CLAUDE.md`, find the table with `TodoHidden` and the description of `h:1`. Immediately after that paragraph, add a new short section:

```markdown
## Folding

`foldmethod=expr`, driven by `M.fold_expr` in `lua/todotxt/init.lua`:

- Level 1: active tasks with an `@context`. Contiguous same-context tasks share one fold. Open on buffer entry; toggle with `za`.
- Level 2: completed (`x `) and hidden (`h:1`, future `t:`) tasks. Folded on buffer entry.
- Level 0: active tasks with no `@context`. Never folded.

Buffer-local `foldlevel = 1` is set in `ftplugin/todo.lua` so level-1 opens on entry while level-2 stays closed. `foldlevelstart` is global and deliberately not touched.

The `-s@` sort groups same-context tasks into contiguous blocks, which is the workflow this folding is designed around.
```

- [ ] Step 2: Verify the file renders cleanly

```bash
head -200 CLAUDE.md
```

No tool check required — just confirm the new section appears in a sensible place (near the existing highlight-group table).

- [ ] Step 3: Commit

```bash
git add CLAUDE.md
git commit -m "docs: describe fold levels for @context, completed, hidden tasks"
```

---

## Self-review notes

- Spec coverage:
  - Fold-level model (spec §"Fold-level model") → Task 1 (category) + Task 2 (fold_expr).
  - Category keys, including first-@context-wins → Task 1.
  - Legacy `threshold_fold = false` path → Task 2, dedicated test case.
  - Fold text per category → Task 3.
  - Buffer-local `foldlevel = 1`, no `foldlevelstart` → Task 4.
  - Documentation alignment → Task 5.
- No placeholders, no "similar to Task N" references.
- Signatures are consistent across tasks: `M.category(line) -> (key, level)`, `M.fold_header(first_line, count, dashes) -> string`, `M.fold_expr(lnum) -> number|string`, `M.fold_text() -> string`.
- Task ordering: category (pure) → fold_expr (depends on category) → fold_header/fold_text (depends on category) → ftplugin glue → docs. Each task ends green and committed before the next starts.
