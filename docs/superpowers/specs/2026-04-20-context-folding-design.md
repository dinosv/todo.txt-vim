# Context folding for todo.txt-vim

Date: 2026-04-20
Status: design approved, pending spec review
Scope: nvim branch, Lua side only

## Overview

Extend the existing `foldmethod=expr` folding so that a contiguous run of tasks sharing the same `@context` becomes one fold, toggleable with stock `za`. Completed (`x `) and hidden (`h:1`, future `t:`) tasks remain folded-on-open as they are today — they just move to a deeper fold level so they nest correctly under a context fold.

Intent: let the user sort with `-s@` (which already groups same-context tasks contiguously), place the cursor on any task in that block, and press `za` to hide the whole context. No new keybindings, no new commands, no state to manage.

## User-facing contract

After `-s@`, the buffer looks like:

```
(A) 2026-04-20 task one   @UDD
(B) 2026-04-19 task two   @UDD
    2026-04-18 task three @casa
    2026-04-17 task four  @casa
x 2026-04-10 archived done task
```

On opening the file:

- Both `@UDD` tasks are visible (one level-1 fold, open by default).
- Both `@casa` tasks are visible (another level-1 fold, open by default).
- The completed line is folded away (level 2, closed by default).
- A task with no `@context` stays at level 0 — never folded, always visible.

`za` on any `@UDD` line toggles the two-line `@UDD` fold. `zM` closes all contexts; `zR` opens everything including completed/hidden.

## Fold-level model

| Category                                | Level | Behaviour on open                  |
| --------------------------------------- | ----- | ---------------------------------- |
| Active task with no `@context`          | 0     | Always visible, not a fold         |
| Active task with `@context`             | 1     | Visible, but user can `za` to fold |
| Completed (`x `) or hidden (`h:1`, `t:` in future) | 2     | Folded away on open                |

`vim.opt_local.foldlevel = 1` ensures level 1 is open and level 2 is closed on entry. (`foldlevelstart` is a global option, so we do not touch it — we set the buffer-local `foldlevel` directly from the ftplugin, which runs during file load.) Users can still `zM` / `zR` as usual.

Fold boundaries: two consecutive lines share a fold iff they have the same category key. Category keys:

- `"@" .. context` for active tasks with a context (first `@tag` wins if multiple).
- `"completed"` for `x ...` lines.
- `"hidden"` for lines where `threshold.is_hidden(line)` returns true.
- `nil` for active tasks with no context — these produce fold level 0.

When `lnum == 1` or the category key differs from the previous line, `fold_expr` returns `">"..level` to start a new fold; otherwise it returns `level`.

## Design decisions, explicit

- Multi-context lines: use the first `@tag`. CLAUDE.md's format convention is one `@context` per line; honouring only the first keeps the mapping deterministic and the fold grouping stable under `-s@`.
- Non-contiguous same-context tasks (e.g. if the user hasn't sorted) become separate folds. That is intentional — vim folds are contiguous, and the user confirmed the `-s@`-then-`za` workflow.
- Hidden tasks interleaved with active tasks of the same context: the hidden one becomes a nested level-2 fold inside the level-1 context fold. Closing the context still hides them (level 2 is inside level 1).
- Hidden or completed tasks with no surrounding context fold still get level 2. Vim creates an implicit top-level structure for them; `foldlevel=1` keeps them closed on open — identical to today's behaviour.
- Completed and hidden blocks are kept as separate folds (different category keys) so the fold header can describe what it contains.
- `foldlevel` is set buffer-local only; global vim settings are not touched.

## Fold-text

Replace the current `fold_text()` (which hard-codes `"Completed tasks"` for every fold) with a category-aware header:

- Context fold: `"+-- @UDD  5 tasks "` — prefix, first-line context, count.
- Completed fold: `"+-- 3 completed tasks "`.
- Hidden fold: `"+-- 2 hidden tasks "`.

Implementation reads `getline(v:foldstart)`, classifies it with the same helper, and formats accordingly. `v:folddashes` is preserved as the prefix.

## Module structure

All changes are in existing files. No new module.

`lua/todotxt/init.lua`:

- Add a local helper `category(line)` returning `(key, level)`.
- Rewrite `M.fold_expr(lnum)` to use `category`, honouring `M.config.threshold_fold` as today (when false, fall back to completed-only folding, level 1, matching current legacy behaviour).
- Rewrite `M.fold_text()` to classify `v:foldstart` and format accordingly.

`ftplugin/todo.lua`:

- Set `vim.opt_local.foldlevel = 1` alongside the existing `foldmethod` / `foldexpr` / `foldtext` assignments. `foldlevelstart` is global and is deliberately not touched.

No changes to `threshold.lua`, no new autocmds, no new keybindings.

## Interaction with existing features

- `-s@` / `-s+` / `-sd` / `-sdd`: folding follows whatever order the sort produces. The `-s@` workflow is the natural fit; other sorts still yield valid folds but contexts may be split.
- `sort_hidden_to_bottom`: after this runs, all hidden tasks sit at the end. They collapse into a single level-2 "hidden" fold — better than today's per-line fold.
- `TodoOverdue` / `TodoHidden` extmarks: unaffected. Folding is orthogonal to highlighting.
- Dependency-driven `wf:1` and `(D)`: unaffected. A `(D)` task with `@context` still folds under its context.
- `threshold_fold = false` config path: still works, still folds only `x ` lines at level 1.

## Testing checklist

Manual checks inside `todo.txt`:

1. `-s@`, cursor on any line with `@UDD`, `za` → only the `@UDD` block folds.
2. `zR` → every context opens AND completed/hidden blocks open (both levels).
3. `zM` → every context folds; re-open with `zr` once to get contexts open but completed/hidden still folded.
4. Open the file fresh → contexts visible, completed and hidden blocks folded, same as today for the latter two.
5. Line with no `@context` is never folded.
6. Fold headers show `@tag N tasks` / `N completed tasks` / `N hidden tasks`.
7. `threshold_fold = false` via `setup({ threshold_fold = false })` → only completed lines fold; contexts do not. Legacy path preserved.

## Files to modify

1. `lua/todotxt/init.lua` — rewrite `fold_expr`, rewrite `fold_text`, add `category` helper.
2. `ftplugin/todo.lua` — add `foldlevel` / `foldlevelstart` locals.

No new files. No new keybindings. No public API change (other than fold behaviour, which is what the user asked for).
