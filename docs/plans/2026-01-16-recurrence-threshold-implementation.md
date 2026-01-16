# Recurring Tasks and Threshold Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add recurring task and threshold/hidden task support to todo.txt-vim using Neovim Lua.

**Architecture:** Lua modules in `lua/todotxt/` provide date arithmetic, recurrence parsing, and hidden task detection. Buffer-local setup in `ftplugin/todo.lua` overrides mappings when Neovim detected. Existing Vimscript untouched for Vim compatibility.

**Tech Stack:** Neovim Lua, plenary.nvim (testing)

---

### Task 1: Date Arithmetic Module

**Files:**
- Create: `lua/todotxt/dates.lua`
- Create: `test/lua/todotxt/dates_spec.lua`

**Step 1: Create test directory and spec file with first test**

```lua
-- test/lua/todotxt/dates_spec.lua
describe("todotxt.dates", function()
  local dates = require("todotxt.dates")

  describe("today", function()
    it("returns current date in YYYY-MM-DD format", function()
      local result = dates.today()
      assert.matches("^%d%d%d%d%-%d%d%-%d%d$", result)
    end)
  end)
end)
```

**Step 2: Run test to verify it fails**

Run: `nvim --headless -c "PlenaryBustedDirectory test/lua/todotxt/ {minimal_init = 'test/minimal_init.lua'}"`

Expected: FAIL - module not found

**Step 3: Create minimal init for tests**

```lua
-- test/minimal_init.lua
vim.opt.runtimepath:append(".")
vim.opt.runtimepath:append("~/.local/share/nvim/site/pack/packer/start/plenary.nvim")
```

**Step 4: Create dates module with today()**

```lua
-- lua/todotxt/dates.lua
local M = {}

function M.today()
  return os.date("%Y-%m-%d")
end

return M
```

**Step 5: Run test to verify it passes**

Run: `nvim --headless -c "PlenaryBustedDirectory test/lua/todotxt/ {minimal_init = 'test/minimal_init.lua'}"`

Expected: PASS

**Step 6: Commit**

```bash
git add lua/todotxt/dates.lua test/lua/todotxt/dates_spec.lua test/minimal_init.lua
git commit -m "feat(dates): add today() function"
```

---

### Task 2: Date Comparison

**Files:**
- Modify: `lua/todotxt/dates.lua`
- Modify: `test/lua/todotxt/dates_spec.lua`

**Step 1: Add comparison test**

```lua
-- Add to test/lua/todotxt/dates_spec.lua
describe("is_future", function()
  it("returns true for future dates", function()
    assert.is_true(dates.is_future("2099-12-31"))
  end)

  it("returns false for past dates", function()
    assert.is_false(dates.is_future("2000-01-01"))
  end)

  it("returns false for today", function()
    assert.is_false(dates.is_future(dates.today()))
  end)
end)
```

**Step 2: Run test to verify it fails**

Run: `nvim --headless -c "PlenaryBustedDirectory test/lua/todotxt/ {minimal_init = 'test/minimal_init.lua'}"`

Expected: FAIL - is_future not defined

**Step 3: Implement is_future()**

```lua
-- Add to lua/todotxt/dates.lua
function M.is_future(date_str)
  return date_str > M.today()
end
```

**Step 4: Run test to verify it passes**

Expected: PASS

**Step 5: Commit**

```bash
git add lua/todotxt/dates.lua test/lua/todotxt/dates_spec.lua
git commit -m "feat(dates): add is_future() comparison"
```

---

### Task 3: Parse Date String to Components

**Files:**
- Modify: `lua/todotxt/dates.lua`
- Modify: `test/lua/todotxt/dates_spec.lua`

**Step 1: Add parse test**

```lua
-- Add to test/lua/todotxt/dates_spec.lua
describe("parse", function()
  it("parses YYYY-MM-DD to components", function()
    local y, m, d = dates.parse("2025-03-15")
    assert.equals(2025, y)
    assert.equals(3, m)
    assert.equals(15, d)
  end)

  it("returns nil for invalid format", function()
    local y, m, d = dates.parse("invalid")
    assert.is_nil(y)
  end)
end)
```

**Step 2: Run test to verify it fails**

Expected: FAIL

**Step 3: Implement parse()**

```lua
-- Add to lua/todotxt/dates.lua
function M.parse(date_str)
  local y, m, d = date_str:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
  if y then
    return tonumber(y), tonumber(m), tonumber(d)
  end
  return nil, nil, nil
end
```

**Step 4: Run test to verify it passes**

Expected: PASS

**Step 5: Commit**

```bash
git add lua/todotxt/dates.lua test/lua/todotxt/dates_spec.lua
git commit -m "feat(dates): add parse() for date components"
```

---

### Task 4: Format Date Components to String

**Files:**
- Modify: `lua/todotxt/dates.lua`
- Modify: `test/lua/todotxt/dates_spec.lua`

**Step 1: Add format test**

```lua
-- Add to test/lua/todotxt/dates_spec.lua
describe("format", function()
  it("formats components to YYYY-MM-DD", function()
    assert.equals("2025-03-15", dates.format(2025, 3, 15))
  end)

  it("zero-pads single digit month and day", function()
    assert.equals("2025-01-05", dates.format(2025, 1, 5))
  end)
end)
```

**Step 2: Run test to verify it fails**

Expected: FAIL

**Step 3: Implement format()**

