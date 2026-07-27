# CLAUDE.md — todo.txt-vim plugin (nvim branch)

## Overview

Neovim plugin for todo.txt format. Fork at `dinosv/todo.txt-vim`, branch `nvim`.
Combines VimScript (sorting, priorities, mark-done) with Lua modules (recurring tasks, threshold dates, hidden tasks).

## Architecture

```
todo.txt-vim/
├── plugin/
│   └── todotxt.lua       # Autocmd setup for wiki two-way integration
├── ftplugin/
│   ├── todo.vim          # VimScript: keybindings, sorting, priorities, mark-done
│   └── todo.lua          # Lua loader: sets up recurring, threshold, folding
├── autoload/todo/
│   └── txt.vim           # Core VimScript functions (mark_done, sort_by_*, prioritize)
├── lua/todotxt/
│   ├── init.lua          # Config and setup()
│   ├── recurrence.lua    # Recurring task logic (rec: tag)
│   ├── threshold.lua     # Hidden/threshold task logic (t: and h:1 tags)
│   ├── dependency.lua    # Task dependencies (id: and pending: tags)
│   ├── wiki.lua          # Wiki navigation and two-way integration
│   └── dates.lua         # Date arithmetic (add_days, add_weeks, add_months, parse_pattern)
├── syntax/todo.vim       # Syntax highlighting (priorities, contexts, projects, dates)
├── ftdetect/todo.vim     # Filetype detection (todo.txt, done.txt)
└── doc/                  # Help documentation
```

## Configuration

- Plugin manager: vim-plug (defined in `~/.vimrc`)
- Local leader: `-` (all todo.txt keybindings use `-` prefix)
- Todo file: `/home/dsv/00000_DATA/00000_GITHUB/00000_SYNC/010_TODOTXT/todo.txt`
- Done file: `/home/dsv/00000_DATA/00000_GITHUB/00000_SYNC/010_TODOTXT/done.txt`

## Existing keybindings (localleader = `-`)

| Key | Action |
|-----|--------|
| `-s` | Sort file |
| `-s@` | Sort by contexts |
| `-s+` | Sort by projects |
| `-sd` | Sort by dates |
| `-sdd` | Sort by due dates |
| `-j` / `-k` | Decrease / increase priority |
| `-a` / `-b` / `-c` | Set priority A / B / C |
| `-d` | Set creation date to today |
| `-x` | Mark as done (triggers recurrence if rec: tag present) |
| `-X` | Mark all as done |
| `-D` | Move completed to done.txt |
| `-wp` | Go to project wiki (todo.txt) |
| `-wc` | Create project wiki (todo.txt) |
| `-wl` | List project wiki status, `[stalled]` = no active task (todo.txt) |
| `-wt` | Show this project's active tasks (wiki project pages) |
| `-wa` | Capture a task for this project into todo.txt (wiki project pages) |

## Task format

```
(A) 2026-02-17 +project_tag task description @context due:2026-03-01 t:2026-02-20 rec:+1w wf:1 h:1 id:42 pid:43
```

- `+project_tag`: Project identifier. MUST match wiki filename (see below).
- `@context`: Location/mode (`@UDD`, `@casa`).
- `due:YYYY-MM-DD`: Due date. Overdue dates (past due, active tasks only) highlighted with `TodoOverdue` (red background, via extmarks in `ftplugin/todo.lua`).
- `t:YYYY-MM-DD`: Threshold date (task hidden until this date).
- `rec:+1w`: Recurrence pattern (strict mode with `+`).
- `wf:1`: Waiting-for flag. Entire line highlighted with `TodoWaitingFor` (linked to `DiagnosticWarn`), active tasks only — completed lines keep `TodoDone`. Defined in `syntax/todo.vim`. Task keeps its position (not folded/hidden).
- `h:1`: Hidden flag. Entire line highlighted with `TodoHidden` (linked to `Comment`). Defined in `ftplugin/todo.lua` via extmarks. Task is folded and sorted to bottom.
- `id:N`: Task identifier used as a dependency anchor. User-assigned; the plugin never generates or renames IDs.
- `pid:N,M,...`: Task blocked until every listed `id:` refers to a line that is either completed (`x ...`) or absent. While any blocker stays active, the plugin stamps `wf:1` (ensuring the `TodoWaitingFor` highlight) and prepends `(D)` if no priority is set. When all blockers resolve, the `wf:1` flips to `wf:0`; priority is not touched — a `(D)` that the plugin added stays on the line until you promote it manually. Logic in `lua/todotxt/dependency.lua`, autocmd in `ftplugin/todo.lua`.

## Syntax highlighting

Defined in `syntax/todo.vim`. Key highlight groups:

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

`TodoWaitingFor` is defined after priority rules in `syntax/todo.vim` so it overrides priority colours for `wf:1` lines.

## Folding

`foldmethod=expr`, driven by `M.fold_expr` in `lua/todotxt/init.lua`:

- Level 1: active tasks with an `@context`. Contiguous same-context tasks share one fold. Open on buffer entry; toggle with `za`.
- Level 2: completed (`x `) and hidden (`h:1`, future `t:`) tasks. Folded on buffer entry.
- Level 0: active tasks with no `@context`. Never folded.

