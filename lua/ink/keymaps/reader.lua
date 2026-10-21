local M = {}

-- Setup all book-specific keymaps
function M.setup_book_keymaps(content_buf, context)
  local keymaps = context.config.keymaps or {}

  if keymaps.next_chapter then
    vim.keymap.set("n", keymaps.next_chapter, function()
      require("ink.ui").next_chapter()
    end, { buffer = content_buf, noremap = true, silent = true, desc = "Next chapter" })
  end
  if keymaps.prev_chapter then
    vim.keymap.set("n", keymaps.prev_chapter, function()
      require("ink.ui").prev_chapter()
    end, { buffer = content_buf, noremap = true, silent = true, desc = "Previous chapter" })
  end
  if keymaps.activate then
    vim.keymap.set("n", keymaps.activate, function()
      require("ink.ui").handle_enter()
    end, { buffer = content_buf, noremap = true, silent = true, desc = "Activate (footnote/link/image)" })
  end

  local jump_key = keymaps.jump_to_link or "g<CR>"
  vim.keymap.set("n", jump_key, function()
    require("ink.ui").jump_to_link()
  end, { buffer = content_buf, noremap = true, silent = true, desc = "Jump to link" })

  if keymaps.search_toc then
    vim.keymap.set("n", keymaps.search_toc, function()
      require("ink.ui").search_toc()
    end, { buffer = content_buf, noremap = true, silent = true, desc = "Search TOC" })
  end
  if keymaps.search_content then
    vim.keymap.set("n", keymaps.search_content, function()
      require("ink.ui").search_content()
    end, { buffer = content_buf, noremap = true, silent = true, desc = "Search content" })
  end
  if keymaps.width_increase then
    vim.keymap.set("n", keymaps.width_increase, function()
      require("ink.ui").increase_width()
    end, { buffer = content_buf, noremap = true, silent = true, desc = "Increase width" })
  end
  if keymaps.width_decrease then
    vim.keymap.set("n", keymaps.width_decrease, function()
      require("ink.ui").decrease_width()
    end, { buffer = content_buf, noremap = true, silent = true, desc = "Decrease width" })
  end
  if keymaps.width_reset then
    vim.keymap.set("n", keymaps.width_reset, function()
      require("ink.ui").reset_width()
    end, { buffer = content_buf, noremap = true, silent = true, desc = "Reset width" })
  end
  if keymaps.toggle_justify then
    vim.keymap.set("n", keymaps.toggle_justify, function()
      require("ink.ui").toggle_justify()
    end, { buffer = content_buf, noremap = true, silent = true, desc = "Toggle text justification" })
  end

  -- Typography keymaps
  local typography_keymaps = context.config.typography_keymaps or {}
  if typography_keymaps.line_spacing_increase then
    vim.keymap.set("n", typography_keymaps.line_spacing_increase, function()
      require("ink.ui").increase_line_spacing()
    end, { buffer = content_buf, noremap = true, silent = true, desc = "Increase line spacing" })
  end
  if typography_keymaps.line_spacing_decrease then
    vim.keymap.set("n", typography_keymaps.line_spacing_decrease, function()
      require("ink.ui").decrease_line_spacing()
    end, { buffer = content_buf, noremap = true, silent = true, desc = "Decrease line spacing" })
  end
  if typography_keymaps.line_spacing_reset then
    vim.keymap.set("n", typography_keymaps.line_spacing_reset, function()
      require("ink.ui").reset_line_spacing()
    end, { buffer = content_buf, noremap = true, silent = true, desc = "Reset line spacing" })
  end
  if typography_keymaps.paragraph_spacing_increase then
    vim.keymap.set("n", typography_keymaps.paragraph_spacing_increase, function()
      require("ink.ui").increase_paragraph_spacing()
    end, { buffer = content_buf, noremap = true, silent = true, desc = "Increase paragraph spacing" })
  end
  if typography_keymaps.paragraph_spacing_decrease then
    vim.keymap.set("n", typography_keymaps.paragraph_spacing_decrease, function()
      require("ink.ui").decrease_paragraph_spacing()
    end, { buffer = content_buf, noremap = true, silent = true, desc = "Decrease paragraph spacing" })
  end
  if typography_keymaps.paragraph_spacing_reset then
    vim.keymap.set("n", typography_keymaps.paragraph_spacing_reset, function()
      require("ink.ui").reset_paragraph_spacing()
    end, { buffer = content_buf, noremap = true, silent = true, desc = "Reset paragraph spacing" })
  end

  -- TOC toggle keymap
  if keymaps.toggle_toc then
    vim.keymap.set("n", keymaps.toggle_toc, function()
      require("ink.ui.floating_toc").toggle_floating_toc()
    end, { buffer = content_buf, noremap = true, silent = true, desc = "Toggle TOC" })
  end

  -- TOC rebuild keymap
  local toc_keymaps = context.config.toc_keymaps or {}
  if toc_keymaps.rebuild then
    vim.keymap.set(
      "n",
      toc_keymaps.rebuild,
      ":InkRebuildTOC<CR>",
      { buffer = content_buf, noremap = true, silent = true, desc = "Rebuild TOC" }
    )
  end

  -- Highlight keymaps
  local highlight_keymaps = context.config.highlight_keymaps or {}
  for color_name, keymap in pairs(highlight_keymaps) do
    if color_name == "remove" then
      vim.keymap.set("n", keymap, function()
        require("ink.ui").remove_highlight()
      end, { buffer = content_buf, noremap = true, silent = true, desc = "Remove highlight" })
    else
      vim.keymap.set("v", keymap, function()
        require("ink.ui").add_highlight(color_name)
      end, { buffer = content_buf, noremap = true, silent = true, desc = "Highlight " .. color_name })
    end
  end

  -- Change highlight color keymaps
  local highlight_change_color_keymaps = context.config.highlight_change_color_keymaps or {}
  for color_name, keymap in pairs(highlight_change_color_keymaps) do
    vim.keymap.set("n", keymap, function()
      require("ink.ui").change_highlight_color(color_name)
    end, { buffer = content_buf, noremap = true, silent = true, desc = "Change highlight to " .. color_name })
  end

  -- Note keymaps
  local note_keymaps = context.config.note_keymaps or {}
  if note_keymaps.add then
    vim.keymap.set("n", note_keymaps.add, function()
      require("ink.ui").add_note()
    end, { buffer = content_buf, noremap = true, silent = true, desc = "Add/edit note" })
    vim.keymap.set("v", note_keymaps.add, function()
      require("ink.ui").add_note_on_selection()
    end, { buffer = content_buf, noremap = true, silent = true, desc = "Add note on selection" })
  end
  if note_keymaps.edit then
    vim.keymap.set("n", note_keymaps.edit, function()
      require("ink.ui").edit_note()
    end, { buffer = content_buf, noremap = true, silent = true, desc = "Edit note" })
  end
  if note_keymaps.remove then
    vim.keymap.set("n", note_keymaps.remove, function()
      require("ink.ui").remove_note()
    end, { buffer = content_buf, noremap = true, silent = true, desc = "Remove note" })
  end
  if note_keymaps.toggle_display then
    vim.keymap.set("n", note_keymaps.toggle_display, function()
      require("ink.ui").toggle_note_display()
    end, { buffer = content_buf, noremap = true, silent = true, desc = "Toggle note display" })
  end

  -- Bookmark keymaps
  local bookmark_keymaps = context.config.bookmark_keymaps or {}
  if bookmark_keymaps.add then
    vim.keymap.set("n", bookmark_keymaps.add, function()
      require("ink.ui").add_bookmark()
    end, { buffer = content_buf, noremap = true, silent = true, desc = "Add bookmark" })
  end
  if bookmark_keymaps.edit then
    vim.keymap.set("n", bookmark_keymaps.edit, function()
      require("ink.ui").edit_bookmark()
    end, { buffer = content_buf, noremap = true, silent = true, desc = "Edit bookmark" })
  end
  if bookmark_keymaps.remove then
    vim.keymap.set("n", bookmark_keymaps.remove, function()
      require("ink.ui").remove_bookmark()
    end, { buffer = content_buf, noremap = true, silent = true, desc = "Remove bookmark" })
  end
  if bookmark_keymaps.next then
    vim.keymap.set("n", bookmark_keymaps.next, function()
      require("ink.ui").goto_next_bookmark()
    end, { buffer = content_buf, noremap = true, silent = true, desc = "Next bookmark" })
  end
  if bookmark_keymaps.prev then
    vim.keymap.set("n", bookmark_keymaps.prev, function()
      require("ink.ui").goto_prev_bookmark()
    end, { buffer = content_buf, noremap = true, silent = true, desc = "Previous bookmark" })
  end
  if bookmark_keymaps.list_book then
    vim.keymap.set(
      "n",
      bookmark_keymaps.list_book,
      ":InkBookmarksBook<CR>",
      { buffer = content_buf, noremap = true, silent = true, desc = "List book bookmarks" }
    )
  end

  -- Notes list keymap
  local notes_list_keymaps = context.config.notes_list_keymaps or {}
  if notes_list_keymaps.list_book then
    vim.keymap.set(
      "n",
      notes_list_keymaps.list_book,
      ":InkNotesBook<CR>",
      { buffer = content_buf, noremap = true, silent = true, desc = "List book notes" }
    )
  end

  -- Glossary keymaps
  local glossary_keymaps = context.config.glossary_keymaps or {}
  if glossary_keymaps.add then
    vim.keymap.set("v", glossary_keymaps.add, function()
      require("ink.ui").add_glossary_from_selection()
    end, { buffer = content_buf, noremap = true, silent = true, desc = "Add glossary from selection" })
    vim.keymap.set("n", glossary_keymaps.add, function()
      require("ink.ui").add_glossary_under_cursor()
    end, { buffer = content_buf, noremap = true, silent = true, desc = "Add glossary entry" })
  end
  if glossary_keymaps.edit then
    vim.keymap.set("n", glossary_keymaps.edit, function()
      require("ink.ui").edit_glossary_under_cursor()
    end, { buffer = content_buf, noremap = true, silent = true, desc = "Edit glossary entry" })
  end
  if glossary_keymaps.remove then
    vim.keymap.set("n", glossary_keymaps.remove, function()
      require("ink.ui").remove_glossary_under_cursor()
    end, { buffer = content_buf, noremap = true, silent = true, desc = "Remove glossary entry" })
  end
  if glossary_keymaps.preview then
    vim.keymap.set("n", glossary_keymaps.preview, function()
      require("ink.ui").preview_glossary()
    end, { buffer = content_buf, noremap = true, silent = true, desc = "Preview glossary entry" })
  end
  if glossary_keymaps.browser then
    vim.keymap.set("n", glossary_keymaps.browser, function()
      require("ink.ui").show_glossary_browser()
    end, { buffer = content_buf, noremap = true, silent = true, desc = "Browse glossary" })
  end
  if glossary_keymaps.show_related then
    vim.keymap.set("n", glossary_keymaps.show_related, function()
      require("ink.ui").show_term_graph_under_cursor()
    end, { buffer = content_buf, noremap = true, silent = true, desc = "Show related terms" })
  end
  if glossary_keymaps.show_graph then
    vim.keymap.set("n", glossary_keymaps.show_graph, function()
      require("ink.ui").show_glossary_graph()
    end, { buffer = content_buf, noremap = true, silent = true, desc = "Show glossary graph" })
  end
  if glossary_keymaps.toggle_display then
    vim.keymap.set("n", glossary_keymaps.toggle_display, function()
      require("ink.ui").toggle_glossary_display()
    end, { buffer = content_buf, noremap = true, silent = true, desc = "Toggle glossary display" })
  end

  -- Padnotes keymaps
  if context.config.padnotes and context.config.padnotes.enabled then
    local padnotes = require("ink.padnotes")
    local pk = context.config.padnotes_keymaps or {}
    if pk.list_all then
      vim.keymap.set("n", pk.list_all, function()
        padnotes.list_all()
      end, { buffer = content_buf, noremap = true, silent = true, desc = "List all padnotes" })
    end
    if pk.toggle then
      vim.keymap.set("n", pk.toggle, function()
        padnotes.toggle()
      end, { buffer = content_buf, noremap = true, silent = true, desc = "Toggle padnote" })
    end
    if pk.open then
      vim.keymap.set("n", pk.open, function()
        padnotes.open()
      end, { buffer = content_buf, noremap = true, silent = true, desc = "Open padnote" })
    end
    if pk.close then
      vim.keymap.set("n", pk.close, function()
        padnotes.close(true)
      end, { buffer = content_buf, noremap = true, silent = true, desc = "Close padnote" })
    end
  end

  -- Linked resources keymap
  if keymaps.related_resources then
    vim.keymap.set(
      "n",
      keymaps.related_resources,
      ":InkListRelated<CR>",
      { buffer = content_buf, noremap = true, silent = true, desc = "List related resources" }
    )
  end

  -- Focused mode keymap
  if keymaps.toggle_focused_mode then
    vim.keymap.set(
      "n",
      keymaps.toggle_focused_mode,
      ":InkToggleFocusedMode<CR>",
      { buffer = content_buf, noremap = true, silent = true, desc = "Toggle focused mode" }
    )
  end

  -- Reading paragraph mode keymap
  if keymaps.toggle_reading_paragraph_mode then
    vim.keymap.set(
      "n",
      keymaps.toggle_reading_paragraph_mode,
      ":InkToggleParagraphMode<CR>",
      { buffer = content_buf, noremap = true, silent = true, desc = "Toggle reading paragraph mode" }
    )
  end

  -- Export keymap
  local export_keymaps = context.config.export_keymaps or {}
  if export_keymaps.current_book then
    vim.keymap.set(
      "n",
      export_keymaps.current_book,
      ":InkExport<CR>",
      { buffer = content_buf, noremap = true, silent = true, desc = "Export current book" }
    )
  end
end

return M
