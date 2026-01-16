describe("todotxt.dates", function()
  local dates = require("todotxt.dates")

  describe("today", function()
    it("returns current date in YYYY-MM-DD format", function()
      local result = dates.today()
      assert.matches("^%d%d%d%d%-%d%d%-%d%d$", result)
    end)
  end)

  describe("is_future", function()
    it("returns true for future dates", function()
      assert.is_true(dates.is_future("2099-12-31"))
    end)

    it("returns false for past dates", function()
      assert.is_false(dates.is_future("2000-01-01"))
    end)

    it("returns false for today", function()
      assert.is_false(dates.is_future(dates.today()))
    end)
  end)
end)
