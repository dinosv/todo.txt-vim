local M = {}

local recurrence = require("todotxt.recurrence")

function M.parse_id(line)
  local padded = " " .. line
  return padded:match("%sid:(%S+)")
end

function M.parse_pid(line)
  local padded = " " .. line
  local value = padded:match("%spid:(%S+)")
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
  local pids = M.parse_pid(line)
  for _, id in ipairs(pids) do
    if active_ids[id] then return true end
  end
  return false
end

function M.apply_blocked(line)
  local new_line = recurrence.set_tag(line, "wf", "1")
  if not new_line:match("^%(%a%)") then
    new_line = "(D) " .. new_line
  end
  return new_line
end

function M.apply_unblocked(line)
  local padded = " " .. line
  if padded:match("%swf:1%s") or padded:match("%swf:1$") then
    return recurrence.set_tag(line, "wf", "0")
  end
  return line
end

function M.transform_line(line, active_ids)
  if not M.is_active(line) then return line end
  local pids = M.parse_pid(line)
  if #pids == 0 then return line end
  if M.is_blocked(line, active_ids) then
    return M.apply_blocked(line)
  else
    return M.apply_unblocked(line)
  end
end

return M
