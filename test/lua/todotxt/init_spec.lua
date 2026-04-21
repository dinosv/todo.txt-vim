-- test/lua/todotxt/init_spec.lua
describe("todotxt", function()
  local todotxt = require("todotxt")

  describe("mark_done", function()
    local dates = require("todotxt.dates")

    before_each(function()
      dates._original_today = dates.today
      dates.today = function() return "2025-01-16" end
      todotxt.setup({})
    end)

    after_each(function()
      dates.today = dates._original_today
    end)

    it("returns completed task and new recurring task", function()
      local task = "(A) Pay rent due:2025-01-15 rec:1m"
      local done, new = todotxt.mark_done(task)

      assert.matches("^x 2025%-01%-16", done)
      assert.matches("Pay rent", done)
      assert.matches("due:2025%-02%-16", new)
      assert.matches("rec:1m", new)
    end)

    it("returns only completed task for non-recurring", function()
      local task = "(A) Simple task"
      local done, new = todotxt.mark_done(task)

      assert.matches("^x 2025%-01%-16", done)
      assert.is_nil(new)
    end)

    it("respects auto_recur config", function()
      todotxt.setup({ auto_recur = false })
      local task = "(A) Pay rent due:2025-01-15 rec:1m"
      local done, new = todotxt.mark_done(task)

      assert.matches("^x", done)
      assert.is_nil(new)
    end)
  end)

  describe("setup", function()
    before_each(function()
      -- Reset config to defaults before each test
      todotxt.config = {
        auto_recur = true,
        threshold_fold = true,
        threshold_highlight = true,
      }
    end)

    it("accepts empty config", function()
      assert.has_no.errors(function()
        todotxt.setup({})
      end)
    end)

    it("sets default config values", function()
      todotxt.setup({})
      assert.is_true(todotxt.config.auto_recur)
      assert.is_true(todotxt.config.threshold_fold)
      assert.is_true(todotxt.config.threshold_highlight)
    end)

    it("allows overriding config", function()
      todotxt.setup({ auto_recur = false })
      assert.is_false(todotxt.config.auto_recur)
    end)
  end)

  describe("category", function()
    local dates = require("todotxt.dates")

    before_each(function()
      dates._original_today = dates.today
      dates.today = function() return "2026-04-20" end
    end)

    after_each(function()
      dates.today = dates._original_today
    end)

    it("returns nil key and level 0 for active task with no context", function()
      local key, level = todotxt.category("(A) 2026-04-20 plain task")
      assert.is_nil(key)
      assert.equals(0, level)
    end)

    it("returns @context key and level 1 for active task with one context", function()
      local key, level = todotxt.category("(A) 2026-04-20 task @UDD")
      assert.equals("@UDD", key)
      assert.equals(1, level)
    end)

    it("returns first @context when several are present", function()
      local key, level = todotxt.category("task @casa @work")
      assert.equals("@casa", key)
      assert.equals(1, level)
    end)

    it("returns completed key and level 2 for x-prefixed line", function()
      local key, level = todotxt.category("x 2026-04-19 done task @UDD")
      assert.equals("completed", key)
      assert.equals(2, level)
    end)

    it("returns hidden key and level 2 for h:1", function()
      local key, level = todotxt.category("(A) 2026-04-20 task @UDD h:1")
      assert.equals("hidden", key)
      assert.equals(2, level)
    end)

    it("returns hidden key and level 2 for future threshold", function()
      local key, level = todotxt.category("(A) 2026-04-20 task t:2026-05-01")
      assert.equals("hidden", key)
      assert.equals(2, level)
    end)

    it("treats t: in the past as not hidden", function()
      local key, level = todotxt.category("(A) 2026-04-20 task @UDD t:2026-04-01")
      assert.equals("@UDD", key)
      assert.equals(1, level)
    end)

    it("returns nil key and level 0 for empty line", function()
      local key, level = todotxt.category("")
      assert.is_nil(key)
      assert.equals(0, level)
    end)
  end)

  describe("fold_expr", function()
    local dates = require("todotxt.dates")
    local bufnr

    local function set_buffer(lines)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    end

    before_each(function()
      dates._original_today = dates.today
      dates.today = function() return "2026-04-20" end
      bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(bufnr)
      todotxt.setup({})
    end)

    after_each(function()
      dates.today = dates._original_today
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("returns 0 for a line with no category", function()
      set_buffer({ "(A) 2026-04-20 plain task" })
      assert.equals(0, todotxt.fold_expr(1))
    end)

    it("starts a level-1 fold on the first @context line", function()
      set_buffer({ "(A) task @UDD" })
      assert.equals(">1", todotxt.fold_expr(1))
    end)

    it("stays at level 1 for contiguous same-@context lines", function()
      set_buffer({
        "(A) task one @UDD",
        "(B) task two @UDD",
      })
      assert.equals(">1", todotxt.fold_expr(1))
      assert.equals(1,    todotxt.fold_expr(2))
    end)

    it("starts a new level-1 fold when @context changes", function()
      set_buffer({
        "(A) task one @UDD",
        "(B) task two @casa",
      })
      assert.equals(">1", todotxt.fold_expr(1))
      assert.equals(">1", todotxt.fold_expr(2))
    end)

    it("starts a level-2 fold for a completed line", function()
      set_buffer({ "x 2026-04-19 done task" })
      assert.equals(">2", todotxt.fold_expr(1))
    end)

    it("keeps contiguous completed lines in one level-2 fold", function()
      set_buffer({
        "x 2026-04-19 done one",
        "x 2026-04-18 done two",
      })
      assert.equals(">2", todotxt.fold_expr(1))
      assert.equals(2,    todotxt.fold_expr(2))
    end)

    it("separates completed and hidden into different level-2 folds", function()
      set_buffer({
        "x 2026-04-19 done one",
        "(A) 2026-04-20 task @UDD h:1",
      })
      assert.equals(">2", todotxt.fold_expr(1))
      assert.equals(">2", todotxt.fold_expr(2))
    end)

    it("drops to level 0 for a no-context line after a context fold", function()
      set_buffer({
        "(A) task @UDD",
        "(B) plain task",
      })
      assert.equals(">1", todotxt.fold_expr(1))
      assert.equals(0,    todotxt.fold_expr(2))
    end)

    it("falls back to completed-only folding when threshold_fold is false", function()
      todotxt.setup({ threshold_fold = false })
      set_buffer({
        "(A) task @UDD",
        "x 2026-04-19 done",
      })
      assert.equals(0, todotxt.fold_expr(1))
      assert.equals(1, todotxt.fold_expr(2))
    end)
  end)
end)
