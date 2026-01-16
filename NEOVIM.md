# Neovim Features for todo.txt-vim

This document covers the Neovim-specific Lua features available on the `nvim` branch.
These features require Neovim 0.7+ and are not available in Vim.

## What's Different from Vim

| Feature | Vim (master) | Neovim (nvim) |
|---------|--------------|---------------|
| Recurring tasks | No | Yes - auto-create next occurrence |
| Hidden tasks | No | Yes - dimming, folding, sort-to-bottom |
| Threshold dates | No | Yes - hide until date |
| Implementation | VimScript | Lua + VimScript |

## Requirements

- Neovim 0.7 or later
- `nvim` branch of this plugin (not `master`)

## Installation

### lazy.nvim

```lua
{
  "dinosv/todo.txt-vim",
  branch = "nvim",
  ft = { "todo", "done" },
  config = function()
    require("todotxt").setup()
  end,
}
```

### packer.nvim

```lua
use {
  "dinosv/todo.txt-vim",
  branch = "nvim",
  ft = { "todo", "done" },
  config = function()
    require("todotxt").setup()
  end,
}
```

### vim-plug

```vim
" In init.vim or .vimrc
if has('nvim')
  Plug 'dinosv/todo.txt-vim', { 'branch': 'nvim' }
else
  Plug 'dinosv/todo.txt-vim', { 'branch': 'master' }
endif
```

Then in `init.lua`:

```lua
require("todotxt").setup()
```

## Quick Start

1. Install the plugin using the `nvim` branch
2. Add `require("todotxt").setup()` to your config
3. Open a `todo.txt` file
4. Add a recurring task: `Pay rent due:2025-01-15 rec:1m`
5. Mark it done with `<localleader>x`
6. Watch the new task appear below

## Recurring Tasks

When you mark a task done with `<localleader>x`, if it has a `rec:` tag, a new task is automatically created.

### Pattern Reference

| Pattern | Meaning | Example |
|---------|---------|---------|
| `rec:Nd` | Every N days | `rec:1d` = daily, `rec:7d` = weekly |
| `rec:Nw` | Every N weeks | `rec:1w` = weekly, `rec:2w` = fortnightly |
| `rec:Nm` | Every N months | `rec:1m` = monthly, `rec:3m` = quarterly |
| `rec:Ny` | Every N years | `rec:1y` = annually |

### Normal vs Strict Mode

| Mode | Syntax | New date calculated from |
|------|--------|--------------------------|
| Normal | `rec:1w` | Today's date |
| Strict | `rec:+1w` | Original `due:` date |

**Normal mode** is useful when you complete tasks late - the next occurrence adjusts to today.

**Strict mode** (with `+` prefix) is useful for fixed schedules - the next occurrence is always relative to the original due date, regardless of when you complete it.

### Date Gap Preservation

If a task has both `t:` (threshold) and `due:` dates, the gap between them is preserved.

**Before marking done:**
```
(A) Pay rent t:2025-01-10 due:2025-01-15 rec:1m
```

**After `<localleader>x` on 2025-01-16:**
```
x 2025-01-16 Pay rent t:2025-01-10 due:2025-01-15 rec:1m
(A) Pay rent t:2025-02-11 due:2025-02-16 rec:1m
```

The 5-day gap (threshold is 5 days before due) is maintained.

### Examples

**Daily standup reminder:**
```
Daily standup @work due:2025-01-16 rec:1d
```

**Weekly review (strict, always Friday):**
```
Weekly review @personal due:2025-01-17 rec:+1w
```

**Monthly rent (with advance notice):**
```
(A) Pay rent t:2025-01-10 due:2025-01-15 rec:1m
```

## Hidden Tasks

Tasks can be hidden from view to reduce clutter. Hidden tasks are visually dimmed, auto-folded, and sorted to the bottom.

### Trigger Conditions

| Condition | Example | When hidden |
|-----------|---------|-------------|
| Future threshold | `t:2025-02-01` | Until 2025-02-01 |
| Explicit hide tag | `h:1` | Always |
| Explicit hide tag | `hide:1` | Always |

### Visual Behaviour

| Behaviour | Default | Controlled by |
|-----------|---------|---------------|
| Dimmed text | Yes (Comment highlight) | `threshold_highlight` option |
| Auto-folded | Yes (fold level 1) | `threshold_fold` option |
| Sort to bottom | Yes | Built into sort mappings |

### Examples

**Task hidden until start date:**
```
Prepare quarterly report t:2025-03-15 due:2025-03-31 +reports
```
This task won't clutter your view until 15 March.

**Permanently hidden task:**
```
Template: New project checklist h:1
```
Useful for template tasks you copy but don't want to see.

**Seasonal task:**
```
Buy Christmas gifts t:2025-11-01 due:2025-12-20 rec:1y
```
Hidden until November each year.

## Mappings Reference

All mappings use `<localleader>` as prefix. Set your localleader in your config:

```vim
let maplocalleader = "-"
```

Or in Lua:

```lua
vim.g.maplocalleader = "-"
```

### All Mappings

| Mapping | Mode | Action |
|---------|------|--------|
| `<localleader>x` | n | Mark task done (creates recurring if applicable) |
| `<localleader>x` | v | Mark selected tasks done |
| `<localleader>X` | n | Mark all tasks done |
| `<localleader>D` | n | Move completed tasks to done.txt |
| `<localleader>s` | n, v | Sort + hidden to bottom |
| `<localleader>s+` | n, v | Sort by +project + hidden to bottom |
| `<localleader>s@` | n, v | Sort by @context + hidden to bottom |
| `<localleader>sd` | n, v | Sort by date + hidden to bottom |
| `<localleader>sdd` | n, v | Sort by due date + hidden to bottom |
| `<localleader>j` | n | Decrease priority |
| `<localleader>k` | n | Increase priority |
| `<localleader>a` | n | Set priority (A) |
| `<localleader>b` | n | Set priority (B) |
| `<localleader>c` | n | Set priority (C) |
| `<localleader>d` | n | Set creation date to today |
| `date<tab>` | i | Insert current date |

## Configuration

### Options Reference

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `auto_recur` | boolean | `true` | Create new task when marking recurring task done |
| `threshold_fold` | boolean | `true` | Auto-fold hidden and completed tasks |
| `threshold_highlight` | boolean | `true` | Dim hidden tasks |

### Setup Examples

**Minimal (all defaults):**
```lua
require("todotxt").setup()
```

**Explicit configuration:**
```lua
require("todotxt").setup({
  auto_recur = true,
  threshold_fold = true,
  threshold_highlight = true,
})
```

**Disable auto-folding:**
```lua
require("todotxt").setup({
  threshold_fold = false,
})
```

**Disable recurring (manual workflow):**
```lua
require("todotxt").setup({
  auto_recur = false,
})
```

### Highlight Groups

| Group | Default | Purpose |
|-------|---------|---------|
| `TodoHidden` | links to `Comment` | Hidden tasks (future threshold or h:1) |
| `TodoRecurring` | links to `Special` | Tasks with rec: tag |

### Highlight Customisation

**In init.lua:**
```lua
vim.api.nvim_set_hl(0, "TodoHidden", { fg = "#808080", italic = true })
vim.api.nvim_set_hl(0, "TodoRecurring", { fg = "#d79921", bold = true })
```

**In a colorscheme file:**
```lua
-- after/colors/myscheme.lua
vim.api.nvim_set_hl(0, "TodoHidden", { link = "NonText" })
```

**Using highlight command:**
```vim
highlight TodoHidden guifg=#808080 gui=italic
highlight TodoRecurring guifg=#d79921 gui=bold
```