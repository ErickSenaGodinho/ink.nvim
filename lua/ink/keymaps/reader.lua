local M = {}

local function ui()
  return require("ink.ui")
end

local function map(mode, lhs, rhs, buf, desc)
  vim.keymap.set(mode, lhs, rhs, {
    buffer = buf,
    noremap = true,
    silent = true,
    desc = desc,
  })
end

--- Each entry is either a keymap spec or a `dynamic` block.
---
--- Keymap spec:
---   group   string    key in the plugin config holding the lhs table (e.g. "keymaps")
---   key     string    entry inside that table (e.g. "next_chapter")
---   mode    string?   defaults to "n"
---   desc    string    keymap description
---   run     function? Lua callback          (use `run` OR `cmd`)
---   cmd     string?   Ex command, without ":" and "<CR>"
---   default string?   lhs used when the config does not define one
---   when    function? receives config; keymap is skipped if it returns falsy
---
--- Dynamic block:
---   dynamic function(buf, config) for keymaps generated from config tables
local specs = {
  -- Navigation and basic reading
  {
    group = "keymaps",
    key = "next_chapter",
    desc = "Next chapter",
    run = function()
      ui().next_chapter()
    end,
  },
  {
    group = "keymaps",
    key = "prev_chapter",
    desc = "Previous chapter",
    run = function()
      ui().prev_chapter()
    end,
  },
  {
    group = "keymaps",
    key = "activate",
    desc = "Activate (footnote/link/image)",
    run = function()
      ui().handle_enter()
    end,
  },
  {
    group = "keymaps",
    key = "jump_to_link",
    default = "g<CR>",
    desc = "Jump to link",
    run = function()
      ui().jump_to_link()
    end,
  },
  {
    group = "keymaps",
    key = "search_toc",
    desc = "Search TOC",
    run = function()
      ui().search_toc()
    end,
  },
  {
    group = "keymaps",
    key = "search_content",
    desc = "Search content",
    run = function()
      ui().search_content()
    end,
  },

  -- Layout
  {
    group = "keymaps",
    key = "width_increase",
    desc = "Increase width",
    run = function()
      ui().increase_width()
    end,
  },
  {
    group = "keymaps",
    key = "width_decrease",
    desc = "Decrease width",
    run = function()
      ui().decrease_width()
    end,
  },
  {
    group = "keymaps",
    key = "width_reset",
    desc = "Reset width",
    run = function()
      ui().reset_width()
    end,
  },
  {
    group = "keymaps",
    key = "toggle_justify",
    desc = "Toggle text justification",
    run = function()
      ui().toggle_justify()
    end,
  },

  -- Typography
  {
    group = "typography_keymaps",
    key = "line_spacing_increase",
    desc = "Increase line spacing",
    run = function()
      ui().increase_line_spacing()
    end,
  },
  {
    group = "typography_keymaps",
    key = "line_spacing_decrease",
    desc = "Decrease line spacing",
    run = function()
      ui().decrease_line_spacing()
    end,
  },
  {
    group = "typography_keymaps",
    key = "line_spacing_reset",
    desc = "Reset line spacing",
    run = function()
      ui().reset_line_spacing()
    end,
  },
  {
    group = "typography_keymaps",
    key = "paragraph_spacing_increase",
    desc = "Increase paragraph spacing",
    run = function()
      ui().increase_paragraph_spacing()
    end,
  },
  {
    group = "typography_keymaps",
    key = "paragraph_spacing_decrease",
    desc = "Decrease paragraph spacing",
    run = function()
      ui().decrease_paragraph_spacing()
    end,
  },
  {
    group = "typography_keymaps",
    key = "paragraph_spacing_reset",
    desc = "Reset paragraph spacing",
    run = function()
      ui().reset_paragraph_spacing()
    end,
  },

  -- TOC
  {
    group = "keymaps",
    key = "toggle_toc",
    desc = "Toggle TOC",
    run = function()
      require("ink.ui.floating_toc").toggle_floating_toc()
    end,
  },
  { group = "toc_keymaps", key = "rebuild", desc = "Rebuild TOC", cmd = "InkRebuildTOC" },

  -- Highlights
  {
    dynamic = function(buf, config)
      for color_name, lhs in pairs(config.highlight_keymaps or {}) do
        if color_name == "remove" then
          map("n", lhs, function()
            ui().remove_highlight()
          end, buf, "Remove highlight")
        else
          map("v", lhs, function()
            ui().add_highlight(color_name)
          end, buf, "Highlight " .. color_name)
        end
      end
    end,
  },
  {
    dynamic = function(buf, config)
      for color_name, lhs in pairs(config.highlight_change_color_keymaps or {}) do
        map("n", lhs, function()
          ui().change_highlight_color(color_name)
        end, buf, "Change highlight to " .. color_name)
      end
    end,
  },

  -- Notes
  {
    group = "note_keymaps",
    key = "add",
    mode = "n",
    desc = "Add/edit note",
    run = function()
      ui().add_note()
    end,
  },
  {
    group = "note_keymaps",
    key = "add",
    mode = "v",
    desc = "Add note on selection",
    run = function()
      ui().add_note_on_selection()
    end,
  },
  {
    group = "note_keymaps",
    key = "edit",
    desc = "Edit note",
    run = function()
      ui().edit_note()
    end,
  },
  {
    group = "note_keymaps",
    key = "remove",
    desc = "Remove note",
    run = function()
      ui().remove_note()
    end,
  },
  {
    group = "note_keymaps",
    key = "toggle_display",
    desc = "Toggle note display",
    run = function()
      ui().toggle_note_display()
    end,
  },

  -- Bookmarks
  {
    group = "bookmark_keymaps",
    key = "add",
    desc = "Add bookmark",
    run = function()
      ui().add_bookmark()
    end,
  },
  {
    group = "bookmark_keymaps",
    key = "edit",
    desc = "Edit bookmark",
    run = function()
      ui().edit_bookmark()
    end,
  },
  {
    group = "bookmark_keymaps",
    key = "remove",
    desc = "Remove bookmark",
    run = function()
      ui().remove_bookmark()
    end,
  },
  {
    group = "bookmark_keymaps",
    key = "next",
    desc = "Next bookmark",
    run = function()
      ui().goto_next_bookmark()
    end,
  },
  {
    group = "bookmark_keymaps",
    key = "prev",
    desc = "Previous bookmark",
    run = function()
      ui().goto_prev_bookmark()
    end,
  },

  -- Glossary
  {
    group = "glossary_keymaps",
    key = "add",
    mode = "v",
    desc = "Add glossary from selection",
    run = function()
      ui().add_glossary_from_selection()
    end,
  },
  {
    group = "glossary_keymaps",
    key = "add",
    mode = "n",
    desc = "Add glossary entry",
    run = function()
      ui().add_glossary_under_cursor()
    end,
  },
  {
    group = "glossary_keymaps",
    key = "edit",
    desc = "Edit glossary entry",
    run = function()
      ui().edit_glossary_under_cursor()
    end,
  },
  {
    group = "glossary_keymaps",
    key = "remove",
    desc = "Remove glossary entry",
    run = function()
      ui().remove_glossary_under_cursor()
    end,
  },
  {
    group = "glossary_keymaps",
    key = "preview",
    desc = "Preview glossary entry",
    run = function()
      ui().preview_glossary()
    end,
  },
  {
    group = "glossary_keymaps",
    key = "browser",
    desc = "Browse glossary",
    run = function()
      ui().show_glossary_browser()
    end,
  },
  {
    group = "glossary_keymaps",
    key = "show_related",
    desc = "Show related terms",
    run = function()
      ui().show_term_graph_under_cursor()
    end,
  },
  {
    group = "glossary_keymaps",
    key = "show_graph",
    desc = "Show glossary graph",
    run = function()
      ui().show_glossary_graph()
    end,
  },
  {
    group = "glossary_keymaps",
    key = "toggle_display",
    desc = "Toggle glossary display",
    run = function()
      ui().toggle_glossary_display()
    end,
  },

  -- Per-book lists
  { group = "bookmark_keymaps", key = "list_book", desc = "List book bookmarks", cmd = "InkBookmarksBook" },
  { group = "notes_list_keymaps", key = "list_book", desc = "List book notes", cmd = "InkNotesBook" },

  -- Padnotes (only when enabled)
  {
    group = "padnotes_keymaps",
    key = "list_all",
    desc = "List all padnotes",
    when = function(config)
      return config.padnotes and config.padnotes.enabled
    end,
    run = function()
      require("ink.padnotes").list_all()
    end,
  },
  {
    group = "padnotes_keymaps",
    key = "toggle",
    desc = "Toggle padnote",
    when = function(config)
      return config.padnotes and config.padnotes.enabled
    end,
    run = function()
      require("ink.padnotes").toggle()
    end,
  },
  {
    group = "padnotes_keymaps",
    key = "open",
    desc = "Open padnote",
    when = function(config)
      return config.padnotes and config.padnotes.enabled
    end,
    run = function()
      require("ink.padnotes").open()
    end,
  },
  {
    group = "padnotes_keymaps",
    key = "close",
    desc = "Close padnote",
    when = function(config)
      return config.padnotes and config.padnotes.enabled
    end,
    run = function()
      require("ink.padnotes").close(true)
    end,
  },

  -- Related resources, reading modes and export
  { group = "keymaps", key = "related_resources", desc = "List related resources", cmd = "InkListRelated" },
  { group = "keymaps", key = "toggle_focused_mode", desc = "Toggle focused mode", cmd = "InkToggleFocusedMode" },
  {
    group = "keymaps",
    key = "toggle_reading_paragraph_mode",
    desc = "Toggle reading paragraph mode",
    cmd = "InkToggleParagraphMode",
  },
  { group = "export_keymaps", key = "current_book", desc = "Export current book", cmd = "InkExport" },
}

--- Sets up all book-specific keymaps on the content buffer.
---@param content_buf integer
---@param config? table defaults to the UI context config
function M.setup(content_buf, config)
  config = config or require("ink.ui.context").config or {}

  for _, spec in ipairs(specs) do
    if spec.dynamic then
      spec.dynamic(content_buf, config)
    elseif not spec.when or spec.when(config) then
      local group = config[spec.group] or {}
      local lhs = group[spec.key] or spec.default

      if lhs then
        local rhs = spec.cmd and (":" .. spec.cmd .. "<CR>") or spec.run
        map(spec.mode or "n", lhs, rhs, content_buf, spec.desc)
      end
    end
  end
end

return M
