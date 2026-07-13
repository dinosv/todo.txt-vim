-- test/lua/todotxt/wiki_integration_spec.lua
-- Two-way wiki integration: reverse link, capture, journal, stalled detection.
describe("todotxt.wiki integration", function()
  local todotxt = require("todotxt")
  local wiki = require("todotxt.wiki")

  describe("collect_active_tags", function()
    it("ignores tags that only appear on completed lines", function()
      local tags = wiki.collect_active_tags({
        "task one +alpha",
        "x 2026-07-01 old task +beta",
        "task two +alpha h:1",
      })
      assert.same({ "alpha" }, tags)
    end)
  end)

  describe("active_tasks", function()
    local lines = {
      "(A) 2026-07-01 write report +VRS_GSK @UDD",
      "x 2026-07-02 done thing +VRS_GSK",
      "call client +VRS_GSK due:2026-07-20",
      "unrelated +other",
      "recurring rec:+1w @casa",
    }

    it("returns lnum and text for active lines with the tag", function()
      local tasks = wiki.active_tasks(lines, "VRS_GSK")
      assert.equals(2, #tasks)
      assert.equals(1, tasks[1].lnum)
      assert.equals("(A) 2026-07-01 write report +VRS_GSK @UDD", tasks[1].text)
      assert.equals(3, tasks[2].lnum)
    end)

    it("does not match rec:+1w style tags", function()
      assert.same({}, wiki.active_tasks(lines, "1w"))
    end)
  end)

  describe("tasks_for", function()
    local root

    before_each(function()
      root = vim.fn.tempname()
      vim.fn.mkdir(root, "p")
      todotxt.setup({ todo_file = root .. "/todo.txt" })
    end)

    after_each(function()
      vim.fn.delete(root, "rf")
    end)

    it("reads from the file on disk when no buffer is loaded", function()
      vim.fn.writefile({ "task +alpha", "x 2026-07-01 gone +alpha" }, root .. "/todo.txt")
      local tasks = wiki.tasks_for("alpha")
      assert.equals(1, #tasks)
      assert.equals("task +alpha", tasks[1].text)
    end)

    it("prefers the loaded todo buffer over the file", function()
      vim.fn.writefile({ "stale +alpha" }, root .. "/todo.txt")
      vim.cmd("edit " .. vim.fn.fnameescape(root .. "/todo.txt"))
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "fresh +alpha", "second +alpha" })
      local tasks = wiki.tasks_for("alpha")
      assert.equals(2, #tasks)
      assert.equals("fresh +alpha", tasks[1].text)
      vim.cmd("bwipeout!")
    end)

    it("returns nil when the todo file does not exist", function()
      assert.is_nil(wiki.tasks_for("alpha"))
    end)
  end)
end)
