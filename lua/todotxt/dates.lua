local M = {}

function M.today()
  return os.date("%Y-%m-%d")
end

function M.is_future(date_str)
  return date_str > M.today()
end

function M.parse(date_str)
  local y, m, d = date_str:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
  if y then
    return tonumber(y), tonumber(m), tonumber(d)
  end
  return nil, nil, nil
end

function M.format(year, month, day)
  return string.format("%04d-%02d-%02d", year, month, day)
end

function M.add_days(date_str, days)
  local y, m, d = M.parse(date_str)
  if not y then return nil end
  local time = os.time({ year = y, month = m, day = d })
  local new_time = time + (days * 86400)
  return os.date("%Y-%m-%d", new_time)
end

function M.add_weeks(date_str, weeks)
  return M.add_days(date_str, weeks * 7)
end

local function days_in_month(year, month)
  local days = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
  if month == 2 then
    local is_leap = (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0)
    return is_leap and 29 or 28
  end
  return days[month]
end

function M.add_months(date_str, months)
  local y, m, d = M.parse(date_str)
  if not y then return nil end

  m = m + months
  while m > 12 do
    m = m - 12
    y = y + 1
  end
  while m < 1 do
    m = m + 12
    y = y - 1
  end

  local max_day = days_in_month(y, m)
  d = math.min(d, max_day)

  return M.format(y, m, d)
end

function M.add_years(date_str, years)
  return M.add_months(date_str, years * 12)
end

function M.parse_pattern(pattern)
  local strict = false
  if pattern:sub(1, 1) == "+" then
    strict = true
    pattern = pattern:sub(2)
  end

  local count, unit = pattern:match("^(%d+)([dwmy])$")
  if not count then return nil end

  return {
    count = tonumber(count),
    unit = unit,
    strict = strict,
  }
end

function M.add_relative(date_str, pattern)
  local p = M.parse_pattern(pattern)
  if not p then return nil end

  if p.unit == "d" then
    return M.add_days(date_str, p.count)
  elseif p.unit == "w" then
    return M.add_weeks(date_str, p.count)
  elseif p.unit == "m" then
    return M.add_months(date_str, p.count)
  elseif p.unit == "y" then
    return M.add_years(date_str, p.count)
  end

  return nil
end

function M.diff_days(from_date, to_date)
  local y1, m1, d1 = M.parse(from_date)
  local y2, m2, d2 = M.parse(to_date)
  if not y1 or not y2 then return nil end

  local t1 = os.time({ year = y1, month = m1, day = d1 })
  local t2 = os.time({ year = y2, month = m2, day = d2 })

  return math.floor((t2 - t1) / 86400)
end

return M
