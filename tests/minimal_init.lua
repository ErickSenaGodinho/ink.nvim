-- Isolated init: only the plugin and plenary on the runtimepath
-- Run from the repository root
local root = vim.fn.getcwd()
vim.opt.rtp:prepend(root)

local sibling = vim.fn.fnamemodify(root, ":h") .. "/plenary.nvim"

local candidates = {
  vim.env.PLENARY_DIR or "",
  sibling,
  vim.fn.stdpath("data") .. "/lazy/plenary.nvim",
}

local found
for _, dir in ipairs(candidates) do
  if dir ~= "" and vim.fn.isdirectory(dir) == 1 then
    found = dir
    break
  end
end

if not found then
  error("plenary.nvim not found. Tried:\n" .. table.concat(candidates, "\n"))
end

vim.opt.rtp:append(found)
package.path = root .. "/tests/?.lua;" .. package.path
vim.o.swapfile = false
vim.cmd("runtime plugin/plenary.vim")
