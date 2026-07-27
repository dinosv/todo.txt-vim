# Syntax Colour Differentiation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every highlighted component of a todo.txt line a distinct colour under gruvbox by re-linking two highlight groups.

**Architecture:** `syntax/todo.vim` links todo.txt highlight groups to standard Vim groups; the active colorscheme (gruvbox) resolves them to colours. TodoDate moves from `PreProc` (aqua, near-identical to the (C) line's `Identifier` blue) to `Type` (yellow); TodoContext moves from `Special` (orange, identical to TodoProject) to `String` (green). No hardcoded colours, no new configuration.

**Tech Stack:** VimScript syntax file, Neovim 0.12 headless mode for verification.

## Global Constraints

- No hardcoded colour values (`guifg=`/`ctermfg=`) — only `highlight default link` to standard groups.
- Groups that must NOT change: TodoPriorityA (`Constant`), TodoPriorityB (`Statement`), TodoPriorityC (`Identifier`), TodoPriorityD (`DiagnosticHint`), TodoProject (`Special`), TodoDone (`Comment`), TodoWaitingFor (`DiagnosticWarn`).
- Hidden (`h:1`) and waiting-for (`wf:1`) lines stay whole-line single-colour (no change to their match rules).
- Spec: `docs/superpowers/specs/2026-07-27-syntax-colour-differentiation-design.md`.

---

### Task 1: Re-link TodoDate and TodoContext; update CLAUDE.md table

**Files:**
- Modify: `syntax/todo.vim:37-39`
- Modify: `CLAUDE.md` (syntax highlighting table, "## Syntax highlighting" section)

**Interfaces:**
- Consumes: nothing from other tasks (single-task plan).
- Produces: highlight group `TodoDate` linked to `Type`, `TodoContext` linked to `String`. No code consumes these links programmatically.

- [ ] **Step 1: Verify the current (failing) state**

Run this headless check. It prints each group's translated link target; the point is to see the wrong values before the change:

```bash
nvim --headless \
  +'set runtimepath+=/home/dsv/.local/share/nvim/plugged/todo.txt-vim' \
  +'edit /tmp/probe-todo.txt' +'set filetype=todo' \
  +'for g in ["TodoDate","TodoContext","TodoProject"] | echo g . " -> " . synIDattr(synIDtrans(hlID(g)), "name") | endfor' \
  +'q!' 2>&1
```

Expected output (the failing state):

```
TodoDate -> PreProc
TodoContext -> Special
TodoProject -> Special
```

- [ ] **Step 2: Change the two link lines in `syntax/todo.vim`**

The file currently ends with this block (lines 29–39):

```vim
highlight  default  link  TodoDone       Comment
highlight  default  link  TodoWaitingFor  DiagnosticWarn
highlight  default  link  TodoPriorityA  Constant
highlight  default  link  TodoPriorityB  Statement
highlight  default  link  TodoPriorityC  Identifier
" (D) is stamped on blocked tasks by lua/todotxt/dependency.lua, so it
" gets a default colour to stay distinguishable once wf: flips to 0.
highlight  default  link  TodoPriorityD  DiagnosticHint
highlight  default  link  TodoDate       PreProc
highlight  default  link  TodoProject    Special
highlight  default  link  TodoContext    Special
```

Change exactly two lines, keeping the column alignment of the block:

```vim
highlight  default  link  TodoDate       Type
```

and

```vim
highlight  default  link  TodoContext    String
```

All other lines stay byte-identical.

- [ ] **Step 3: Re-run the headless check to verify it passes**

Run the same command as Step 1. Expected output:

```
TodoDate -> Type
TodoContext -> String
TodoProject -> Special
```

TodoProject must still print `Special` — if it changed, Step 2 touched the wrong line.

- [ ] **Step 4: Update the CLAUDE.md syntax highlighting table**

In `CLAUDE.md`, section `## Syntax highlighting`, the table currently has no rows for TodoDate/TodoProject/TodoContext — add them so the table documents the full mapping, and keep existing rows unchanged. The table becomes:

```markdown
| Group | Linked to | Purpose |
|-------|-----------|---------|
| `TodoDone` | `Comment` | Completed tasks (`x ...`) |
| `TodoWaitingFor` | `DiagnosticWarn` | Waiting-for tasks (`wf:1`) |
| `TodoPriorityA` | `Constant` | Priority (A) tasks |
| `TodoPriorityB` | `Statement` | Priority (B) tasks |
| `TodoPriorityC` | `Identifier` | Priority (C) tasks |
| `TodoDate` | `Type` | Dates (creation, `due:`, `t:`) |
| `TodoProject` | `Special` | `+project` tags |
| `TodoContext` | `String` | `@context` tags |
| `TodoHidden` | `Comment` | Hidden/threshold tasks (via extmarks in `ftplugin/todo.lua`) |
| `TodoOverdue` | `#592222` bg / `#ff6666` fg | Overdue `due:` dates on active tasks (via extmarks in `ftplugin/todo.lua`) |
```

- [ ] **Step 5: Visual smoke test**

Open the real todo file and confirm distinct hues on a priority-B line with dates, a project and a context (e.g. `(B) 2026-07-27 +proj task @ctx due:2026-08-01`): line body red, dates yellow, `+proj` orange, `@ctx` green. Confirm a `wf:1` line and an `h:1` line still render single-colour.

```bash
nvim /home/dsv/00000_DATA/00000_GITHUB/00000_SYNC/010_TODOTXT/todo.txt
```

(If running unattended, skip this step; Step 3 is the authoritative check.)

- [ ] **Step 6: Commit**

```bash
git add syntax/todo.vim CLAUDE.md
git commit -m "feat(syntax): distinct colours for dates and contexts

TodoDate PreProc->Type, TodoContext Special->String, so dates no
longer shadow the (C) line colour and @context no longer matches
+project.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```
