local M = {}

function M.parse_id(line)
  local padded = " " .. line
  return padded:match("%sid:(%S+)")
end

function M.parse_pending(line)
  local padded = " " .. line
  local value = padded:match("%spending:(%S+)")
  if not value then return {} end
  local ids = {}
  for id in value:gmatch("([^,]+)") do
    table.insert(ids, id)
  end
  return ids
end

function M.is_active(line)
  if line == nil or line == "" then return false end
  if line:match("^[xX]%s") then return false end
  return true
end

return M
