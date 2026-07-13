# Two-way wiki integration for todo.txt-vim

Date: 2026-07-13
Status: implemented
Scope: nvim branch, Lua side only

## Overview

The existing wiki bridge is one-way: from a todo.txt line, `-wp`/`-wc`/`-wl`
navigate to or create the VimWiki project page named after the `+tag`. This
design adds the reverse direction and two workflow features:

1. Reverse link (`-wt` in a wiki project page): list that project's active
   tasks from todo.txt in a floating window; `<CR>` jumps to the task.
2. Capture (`-wa` in a wiki project page): prompt for task text and append it
   to todo.txt with the creation date and `+tag` added automatically.
3. Done-task journal: when `-x` (or visual `-x`, or `-X`) completes a task
   carrying a `+tag`, the completed line is recorded under a `## Registro`
   section of that project's wiki page.
4. Stalled-project detection: `-wl` additionally flags projects that have no
   remaining active task.

## Conventions relied on

- The `+tag` is identical to the wiki filename stem (existing convention).
- In a wiki project page the tag is derived from the filename: `%:t:r`.
- Project pages live in `config.wiki_projects_dir` with extension
  `config.wiki_ext`; the todo file is `config.todo_file`.
- "Active task" means a non-empty line not starting with `x `/`X `. Hidden
  and threshold tasks (`h:1`, future `t:`) count as active — they are future
  work, not absence of work.

## Architecture

```
plugin/todotxt.lua          NEW — at startup registers an autocmd:
                            BufEnter/BufReadPost pattern
                            wiki_projects_dir .. "*" .. wiki_ext
                            → require("todotxt.wiki").attach(buf)
lua/todotxt/wiki.lua        EXTENDED — attach(), tasks_for(), show_tasks(),
                            capture_task(), journal_done(); list_projects()
                            gains stalled detection; page template gains
                            a "## Registro" section
lua/todotxt/init.lua        config gains wiki_journal = true; setup()
                            re-registers the plugin autocmd so a changed
                            wiki_projects_dir takes effect
ftplugin/todo.lua           the three mark-done mappings call
                            wiki.journal_done(done) for each line that
                            actually transitioned to done
```

Data flow stays one module deep: `wiki.lua` reads the todo file via the
loaded buffer when one exists, else `vim.fn.readfile`; wiki pages are read
and written with `readfile`/`writefile`. No new state, no timers, no
autocmds beyond the single one in `plugin/`.

### Component contracts

- `tasks_for(tag)` → list of `{lnum, text}` for active lines containing
  `+tag` as a whitespace-delimited word (reuses the `iter_tags` pattern, so
  `rec:+1w` and `key:+value` tags cannot false-match). `lnum` refers to the
  current todo buffer if loaded, else to the file on disk.
- `attach(buf)` → sets buffer-local `-wt` and `-wa` mappings. Idempotent.
- `journal_done(done_line)` → side effect on the wiki page only; never
  touches the todo buffer. No-op when `config.wiki_journal` is false.

## Behaviour: `-wt` (show project tasks)

1. Tag = filename stem of the current wiki buffer.
2. Collect `tasks_for(tag)`. If empty, notify "No active tasks for +tag"
   and return.
3. Open a floating window in the `-wl` style (rounded border, centred,
   minimal) listing each task line prefixed with its todo.txt line number.
4. `q`/`<Esc>` close. `<CR>` closes the float and opens todo.txt with
   `tabedit` (matching `-wp`), cursor on the selected task's line.

## Behaviour: `-wa` (capture task from wiki)

1. Tag = filename stem of the current wiki buffer.
2. `vim.ui.input` prompt "New task for +tag: ". Empty or cancelled input is
   a no-op.
3. Build the line: `<today> <text> +tag`, e.g.
   `2026-07-13 llamar al cliente por contrato +VRS_GSK`.
