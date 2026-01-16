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

  describe("parse", function()
    it("parses YYYY-MM-DD to components", function()
      local y, m, d = dates.parse("2025-03-15")
      assert.equals(2025, y)
      assert.equals(3, m)
      assert.equals(15, d)
    end)

    it("returns nil for invalid format", function()
      local y, m, d = dates.parse("invalid")
      assert.is_nil(y)
    end)
  end)

  describe("format", function()
    it("formats components to YYYY-MM-DD", function()
      assert.equals("2025-03-15", dates.format(2025, 3, 15))
    end)

    it("zero-pads single digit month and day", function()
      assert.equals("2025-01-05", dates.format(2025, 1, 5))
    end)
  end)

  describe("add_days", function()
    it("adds days within same month", function()
      assert.equals("2025-01-15", dates.add_days("2025-01-10", 5))
    end)

    it("rolls over to next month", function()
      assert.equals("2025-02-02", dates.add_days("2025-01-30", 3))
    end)

    it("rolls over year", function()
      assert.equals("2026-01-01", dates.add_days("2025-12-31", 1))
    end)
  end)

  describe("add_weeks", function()
    it("adds weeks", function()
      assert.equals("2025-01-22", dates.add_weeks("2025-01-15", 1))
    end)

    it("adds multiple weeks", function()
      assert.equals("2025-02-12", dates.add_weeks("2025-01-15", 4))
    end)
  end)

  describe("add_months", function()
    it("adds months within same year", function()
      assert.equals("2025-04-15", dates.add_months("2025-01-15", 3))
    end)

    it("rolls over to next year", function()
      assert.equals("2026-02-15", dates.add_months("2025-11-15", 3))
    end)

    it("clamps to last day of shorter month", function()
      assert.equals("2025-02-28", dates.add_months("2025-01-31", 1))
    end)

    it("handles leap year February", function()
      assert.equals("2024-02-29", dates.add_months("2024-01-31", 1))
    end)

    it("handles December to January", function()
      assert.equals("2026-01-15", dates.add_months("2025-12-15", 1))
    end)
  end)

  describe("add_years", function()
    it("adds years", function()
      assert.equals("2027-01-15", dates.add_years("2025-01-15", 2))
    end)

    it("handles leap day to non-leap year", function()
      assert.equals("2025-02-28", dates.add_years("2024-02-29", 1))
    end)
  end)
end)
