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

  describe("strip_completion", function()
    it("removes x prefix and completion date", function()
      local task = "x 2025-01-16 Pay rent due:2025-01-15 rec:1m"
      local result = recurrence.strip_completion(task)
      assert.equals("Pay rent due:2025-01-15 rec:1m", result)
    end)

    it("preserves priority", function()
      local task = "x 2025-01-16 (A) Pay rent due:2025-01-15 rec:1m"
      local result = recurrence.strip_completion(task)
      assert.equals("(A) Pay rent due:2025-01-15 rec:1m", result)
    end)

    it("returns unchanged if not completed", function()
      local task = "(A) Pay rent due:2025-01-15 rec:1m"
      local result = recurrence.strip_completion(task)
      assert.equals("(A) Pay rent due:2025-01-15 rec:1m", result)
    end)
  end)

  describe("set_tag", function()
    it("updates existing due tag", function()
      local task = "(A) Pay rent due:2025-01-15 rec:1m"
      local result = recurrence.set_tag(task, "due", "2025-02-15")
      assert.equals("(A) Pay rent due:2025-02-15 rec:1m", result)
    end)

    it("updates existing t tag", function()
      local task = "(A) Pay rent t:2025-01-10 due:2025-01-15"
      local result = recurrence.set_tag(task, "t", "2025-02-10")
      assert.equals("(A) Pay rent t:2025-02-10 due:2025-01-15", result)
    end)

    it("adds tag if not present", function()
      local task = "(A) Pay rent rec:1m"
      local result = recurrence.set_tag(task, "due", "2025-02-15")
      assert.equals("(A) Pay rent rec:1m due:2025-02-15", result)
    end)
  end)
end)
