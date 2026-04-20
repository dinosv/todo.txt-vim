# Task Dependencies Implementation Plan

> For agentic workers: REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

Goal: Add an id:/pending: task-dependency system that mutates dependent lines to carry `wf:1` and `(D)` (when no priority is set) while blockers remain active, and flips `wf:1` to `wf:0` when all blockers resolve.

Architecture: One new pure-function module (`lua/todotxt/dependency.lua`), one busted spec file (`test/lua/todotxt/dependency_spec.lua`), and one small addition to `ftplugin/todo.lua` that wires a BufEnter + TextChanged autocmd to drive the transform. Reuses `set_tag` from `recurrence.lua` to avoid re-implementing tag rewriting. Pure functions carry 100% of the logic; the ftplugin glue is a thin orchestrator with a re-entry guard.

Tech Stack: Lua (Neovim 0.7+), busted + plenary for testing.

Reference spec: `docs/superpowers/specs/2026-04-20-task-dependencies-design.md`.

---

## File Structure

- Create: `lua/todotxt/dependency.lua` — pure functions: `parse_id`, `parse_pending`, `is_active`, `collect_active_ids`, `is_blocked`, `apply_blocked`, `apply_unblocked`, `transform_line`. No side effects, no buffer access.
- Create: `test/lua/todotxt/dependency_spec.lua` — busted `describe`/`it` specs mirroring the style of `threshold_spec.lua` and `recurrence_spec.lua`.
- Modify: `ftplugin/todo.lua` — add local `update_pending` function and a new autocmd registration under the existing `TodotxtBuf_<bufnr>` group for `BufEnter` + `TextChanged`.

No changes to `lua/todotxt/init.lua`, `autoload/todo/txt.vim`, or `syntax/todo.vim`. The existing `TodoWaitingFor` highlight already targets `wf:1` specifically, so `wf:0` lines correctly fall out of the highlight without any syntax edit.

## Running tests

From the project root:

```bash
nvim --headless -u test/minimal_init.lua -c "PlenaryBustedFile test/lua/todotxt/dependency_spec.lua" -c qa
```

For the whole suite:

```bash
nvim --headless -u test/minimal_init.lua -c "PlenaryBustedDirectory test/lua/todotxt {minimal_init = 'test/minimal_init.lua'}" -c qa
```

Expected output: `Success || N successes / 0 failures / 0 errors / 0 pending`.

---

## Task 1: Scaffold the dependency module

Files:
- Create: `lua/todotxt/dependency.lua`
- Create: `test/lua/todotxt/dependency_spec.lua`

- [ ] Step 1: Write the failing test

Create `test/lua/todotxt/dependency_spec.lua`:

```lua
describe("todotxt.dependency", function()
  local dependency = require("todotxt.dependency")

  it("loads as a module", function()
    assert.is_table(dependency)
  end)
end)
```

- [ ] Step 2: Run test and confirm it fails

```bash
nvim --headless -u test/minimal_init.lua -c "PlenaryBustedFile test/lua/todotxt/dependency_spec.lua" -c qa
```

Expected: failure with `module 'todotxt.dependency' not found`.

- [ ] Step 3: Create the empty module

Create `lua/todotxt/dependency.lua`:

```lua
local M = {}

return M
```

- [ ] Step 4: Run test and confirm it passes

Same command as step 2. Expected: `1 success / 0 failures`.

- [ ] Step 5: Commit

```bash
git add lua/todotxt/dependency.lua test/lua/todotxt/dependency_spec.lua
git commit -m "feat(deps): scaffold dependency module and spec"
```

---

## Task 2: parse_id

Files:
- Modify: `lua/todotxt/dependency.lua`
- Modify: `test/lua/todotxt/dependency_spec.lua`

`parse_id(line)` returns the string value of the first `id:` tag found on a line, or `nil` if absent. Pads the line with a leading space so an `id:` at line start also matches (same trick as `threshold.is_hidden`).

- [ ] Step 1: Write the failing test

Add to `test/lua/todotxt/dependency_spec.lua` (inside the top-level `describe` block, after the module-loads test):

