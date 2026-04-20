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

  describe("is_blocked", function()
    it("returns true when a pending id is active", function()
      local active = {["42"] = true}
      assert.is_true(dependency.is_blocked("task pending:42", active))
    end)

    it("returns false when all pending ids are resolved", function()
      local active = {}
      assert.is_false(dependency.is_blocked("task pending:42", active))
    end)

    it("returns true when at least one of several pending ids is active", function()
      local active = {["43"] = true}
      assert.is_true(dependency.is_blocked("task pending:42,43", active))
    end)

    it("returns false when no pending tag present", function()
      local active = {["42"] = true}
      assert.is_false(dependency.is_blocked("task without pending", active))
    end)

    it("fails open on missing id (not in active_ids)", function()
      local active = {}
      assert.is_false(dependency.is_blocked("task pending:99", active))
    end)
  end)

  describe("apply_blocked", function()
    it("adds wf:1 and (D) to a bare line", function()
      assert.equals("(D) task pending:42 wf:1", dependency.apply_blocked("task pending:42"))
    end)

    it("flips wf:0 to wf:1 without duplicating", function()
      assert.equals("(D) task pending:42 wf:1 more", dependency.apply_blocked("task pending:42 wf:0 more"))
    end)

    it("keeps existing priority instead of prepending (D)", function()
      assert.equals("(A) task pending:42 wf:1", dependency.apply_blocked("(A) task pending:42"))
    end)

    it("is idempotent on an already-blocked line", function()
      local once = dependency.apply_blocked("task pending:42")
      local twice = dependency.apply_blocked(once)
      assert.equals(once, twice)
    end)
  end)

  describe("apply_unblocked", function()
    it("flips wf:1 to wf:0", function()
      assert.equals("task pending:42 wf:0", dependency.apply_unblocked("task pending:42 wf:1"))
    end)

    it("flips wf:1 at line end", function()
      assert.equals("(D) task wf:0", dependency.apply_unblocked("(D) task wf:1"))
    end)

    it("leaves a line without wf: untouched", function()
      assert.equals("task pending:42", dependency.apply_unblocked("task pending:42"))
    end)

    it("leaves priority untouched", function()
      assert.equals("(A) task pending:42 wf:0", dependency.apply_unblocked("(A) task pending:42 wf:1"))
    end)

    it("is idempotent on an already-unblocked line", function()
      local once = dependency.apply_unblocked("task pending:42 wf:1")
      local twice = dependency.apply_unblocked(once)
      assert.equals(once, twice)
    end)
  end)
end)
