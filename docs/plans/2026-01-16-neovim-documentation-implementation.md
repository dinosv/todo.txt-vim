# NEOVIM.md Documentation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create comprehensive NEOVIM.md documentation for power users

**Architecture:** Single markdown file with reference-style sections, tables for quick scanning, copy-paste code examples

**Tech Stack:** Markdown with fenced code blocks

---

### Task 1: Create NEOVIM.md with Overview and Installation

**Files:**
- Create: `NEOVIM.md`

**Step 1: Create file with header and overview**

```markdown
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

\`\`\`lua
{
  "dinosv/todo.txt-vim",
  branch = "nvim",
  ft = { "todo", "done" },
  config = function()
    require("todotxt").setup()
  end,
}
\`\`\`

### packer.nvim

\`\`\`lua
use {
  "dinosv/todo.txt-vim",
  branch = "nvim",
  ft = { "todo", "done" },
  config = function()
    require("todotxt").setup()
  end,
}
\`\`\`

### vim-plug

\`\`\`vim
" In init.vim or .vimrc
if has('nvim')
  Plug 'dinosv/todo.txt-vim', { 'branch': 'nvim' }
else
  Plug 'dinosv/todo.txt-vim', { 'branch': 'master' }
endif
\`\`\`

Then in `init.lua`:

\`\`\`lua
require("todotxt").setup()
\`\`\`

## Quick Start

1. Install the plugin using the `nvim` branch
2. Add `require("todotxt").setup()` to your config
3. Open a `todo.txt` file
4. Add a recurring task: `Pay rent due:2025-01-15 rec:1m`
5. Mark it done with `<localleader>x`
6. Watch the new task appear below
```

**Step 2: Verify file created**

Run: `head -20 NEOVIM.md`
Expected: Shows the header and beginning of overview

**Step 3: Commit**

```bash
git add NEOVIM.md
git commit -m "docs: add NEOVIM.md with overview and installation"
```

---

### Task 2: Add Recurring Tasks Section

**Files:**
- Modify: `NEOVIM.md`

**Step 1: Append recurring tasks section**

```markdown
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
```

**Step 2: Verify section appended**

Run: `grep -n "Recurring Tasks" NEOVIM.md`
Expected: Shows line number of Recurring Tasks heading

**Step 3: Commit**

```bash
git add NEOVIM.md
git commit -m "docs: add recurring tasks section to NEOVIM.md"
```

---

### Task 3: Add Hidden Tasks Section

**Files:**
- Modify: `NEOVIM.md`

**Step 1: Append hidden tasks section**

```markdown
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
```

**Step 2: Verify section appended**

Run: `grep -n "Hidden Tasks" NEOVIM.md`
Expected: Shows line number of Hidden Tasks heading

**Step 3: Commit**

```bash
git add NEOVIM.md
git commit -m "docs: add hidden tasks section to NEOVIM.md"
```

---

### Task 4: Add Mappings Reference Section

**Files:**
- Modify: `NEOVIM.md`

**Step 1: Append mappings reference section**

```markdown
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
```

**Step 2: Verify section appended**

Run: `grep -n "Mappings Reference" NEOVIM.md`
Expected: Shows line number of Mappings Reference heading

**Step 3: Commit**

```bash
git add NEOVIM.md
git commit -m "docs: add mappings reference section to NEOVIM.md"
```

---

### Task 5: Add Configuration Section

**Files:**
- Modify: `NEOVIM.md`

**Step 1: Append configuration section**

```markdown
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
```

**Step 2: Verify section appended**

Run: `grep -n "Configuration" NEOVIM.md`
Expected: Shows line number of Configuration heading

**Step 3: Commit**

```bash
git add NEOVIM.md
git commit -m "docs: add configuration section to NEOVIM.md"
```

---

### Task 6: Add Integration Patterns Section

**Files:**
- Modify: `NEOVIM.md`

**Step 1: Append integration patterns section**