```lua
  describe("parse_id", function()
    it("extracts id from middle of line", function()
      assert.equals("42", dependency.parse_id("task id:42 more"))
    end)

    it("extracts id at line start", function()
      assert.equals("42", dependency.parse_id("id:42 task"))
    end)

    it("extracts id at line end", function()
      assert.equals("42", dependency.parse_id("task id:42"))
    end)

    it("returns nil when id tag absent", function()
      assert.is_nil(dependency.parse_id("task without id"))
    end)

    it("accepts non-numeric id values", function()
      assert.equals("abc", dependency.parse_id("task id:abc"))
    end)
  end)
```

- [ ] Step 2: Run test and confirm it fails

```bash
nvim --headless -u test/minimal_init.lua -c "PlenaryBustedFile test/lua/todotxt/dependency_spec.lua" -c qa
```

Expected: failures on the five new cases (function is nil).

- [ ] Step 3: Implement `parse_id`

Edit `lua/todotxt/dependency.lua`:

```lua
local M = {}

function M.parse_id(line)
  local padded = " " .. line
  return padded:match("%sid:(%S+)")
end

return M
```

- [ ] Step 4: Run test and confirm it passes

Same command. Expected: 6 successes (including the module-loads test).

- [ ] Step 5: Commit

```bash
git add lua/todotxt/dependency.lua test/lua/todotxt/dependency_spec.lua
git commit -m "feat(deps): parse_id extracts id:N tag from a line"
```

---

## Task 3: parse_pending

Files:
- Modify: `lua/todotxt/dependency.lua`
- Modify: `test/lua/todotxt/dependency_spec.lua`

`parse_pending(line)` returns a list (possibly empty) of blocker IDs extracted from the first `pending:` tag, splitting on commas.

- [ ] Step 1: Write the failing test

Add to the spec file after the `parse_id` describe block:

```lua
  describe("parse_pending", function()
    it("extracts single id", function()
      assert.are.same({"42"}, dependency.parse_pending("task pending:42"))
    end)

    it("extracts comma-separated ids", function()
      assert.are.same({"42", "43", "7"}, dependency.parse_pending("task pending:42,43,7"))
    end)

    it("returns empty list when tag absent", function()
      assert.are.same({}, dependency.parse_pending("task without pending"))
    end)

    it("returns empty list for empty pending value", function()
      assert.are.same({}, dependency.parse_pending("task pending:"))
    end)

    it("matches only the first pending tag", function()
      assert.are.same({"42"}, dependency.parse_pending("task pending:42 pending:43"))
    end)
  end)
```

- [ ] Step 2: Run test and confirm it fails

Same command. Expected: 5 new failures.

- [ ] Step 3: Implement `parse_pending`

Append to `lua/todotxt/dependency.lua` (before `return M`):

```lua
function M.parse_pending(line)
  local padded = " " .. line
  local value = padded:match("%spending:(%S+)")
  if not value then return {} end
  local ids = {}
  for id in value:gmatch("([^,]+)") do
    table.insert(ids, id)
  end
  return ids
end
```

- [ ] Step 4: Run test and confirm it passes

Same command. Expected: 11 successes total.

- [ ] Step 5: Commit

```bash
git add lua/todotxt/dependency.lua test/lua/todotxt/dependency_spec.lua
git commit -m "feat(deps): parse_pending splits pending:N,M,... into id list"
```

---

## Task 4: is_active

Files:
- Modify: `lua/todotxt/dependency.lua`
- Modify: `test/lua/todotxt/dependency_spec.lua`

`is_active(line)` returns `true` iff the line is neither empty nor completed (does not start with `x ` or `X `).

- [ ] Step 1: Write the failing test

Add after the `parse_pending` describe block:

