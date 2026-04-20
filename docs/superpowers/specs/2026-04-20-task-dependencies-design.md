# Task dependencies for todo.txt-vim

Date: 2026-04-20
Status: design approved, pending spec review
Scope: nvim branch, Lua side only

## Overview

Add a lightweight task-dependency system on top of the existing todo.txt format. A task gets an `id:N` tag to declare itself as a potential blocker; another task gets `pending:N` (comma-separated list supported) to declare itself blocked until all listed blockers are resolved. While any blocker is unresolved, the plugin mutates the dependent line to carry `wf:1` and — only if no priority is present — prepends `(D)`. When all blockers resolve, the plugin flips `wf:1` to `wf:0`; priority is left untouched.

Intent: reuse the existing `TodoWaitingFor` highlight (via `wf:1`) so blocked tasks appear with the same waiting-for visual treatment, and let the user see blocked tasks sink to the bottom naturally via `(D)` priority sorting.

## User-facing contract

You write two tags by hand:

```
(A) 2026-04-20 +VRS_GSK draft the protocol id:42
2026-04-18 +VRS_GSK circulate the draft pending:42
```

Rules enforced on every `pending:...` line by the plugin:

1. If any listed blocker ID appears on an active (non-completed) line in the current buffer, the dependent is considered blocked.
2. While blocked: ensure `wf:1` on the line (add if absent, flip from `wf:0`); if the line has no priority, prepend `(D) `. Any user-set priority (e.g. `(A)`) is never overwritten.
3. When all blockers resolve (marked done, removed, or the ID never existed — "fail open"): flip `wf:1` to `wf:0`. Do not add `wf:0` to a line that never had a `wf:` tag. Leave priority untouched.
4. A `pending:N` where `N` appears on no active line is treated as resolved. No dangling-reference marker.
5. `id:` and `pending:` tag contents are user-owned. The plugin reads them; it never assigns, increments, or rewrites them.

Design decisions, explicit:

- IDs are user-assigned manually. No auto-assignment keybinding.
- Multi-blocker syntax is comma-separated: `pending:42,43,7`. All must resolve for the dependent to unblock.
- Buffer-only resolution: done.txt is not read. A blocker archived via `-D` disappears from the buffer and falls through the fail-open rule.
- Mutation is driven by `BufEnter` + `TextChanged` (no `TextChangedI`) to avoid cursor jumps and undo bloat while typing.

## Module structure

New file: `lua/todotxt/dependency.lua`. Pure functions, mirrors the style of `threshold.lua` and `recurrence.lua`.

Public API:

```
parse_id(line)              -> id string or nil
parse_pending(line)         -> list of id strings (possibly empty)
is_active(line)             -> bool      -- not completed, not empty
collect_active_ids(lines)   -> set of ids
is_blocked(line, active_ids)-> bool      -- any pending id is in active_ids
apply_blocked(line)         -> new line  -- sets wf:1, adds (D) if no priority
apply_unblocked(line)       -> new line  -- flips wf:1 to wf:0 if present
transform_line(line, active_ids) -> new line
```

`set_tag` is reused from `recurrence.lua` (`require("todotxt.recurrence").set_tag`). If a third module ever needs it, extract to `lua/todotxt/tags.lua` — out of scope for this change.

Integration in `ftplugin/todo.lua`:

- New local function `update_pending(bufnr)` that reads all lines, calls `collect_active_ids` once, walks lines calling `transform_line`, and — only if any line changed — writes back via `nvim_buf_set_lines` guarded by a re-entry flag.
- A new autocmd group registers `update_pending` on `BufEnter` and `TextChanged` (no `TextChangedI`).
- The existing `update_highlights` autocmd is untouched.

No additions to `M.config` in `init.lua`. The behaviour is deterministic; no user-facing options.

## Algorithm

Per update cycle:

```
1. lines = buffer content
2. active_ids = {}
   for each line:
     skip if line matches ^[xX]%s or is empty
     id = parse_id(line)
     if id: active_ids[id] = true
3. new_lines = {}
   changed = false
   for each line:
     if line matches ^[xX]%s or is empty:
       push line; continue
     pending = parse_pending(line)
     if #pending == 0:
       push line; continue
     blocked = any(id in active_ids for id in pending)
     if blocked:
       new_line = set_tag(line, "wf", "1")
       if not new_line:match("^%(%a%)"):
         new_line = "(D) " .. new_line
     else:
       if new_line has " wf:1" boundary:
         new_line = set_tag(line, "wf", "0")
       else:
         new_line = line
     if new_line ~= line: changed = true
     push new_line
4. if changed:
     guard = true
     nvim_buf_set_lines(0, 0, -1, false, new_lines)
     guard = false
```