```lua
-- Add to lua/todotxt/dates.lua
function M.format(year, month, day)
  return string.format("%04d-%02d-%02d", year, month, day)
end
```

**Step 4: Run test to verify it passes**

Expected: PASS

**Step 5: Commit**

```bash
git add lua/todotxt/dates.lua test/lua/todotxt/dates_spec.lua
git commit -m "feat(dates): add format() for date string output"
```

---

### Task 5: Add Days

**Files:**
- Modify: `lua/todotxt/dates.lua`
- Modify: `test/lua/todotxt/dates_spec.lua`

**Step 1: Add test for adding days**

```lua
-- Add to test/lua/todotxt/dates_spec.lua
describe("add_days", function()
  it("adds days within same month", function()
    assert.equals("2025-01-15", dates.add_days("2025-01-10", 5))
  end)

  it("rolls over to next month", function()
    assert.equals("2025-02-02", dates.add_days("2025-01-30", 3))
  end)

  it("rolls over year", function()
    assert.equals("2026-01-01", dates.add_days("2025-12-31", 1))
  end)
end)
```

**Step 2: Run test to verify it fails**

Expected: FAIL

**Step 3: Implement add_days()**

```lua
-- Add to lua/todotxt/dates.lua
function M.add_days(date_str, days)
  local y, m, d = M.parse(date_str)
  if not y then return nil end
  local time = os.time({ year = y, month = m, day = d })
  local new_time = time + (days * 86400)
  return os.date("%Y-%m-%d", new_time)
end
```

**Step 4: Run test to verify it passes**

Expected: PASS

**Step 5: Commit**

```bash
git add lua/todotxt/dates.lua test/lua/todotxt/dates_spec.lua
git commit -m "feat(dates): add add_days() function"
```

---

### Task 6: Add Weeks

**Files:**
- Modify: `lua/todotxt/dates.lua`
- Modify: `test/lua/todotxt/dates_spec.lua`

**Step 1: Add test for adding weeks**

```lua
-- Add to test/lua/todotxt/dates_spec.lua
describe("add_weeks", function()
  it("adds weeks", function()
    assert.equals("2025-01-22", dates.add_weeks("2025-01-15", 1))
  end)

  it("adds multiple weeks", function()
    assert.equals("2025-02-12", dates.add_weeks("2025-01-15", 4))
  end)
end)
```

**Step 2: Run test to verify it fails**

Expected: FAIL

**Step 3: Implement add_weeks()**

```lua
-- Add to lua/todotxt/dates.lua
function M.add_weeks(date_str, weeks)
  return M.add_days(date_str, weeks * 7)
end
```

**Step 4: Run test to verify it passes**

Expected: PASS

**Step 5: Commit**

```bash
git add lua/todotxt/dates.lua test/lua/todotxt/dates_spec.lua
git commit -m "feat(dates): add add_weeks() function"
```

---

### Task 7: Add Months with Edge Cases

**Files:**
- Modify: `lua/todotxt/dates.lua`
- Modify: `test/lua/todotxt/dates_spec.lua`

**Step 1: Add test for adding months**

```lua
-- Add to test/lua/todotxt/dates_spec.lua
describe("add_months", function()
  it("adds months within same year", function()
    assert.equals("2025-04-15", dates.add_months("2025-01-15", 3))
  end)

  it("rolls over to next year", function()
    assert.equals("2026-02-15", dates.add_months("2025-11-15", 3))
  end)

  it("clamps to last day of shorter month", function()
    assert.equals("2025-02-28", dates.add_months("2025-01-31", 1))
  end)

  it("handles leap year February", function()
    assert.equals("2024-02-29", dates.add_months("2024-01-31", 1))
  end)

  it("handles December to January", function()
    assert.equals("2026-01-15", dates.add_months("2025-12-15", 1))
  end)
end)
```

**Step 2: Run test to verify it fails**

Expected: FAIL

**Step 3: Implement add_months()**

```lua
-- Add to lua/todotxt/dates.lua
local function days_in_month(year, month)
  local days = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
  if month == 2 then
    local is_leap = (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0)
    return is_leap and 29 or 28
  end
  return days[month]
end

function M.add_months(date_str, months)
  local y, m, d = M.parse(date_str)
  if not y then return nil end

  m = m + months
  while m > 12 do
    m = m - 12
    y = y + 1
  end
  while m < 1 do
    m = m + 12
    y = y - 1
  end

  local max_day = days_in_month(y, m)
  d = math.min(d, max_day)

  return M.format(y, m, d)
end
```

**Step 4: Run test to verify it passes**

Expected: PASS

**Step 5: Commit**

```bash
git add lua/todotxt/dates.lua test/lua/todotxt/dates_spec.lua
git commit -m "feat(dates): add add_months() with edge case handling"
```

---

### Task 8: Add Years

**Files:**
- Modify: `lua/todotxt/dates.lua`
- Modify: `test/lua/todotxt/dates_spec.lua`

**Step 1: Add test for adding years**

```lua
-- Add to test/lua/todotxt/dates_spec.lua
describe("add_years", function()
  it("adds years", function()
    assert.equals("2027-01-15", dates.add_years("2025-01-15", 2))
  end)

  it("handles leap day to non-leap year", function()
    assert.equals("2025-02-28", dates.add_years("2024-02-29", 1))
  end)
end)
```

**Step 2: Run test to verify it fails**

Expected: FAIL

**Step 3: Implement add_years()**

