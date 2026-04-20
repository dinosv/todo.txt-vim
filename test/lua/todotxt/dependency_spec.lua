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
end)
