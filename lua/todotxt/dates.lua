local M = {}

function M.today()
  return os.date("%Y-%m-%d")
end

function M.is_future(date_str)
  return date_str > M.today()
end

return M
