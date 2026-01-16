local M = {}

function M.parse_task(line)
  local tags = {}

  tags.rec = line:match("%srec:([^%s]+)") or line:match("^rec:([^%s]+)")
  tags.due = line:match("%sdue:(%d%d%d%d%-%d%d%-%d%d)")
  tags.t = line:match("%st:(%d%d%d%d%-%d%d%-%d%d)")

  return tags
end

return M