```markdown
## Integration Patterns

### telescope.nvim

Find tasks by project or context:

```lua
-- In your telescope config or keymaps
vim.keymap.set("n", "<leader>tp", function()
  require("telescope.builtin").live_grep({
    prompt_title = "Find by +project",
    default_text = "+",
    search_dirs = { vim.fn.expand("~/todo.txt") },
  })
end, { desc = "Find tasks by project" })

vim.keymap.set("n", "<leader>tc", function()
  require("telescope.builtin").live_grep({
    prompt_title = "Find by @context",
    default_text = "@",
    search_dirs = { vim.fn.expand("~/todo.txt") },
  })
end, { desc = "Find tasks by context" })
```

### which-key.nvim

Make mappings discoverable:

```lua
require("which-key").register({
  ["<localleader>"] = {
    x = { name = "Mark done" },
    s = {
      name = "Sort",
      ["+"] = "by +project",
      ["@"] = "by @context",
      d = "by date",
      dd = "by due date",
    },
    a = "Priority (A)",
    b = "Priority (B)",
    c = "Priority (C)",
    j = "Priority down",
    k = "Priority up",
    d = "Set date",
    D = "Archive done",
  },
}, { buffer = 0 })
```

### lualine.nvim

Show task counts in status line:

```lua
-- Helper function (add to your config)
local function todo_stats()
  local bufname = vim.fn.expand("%:t")
  if not bufname:match("todo%.txt$") then return "" end

  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local total, hidden, done = 0, 0, 0

  local threshold = require("todotxt.threshold")
  for _, line in ipairs(lines) do
    if line ~= "" then
      total = total + 1
      if line:match("^x%s") then
        done = done + 1
      elseif threshold.is_hidden(line) then
        hidden = hidden + 1
      end
    end
  end

  local active = total - done - hidden
  return string.format("T:%d H:%d D:%d", active, hidden, done)
end

-- In lualine setup
require("lualine").setup({
  sections = {
    lualine_x = { todo_stats, "encoding", "fileformat", "filetype" },
  },
})
```

### topydo Coexistence

This plugin uses the same file format as topydo, so both can edit the same files:

- `rec:` tags are compatible
- `t:` threshold dates are compatible
- `h:1` hide tags are compatible
- `due:` dates are compatible

You can use topydo's CLI for quick additions and this plugin for editing.
```

**Step 2: Verify section appended**

Run: `grep -n "Integration Patterns" NEOVIM.md`
Expected: Shows line number of Integration Patterns heading

**Step 3: Commit**

```bash
git add NEOVIM.md
git commit -m "docs: add integration patterns section to NEOVIM.md"
```

---

### Task 7: Add Workflow Examples Section

**Files:**
- Modify: `NEOVIM.md`

**Step 1: Append workflow examples section**

```markdown
## Workflow Examples

### Weekly Review Pattern

Set up tasks that appear only on review day:

```
Weekly review @personal t:2025-01-17 due:2025-01-17 rec:+1w
Review project goals @work t:2025-01-17 due:2025-01-17 rec:+1w
Check budget @finance t:2025-01-17 due:2025-01-17 rec:+1w
```

- Hidden until Friday (threshold = due date)
- Strict recurrence keeps them on Friday
- All appear together for batch processing

### Bill Payment Tracking

Track recurring bills with advance notice:

```
(A) Pay rent t:2025-01-10 due:2025-01-15 rec:1m @bills
(B) Pay electricity t:2025-01-18 due:2025-01-23 rec:1m @bills
(B) Pay internet t:2025-01-01 due:2025-01-05 rec:1m @bills
```

- Threshold gives 5-day advance warning
- Priority (A) for important bills
- `@bills` context for filtering

### Project Templates

Keep template tasks hidden but available:

```
Template: New feature checklist h:1 +templates
  [ ] Write spec h:1 +templates
  [ ] Create branch h:1 +templates
  [ ] Write tests h:1 +templates
  [ ] Implement h:1 +templates
  [ ] Code review h:1 +templates
  [ ] Merge h:1 +templates
