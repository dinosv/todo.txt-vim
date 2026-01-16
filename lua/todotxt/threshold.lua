local dates = require("todotxt.dates")

local M = {}

function M.is_hidden(line)
  -- Check h:1 or hide:1
  if line:match("%sh:1") or line:match("%shide:1") then
    return true
  end
  if line:match("^h:1") or line:match("^hide:1") then
    return true
  end

  -- Check future threshold
  local t = line:match("%st:(%d%d%d%d%-%d%d%-%d%d)")
  if t and dates.is_future(t) then
    return true
  end

  return false
end

return M
