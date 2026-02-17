# CLAUDE.md — todo.txt-vim plugin (nvim branch)

## Overview

Neovim plugin for todo.txt format. Fork at `dinosv/todo.txt-vim`, branch `nvim`.
Combines VimScript (sorting, priorities, mark-done) with Lua modules (recurring tasks, threshold dates, hidden tasks).

## Architecture

```
todo.txt-vim/
├── ftplugin/
│   ├── todo.vim          # VimScript: keybindings, sorting, priorities, mark-done
│   └── todo.lua          # Lua loader: sets up recurring, threshold, folding
├── autoload/todo/
│   └── txt.vim           # Core VimScript functions (mark_done, sort_by_*, prioritize)
├── lua/todotxt/
│   ├── init.lua          # Config and setup()
│   ├── recurrence.lua    # Recurring task logic (rec: tag)
│   ├── threshold.lua     # Hidden/threshold task logic (t: and h:1 tags)
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

## Task format

```
(A) 2026-02-17 +project_tag task description @context due:2026-03-01 t:2026-02-20 rec:+1w wf:1 h:1
```

- `+project_tag`: Project identifier. MUST match wiki filename (see below).
- `@context`: Location/mode (`@UDD`, `@casa`).
- `due:YYYY-MM-DD`: Due date.
- `t:YYYY-MM-DD`: Threshold date (task hidden until this date).
- `rec:+1w`: Recurrence pattern (strict mode with `+`).
- `wf:1`: Waiting-for flag.
- `h:1`: Hidden flag.

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
