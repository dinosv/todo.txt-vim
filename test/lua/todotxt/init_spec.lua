-- test/lua/todotxt/init_spec.lua
describe("todotxt", function()
  local todotxt = require("todotxt")

  describe("setup", function()
    it("accepts empty config", function()
      assert.has_no.errors(function()
        todotxt.setup({})
      end)
    end)

    it("sets default config values", function()
      todotxt.setup({})
      assert.is_true(todotxt.config.auto_recur)
      assert.is_true(todotxt.config.threshold_fold)
      assert.is_true(todotxt.config.threshold_highlight)
    end)

    it("allows overriding config", function()
      todotxt.setup({ auto_recur = false })
      assert.is_false(todotxt.config.auto_recur)
    end)
  end)
end)