```lua
  describe("is_active", function()
    it("returns true for a normal task", function()
      assert.is_true(dependency.is_active("(A) task"))
    end)

    it("returns false for a completed task", function()
      assert.is_false(dependency.is_active("x 2026-01-01 task"))
    end)

    it("returns false for an uppercase X completed task", function()
      assert.is_false(dependency.is_active("X 2026-01-01 task"))
    end)

    it("returns false for an empty line", function()
      assert.is_false(dependency.is_active(""))
    end)

    it("returns true for a line that merely contains 'x'", function()
      assert.is_true(dependency.is_active("fix the xray machine"))
    end)
  end)
```

- [ ] Step 2: Run test and confirm it fails

Same command. Expected: 5 new failures.

- [ ] Step 3: Implement `is_active`

Append to `lua/todotxt/dependency.lua` (before `return M`):

```lua
function M.is_active(line)
  if line == nil or line == "" then return false end
  if line:match("^[xX]%s") then return false end
  return true
end
```

- [ ] Step 4: Run test and confirm it passes

Same command. Expected: 16 successes total.

- [ ] Step 5: Commit

```bash
git add lua/todotxt/dependency.lua test/lua/todotxt/dependency_spec.lua
git commit -m "feat(deps): is_active detects non-empty, non-completed lines"
```

---

## Task 5: collect_active_ids

Files:
- Modify: `lua/todotxt/dependency.lua`
- Modify: `test/lua/todotxt/dependency_spec.lua`

`collect_active_ids(lines)` walks a list of lines and returns a set (Lua table `{[id]=true}`) of IDs appearing on active lines.

- [ ] Step 1: Write the failing test

Add after the `is_active` describe block:

```lua
  describe("collect_active_ids", function()
    it("collects ids from active lines", function()
      local lines = {"(A) task id:1", "(B) task id:2", "task without id"}
      local ids = dependency.collect_active_ids(lines)
      assert.is_true(ids["1"])
      assert.is_true(ids["2"])
    end)

    it("ignores ids on completed lines", function()
      local lines = {"x 2026-01-01 done id:1", "(A) active id:2"}
      local ids = dependency.collect_active_ids(lines)
      assert.is_nil(ids["1"])
      assert.is_true(ids["2"])
    end)

    it("ignores empty lines", function()
      local lines = {"", "(A) active id:1"}
      local ids = dependency.collect_active_ids(lines)
      assert.is_true(ids["1"])
    end)

    it("returns empty table when no ids present", function()
      local lines = {"(A) task one", "(B) task two"}
      local ids = dependency.collect_active_ids(lines)
      assert.are.same({}, ids)
    end)
  end)
```

- [ ] Step 2: Run test and confirm it fails

Same command. Expected: 4 new failures.

- [ ] Step 3: Implement `collect_active_ids`

Append to `lua/todotxt/dependency.lua` (before `return M`):

```lua
function M.collect_active_ids(lines)
  local set = {}
  for _, line in ipairs(lines) do
    if M.is_active(line) then
      local id = M.parse_id(line)
      if id then set[id] = true end
    end
  end
  return set
end
```

- [ ] Step 4: Run test and confirm it passes

Same command. Expected: 20 successes total.

- [ ] Step 5: Commit

```bash
git add lua/todotxt/dependency.lua test/lua/todotxt/dependency_spec.lua
git commit -m "feat(deps): collect_active_ids scans buffer for live blocker ids"
```

---

## Task 6: is_blocked

Files:
- Modify: `lua/todotxt/dependency.lua`
- Modify: `test/lua/todotxt/dependency_spec.lua`

`is_blocked(line, active_ids)` returns `true` iff the line has a `pending:` tag with at least one id that is still in `active_ids`. Missing ids (not in the set) are treated as resolved (fail-open per spec).

- [ ] Step 1: Write the failing test

Add after the `collect_active_ids` describe block:

```lua
  describe("is_blocked", function()
    it("returns true when a pending id is active", function()
      local active = {["42"] = true}
      assert.is_true(dependency.is_blocked("task pending:42", active))
    end)

    it("returns false when all pending ids are resolved", function()
      local active = {}
      assert.is_false(dependency.is_blocked("task pending:42", active))
    end)

    it("returns true when at least one of several pending ids is active", function()
      local active = {["43"] = true}
      assert.is_true(dependency.is_blocked("task pending:42,43", active))
    end)

    it("returns false when no pending tag present", function()
      local active = {["42"] = true}
      assert.is_false(dependency.is_blocked("task without pending", active))
    end)

    it("fails open on missing id (not in active_ids)", function()
      local active = {}
      assert.is_false(dependency.is_blocked("task pending:99", active))
    end)
  end)
```