```lua
-- Add to lua/todotxt/dates.lua
function M.add_years(date_str, years)
  return M.add_months(date_str, years * 12)
end
```

**Step 4: Run test to verify it passes**

Expected: PASS

**Step 5: Commit**

```bash
git add lua/todotxt/dates.lua test/lua/todotxt/dates_spec.lua
git commit -m "feat(dates): add add_years() function"
```

---

### Task 9: Parse Recurrence Pattern

**Files:**
- Modify: `lua/todotxt/dates.lua`
- Modify: `test/lua/todotxt/dates_spec.lua`

**Step 1: Add test for pattern parsing**

```lua
-- Add to test/lua/todotxt/dates_spec.lua
describe("parse_pattern", function()
  it("parses simple day pattern", function()
    local p = dates.parse_pattern("3d")
    assert.equals(3, p.count)
    assert.equals("d", p.unit)
    assert.is_false(p.strict)
  end)

  it("parses week pattern", function()
    local p = dates.parse_pattern("2w")
    assert.equals(2, p.count)
    assert.equals("w", p.unit)
  end)

  it("parses month pattern", function()
    local p = dates.parse_pattern("1m")
    assert.equals(1, p.count)
    assert.equals("m", p.unit)
  end)

  it("parses year pattern", function()
    local p = dates.parse_pattern("1y")
    assert.equals(1, p.count)
    assert.equals("y", p.unit)
  end)

  it("parses strict pattern with + prefix", function()
    local p = dates.parse_pattern("+2w")
    assert.equals(2, p.count)
    assert.equals("w", p.unit)
    assert.is_true(p.strict)
  end)

  it("returns nil for invalid pattern", function()
    assert.is_nil(dates.parse_pattern("invalid"))
  end)
end)
```

**Step 2: Run test to verify it fails**

Expected: FAIL

**Step 3: Implement parse_pattern()**

```lua
-- Add to lua/todotxt/dates.lua
function M.parse_pattern(pattern)
  local strict = false
  if pattern:sub(1, 1) == "+" then
    strict = true
    pattern = pattern:sub(2)
  end

  local count, unit = pattern:match("^(%d+)([dwmy])$")
  if not count then return nil end

  return {
    count = tonumber(count),
    unit = unit,
    strict = strict,
  }
end
```

**Step 4: Run test to verify it passes**

Expected: PASS

**Step 5: Commit**

```bash
git add lua/todotxt/dates.lua test/lua/todotxt/dates_spec.lua
git commit -m "feat(dates): add parse_pattern() for recurrence"
```

---

### Task 10: Add Relative Date by Pattern

**Files:**
- Modify: `lua/todotxt/dates.lua`
- Modify: `test/lua/todotxt/dates_spec.lua`

**Step 1: Add test for add_relative**

```lua
-- Add to test/lua/todotxt/dates_spec.lua
describe("add_relative", function()
  it("adds days with pattern", function()
    assert.equals("2025-01-20", dates.add_relative("2025-01-15", "5d"))
  end)

  it("adds weeks with pattern", function()
    assert.equals("2025-01-29", dates.add_relative("2025-01-15", "2w"))
  end)

  it("adds months with pattern", function()
    assert.equals("2025-04-15", dates.add_relative("2025-01-15", "3m"))
  end)

  it("adds years with pattern", function()
    assert.equals("2026-01-15", dates.add_relative("2025-01-15", "1y"))
  end)

  it("handles strict prefix (returns same result)", function()
    assert.equals("2025-01-22", dates.add_relative("2025-01-15", "+1w"))
  end)

  it("returns nil for invalid pattern", function()
    assert.is_nil(dates.add_relative("2025-01-15", "invalid"))
  end)
end)
```

**Step 2: Run test to verify it fails**

Expected: FAIL

**Step 3: Implement add_relative()**

```lua
-- Add to lua/todotxt/dates.lua
function M.add_relative(date_str, pattern)
  local p = M.parse_pattern(pattern)
  if not p then return nil end

  if p.unit == "d" then
    return M.add_days(date_str, p.count)
  elseif p.unit == "w" then
    return M.add_weeks(date_str, p.count)
  elseif p.unit == "m" then
    return M.add_months(date_str, p.count)
  elseif p.unit == "y" then
    return M.add_years(date_str, p.count)
  end

  return nil
end
```

**Step 4: Run test to verify it passes**

Expected: PASS

**Step 5: Commit**

```bash
git add lua/todotxt/dates.lua test/lua/todotxt/dates_spec.lua
git commit -m "feat(dates): add add_relative() for pattern-based addition"
```

---

### Task 11: Diff Between Dates

**Files:**
- Modify: `lua/todotxt/dates.lua`
- Modify: `test/lua/todotxt/dates_spec.lua`

**Step 1: Add test for diff_days**

```lua
-- Add to test/lua/todotxt/dates_spec.lua
describe("diff_days", function()
  it("returns positive for future date", function()
    assert.equals(5, dates.diff_days("2025-01-10", "2025-01-15"))
  end)

  it("returns negative for past date", function()
    assert.equals(-5, dates.diff_days("2025-01-15", "2025-01-10"))
  end)

  it("returns zero for same date", function()
    assert.equals(0, dates.diff_days("2025-01-15", "2025-01-15"))
  end)
end)
```

**Step 2: Run test to verify it fails**

Expected: FAIL

**Step 3: Implement diff_days()**

