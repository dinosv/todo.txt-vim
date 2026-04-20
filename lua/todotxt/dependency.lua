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

function M.collect_active_ids(lines)
  local set = {}
  for _, line in ipairs(lines) do
    if M.is_active(line) then
      local id = M.parse_id(line)
      if id then set[id] = true end
    end
  end
  return set
end

function M.is_blocked(line, active_ids)
  local pending = M.parse_pending(line)
  for _, id in ipairs(pending) do
    if active_ids[id] then return true end
  end
  return false
end

return M
