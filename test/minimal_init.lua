vim.opt.runtimepath:append(".")

-- Try common plenary locations
local plenary_paths = {
  vim.fn.expand("~/.local/share/nvim/site/pack/packer/start/plenary.nvim"),
  vim.fn.expand("~/.local/share/nvim/plugged/plenary.nvim"),
  vim.fn.expand("~/.vim/plugged/plenary.nvim"),
  vim.fn.expand("~/.local/share/nvim/lazy/plenary.nvim"),
}

local found = false
for _, path in ipairs(plenary_paths) do
  if vim.fn.isdirectory(path) == 1 then
    vim.opt.runtimepath:append(path)
    found = true
    break
  end
end

if not found then
  print("Warning: plenary.nvim not found. Tests may fail.")
  print("Searched: " .. table.concat(plenary_paths, ", "))
end