- [ ] Step 2: Run test and confirm it fails

Same command. Expected: 5 new failures.

- [ ] Step 3: Implement `is_blocked`

Append to `lua/todotxt/dependency.lua` (before `return M`):

```lua
function M.is_blocked(line, active_ids)
  local pending = M.parse_pending(line)
  for _, id in ipairs(pending) do
    if active_ids[id] then return true end
  end
  return false
end
```

- [ ] Step 4: Run test and confirm it passes

Same command. Expected: 25 successes total.

- [ ] Step 5: Commit

```bash
git add lua/todotxt/dependency.lua test/lua/todotxt/dependency_spec.lua
git commit -m "feat(deps): is_blocked checks pending ids against active set"
```

---

## Task 7: apply_blocked

Files:
- Modify: `lua/todotxt/dependency.lua`
- Modify: `test/lua/todotxt/dependency_spec.lua`

`apply_blocked(line)` ensures the line carries `wf:1` (replacing any existing `wf:` value via `set_tag`) and, only when no priority is set, prepends `(D) `. Does not otherwise modify the line.

- [ ] Step 1: Write the failing test

Add after the `is_blocked` describe block:

```lua
  describe("apply_blocked", function()
    it("adds wf:1 and (D) to a bare line", function()
      assert.equals("(D) task pending:42 wf:1", dependency.apply_blocked("task pending:42"))
    end)

    it("flips wf:0 to wf:1 without duplicating", function()
      assert.equals("(D) task pending:42 wf:1 more", dependency.apply_blocked("task pending:42 wf:0 more"))
    end)

    it("keeps existing priority instead of prepending (D)", function()
      assert.equals("(A) task pending:42 wf:1", dependency.apply_blocked("(A) task pending:42"))
    end)

    it("is idempotent on an already-blocked line", function()
      local once = dependency.apply_blocked("task pending:42")
      local twice = dependency.apply_blocked(once)
      assert.equals(once, twice)
    end)
  end)
```

- [ ] Step 2: Run test and confirm it fails

Same command. Expected: 4 new failures.

- [ ] Step 3: Implement `apply_blocked`

Append to `lua/todotxt/dependency.lua` (before `return M`, after inserting the `recurrence` require at the top of the file):

First, at the very top of the file (just after `local M = {}`), add:

```lua
local recurrence = require("todotxt.recurrence")
```

Then add the function:

```lua
function M.apply_blocked(line)
  local new_line = recurrence.set_tag(line, "wf", "1")
  if not new_line:match("^%(%a%)") then
    new_line = "(D) " .. new_line
  end
  return new_line
end
```

- [ ] Step 4: Run test and confirm it passes

Same command. Expected: 29 successes total.

- [ ] Step 5: Commit

```bash
git add lua/todotxt/dependency.lua test/lua/todotxt/dependency_spec.lua
git commit -m "feat(deps): apply_blocked stamps wf:1 and optional (D)"
```

---

## Task 8: apply_unblocked

Files:
- Modify: `lua/todotxt/dependency.lua`
- Modify: `test/lua/todotxt/dependency_spec.lua`

`apply_unblocked(line)` flips `wf:1` to `wf:0` only if `wf:1` is present on the line; otherwise returns the line unchanged. Priority is not touched. `wf:0` is never added to a line that didn't already have `wf:`.

- [ ] Step 1: Write the failing test

Add after the `apply_blocked` describe block:

```lua
  describe("apply_unblocked", function()
    it("flips wf:1 to wf:0", function()
      assert.equals("task pending:42 wf:0", dependency.apply_unblocked("task pending:42 wf:1"))
    end)

    it("flips wf:1 at line end", function()
      assert.equals("(D) task wf:0", dependency.apply_unblocked("(D) task wf:1"))
    end)

    it("leaves a line without wf: untouched", function()
      assert.equals("task pending:42", dependency.apply_unblocked("task pending:42"))
    end)

    it("leaves priority untouched", function()
      assert.equals("(A) task pending:42 wf:0", dependency.apply_unblocked("(A) task pending:42 wf:1"))
    end)

    it("is idempotent on an already-unblocked line", function()
      local once = dependency.apply_unblocked("task pending:42 wf:1")
      local twice = dependency.apply_unblocked(once)
      assert.equals(once, twice)
    end)
  end)
```

- [ ] Step 2: Run test and confirm it fails

Same command. Expected: 5 new failures.

- [ ] Step 3: Implement `apply_unblocked`

Append to `lua/todotxt/dependency.lua` (before `return M`):

```lua
function M.apply_unblocked(line)
  local padded = " " .. line
  if padded:match("%swf:1%s") or padded:match("%swf:1$") then
    return recurrence.set_tag(line, "wf", "0")
  end
  return line
end
```

- [ ] Step 4: Run test and confirm it passes

Same command. Expected: 34 successes total.

- [ ] Step 5: Commit

```bash
git add lua/todotxt/dependency.lua test/lua/todotxt/dependency_spec.lua
git commit -m "feat(deps): apply_unblocked flips wf:1 to wf:0 in place"
```

---

## Task 9: transform_line

Files:
- Modify: `lua/todotxt/dependency.lua`
- Modify: `test/lua/todotxt/dependency_spec.lua`

`transform_line(line, active_ids)` is the dispatcher: skip if the line is inactive or has no `pending:` tag; otherwise call `apply_blocked` or `apply_unblocked` based on `is_blocked`.

- [ ] Step 1: Write the failing test

Add after the `apply_unblocked` describe block:

```lua
  describe("transform_line", function()
    it("blocks a dependent whose blocker is active", function()
      local active = {["42"] = true}
      assert.equals("(D) task pending:42 wf:1", dependency.transform_line("task pending:42", active))
    end)

    it("unblocks a dependent whose blocker is resolved", function()
      local active = {}
      assert.equals("(D) task pending:42 wf:0", dependency.transform_line("(D) task pending:42 wf:1", active))
    end)

    it("does not touch lines without pending", function()
      local active = {["42"] = true}
      assert.equals("(A) task wf:1", dependency.transform_line("(A) task wf:1", active))
    end)

    it("does not touch completed lines", function()
      local active = {["42"] = true}
      assert.equals("x 2026-01-01 old pending:42", dependency.transform_line("x 2026-01-01 old pending:42", active))
    end)

    it("does not touch empty lines", function()
      local active = {}
      assert.equals("", dependency.transform_line("", active))
    end)
  end)
```

- [ ] Step 2: Run test and confirm it fails

Same command. Expected: 5 new failures.

- [ ] Step 3: Implement `transform_line`

Append to `lua/todotxt/dependency.lua` (before `return M`):

```lua
function M.transform_line(line, active_ids)
  if not M.is_active(line) then return line end
  local pending = M.parse_pending(line)
  if #pending == 0 then return line end
  if M.is_blocked(line, active_ids) then
    return M.apply_blocked(line)
  else
    return M.apply_unblocked(line)
  end
end
```

- [ ] Step 4: Run test and confirm it passes

Same command. Expected: 39 successes total.

- [ ] Step 5: Commit

```bash
git add lua/todotxt/dependency.lua test/lua/todotxt/dependency_spec.lua
git commit -m "feat(deps): transform_line dispatches blocked/unblocked"
```

---

## Task 10: wire autocmd into ftplugin

Files:
- Modify: `ftplugin/todo.lua`

Add an `update_pending` local function and register it against `BufEnter` and `TextChanged` under the existing `TodotxtBuf_<bufnr>` augroup. Re-entry guard prevents infinite recursion from `nvim_buf_set_lines` retriggering `TextChanged`.

- [ ] Step 1: Read the current ftplugin to identify the insertion point

