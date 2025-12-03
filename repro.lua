-- repro.lua
-- Run with: nvim -u repro.lua

-- Add current directory to runtime path
vim.opt.rtp:prepend(".")

-- Enable true color support
vim.opt.termguicolors = true

-- Setup the plugin
require("ink").setup()

print("ink.nvim loaded! Try :InkOpen <epub_file>")

-- Debug command to inspect extmarks in current buffer
vim.api.nvim_create_user_command("InkDebugHighlights", function()
  local ns_id = vim.api.nvim_create_namespace("ink_nvim")
  local buf = vim.api.nvim_get_current_buf()
  local extmarks = vim.api.nvim_buf_get_extmarks(buf, ns_id, 0, -1, { details = true })

  print("Extmarks in buffer (first 10):")
  for i, mark in ipairs(extmarks) do
    if i <= 10 then
      local id, row, col, details = mark[1], mark[2], mark[3], mark[4]
      print(string.format("  %d: row=%d, col=%d-%d, hl=%s",
        id, row, col, details.end_col or col, details.hl_group or "none"))
    end
  end

  print("\nHighlight groups:")
  for _, name in ipairs({"InkBold", "InkItalic", "InkUnderlined", "InkStrikethrough"}) do
    local hl = vim.api.nvim_get_hl(0, { name = name })
    print(string.format("  %s: %s", name, vim.inspect(hl)))
  end
end, {})

print("Run :InkDebugHighlights after opening EPUB to inspect highlights")
