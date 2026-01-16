# Recurring Tasks and Threshold Support for todo.txt-vim

## Overview

Extend todo.txt-vim with topydo-inspired features for recurring tasks and threshold/hidden task management. Implementation will be Neovim-only using Lua, added alongside existing Vimscript.

## Features

### 1. Recurring Tasks

When marking a task done with `<localleader>x`:

1. Check if task has `rec:` tag
2. If recurring:
   - Clone original task (without completion marker)
   - Parse `rec:` pattern and calculate new dates
   - Preserve gap between `t:` (threshold) and `due:` dates
   - Insert new task on line below current task
3. Mark original task done as usual

Supported patterns:
- `Nd` - N days
- `Nw` - N weeks
- `Nm` - N months
- `Ny` - N years

Recurrence modes:
- `rec:1w` - calculate from today (normal)
- `rec:+1w` - calculate from original `due:` date (strict)

Example:
```
(A) Pay rent due:2025-01-15 t:2025-01-10 rec:1m
```

After `<localleader>x` on 2025-01-16:
```
x 2025-01-16 Pay rent due:2025-01-15 t:2025-01-10 rec:1m
(A) Pay rent due:2025-02-16 t:2025-02-11 rec:1m
```

Note: The 5-day gap between threshold and due date is preserved.

### 2. Hidden Tasks

Tasks are considered hidden if:
- `t:YYYY-MM-DD` where date is in the future (threshold not yet reached)
- `h:1` or `hide:1` tag present

Hidden tasks receive:
- Dimmed visual styling (greyed out)
- Auto-folded (fold level 1, same as completed tasks)
- Sorted to bottom when using any sort mapping

### 3. Sorting Behaviour

All existing sort mappings gain threshold/hidden awareness:

| Mapping | Action |
|---------|--------|
| `<localleader>s` | Sort + hidden tasks to bottom |
| `<localleader>s+` | Sort by project + hidden to bottom |
| `<localleader>s@` | Sort by context + hidden to bottom |
| `<localleader>sd` | Sort by date + hidden to bottom |
| `<localleader>sdd` | Sort by due date + hidden to bottom |

Hidden tasks preserve their relative order among themselves.

## File Structure

```
lua/
  todotxt/
    init.lua          -- setup, mappings, autocommands
    recurrence.lua    -- parse rec: tags, calculate new dates
    dates.lua         -- relative date arithmetic
    threshold.lua     -- detect hidden tasks, highlighting

ftplugin/
  todo.lua            -- buffer-local setup, override mappings
```

## Date Arithmetic

The `dates.lua` module handles relative date calculations.

Month/year edge cases:
- Adding 1 month to Jan 31 yields Feb 28 (or 29 in leap year)
- Uses last valid day when target month is shorter

API:
```lua
local dates = require('todotxt.dates')
dates.add_relative("2025-01-15", "1m")  --> "2025-02-15"
dates.add_relative("2025-01-31", "1m")  --> "2025-02-28"
dates.parse_pattern("+2w")              --> { strict = true, count = 2, unit = "w" }
dates.today()                           --> "2025-01-16"
```

## Highlight Groups

| Group | Default | Purpose |
|-------|---------|---------|
| `TodoHidden` | links to `Comment` | Hidden tasks (future threshold or h:1) |
| `TodoRecurring` | links to `Special` | Tasks with rec: tag (optional) |

Users can override in their colorscheme.

## Configuration

```lua
require('todotxt').setup({
  auto_recur = true,          -- auto-create recurring on mark done
  threshold_fold = true,      -- fold future threshold tasks
  threshold_highlight = true, -- dim hidden tasks
})
```

All options default to `true`.

## Detection Logic

```lua
local function is_hidden(line)
  -- Future threshold
  local threshold = line:match("t:(%d%d%d%d%-%d%d%-%d%d)")
  if threshold and threshold > dates.today() then
    return true
  end
  -- Explicit hide tag
  if line:match("[%s]h:1") or line:match("[%s]hide:1") then
    return true
  end
  return false
end
```

## Compatibility

- Neovim-only (requires Lua support)
- Existing Vimscript functionality preserved for Vim users
- Lua modules only loaded when Neovim detected
