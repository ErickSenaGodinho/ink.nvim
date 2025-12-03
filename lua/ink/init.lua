local epub = require("ink.epub")
local ui = require("ink.ui")

local M = {}

local default_config = {
  focused_mode = true,
  image_open = true,
  keymaps = {
    next_chapter = "]c",
    prev_chapter = "[c",
    toggle_toc = "<leader>t",
    activate = "<CR>"
  },
  max_width = 120
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", default_config, opts or {})
  ui.setup(M.config)

  -- Function to define highlights
  local function define_highlights()
    vim.cmd([[
      highlight default link InkTitle Title
      highlight default link InkH1 Title
      highlight default link InkH2 Constant
      highlight default link InkH3 Identifier
      highlight default link InkH4 Statement
      highlight default link InkH5 PreProc
      highlight default link InkH6 Type
      highlight default link InkStatement Statement
      highlight default link InkComment Comment
      highlight default link InkSpecial Special
      highlight default link InkListItem Special
      highlight default link InkHorizontalRule Comment
      highlight default link InkCode String
      highlight default link InkHighlight Search
      highlight! InkBold cterm=bold gui=bold
      highlight! InkItalic cterm=italic gui=italic
      highlight! InkUnderlined cterm=underline gui=underline
      highlight! InkStrikethrough cterm=strikethrough gui=strikethrough
    ]])
  end

  -- Define highlights initially
  define_highlights()

  -- Re-define highlights after colorscheme changes
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("InkHighlights", { clear = true }),
    callback = function()
      define_highlights()
    end
  })
  
  -- Create Command
  vim.api.nvim_create_user_command("InkOpen", function(args)
    local path = args.args
    if path == "" then
      -- If no path, maybe open file picker? For now just error.
      vim.notify("Please provide an EPUB file path", vim.log.levels.ERROR)
      return
    end
    
    -- Expand path
    path = vim.fn.expand(path)
    
    local ok, data = pcall(epub.open, path)
    if not ok then
      vim.notify("Failed to open EPUB: " .. data, vim.log.levels.ERROR)
      return
    end
    
    ui.open_book(data)
    
  end, {
    nargs = 1,
    complete = "file"
  })
end

return M
