describe("todotxt.dependency", function()
  local dependency = require("todotxt.dependency")

  it("loads as a module", function()
    assert.is_table(dependency)
  end)

  describe("parse_id", function()
    it("extracts id from middle of line", function()
      assert.equals("42", dependency.parse_id("task id:42 more"))
    end)

    it("extracts id at line start", function()
      assert.equals("42", dependency.parse_id("id:42 task"))
    end)

    it("extracts id at line end", function()
      assert.equals("42", dependency.parse_id("task id:42"))
    end)

    it("returns nil when id tag absent", function()
      assert.is_nil(dependency.parse_id("task without id"))
    end)

    it("accepts non-numeric id values", function()
      assert.equals("abc", dependency.parse_id("task id:abc"))
    end)
  end)

  describe("parse_pending", function()
    it("extracts single id", function()
      assert.are.same({"42"}, dependency.parse_pending("task pending:42"))
    end)

    it("extracts comma-separated ids", function()
      assert.are.same({"42", "43", "7"}, dependency.parse_pending("task pending:42,43,7"))
    end)

    it("returns empty list when tag absent", function()
      assert.are.same({}, dependency.parse_pending("task without pending"))
    end)

    it("returns empty list for empty pending value", function()
      assert.are.same({}, dependency.parse_pending("task pending:"))
    end)

    it("matches only the first pending tag", function()
      assert.are.same({"42"}, dependency.parse_pending("task pending:42 pending:43"))
    end)
  end)

  describe("is_active", function()
    it("returns true for a normal task", function()
      assert.is_true(dependency.is_active("(A) task"))
    end)

    it("returns false for a completed task", function()
      assert.is_false(dependency.is_active("x 2026-01-01 task"))
    end)

    it("returns false for an uppercase X completed task", function()
      assert.is_false(dependency.is_active("X 2026-01-01 task"))
    end)

    it("returns false for an empty line", function()
      assert.is_false(dependency.is_active(""))
    end)

    it("returns true for a line that merely contains 'x'", function()
      assert.is_true(dependency.is_active("fix the xray machine"))
    end)
  end)

  describe("collect_active_ids", function()
    it("collects ids from active lines", function()
      local lines = {"(A) task id:1", "(B) task id:2", "task without id"}
      local ids = dependency.collect_active_ids(lines)
      assert.is_true(ids["1"])
      assert.is_true(ids["2"])
    end)

    it("ignores ids on completed lines", function()
      local lines = {"x 2026-01-01 done id:1", "(A) active id:2"}
      local ids = dependency.collect_active_ids(lines)
      assert.is_nil(ids["1"])
      assert.is_true(ids["2"])
    end)

    it("ignores empty lines", function()
      local lines = {"", "(A) active id:1"}
      local ids = dependency.collect_active_ids(lines)
      assert.is_true(ids["1"])
    end)

    it("returns empty table when no ids present", function()
      local lines = {"(A) task one", "(B) task two"}
      local ids = dependency.collect_active_ids(lines)
      assert.are.same({}, ids)
    end)
  end)
end)
