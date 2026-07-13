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

  describe("journal_entry", function()
    it("reorders a done line into '- date x task'", function()
      assert.equals(
        "- 2026-07-13 x enviar informe final +VRS_GSK",
        wiki.journal_entry("x 2026-07-13 enviar informe final +VRS_GSK")
      )
    end)

    it("returns nil for a line that is not completed", function()
      assert.is_nil(wiki.journal_entry("(A) still active +VRS_GSK"))
    end)

    it("falls back to today when the done line has no date", function()
      local dates = require("todotxt.dates")
      assert.equals(
        "- " .. dates.today() .. " x undated task +tag",
        wiki.journal_entry("x undated task +tag")
      )
    end)
  end)

  describe("insert_journal_entry", function()
    it("inserts directly under an existing Registro heading, newest first", function()
      local page = {
        "# VRS_GSK",
        "",
        "## Registro",
        "- 2026-07-10 x reunion kickoff +VRS_GSK",
      }
      local out = wiki.insert_journal_entry(page, "- 2026-07-13 x enviar informe +VRS_GSK")
      assert.same({
        "# VRS_GSK",
        "",
        "## Registro",
        "- 2026-07-13 x enviar informe +VRS_GSK",
        "- 2026-07-10 x reunion kickoff +VRS_GSK",
      }, out)
      -- input not mutated
      assert.equals(4, #page)
    end)

    it("appends the section when the page has no Registro heading", function()
      local out = wiki.insert_journal_entry({ "# VRS_GSK" }, "- 2026-07-13 x tarea +VRS_GSK")
      assert.same({
        "# VRS_GSK",
        "",
        "## Registro",
        "- 2026-07-13 x tarea +VRS_GSK",
      }, out)
    end)
  end)

  describe("page template", function()
    local root

    before_each(function()
      root = vim.fn.tempname()
      vim.fn.mkdir(root .. "/wiki/projects", "p")
      todotxt.setup({ wiki_projects_dir = root .. "/wiki/projects/", wiki_ext = ".md" })
      vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(false, true))
    end)

    after_each(function()
      vim.fn.delete(root, "rf")
    end)

    it("includes a Registro section in newly created pages", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "+VRS_GSK write report" })
      wiki.create_project()
      local page = table.concat(vim.fn.readfile(root .. "/wiki/projects/VRS_GSK.md"), "\n")
      assert.matches("## Registro", page)
    end)
  end)

  describe("journal_done", function()
    local root

    before_each(function()
      root = vim.fn.tempname()
      vim.fn.mkdir(root .. "/wiki/projects", "p")
      todotxt.setup({
        wiki_projects_dir = root .. "/wiki/projects/",
        wiki_ext = ".md",
        wiki_journal = true,
      })
    end)

    after_each(function()
      vim.fn.delete(root, "rf")
      todotxt.setup({ wiki_journal = true })
    end)

    it("writes the entry under Registro in the project page", function()
      vim.fn.writefile({ "# VRS_GSK", "", "## Registro" }, root .. "/wiki/projects/VRS_GSK.md")
      wiki.journal_done("x 2026-07-13 enviar informe +VRS_GSK")
      local page = vim.fn.readfile(root .. "/wiki/projects/VRS_GSK.md")
      assert.equals("- 2026-07-13 x enviar informe +VRS_GSK", page[4])
    end)

    it("does nothing when the project has no wiki page", function()
      wiki.journal_done("x 2026-07-13 tarea +nopage")
      assert.equals(0, vim.fn.filereadable(root .. "/wiki/projects/nopage.md"))
    end)

    it("does nothing when wiki_journal is false", function()
      vim.fn.writefile({ "# VRS_GSK" }, root .. "/wiki/projects/VRS_GSK.md")
      todotxt.setup({ wiki_journal = false })
      wiki.journal_done("x 2026-07-13 tarea +VRS_GSK")
      assert.same({ "# VRS_GSK" }, vim.fn.readfile(root .. "/wiki/projects/VRS_GSK.md"))
    end)

    it("does nothing for a line without a project tag", function()
      wiki.journal_done("x 2026-07-13 tarea sin proyecto")
      -- nothing to assert beyond not erroring and no file appearing
      assert.same({}, vim.fn.glob(root .. "/wiki/projects/*", false, true))
    end)
  end)
end)