Buffer-local `foldlevel = 1` is set in `ftplugin/todo.lua` so level-1 opens on entry while level-2 stays closed (`foldlevel = 0` when `threshold_fold = false`, whose legacy foldexpr puts completed tasks at level 1). `foldlevelstart` is global and deliberately not touched.

The `-s@` sort groups same-context tasks into contiguous blocks, which is the workflow this folding is designed around. Fold headers are category-aware: `+-- @UDD  N tasks`, `+-- N completed tasks`, `+-- N hidden tasks`.

---

## Modification: Project wiki navigation

### What to build

Add a Lua module `lua/todotxt/wiki.lua` and keybindings in `ftplugin/todo.lua` that link `+project` tags in todo.txt to their corresponding VimWiki pages.

### Critical convention

The `+project` tag in todo.txt is identical to the wiki filename (without extension):

```
+VRS_GSK  -->  ~/00000_DATA/00000_GITHUB/00000_SYNC/020_VIMWIKI/wiki/projects/VRS_GSK.md
+overusing  -->  ~/00000_DATA/00000_GITHUB/00000_SYNC/020_VIMWIKI/wiki/projects/overusing.md
```

### Wiki path

```lua
local wiki_projects_dir = vim.fn.expand("~/00000_DATA/00000_GITHUB/00000_SYNC/020_VIMWIKI/wiki/projects/")
local wiki_ext = ".md"
```

### Keybindings to add

All using `<localleader>` (which is `-`):

| Key | Action | Description |
|-----|--------|-------------|
| `-wp` | Go to project wiki | Extract `+tag` from current line, open its wiki page |
| `-wc` | Create project wiki | Same as `-wp` but create from template if file missing |
| `-wl` | List project status | Show all `+tags` and whether they have a wiki page |

### Behaviour: `-wp` (go to project wiki)

1. Parse current line for the first `+tag` (pattern: `+\zs\S\+` or Lua equivalent `%+(%S+)`).
2. If no `+tag` found, display message and return.
3. Construct path: `wiki_projects_dir .. tag .. wiki_ext`.
4. If file exists, open it with `:edit`.
5. If file does not exist, display message: `"No wiki page for +tag. Use -wc to create."`.

### Behaviour: `-wc` (create project wiki)

1. Same extraction as `-wp`.
2. If file exists, open it.
3. If file does not exist, create it with this template:

```markdown
# Tag Name (humanised)

## Contexto
Descripción breve. Cliente, objetivo, alcance.

## Acciones activas
Ver: `grep '+tag' ~/00000_DATA/00000_GITHUB/00000_SYNC/010_TODOTXT/todo.txt`

## Notas y decisiones

## Referencias
```

4. Open the newly created file.

### Behaviour: `-wl` (list project status)

1. Parse all lines in the buffer for unique `+tags`.
2. For each tag, check if `wiki_projects_dir .. tag .. wiki_ext` exists.
3. Display in a floating window or quickfix list:

```
+VRS_GSK           [wiki exists]
+VRS_OBSERVATORIO  [wiki exists]
+english           [no wiki]
+casa              [no wiki]
```

### Two-way integration

- `-wt`/`-wa` are attached to buffers under `wiki_projects_dir` by a
  `BufEnter` autocmd registered in `plugin/todotxt.lua` (re-registered by
  `setup()`). The project tag is the filename stem.
- `-wa` appends `<today> <text> +tag` to the loaded todo buffer if one
  exists (left unsaved), else to the file on disk.
- Completing a `+project` task (`-x`, visual `-x`, `-X`) appends
  `- <date> x <task>` newest-first under `## Registro` in the project's
  page. No page, no journal — pages are never auto-created. Disable with
  `require("todotxt").setup({ wiki_journal = false })`.
- `-wl` lists the union of buffer tags and wiki pages; `[stalled]` marks
  projects with no active task (hidden/threshold tasks count as active).

### Implementation notes

- Add the module as `lua/todotxt/wiki.lua` following the same pattern as `recurrence.lua` and `threshold.lua`.
- Register keybindings in `ftplugin/todo.lua` alongside existing Lua setup.
- The wiki path should be configurable via `require("todotxt").setup({ wiki_projects_dir = "...", wiki_ext = ".md" })` — extend the existing config table in `lua/todotxt/init.lua`.
- Use `vim.fn.filereadable()` to check file existence.
- Use `vim.fn.matchstr()` or Lua pattern matching for tag extraction.
- For `-wl`, prefer a floating window (`vim.api.nvim_open_win`) for quick display, dismiss with `q` or `<Esc>`.

### Files to modify

1. `lua/todotxt/init.lua` — add `wiki_projects_dir` and `wiki_ext` to `M.config`.
2. `lua/todotxt/wiki.lua` — NEW: all wiki navigation logic.
3. `ftplugin/todo.lua` — register the three new keybindings.

### Testing

- Open todo.txt, place cursor on a line with `+VRS_GSK`, press `-wp` — should open `VRS_GSK.md`.
- On a line with `+casa` (no wiki page), press `-wp` — should show message.
- Press `-wc` on same line — should create file from template and open it.
- Press `-wl` — should show floating window with all tags and their wiki status.
