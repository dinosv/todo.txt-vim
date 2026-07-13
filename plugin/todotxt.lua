-- plugin/todotxt.lua
-- Wiki-side mappings (-wt, -wa) for project pages need an autocmd that
-- exists before any project page is opened, hence plugin/ not ftplugin/.
if vim.fn.has("nvim-0.7") ~= 1 then
  return
end

require("todotxt.wiki").register_autocmd()