4. Destination:
   - If `config.todo_file` is loaded in a buffer (`bufloaded`), append the
     line to that buffer with `nvim_buf_set_lines` and leave it modified —
     the user saves. This avoids clobbering unsaved edits.
   - Otherwise append to the file on disk (`writefile` with append flag).
5. Notify confirmation including the destination (buffer vs file).

## Behaviour: done-task journal

Trigger: in `ftplugin/todo.lua`, each of the three mark-done mappings
(`-x` normal, `-x` visual, `-X`) calls `wiki.journal_done(done)` for every
line whose text actually changed (lines already done are returned unchanged
by `mark_done` and never journal — this also prevents duplicates).

`journal_done(done_line)`:

1. If `config.wiki_journal` is false, return.
2. Extract the first `+tag` (consistent with `-wp`); no tag → return.
3. If the project's wiki page does not exist, return silently — no page is
   created behind the user's back.
4. Parse `done_line` as `x <date> <task>`; build the entry
   `- <date> x <task>`, e.g. `- 2026-07-13 x enviar informe final +VRS_GSK`.
   If the done line has no completion date (edge case), use today's date.
5. Insert the entry directly under the `## Registro` heading (newest first).
   If the page has no `## Registro` section, append the heading and entry at
   the end of the page.
6. Write the page back with `writefile`.

The page template used by `-wc`/`ensure_page` gains a `## Registro` section
after `## Notas y decisiones`.

If the wiki page is open in a buffer at journal time, the on-disk write will
make that buffer stale; nvim's normal "file changed on disk" handling
applies. This is accepted for v1 (marking done from todo.txt while the same
project's page is being edited is a rare overlap).

## Behaviour: stalled detection in `-wl`

The listing becomes the union of (a) all `+tags` in the todo buffer and
(b) all wiki page stems in `wiki_projects_dir` (via `glob`). Statuses:

```
+VRS_GSK           [wiki exists]
+VRS_OBS           [wiki exists] [stalled]
+english           [no wiki]
+archived_thing    [wiki exists] [stalled]   <- page exists, no task at all
```

`[stalled]` means no active task for that tag exists in the buffer — covers
both orphan pages and tags whose tasks are all completed. `<CR>` keeps its
current behaviour (create page if missing, open it).

## Config additions

```lua
M.config = {
  ...existing...
  wiki_journal = true,  -- append completed +project tasks to the page's Registro
}
```

`setup()` re-registers the `plugin/` autocmd group so a customised
`wiki_projects_dir`/`wiki_ext` takes effect after startup.

## Error handling

- All wiki page writes are guarded: unreadable/unwritable paths degrade to
  a `vim.notify` warning, never an error in the mark-done path (journal
  failures must not block completing a task — wrap in `pcall`).
- `-wt`/`-wa` in a projects-dir buffer whose todo file is missing on disk
  and not loaded: `-wt` notifies "todo file not found"; `-wa` creates the
  file via the append path.

## Testing (manual checklist)

- `-wt` on a page with active tasks → float lists them; `<CR>` jumps to the
  right line in todo.txt.
- `-wt` on a page whose tasks are all completed → "No active tasks" notify.
- `-wa` with todo.txt open and modified → line appended to the buffer,
  buffer stays modified, no disk write.
- `-wa` with todo.txt not loaded → line appended on disk; reopening shows it.
- `-x` on a `+project` task with a wiki page → entry appears at the top of
  `## Registro`; a page without the section gets one appended.
- `-x` on a task whose project has no page → nothing happens.
- `-x` on an already-completed line → no journal entry (no duplicate).
- `-X` with several `+project` tasks → one entry per completed task.
- `-wl` in a buffer where a wiki page's tag has only completed tasks →
  `[stalled]` shown; orphan pages appear in the list.
- `-wc` creates pages containing the `## Registro` section.

## Out of scope

- Journaling into pages for second and later `+tags` on a line.
- Auto-creating wiki pages at journal time.
- Journaling from `-D` (move to done.txt) — completion time is the journal
  point, and `-D` runs after `-x` has already journalled.
- Refreshing an open wiki buffer after a journal write.
