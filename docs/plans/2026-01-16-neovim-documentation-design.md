# NEOVIM.md Documentation Design

## Overview

Create a dedicated `NEOVIM.md` guide for the nvim branch's Lua features.

## Target Audience

Power users - assumes vim/neovim basics, covers customisation, highlight overrides, plugin integrations.

## Format

Reference style - organised by feature, quick to scan, tables and code blocks.

## Document Structure

```
NEOVIM.md
├── Overview
│   └── What's different from Vim version
├── Installation
│   ├── Requirements (Neovim 0.7+)
│   ├── Plugin managers (lazy.nvim, packer, vim-plug)
│   └── Branch selection (nvim vs master)
├── Quick Start
│   └── Minimal config to get going
├── Recurring Tasks
│   ├── Pattern reference table (Nd, Nw, Nm, Ny)
│   ├── Normal vs strict mode (+)
│   ├── Date gap preservation (t: to due:)
│   └── Examples with before/after
├── Hidden Tasks
│   ├── Trigger conditions table (t: future, h:1, hide:1)
│   ├── Visual behaviour (dimming, folding, sort position)
│   └── Examples
├── Mappings Reference
│   └── Table of all mappings with descriptions
├── Configuration
│   ├── All options table with defaults
│   ├── setup() examples (minimal, full, conditional)
│   ├── Per-filetype overrides
│   └── Highlight group customisation
│       ├── TodoHidden
│       ├── TodoRecurring
│       └── Colorscheme integration examples
├── Integration Patterns
│   ├── telescope.nvim - fuzzy find tasks by project/context
│   ├── which-key.nvim - discoverable mappings
│   ├── lualine.nvim - status line (hidden task count, overdue count)
│   └── Other todo.txt tools (topydo, todotxt-cli) - coexistence notes
├── Workflow Examples
│   ├── Weekly review pattern (threshold + recurring)
│   ├── Bill payment tracking (strict recurrence)
│   ├── Project templates (hidden until start date)
│   └── Seasonal tasks (yearly recurrence)
├── Troubleshooting
│   ├── Common issues table
│   │   ├── "Recurring not working" - check Neovim version, branch
│   │   ├── "Tasks not hiding" - check date format, today's date
│   │   ├── "Highlights not showing" - check termguicolors, setup()
│   │   └── "Folds not working" - check foldmethod not overridden
│   ├── Debug checklist (verify setup loaded, check health)
│   └── Version compatibility notes
```

## Content Guidelines

- Each feature section starts with quick reference table
- Code examples are copy-paste ready
- Integration snippets are working examples users can adapt
- Troubleshooting uses problem/cause/solution table format
- Workflow examples show complete task lines with context
