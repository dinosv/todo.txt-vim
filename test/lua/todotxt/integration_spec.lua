-- test/lua/todotxt/integration_spec.lua
describe("todotxt integration", function()
  local todotxt = require("todotxt")
  local dates = require("todotxt.dates")
  local threshold = require("todotxt.threshold")

  before_each(function()
    todotxt.setup({})
    dates._original_today = dates.today
    dates.today = function() return "2025-01-16" end
  end)

  after_each(function()
    dates.today = dates._original_today
  end)

  describe("full workflow", function()
    it("marks recurring task done and creates new one", function()
      local task = "(A) Pay rent t:2025-01-10 due:2025-01-15 rec:1m"
      local done, new = todotxt.mark_done(task)

      -- Done task
      assert.matches("^x 2025%-01%-16", done)
      assert.matches("Pay rent", done)

      -- New task has updated dates
      assert.matches("%(A%)", new)
      assert.matches("t:2025%-02%-11", new)
      assert.matches("due:2025%-02%-16", new)
      assert.matches("rec:1m", new)

      -- New task is hidden (threshold in future)
      assert.is_true(threshold.is_hidden(new))
    end)

    it("handles strict recurrence", function()
      local task = "(A) Pay rent due:2025-01-15 rec:+1m"
      local done, new = todotxt.mark_done(task)

      -- Strict: based on original due date, not today
      assert.matches("due:2025%-02%-15", new)
    end)
  end)
end)
