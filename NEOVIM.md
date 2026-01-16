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

```lua
{
  "dinosv/todo.txt-vim",
  branch = "nvim",
  ft = { "todo", "done" },
  config = function()
    require("todotxt").setup()
  end,
}
```

### packer.nvim

```lua
use {
  "dinosv/todo.txt-vim",
  branch = "nvim",
  ft = { "todo", "done" },
  config = function()
    require("todotxt").setup()
  end,
}
```

### vim-plug

```vim
" In init.vim or .vimrc
if has('nvim')
  Plug 'dinosv/todo.txt-vim', { 'branch': 'nvim' }
else
  Plug 'dinosv/todo.txt-vim', { 'branch': 'master' }
endif
```

Then in `init.lua`:

```lua
require("todotxt").setup()
```

## Quick Start

1. Install the plugin using the `nvim` branch
2. Add `require("todotxt").setup()` to your config
3. Open a `todo.txt` file
4. Add a recurring task: `Pay rent due:2025-01-15 rec:1m`
5. Mark it done with `<localleader>x`
6. Watch the new task appear below