```

Copy lines as needed, remove `h:1` to make visible.

### Seasonal Tasks

Tasks that recur annually with preparation time:

```
File taxes t:2025-02-01 due:2025-04-15 rec:1y @annual
Christmas shopping t:2025-11-01 due:2025-12-20 rec:1y @annual
Birthday: Mum t:2025-03-01 due:2025-03-15 rec:1y @annual
```

- Hidden until preparation period
- Annual recurrence with strict dates
```

**Step 2: Verify section appended**

Run: `grep -n "Workflow Examples" NEOVIM.md`
Expected: Shows line number of Workflow Examples heading

**Step 3: Commit**

```bash
git add NEOVIM.md
git commit -m "docs: add workflow examples section to NEOVIM.md"
```

---

### Task 8: Add Troubleshooting Section

**Files:**
- Modify: `NEOVIM.md`

**Step 1: Append troubleshooting section**

```markdown
## Troubleshooting

### Common Issues

| Problem | Cause | Solution |
|---------|-------|----------|
| Recurring not working | Wrong branch | Ensure using `nvim` branch, not `master` |
| Recurring not working | Old Neovim | Requires Neovim 0.7+, check `:version` |
| Recurring not working | setup() not called | Add `require("todotxt").setup()` to config |
| Tasks not hiding | Wrong date format | Use `YYYY-MM-DD` format (e.g., `t:2025-01-15`) |
| Tasks not hiding | Date not in future | Check `t:` date is after today |
| Highlights not showing | No termguicolors | Add `set termguicolors` or `vim.opt.termguicolors = true` |
| Highlights not showing | setup() not called | Add `require("todotxt").setup()` to config |
| Folds not working | foldmethod overridden | Remove other foldmethod settings for todo files |
| Folds not working | threshold_fold disabled | Check `threshold_fold = true` in setup |

### Debug Checklist

**1. Verify Neovim version:**
```vim
:version
```
Look for `NVIM v0.7` or higher.

**2. Verify branch:**
```bash
cd ~/.vim/plugged/todo.txt-vim  # or your plugin path
git branch
```
Should show `* nvim`.

**3. Verify module loads:**
```vim
:lua print(vim.inspect(require("todotxt")))
```
Should print table with `setup`, `mark_done`, etc.

**4. Verify config:**
```vim
:lua print(vim.inspect(require("todotxt").config))
```
Should show `auto_recur`, `threshold_fold`, `threshold_highlight`.

**5. Verify ftplugin loaded:**
```vim
:scriptnames
```
Look for `ftplugin/todo.lua` in the list.

**6. Check for errors:**
```vim
:messages
```
Look for Lua errors related to todotxt.

### Version Compatibility

| Neovim Version | Status |
|----------------|--------|
| 0.7.x | Supported |
| 0.8.x | Supported |
| 0.9.x | Supported |
| 0.10.x | Supported |
| < 0.7 | Not supported (use master branch) |
```

**Step 2: Verify section appended**

Run: `grep -n "Troubleshooting" NEOVIM.md`
Expected: Shows line number of Troubleshooting heading

**Step 3: Commit**

```bash
git add NEOVIM.md
git commit -m "docs: add troubleshooting section to NEOVIM.md"
```

---

### Task 9: Review and Final Commit

**Files:**
- Review: `NEOVIM.md`

**Step 1: Verify document structure**

Run: `grep "^## " NEOVIM.md`
Expected output:
```
## What's Different from Vim
## Requirements
## Installation
## Quick Start
## Recurring Tasks
## Hidden Tasks
## Mappings Reference
## Configuration
## Integration Patterns
## Workflow Examples
## Troubleshooting
```

**Step 2: Check file length**

Run: `wc -l NEOVIM.md`
Expected: Approximately 400-500 lines

**Step 3: Verify no broken markdown**

Run: `head -5 NEOVIM.md && echo "..." && tail -5 NEOVIM.md`
Expected: Clean markdown at start and end

**Step 4: Push to remote**

```bash
git push origin nvim
```
