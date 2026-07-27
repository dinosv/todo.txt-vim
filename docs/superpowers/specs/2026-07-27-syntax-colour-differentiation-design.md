# Syntax colour differentiation — design

Date: 2026-07-27
Status: approved

## Problem

With gruvbox (truecolor, dark background), several line components in
todo.txt buffers share or nearly share a colour:

- `+project` (TodoProject) and `@context` (TodoContext) both link to
  `Special` (orange) — identical.
- Dates (TodoDate → `PreProc`, aqua) are near-indistinguishable from the
  (C) line body (TodoPriorityC → `Identifier`, blue).
- The (B) line body (`Statement`, red) sits next to orange
  project/context tags, which read as the same colour at a glance.

Hidden (`h:1`) and waiting-for (`wf:1`) lines are intentionally
single-colour and stay that way.

## Decision

Re-link two highlight groups to different standard groups in
`syntax/todo.vim`. No hardcoded colours, no new configuration; the
syntax file stays colorscheme-agnostic.

| Group | Old link | New link | Gruvbox result |
|-------|----------|----------|----------------|
| TodoDate | PreProc | Type | aqua → yellow |
| TodoContext | Special | String | orange → green |

All other groups are unchanged: TodoPriorityA `Constant` (purple),
TodoPriorityB `Statement` (red), TodoPriorityC `Identifier` (blue),
TodoPriorityD `DiagnosticHint`, TodoProject `Special` (orange),
TodoDone `Comment` (grey), TodoWaitingFor `DiagnosticWarn`
(whole-line), TodoHidden `Comment`, TodoOverdue custom extmark colours.

Resulting hues on one line: priority body purple/red/blue, dates
yellow, `+project` orange, `@context` green — six distinct hues.

## Alternatives considered

- Hardcode gruvbox palette values (`guifg=...`): exact control, but
  breaks silently on colorscheme change or light background. Rejected.
- Conditionally link to `Gruvbox*` groups with fallback: faithful to
  gruvbox but adds conditional logic for marginal gain. Rejected.

## Files to modify

1. `syntax/todo.vim` — change the two `highlight default link` lines.
2. `CLAUDE.md` — update the syntax highlighting table.

`doc/todo.txt` does not document the TodoDate/TodoContext links, so no
help change is needed.

## Testing

Open todo.txt and eyeball a line such as
`(B) 2026-07-27 +proj task @ctx due:2026-08-01`: the line body, both
dates, the project tag and the context tag must each show a distinct
hue. Confirm `wf:1` and `h:1` lines still render as a single colour.