Properties:

- Idempotent: second run on the same state is a no-op. `apply_blocked` on an already-blocked line finds `wf:1` present and priority present, returns unchanged.
- Re-entry safe: `nvim_buf_set_lines` retriggers `TextChanged`; the module-local `guard` flag causes the autocmd to early-return when we're the writer.
- Single-pass: O(N) to collect, O(N) to transform. Negligible for typical todo.txt sizes (<1000 lines).
- Priority placement: `(D) ` is prepended at line start (todo.txt spec: priority before creation date).
- `apply_unblocked` never adds `wf:0` to a line that lacks a `wf:` tag — keeps pristine lines clean until they've actually cycled through a blocked state.

Interaction with other features:

- Recurring blocker: `recurrence.advance_task` preserves `id:` on the emitted copy, so "weekly X blocks Y" works — dependents stay blocked until the current period's X is done.
- Mark-done (`-x`): completing a blocker transitions its line to `^x ...`, dropping it from `active_ids` on the next cycle; dependents unblock automatically.
- Existing `wf:1` feature (pure waiting-for tasks with no `pending:`): untouched. The plugin never inspects lines without a `pending:` tag.
- `TodoWaitingFor` syntax match in `syntax/todo.vim` targets `wf:1` specifically, so `wf:0` lines do not trigger the highlight. No syntax changes needed.

## Edge cases

- Empty `pending:` value → parse_pending returns empty list → line untouched.
- Whitespace-bearing value (`pending: 42`) → won't match; user must use `pending:42`. Standard todo.txt discipline.
- Multiple `pending:` tags on one line (non-canonical) → `parse_pending` matches the first occurrence only. Canonical form is comma-separated; document in help text.
- Self-reference (`id:5 pending:5`) → permanently blocked until manually marked done. No loop risk (no recursion).
- Mutual cycle (A blocks B, B blocks A) → both remain blocked until one is manually closed.
- Blocker moved to done.txt via `-D` → disappears from the buffer → fail-open → dependents unblock on the next cycle.

## Known limitations

1. If a user manually adds `wf:1` to a line that also has `pending:...` for an independent reason, the plugin will flip it to `wf:0` on unblock. The plugin treats `wf:1` as tool-owned on any line carrying `pending:`. A pure waiting-for task (`wf:1` alone, no `pending:`) is safe — the plugin ignores it entirely.
2. `id:` uniqueness is not enforced. Two lines with `id:42` both count as blockers; dependents unblock only when both are completed. No warning on duplicates.
3. Blockers archived to done.txt are indistinguishable from deleted blockers. Both resolve via the fail-open path.
4. IDs are opaque strings. `id:42` and `id:42a` are distinct. No numeric comparison or zero-padding.

## Testing

New file: `test/lua/todotxt/dependency_spec.lua`, mirroring the busted `describe`/`it` style of existing specs (`threshold_spec.lua`, `recurrence_spec.lua`).

Unit coverage:

- `parse_id`: present / absent / surrounded by other tags.
- `parse_pending`: single / comma-list / empty / missing.
- `collect_active_ids`: mixed active / `x ...` / empty.
- `is_blocked`: all resolved / some resolved / none resolved / missing IDs / empty pending.
- `apply_blocked`: no-priority line (prepends `(D)`), priority line (untouched), `wf:0` → `wf:1`, no-`wf:` → adds `wf:1`.
- `apply_unblocked`: `wf:1` → `wf:0`, no `wf:` → unchanged, priority untouched regardless.
- `transform_line`: full dispatcher with active_ids fixture, covering the four quadrants (blocked/unblocked × has-wf/no-wf).

Integration: not required. The autocmd glue in `ftplugin/todo.lua` is a thin orchestrator over the pure functions; unit coverage on those is sufficient. If a regression is found in the autocmd path later, add a targeted integration test then.

## Files changed

- `lua/todotxt/dependency.lua` — NEW
- `ftplugin/todo.lua` — add `update_pending` function, autocmd registration
- `test/lua/todotxt/dependency_spec.lua` — NEW

No changes to:
- `lua/todotxt/init.lua` (no config keys added)
- `autoload/todo/txt.vim` (VimScript core untouched)
- `syntax/todo.vim` (existing `TodoWaitingFor` already handles the highlight)
- `doc/` (user-facing docs deferred; CLAUDE.md will be updated in the implementation step to reflect the new tags)
