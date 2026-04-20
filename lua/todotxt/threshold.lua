local dates = require("todotxt.dates")

local M = {}

function M.is_hidden(line)
  local padded = " " .. line

  if padded:match("%sh:1") or padded:match("%shide:1") then
    return true
  end

  local t = padded:match("%st:(%d%d%d%d%-%d%d%-%d%d)")
  if t and dates.is_future(t) then
    return true
  end

  return false
end

return M