```lua
-- Add to lua/todotxt/dates.lua
function M.diff_days(from_date, to_date)
  local y1, m1, d1 = M.parse(from_date)
  local y2, m2, d2 = M.parse(to_date)
  if not y1 or not y2 then return nil end

  local t1 = os.time({ year = y1, month = m1, day = d1 })
  local t2 = os.time({ year = y2, month = m2, day = d2 })

  return math.floor((t2 - t1) / 86400)
end
```

**Step 4: Run test to verify it passes**

Expected: PASS

**Step 5: Commit**

```bash
git add lua/todotxt/dates.lua test/lua/todotxt/dates_spec.lua
git commit -m "feat(dates): add diff_days() for date difference"
```

---

### Task 12: Recurrence Module - Parse Task

**Files:**
- Create: `lua/todotxt/recurrence.lua`
- Create: `test/lua/todotxt/recurrence_spec.lua`

**Step 1: Create test for parsing task tags**

```lua
-- test/lua/todotxt/recurrence_spec.lua
describe("todotxt.recurrence", function()
  local recurrence = require("todotxt.recurrence")

  describe("parse_task", function()
    it("extracts rec tag", function()
      local task = "(A) Pay rent due:2025-01-15 rec:1m"
      local tags = recurrence.parse_task(task)
      assert.equals("1m", tags.rec)
    end)

    it("extracts due tag", function()
      local task = "(A) Pay rent due:2025-01-15 rec:1m"
      local tags = recurrence.parse_task(task)
      assert.equals("2025-01-15", tags.due)
    end)

    it("extracts threshold tag", function()
      local task = "(A) Pay rent t:2025-01-10 due:2025-01-15 rec:1m"
      local tags = recurrence.parse_task(task)
      assert.equals("2025-01-10", tags.t)
    end)

    it("returns nil for missing tags", function()
      local task = "(A) Simple task"
      local tags = recurrence.parse_task(task)
      assert.is_nil(tags.rec)
      assert.is_nil(tags.due)
    end)
  end)
end)
```

**Step 2: Run test to verify it fails**

Expected: FAIL

**Step 3: Implement parse_task()**

```lua
-- lua/todotxt/recurrence.lua
local M = {}

function M.parse_task(line)
  local tags = {}

  tags.rec = line:match("%srec:([^%s]+)") or line:match("^rec:([^%s]+)")
  tags.due = line:match("%sdue:(%d%d%d%d%-%d%d%-%d%d)")
  tags.t = line:match("%st:(%d%d%d%d%-%d%d%-%d%d)")

  return tags
end

return M
```

**Step 4: Run test to verify it passes**

Expected: PASS

**Step 5: Commit**

```bash
git add lua/todotxt/recurrence.lua test/lua/todotxt/recurrence_spec.lua
git commit -m "feat(recurrence): add parse_task() for tag extraction"
```

---

### Task 13: Update Task Tags

**Files:**
- Modify: `lua/todotxt/recurrence.lua`
- Modify: `test/lua/todotxt/recurrence_spec.lua`

**Step 1: Add test for set_tag**

```lua
-- Add to test/lua/todotxt/recurrence_spec.lua
describe("set_tag", function()
  it("updates existing due tag", function()
    local task = "(A) Pay rent due:2025-01-15 rec:1m"
    local result = recurrence.set_tag(task, "due", "2025-02-15")
    assert.equals("(A) Pay rent due:2025-02-15 rec:1m", result)
  end)

  it("updates existing t tag", function()
    local task = "(A) Pay rent t:2025-01-10 due:2025-01-15"
    local result = recurrence.set_tag(task, "t", "2025-02-10")
    assert.equals("(A) Pay rent t:2025-02-10 due:2025-01-15", result)
  end)

  it("adds tag if not present", function()
    local task = "(A) Pay rent rec:1m"
    local result = recurrence.set_tag(task, "due", "2025-02-15")
    assert.equals("(A) Pay rent rec:1m due:2025-02-15", result)
  end)
end)
```

**Step 2: Run test to verify it fails**

Expected: FAIL

**Step 3: Implement set_tag()**

```lua
-- Add to lua/todotxt/recurrence.lua
function M.set_tag(line, tag, value)
  local pattern = "(%s)" .. tag .. ":[^%s]+"
  local replacement = "%1" .. tag .. ":" .. value

  local result, count = line:gsub(pattern, replacement)
  if count == 0 then
    result = line .. " " .. tag .. ":" .. value
  end

  return result
end
```

**Step 4: Run test to verify it passes**

Expected: PASS

**Step 5: Commit**

```bash
git add lua/todotxt/recurrence.lua test/lua/todotxt/recurrence_spec.lua
git commit -m "feat(recurrence): add set_tag() for modifying task tags"
```

---

### Task 14: Strip Completion from Task

**Files:**
- Modify: `lua/todotxt/recurrence.lua`
- Modify: `test/lua/todotxt/recurrence_spec.lua`

**Step 1: Add test for strip_completion**

```lua
-- Add to test/lua/todotxt/recurrence_spec.lua
describe("strip_completion", function()
  it("removes x prefix and completion date", function()
    local task = "x 2025-01-16 Pay rent due:2025-01-15 rec:1m"
    local result = recurrence.strip_completion(task)
    assert.equals("Pay rent due:2025-01-15 rec:1m", result)
  end)

  it("preserves priority", function()
    local task = "x 2025-01-16 (A) Pay rent due:2025-01-15 rec:1m"
    local result = recurrence.strip_completion(task)
    assert.equals("(A) Pay rent due:2025-01-15 rec:1m", result)
  end)

  it("returns unchanged if not completed", function()
    local task = "(A) Pay rent due:2025-01-15 rec:1m"
    local result = recurrence.strip_completion(task)
    assert.equals("(A) Pay rent due:2025-01-15 rec:1m", result)
  end)
end)
```

