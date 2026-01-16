describe("todotxt.recurrence", function()
  local recurrence = require("todotxt.recurrence")

  describe("parse_task", function()
    it("extracts rec tag", function()
      local task = "(A) Pay rent due:2025-01-15 rec:1m"
      local tags = recurrence.parse_task(task)
      assert.equals("1m", tags.rec)
    end)

    it("extracts due tag", function()
      local task = "(A) Pay rent due:2025-01-15 rec:1m"
      local tags = recurrence.parse_task(task)
      assert.equals("2025-01-15", tags.due)
    end)

    it("extracts threshold tag", function()
      local task = "(A) Pay rent t:2025-01-10 due:2025-01-15 rec:1m"
      local tags = recurrence.parse_task(task)
      assert.equals("2025-01-10", tags.t)
    end)

    it("returns nil for missing tags", function()
      local task = "(A) Simple task"
      local tags = recurrence.parse_task(task)
      assert.is_nil(tags.rec)
      assert.is_nil(tags.due)
    end)
  end)
end)
