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

return M