Target location: after the existing `update_highlights` autocmd registration (around line 130 in the current file, right before `update_highlights()` is called).

- [ ] Step 2: Add the `update_pending` function and its autocmd

Edit `ftplugin/todo.lua`. Near the top, alongside `local threshold = require("todotxt.threshold")`, add:

```lua
local dependency = require("todotxt.dependency")
```

Then, after the `update_highlights` function is defined but before its `nvim_create_autocmd` registration block, add the new local function:

```lua
local updating_pending = false

local function update_pending()
  if updating_pending then return end
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local active_ids = dependency.collect_active_ids(lines)
  local new_lines = {}
  local changed = false
  for _, line in ipairs(lines) do
    local new_line = dependency.transform_line(line, active_ids)
    if new_line ~= line then
      changed = true
    end
    table.insert(new_lines, new_line)
  end
  if changed then
    updating_pending = true
    vim.api.nvim_buf_set_lines(0, 0, -1, false, new_lines)
    updating_pending = false
  end
end
```

After the existing `vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "TextChangedI" }, { ... callback = update_highlights ... })` block, add:

```lua
vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged" }, {
  group = buf_group,
  buffer = bufnr,
  callback = update_pending,
})
```

And after the existing `update_highlights()` initial call, add:

```lua
update_pending()
```

- [ ] Step 3: Reload the buffer and verify no errors at load time

Open a todo.txt file in Neovim and confirm no error message appears:

```bash
nvim ~/00000_DATA/00000_GITHUB/00000_SYNC/010_TODOTXT/todo.txt
```

Then in Neovim: `:messages` — should be clean of Lua errors.

- [ ] Step 4: Manual smoke test

In the buffer, add these two lines:

```
(A) 2026-04-20 +test draft the protocol id:999
2026-04-20 +test circulate the draft pending:999
```

Expected after the buffer update fires (leave insert mode):
- First line unchanged.
- Second line becomes: `(D) 2026-04-20 +test circulate the draft pending:999 wf:1`
- Second line should take on the `TodoWaitingFor` (cyan/DiagnosticWarn) highlight.

Then mark the first line done with `-x`. Expected: second line becomes `(D) 2026-04-20 +test circulate the draft pending:999 wf:0` and loses the cyan highlight.

Then delete both test lines.

- [ ] Step 5: Commit

```bash
git add ftplugin/todo.lua
git commit -m "feat(deps): wire dependency autocmd into ftplugin"
```

---

## Task 11: Full suite sanity check

- [ ] Step 1: Run the entire test directory

```bash
nvim --headless -u test/minimal_init.lua -c "PlenaryBustedDirectory test/lua/todotxt {minimal_init = 'test/minimal_init.lua'}" -c qa
```

Expected: all specs pass (existing specs untouched, new `dependency_spec.lua` fully green).

- [ ] Step 2: If any unrelated spec fails, investigate

Do not modify unrelated code. If a failure pre-dates this work (verify by `git stash` + rerun), flag it to the user rather than patching.

- [ ] Step 3: Update CLAUDE.md to document the new tags

Edit `CLAUDE.md` — in the "Task format" section, extend the example line and table to mention `id:N` and `pending:N,M,...`. Keep it concise; one row per tag.

Example addition to the existing task format example:

```
(A) 2026-02-17 +project_tag task description @context due:2026-03-01 t:2026-02-20 rec:+1w wf:1 h:1 id:42 pending:43
```

Add to the descriptive bullet list:

```
- `id:N`: Task identifier, used as a dependency anchor. User-assigned.
- `pending:N,M,...`: Task blocked until all listed ids refer to lines that are either completed (`x ...`) or absent. While any blocker remains active, the plugin stamps `wf:1` and `(D)` (if no priority). On resolution, `wf:1` flips to `wf:0`; priority is not changed. See `lua/todotxt/dependency.lua`.
```

- [ ] Step 4: Commit

```bash
git add CLAUDE.md
git commit -m "docs: document id: and pending: dependency tags in CLAUDE.md"
```
