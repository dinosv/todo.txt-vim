local M = {}

function M.parse_task(line)
  local tags = {}

  tags.rec = line:match("%srec:([^%s]+)") or line:match("^rec:([^%s]+)")
  tags.due = line:match("%sdue:(%d%d%d%d%-%d%d%-%d%d)")
  tags.t = line:match("%st:(%d%d%d%d%-%d%d%-%d%d)")

  return tags
end

function M.strip_completion(line)
  -- Match: x YYYY-MM-DD optionally followed by (priority)
  local result = line:gsub("^x%s+%d%d%d%d%-%d%d%-%d%d%s+", "")
  return result
end

function M.set_tag(line, tag, value)
  local pattern = "(%s)" .. tag .. ":[^%s]+"
  local replacement = "%1" .. tag .. ":" .. value

  local result, count = line:gsub(pattern, replacement)
  if count == 0 then
    result = line .. " " .. tag .. ":" .. value
  end

  return result
end

return M
