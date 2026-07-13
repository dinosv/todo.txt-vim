-- test/lua/todotxt/ftplugin_spec.lua
-- Exercises the buffer-local mappings defined in ftplugin/todo.lua
-- through real keystrokes, so visual-mode mark handling is tested
-- as the user experiences it.
describe("todotxt ftplugin mappings", function()
  local function feed(keys)
    local termcodes = vim.api.nvim_replace_termcodes(keys, true, false, true)
    vim.api.nvim_feedkeys(termcodes, "x", false)
  end

  local function setup_buffer(lines)
    vim.g.maplocalleader = "-"
    local buf = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].filetype = "todo"
    return buf
  end

  local function buffer_lines()
    return vim.api.nvim_buf_get_lines(0, 0, -1, false)
  end

  describe("visual <localleader>x", function()
    it("marks the currently selected lines done on first use", function()
      setup_buffer({ "task one", "task two", "task three" })

      feed("ggVj-x")

      local lines = buffer_lines()
      assert.matches("^x %d%d%d%d%-%d%d%-%d%d task one", lines[1])
      assert.matches("^x %d%d%d%d%-%d%d%-%d%d task two", lines[2])
      assert.equals("task three", lines[3])
    end)

    it("acts on the current selection, not a previous one", function()
      setup_buffer({ "task one", "task two", "task three" })

      -- Establish stale '< '> marks on line 1 via a previous selection.
      feed("ggV<Esc>")
      -- Now select line 3 and mark it done.
      feed("GV-x")

      local lines = buffer_lines()
      assert.equals("task one", lines[1])
      assert.equals("task two", lines[2])
      assert.matches("^x %d%d%d%d%-%d%d%-%d%d task three", lines[3])
    end)

    it("leaves visual mode afterwards", function()
      setup_buffer({ "task one" })
      feed("ggV-x")
      assert.equals("n", vim.fn.mode())
    end)
  end)

  describe("fold level", function()
    local todotxt = require("todotxt")

    after_each(function()
      todotxt.setup({ threshold_fold = true })
    end)

    it("opens level-1 context folds by default", function()
      setup_buffer({ "task @UDD" })
      assert.equals(1, vim.wo.foldlevel)
    end)

    it("keeps completed folds closed with threshold_fold = false", function()
      -- The legacy fallback foldexpr gives completed tasks level 1, so
      -- the buffer must start at foldlevel 0 for them to be closed.
      todotxt.setup({ threshold_fold = false })
      setup_buffer({ "task one", "x 2026-01-01 old task" })
      assert.equals(0, vim.wo.foldlevel)
    end)
  end)

  describe("visual <localleader>s", function()
    it("sorts the currently selected lines on first use", function()
      setup_buffer({ "b task", "a task", "z task" })

      feed("ggVj-s")

      local lines = buffer_lines()
      assert.equals("a task", lines[1])
      assert.equals("b task", lines[2])
      assert.equals("z task", lines[3])
    end)
  end)
end)