**Step 2: Run test to verify it fails**

Expected: FAIL

**Step 3: Implement strip_completion()**

```lua
-- Add to lua/todotxt/recurrence.lua
function M.strip_completion(line)
  -- Match: x YYYY-MM-DD optionally followed by (priority)
  local result = line:gsub("^x%s+%d%d%d%d%-%d%d%-%d%d%s+", "")
  return result
end
```

**Step 4: Run test to verify it passes**

Expected: PASS

**Step 5: Commit**

```bash
git add lua/todotxt/recurrence.lua test/lua/todotxt/recurrence_spec.lua
git commit -m "feat(recurrence): add strip_completion() function"
```

---

### Task 15: Advance Recurring Task

**Files:**
- Modify: `lua/todotxt/recurrence.lua`
- Modify: `test/lua/todotxt/recurrence_spec.lua`

**Step 1: Add test for advance_task**

```lua
-- Add to test/lua/todotxt/recurrence_spec.lua
describe("advance_task", function()
  local dates = require("todotxt.dates")

  it("advances due date by recurrence pattern (normal)", function()
    -- Mock today as 2025-01-16
    local original_today = dates.today
    dates.today = function() return "2025-01-16" end

    local task = "(A) Pay rent due:2025-01-15 rec:1m"
    local result = recurrence.advance_task(task)
    assert.matches("due:2025%-02%-16", result)

    dates.today = original_today
  end)

  it("advances due date by recurrence pattern (strict)", function()
    local task = "(A) Pay rent due:2025-01-15 rec:+1m"
    local result = recurrence.advance_task(task)
    assert.matches("due:2025%-02%-15", result)
  end)

  it("preserves gap between t and due", function()
    local original_today = dates.today
    dates.today = function() return "2025-01-16" end

    local task = "(A) Pay rent t:2025-01-10 due:2025-01-15 rec:1m"
    local result = recurrence.advance_task(task)
    assert.matches("t:2025%-02%-11", result)
    assert.matches("due:2025%-02%-16", result)

    dates.today = original_today
  end)

  it("returns nil for non-recurring task", function()
    local task = "(A) Simple task"
    local result = recurrence.advance_task(task)
    assert.is_nil(result)
  end)
end)
```

**Step 2: Run test to verify it fails**

Expected: FAIL

**Step 3: Implement advance_task()**

```lua
-- Add to lua/todotxt/recurrence.lua
local dates = require("todotxt.dates")

function M.advance_task(line)
  local tags = M.parse_task(line)
  if not tags.rec then return nil end

  local pattern = dates.parse_pattern(tags.rec)
  if not pattern then return nil end

  local base_date
  if pattern.strict and tags.due then
    base_date = tags.due
  else
    base_date = dates.today()
  end

  local new_due = dates.add_relative(base_date, tags.rec)
  if not new_due then return nil end

  local new_task = M.strip_completion(line)
  new_task = M.set_tag(new_task, "due", new_due)

  -- Preserve threshold-due gap
  if tags.t and tags.due then
    local gap = dates.diff_days(tags.t, tags.due)
    local new_t = dates.add_days(new_due, -gap)
    new_task = M.set_tag(new_task, "t", new_t)
  end

  return new_task
end
```

**Step 4: Run test to verify it passes**

Expected: PASS

**Step 5: Commit**

```bash
git add lua/todotxt/recurrence.lua test/lua/todotxt/recurrence_spec.lua
git commit -m "feat(recurrence): add advance_task() for recurring todos"
```

---

### Task 16: Threshold Module - Is Hidden

**Files:**
- Create: `lua/todotxt/threshold.lua`
- Create: `test/lua/todotxt/threshold_spec.lua`

**Step 1: Create test for is_hidden**

```lua
-- test/lua/todotxt/threshold_spec.lua
describe("todotxt.threshold", function()
  local threshold = require("todotxt.threshold")
  local dates = require("todotxt.dates")

  describe("is_hidden", function()
    before_each(function()
      -- Mock today
      dates._original_today = dates.today
      dates.today = function() return "2025-01-16" end
    end)

    after_each(function()
      dates.today = dates._original_today
    end)

    it("returns true for future threshold", function()
      local task = "(A) Future task t:2025-02-01"
      assert.is_true(threshold.is_hidden(task))
    end)

    it("returns false for past threshold", function()
      local task = "(A) Past task t:2025-01-10"
      assert.is_false(threshold.is_hidden(task))
    end)

    it("returns false for today threshold", function()
      local task = "(A) Today task t:2025-01-16"
      assert.is_false(threshold.is_hidden(task))
    end)

    it("returns true for h:1 tag", function()
      local task = "(A) Hidden task h:1"
      assert.is_true(threshold.is_hidden(task))
    end)

    it("returns true for hide:1 tag", function()
      local task = "(A) Hidden task hide:1"
      assert.is_true(threshold.is_hidden(task))
    end)

    it("returns false for h:0", function()
      local task = "(A) Visible task h:0"
      assert.is_false(threshold.is_hidden(task))
    end)

    it("returns false for task without threshold or hide", function()
      local task = "(A) Normal task"
      assert.is_false(threshold.is_hidden(task))
    end)
  end)
end)
```

