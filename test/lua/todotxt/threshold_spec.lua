describe("todotxt.threshold", function()
  local threshold = require("todotxt.threshold")
  local dates = require("todotxt.dates")

  describe("is_hidden", function()
    before_each(function()
      -- Mock today
      dates._original_today = dates.today
      dates.today = function() return "2025-01-16" end
    end)

    after_each(function()
      dates.today = dates._original_today
    end)

    it("returns true for future threshold", function()
      local task = "(A) Future task t:2025-02-01"
      assert.is_true(threshold.is_hidden(task))
    end)

    it("returns false for past threshold", function()
      local task = "(A) Past task t:2025-01-10"
      assert.is_false(threshold.is_hidden(task))
    end)

    it("returns false for today threshold", function()
      local task = "(A) Today task t:2025-01-16"
      assert.is_false(threshold.is_hidden(task))
    end)

    it("returns true for h:1 tag", function()
      local task = "(A) Hidden task h:1"
      assert.is_true(threshold.is_hidden(task))
    end)

    it("returns true for hide:1 tag", function()
      local task = "(A) Hidden task hide:1"
      assert.is_true(threshold.is_hidden(task))
    end)

    it("returns false for h:0", function()
      local task = "(A) Visible task h:0"
      assert.is_false(threshold.is_hidden(task))
    end)

    it("returns false for task without threshold or hide", function()
      local task = "(A) Normal task"
      assert.is_false(threshold.is_hidden(task))
    end)
  end)
end)
