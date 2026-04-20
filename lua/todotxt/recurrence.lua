local M = {}
local dates = require("todotxt.dates")

function M.parse_task(line)
  local padded = " " .. line
  local tags = {}

  tags.rec = padded:match("%srec:([^%s]+)")
  tags.due = padded:match("%sdue:(%d%d%d%d%-%d%d%-%d%d)")
  tags.t = padded:match("%st:(%d%d%d%d%-%d%d%-%d%d)")

  return tags
end

function M.strip_completion(line)
  local result = line:gsub("^x%s+%d%d%d%d%-%d%d%-%d%d%s+", "")
  return result
end

function M.set_tag(line, tag, value)
  local padded = " " .. line
  local pattern = "(%s)" .. tag .. ":[^%s]+"
  local replacement = "%1" .. tag .. ":" .. value

  local result, count = padded:gsub(pattern, replacement)
  if count == 0 then
    return line .. " " .. tag .. ":" .. value
  end

  return result:sub(2)
end

local function update_creation_date(line, today)
  local with_priority, n = line:gsub("^(%(%a%)%s+)%d%d%d%d%-%d%d%-%d%d", "%1" .. today)
  if n > 0 then
    return with_priority
  end
  return (line:gsub("^%d%d%d%d%-%d%d%-%d%d", today))
end

function M.advance_task(line)
  local tags = M.parse_task(line)
  if not tags.rec then return nil end

  local pattern = dates.parse_pattern(tags.rec)
  if not pattern then return nil end

  local base_date
  if pattern.strict and tags.due then
    base_date = tags.due
  else
    base_date = dates.today()
  end

  local new_due = dates.add_relative(base_date, tags.rec)
  if not new_due then return nil end

  local new_task = M.strip_completion(line)
  new_task = update_creation_date(new_task, dates.today())
  new_task = M.set_tag(new_task, "due", new_due)

  if tags.t and tags.due then
    local gap = dates.diff_days(tags.t, tags.due)
    local new_t = dates.add_days(new_due, -gap)
    new_task = M.set_tag(new_task, "t", new_t)
  end

  return new_task
end

return M