**Step 2: Run test to verify it fails**

Expected: FAIL

**Step 3: Implement is_hidden()**

```lua
-- lua/todotxt/threshold.lua
local dates = require("todotxt.dates")

local M = {}

function M.is_hidden(line)
  -- Check h:1 or hide:1
  if line:match("%sh:1") or line:match("%shide:1") then
    return true
  end
  if line:match("^h:1") or line:match("^hide:1") then
    return true
  end

  -- Check future threshold
  local t = line:match("%st:(%d%d%d%d%-%d%d%-%d%d)")
  if t and dates.is_future(t) then
    return true
  end

  return false
end

return M
```

**Step 4: Run test to verify it passes**

Expected: PASS

**Step 5: Commit**

```bash
git add lua/todotxt/threshold.lua test/lua/todotxt/threshold_spec.lua
git commit -m "feat(threshold): add is_hidden() detection"
```

---

### Task 17: Init Module and Setup Function

**Files:**
- Create: `lua/todotxt/init.lua`
- Modify: `test/lua/todotxt/` (add init_spec.lua)

**Step 1: Create test for setup**

```lua
-- test/lua/todotxt/init_spec.lua
describe("todotxt", function()
  local todotxt = require("todotxt")

  describe("setup", function()
    it("accepts empty config", function()
      assert.has_no.errors(function()
        todotxt.setup({})
      end)
    end)

    it("sets default config values", function()
      todotxt.setup({})
      assert.is_true(todotxt.config.auto_recur)
      assert.is_true(todotxt.config.threshold_fold)
      assert.is_true(todotxt.config.threshold_highlight)
    end)

    it("allows overriding config", function()
      todotxt.setup({ auto_recur = false })
      assert.is_false(todotxt.config.auto_recur)
    end)
  end)
end)
```

**Step 2: Run test to verify it fails**

Expected: FAIL

**Step 3: Implement init.lua**

```lua
-- lua/todotxt/init.lua
local M = {}

M.config = {
  auto_recur = true,
  threshold_fold = true,
  threshold_highlight = true,
}

function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", M.config, opts)
end

return M
```

**Step 4: Run test to verify it passes**

Expected: PASS

**Step 5: Commit**

```bash
git add lua/todotxt/init.lua test/lua/todotxt/init_spec.lua
git commit -m "feat(init): add setup() with configuration"
```

---

### Task 18: Mark Done with Recurrence Handler

**Files:**
- Modify: `lua/todotxt/init.lua`
- Modify: `test/lua/todotxt/init_spec.lua`

**Step 1: Add test for mark_done**

```lua
-- Add to test/lua/todotxt/init_spec.lua
describe("mark_done", function()
  local dates = require("todotxt.dates")

  before_each(function()
    dates._original_today = dates.today
    dates.today = function() return "2025-01-16" end
    todotxt.setup({})
  end)

  after_each(function()
    dates.today = dates._original_today
  end)

  it("returns completed task and new recurring task", function()
    local task = "(A) Pay rent due:2025-01-15 rec:1m"
    local done, new = todotxt.mark_done(task)

    assert.matches("^x 2025%-01%-16", done)
    assert.matches("Pay rent", done)
    assert.matches("due:2025%-02%-16", new)
    assert.matches("rec:1m", new)
  end)

  it("returns only completed task for non-recurring", function()
    local task = "(A) Simple task"
    local done, new = todotxt.mark_done(task)

    assert.matches("^x 2025%-01%-16", done)
    assert.is_nil(new)
  end)

  it("respects auto_recur config", function()
    todotxt.setup({ auto_recur = false })
    local task = "(A) Pay rent due:2025-01-15 rec:1m"
    local done, new = todotxt.mark_done(task)

    assert.matches("^x", done)
    assert.is_nil(new)
  end)
end)
```

**Step 2: Run test to verify it fails**

Expected: FAIL

**Step 3: Implement mark_done()**

```lua
-- Add to lua/todotxt/init.lua
local dates = require("todotxt.dates")
local recurrence = require("todotxt.recurrence")

function M.mark_done(line)
  -- Strip existing priority
  local priority = line:match("^%((%a)%)")
  local task = line:gsub("^%(%a%)%s*", "")

  -- Mark as done
  local done = "x " .. dates.today() .. " " .. task

  -- Handle recurrence
  local new_task = nil
  if M.config.auto_recur then
    new_task = recurrence.advance_task(line)
    -- Restore priority to new task
    if new_task and priority then
      new_task = "(" .. priority .. ") " .. new_task:gsub("^%(%a%)%s*", "")
    end
  end

  return done, new_task
end
```

**Step 4: Run test to verify it passes**

Expected: PASS

**Step 5: Commit**

```bash
git add lua/todotxt/init.lua test/lua/todotxt/init_spec.lua
git commit -m "feat(init): add mark_done() with recurrence support"
```

---

### Task 19: Ftplugin Buffer Setup

**Files:**
- Create: `ftplugin/todo.lua`

**Step 1: Create ftplugin for Neovim**

```lua
-- ftplugin/todo.lua
-- Only load in Neovim
if not vim.fn.has("nvim-0.7") then
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
```

**Step 2: Test manually**

Open a todo.txt file in Neovim with a recurring task:
```
(A) Pay rent due:2025-01-15 rec:1m
```

