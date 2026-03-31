# Overdue task highlighting

## Goal

Visually mark overdue tasks by highlighting the `due:YYYY-MM-DD` span with a red background when the due date is in the past. Only active (non-done) tasks are affected.

## Approach

Use Lua extmarks, extending the existing `update_highlights()` function in `ftplugin/todo.lua`. This is the same mechanism used for `TodoHidden` highlighting.

Vim syntax rules cannot compare dates dynamically, so the existing `OverDueDate` references in `syntax/todo.vim` are dead code and will be removed.

## Highlight group

```lua
vim.api.nvim_set_hl(0, "TodoOverdue", {
  bg = "#592222",
  fg = "#ff6666",
  bold = true,
  default = true,
})
```

Uses an explicit red background rather than linking to `DiagnosticError`, since the requirement is background highlighting specifically. The `default = true` flag allows users to override via their colour scheme.

## Detection logic

For each line in the buffer:

1. Skip if line matches `^[xX]%s` (completed task).
2. Find `due:YYYY-MM-DD` using pattern `due:(%d%d%d%d%-%d%d%-%d%d)`.
3. Compare against today using `dates.diff_days(due_date, dates.today())`.
4. If diff < 0 (due date is in the past), place an extmark on the `due:YYYY-MM-DD` span (including the `due:` prefix) with `TodoOverdue` highlight.

## Files to modify

| File | Change |
|------|--------|
| `ftplugin/todo.lua` | Define `TodoOverdue` hl group; extend `update_highlights()` with overdue extmarks |
| `syntax/todo.vim` | Remove unused `OverDueDate` from `contains=` clauses; remove dead Python block |

## No changes needed

- No new Lua modules.
- No config additions (no user-facing toggle needed).
- No new keybindings.
- `lua/todotxt/dates.lua` already provides `today()`, `diff_days()`, and `parse()`.
