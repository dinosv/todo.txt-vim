-- test/lua/todotxt/wiki_spec.lua
describe("todotxt.wiki", function()
  local todotxt = require("todotxt")
  local wiki = require("todotxt.wiki")

  describe("extract_tag", function()
    it("finds a +tag at the start of the line", function()
      assert.equals("VRS_GSK", wiki.extract_tag("+VRS_GSK write report @UDD"))
    end)

    it("finds a +tag mid-line", function()
      assert.equals("overusing", wiki.extract_tag("(A) 2026-01-01 +overusing draft"))
    end)

    it("returns nil when there is no +tag", function()
      assert.is_nil(wiki.extract_tag("water plants @casa"))
    end)

    it("does not treat rec:+1w as a project tag", function()
      assert.is_nil(wiki.extract_tag("water plants @casa rec:+1w due:2026-07-20"))
    end)

    it("finds the real tag on a line that also has rec:+1w", function()
      assert.equals("casa", wiki.extract_tag("water plants +casa rec:+1w"))
    end)
  end)

  describe("collect_tags", function()
    it("returns unique sorted tags, ignoring key:+value tags", function()
      local tags = wiki.collect_tags({
        "task one +beta rec:+1w",
        "task two +alpha",
        "task three +beta t:2026-01-01",
        "recurring only rec:+3d",
      })
      assert.same({ "alpha", "beta" }, tags)
    end)
  end)

  describe("file operations", function()
    local root

    before_each(function()
      root = vim.fn.tempname()
      vim.fn.mkdir(root .. "/wiki/projects", "p")
      todotxt.setup({
        wiki_projects_dir = root .. "/wiki/projects/",
        wiki_ext = ".md",
      })
      vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(false, true))
    end)

    after_each(function()
      vim.fn.delete(root, "rf")
    end)

    it("creates the page under the projects dir when the configured dir lacks a trailing slash", function()
      todotxt.setup({ wiki_projects_dir = root .. "/wiki/projects" })
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "+VRS_GSK write report" })

      wiki.create_project()

      assert.equals(1, vim.fn.filereadable(root .. "/wiki/projects/VRS_GSK.md"))
    end)

    it("indexes a new tag that is a prefix of an already-indexed tag", function()
      vim.fn.writefile({
        "# Wiki",
        "",
        "## Projects",
        "- [VRS_GSK](projects/VRS_GSK)",
        "---",
      }, root .. "/wiki/index.md")
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "+VRS general admin" })

      wiki.create_project()

      local index = table.concat(vim.fn.readfile(root .. "/wiki/index.md"), "\n")
      assert.matches("%[VRS%]%(projects/VRS%)", index)
    end)

    it("does not duplicate an index entry for an already-indexed tag", function()
      vim.fn.writefile({
        "# Wiki",
        "",
        "## Projects",
        "- [VRS_GSK](projects/VRS_GSK)",
        "---",
      }, root .. "/wiki/index.md")
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "+VRS_GSK follow up" })

      wiki.create_project()

      local count = 0
      for _, l in ipairs(vim.fn.readfile(root .. "/wiki/index.md")) do
        if l:find("(projects/VRS_GSK)", 1, true) then
          count = count + 1
        end
      end
      assert.equals(1, count)
    end)
  end)
end)