Press `<localleader>x` and verify:
- Current line becomes `x YYYY-MM-DD Pay rent due:2025-01-15 rec:1m`
- New line inserted below with updated due date

**Step 3: Commit**

```bash
git add ftplugin/todo.lua
git commit -m "feat(ftplugin): add Neovim mark_done mapping"
```

---

### Task 20: Hidden Task Highlighting

**Files:**
- Modify: `ftplugin/todo.lua`

**Step 1: Add highlight setup**

```lua
-- Add to ftplugin/todo.lua

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
```

**Step 2: Test manually**

Open todo.txt with hidden tasks:
```
(A) Normal task
(A) Future task t:2099-01-01
(A) Hidden task h:1
```

Verify hidden tasks appear dimmed (grey).

**Step 3: Commit**

```bash
git add ftplugin/todo.lua
git commit -m "feat(ftplugin): add hidden task highlighting"
```

---

### Task 21: Hidden Task Folding

**Files:**
- Modify: `ftplugin/todo.lua`

**Step 1: Add fold expression**

```lua
-- Add to ftplugin/todo.lua

local function todo_fold_expr(lnum)
  if not todotxt.config.threshold_fold then
    -- Fall back to original fold (completed tasks)
    local line = vim.fn.getline(lnum)
    if line:match("^[xX]%s") then
      return 1
    end
    return 0
  end

  local line = vim.fn.getline(lnum)

  -- Completed tasks
  if line:match("^[xX]%s") then
    return 1
  end

  -- Hidden tasks
  if threshold.is_hidden(line) then
    return 1
  end

  return 0
end

-- Set fold options
vim.opt_local.foldmethod = "expr"
vim.opt_local.foldexpr = "v:lua.require('todotxt').fold_expr(v:lnum)"

-- Export fold function
todotxt.fold_expr = todo_fold_expr
```

**Step 2: Test manually**

Open todo.txt with hidden and completed tasks. Verify they fold together at level 1.

**Step 3: Commit**

```bash
git add ftplugin/todo.lua lua/todotxt/init.lua
git commit -m "feat(ftplugin): add hidden task folding"
```

---

### Task 22: Sort with Hidden to Bottom

**Files:**
- Modify: `lua/todotxt/init.lua`
- Modify: `ftplugin/todo.lua`

**Step 1: Add sort_hidden_to_bottom function**

```lua
-- Add to lua/todotxt/init.lua
function M.sort_hidden_to_bottom(first_line, last_line)
  local lines = vim.api.nvim_buf_get_lines(0, first_line - 1, last_line, false)

  local visible = {}
  local hidden = {}

  for _, line in ipairs(lines) do
    if threshold.is_hidden(line) then
      table.insert(hidden, line)
    else
      table.insert(visible, line)
    end
  end

  -- Combine: visible first, then hidden
  local result = {}
  for _, line in ipairs(visible) do
    table.insert(result, line)
  end
  for _, line in ipairs(hidden) do
    table.insert(result, line)
  end

  vim.api.nvim_buf_set_lines(0, first_line - 1, last_line, false, result)
end
```

**Step 2: Add to init.lua requires**

```lua
-- At top of lua/todotxt/init.lua
local threshold = require("todotxt.threshold")
```

**Step 3: Override sort mappings in ftplugin**

```lua
-- Add to ftplugin/todo.lua

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
```

**Step 4: Test manually**

Open todo.txt:
```
(C) Third task
(A) Hidden task h:1
(B) Second task
(A) Future task t:2099-01-01
```

Press `<localleader>s` and verify hidden tasks move to bottom while maintaining sort order among themselves.

**Step 5: Commit**

```bash
git add lua/todotxt/init.lua ftplugin/todo.lua
git commit -m "feat: sort functions move hidden tasks to bottom"
```

---

### Task 23: Visual Mode Sort Support

**Files:**
- Modify: `ftplugin/todo.lua`

**Step 1: Add visual mode sort mappings**

```lua
-- Add to ftplugin/todo.lua

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
```

**Step 2: Test manually**

Select lines visually and sort - verify hidden tasks move to bottom of selection only.

**Step 3: Commit**

```bash
git add ftplugin/todo.lua
git commit -m "feat(ftplugin): add visual mode sort with hidden to bottom"
```

---

### Task 24: Visual Mode Mark Done

**Files:**
- Modify: `ftplugin/todo.lua`

**Step 1: Add visual mode mark done**

```lua
-- Add to ftplugin/todo.lua

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

  -- Replace selected lines with done tasks
  vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, result)

  -- Insert new recurring tasks after the last done task
  if #new_tasks > 0 then
    vim.api.nvim_buf_set_lines(0, end_line, end_line, false, new_tasks)
  end
end, { buffer = true, desc = "Mark selected todos as done" })
```

**Step 2: Test manually**

Select multiple lines including recurring tasks, press `<localleader>x`. Verify all marked done and new recurring tasks appear below.

**Step 3: Commit**

```bash
git add ftplugin/todo.lua
git commit -m "feat(ftplugin): add visual mode mark_done"
```

---

### Task 25: Documentation

**Files:**
- Modify: `doc/todo.txt`

**Step 1: Add Neovim-specific documentation**

