local M = {}

function M.parse_id(line)
  local padded = " " .. line
  return padded:match("%sid:(%S+)")
end

return M
