local M = {}

local function define_highlights_groups()
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
      highlight default link InkNoteIndicator DiagnosticInfo
      highlight default link InkNoteText Comment
      highlight default link InkBookmark DiagnosticHint
      highlight default link InkGlossaryUnderline Underlined
      highlight default link InkGlossary DiagnosticInfo
      highlight default link InkGlossaryCharacter DiagnosticInfo
      highlight default link InkGlossaryPlace DiagnosticWarn
      highlight default link InkGlossaryConcept DiagnosticHint
      highlight default link InkGlossaryOrg Function
      highlight default link InkGlossaryObject Constant
      highlight default link InkGlossaryEvent Special
      highlight default link InkGlossaryForeign String
      highlight default link InkGlossaryAlias Comment
    ]])

  -- Define user highlight colors
  for color_name, color_def in pairs(require("ink.config").config.highlight_colors) do
    local hl_group = "InkUserHighlight_" .. color_name
    vim.api.nvim_set_hl(0, hl_group, {
      bg = color_def.bg,
      fg = color_def.fg,
    })
  end

  vim.api.nvim_set_hl(0, "InkDimmed", {
    fg = "#666666",
    blend = 30,
  })

  vim.api.nvim_set_hl(0, "InkUserHighlightDim", {
    fg = "#666666",
    bg = "#1d1d1d",
    blend = 50,
  })
end

local function setup_autocmds()
  -- Re-define highlights after colorscheme changes
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("InkHighlights", { clear = true }),
    callback = function()
      define_highlights_groups()
    end,
  })
end

function M.setup()
  define_highlights_groups()
  setup_autocmds()
end

return M
