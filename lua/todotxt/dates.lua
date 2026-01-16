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

return M