```vim
" Add to doc/todo.txt after existing documentation

==============================================================================
NEOVIM LUA FEATURES                                      *todo-txt-neovim*

When using Neovim (0.7+), additional features are available:

RECURRING TASKS                                          *todo-txt-recurring*

Tasks with a `rec:` tag will automatically create a new task when marked done.

Patterns:
  `rec:Nd`    - N days (e.g., rec:1d, rec:7d)
  `rec:Nw`    - N weeks (e.g., rec:1w, rec:2w)
  `rec:Nm`    - N months (e.g., rec:1m, rec:3m)
  `rec:Ny`    - N years (e.g., rec:1y)

Modes:
  `rec:1w`    - Normal: new due date from today
  `rec:+1w`   - Strict: new due date from original due date

If the task has both `t:` (threshold) and `due:` tags, the gap between them
is preserved in the new task.

Example: >
  (A) Pay rent t:2025-01-10 due:2025-01-15 rec:1m
<
After marking done becomes: >
  x 2025-01-16 Pay rent t:2025-01-10 due:2025-01-15 rec:1m
  (A) Pay rent t:2025-02-11 due:2025-02-16 rec:1m
<

HIDDEN TASKS                                             *todo-txt-hidden*

Tasks are hidden if they have:
  - Future threshold: `t:YYYY-MM-DD` where date > today
  - Explicit hide tag: `h:1` or `hide:1`

Hidden tasks:
  - Appear dimmed (linked to Comment highlight group)
  - Auto-fold at level 1 (with completed tasks)
  - Sort to bottom when using sort mappings

CONFIGURATION                                            *todo-txt-config*

Configure in your init.lua: >
  require('todotxt').setup({
    auto_recur = true,          -- auto-create recurring on mark done
    threshold_fold = true,      -- fold future threshold tasks
    threshold_highlight = true, -- dim hidden tasks
  })
<

HIGHLIGHT GROUPS                                         *todo-txt-highlights*

  TodoHidden      - Hidden tasks (default: links to Comment)
  TodoRecurring   - Tasks with rec: tag (default: links to Special)

Override in your colorscheme: >
  vim.api.nvim_set_hl(0, "TodoHidden", { fg = "#808080", italic = true })
<
```

**Step 2: Generate help tags**

```bash
nvim --headless -c "helptags doc" -c "q"
```

**Step 3: Commit**

```bash
git add doc/todo.txt
git commit -m "docs: add Neovim Lua features documentation"
```

---

### Task 26: Final Integration Test

**Files:**
- Create: `test/lua/todotxt/integration_spec.lua`

**Step 1: Create integration test**

```lua
-- test/lua/todotxt/integration_spec.lua
describe("todotxt integration", function()
  local todotxt = require("todotxt")
  local dates = require("todotxt.dates")
  local threshold = require("todotxt.threshold")

  before_each(function()
    todotxt.setup({})
    dates._original_today = dates.today
    dates.today = function() return "2025-01-16" end
  end)

  after_each(function()
    dates.today = dates._original_today
  end)

  describe("full workflow", function()
    it("marks recurring task done and creates new one", function()
      local task = "(A) Pay rent t:2025-01-10 due:2025-01-15 rec:1m"
      local done, new = todotxt.mark_done(task)

      -- Done task
      assert.matches("^x 2025%-01%-16", done)
      assert.matches("Pay rent", done)

      -- New task has updated dates
      assert.matches("%(A%)", new)
      assert.matches("t:2025%-02%-11", new)
      assert.matches("due:2025%-02%-16", new)
      assert.matches("rec:1m", new)

      -- New task is not hidden (threshold in past relative to new due)
      -- Actually new t:2025-02-11 IS in future, so it should be hidden
      assert.is_true(threshold.is_hidden(new))
    end)

    it("handles strict recurrence", function()
      local task = "(A) Pay rent due:2025-01-15 rec:+1m"
      local done, new = todotxt.mark_done(task)

      -- Strict: based on original due date, not today
      assert.matches("due:2025%-02%-15", new)
    end)
  end)
end)
```

**Step 2: Run all tests**

Run: `nvim --headless -c "PlenaryBustedDirectory test/lua/todotxt/ {minimal_init = 'test/minimal_init.lua'}"`

Expected: All PASS

**Step 3: Commit**

```bash
git add test/lua/todotxt/integration_spec.lua
git commit -m "test: add integration tests"
```

---

### Task 27: Update README

**Files:**
- Modify: `README.markdown`

**Step 1: Add Neovim section to README**

Add after existing content:

```markdown
### Neovim Lua Features

When using Neovim 0.7+, additional features are automatically enabled:

**Recurring Tasks** - Tasks with `rec:` tag auto-create the next occurrence:
- `rec:1d`, `rec:1w`, `rec:1m`, `rec:1y` - daily, weekly, monthly, yearly
- `rec:+1w` - strict mode (from original due date)

**Hidden Tasks** - Tasks with future `t:` date or `h:1` tag:
- Appear dimmed
- Auto-fold
- Sort to bottom

**Configuration:**
```lua
require('todotxt').setup({
  auto_recur = true,
  threshold_fold = true,
  threshold_highlight = true,
})
```

See `:help todo-txt-neovim` for details.
```

**Step 2: Commit**

```bash
git add README.markdown
git commit -m "docs: update README with Neovim features"
```

---

Plan complete and saved to `docs/plans/2026-01-16-recurrence-threshold-implementation.md`. Two execution options:

1. Subagent-Driven (this session) - I dispatch fresh subagent per task, review between tasks, fast iteration

2. Parallel Session (separate) - Open new session with executing-plans, batch execution with checkpoints

Which approach?