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
end)
