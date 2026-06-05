-- lua/ink/ui/book_loader.lua
-- Responsabilidade: Criação e configuração de buffers/contexto para livros

local library = require("ink.library")
local state = require("ink.state")
local context = require("ink.ui.context")
local render = require("ink.ui.render")
local utils = require("ink.utils")
local floating_toc = require("ink.ui.floating_toc")

local M = {}

-- Track if we've already warned about invalid margin
local margin_warning_shown = false

-- Helper to calculate adaptive width based on window size
local function calculate_adaptive_width(ctx)
  if not context.config.adaptive_width then
    return nil  -- Adaptive width disabled, don't modify current_max_width
  end

  if ctx.manual_width_override then
    return nil  -- User manually adjusted width, respect their choice until reset
  end

  if not ctx.content_win or not vim.api.nvim_win_is_valid(ctx.content_win) then
    return nil  -- No valid window, can't calculate
  end

  local win_width = vim.api.nvim_win_get_width(ctx.content_win)
  local margin = context.config.adaptive_width_margin or 0.8

  -- Validate margin is within reasonable bounds (0.1 to 1.0)
  if margin < 0.1 or margin > 1.0 then
    if not margin_warning_shown then
      vim.notify(
        string.format("Invalid adaptive_width_margin (%.2f), using default 0.8", margin),
        vim.log.levels.WARN
      )
      margin_warning_shown = true
    end
    margin = 0.8
  end

  local new_max_width = math.floor(win_width * margin)

  -- Enforce minimum of 40 and don't exceed default max_width
  local min_width = 40
  local default_max = ctx.default_max_width or context.config.max_width
  new_max_width = math.max(min_width, math.min(new_max_width, default_max))

  return new_max_width
end

-- Helper to find buffer by name
local function find_buf_by_name(name)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      local buf_name = vim.api.nvim_buf_get_name(buf)
      if buf_name == name then return buf end
    end
  end
  return nil
end

-- Create content buffer
function M.create_book_buffer()
  -- Delete existing buffers if they exist
  if context.content_buf then
    context.remove(existing_content)
    if vim.api.nvim_buf_is_valid(existing_content) then
      vim.api.nvim_buf_delete(existing_content, { force = true })
    end
  end

  -- Create content buffer
  local content_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("filetype", "ink_content", { buf = content_buf })
  vim.api.nvim_set_option_value("syntax", "off", { buf = content_buf })

  return content_buf
end

-- Setup context for book
function M.setup_book_context(content_buf, book_data)
  local ctx = context.create(content_buf)
  ctx.data = book_data
  ctx.content_buf = content_buf
  ctx.default_max_width = context.config.max_width
  ctx.current_max_width = context.config.max_width  -- Initialize with default, will be adjusted by adaptive width

  return ctx
end

-- Setup basic navigation keymaps
function M.setup_basic_keymaps(buf)
  local keymaps = context.config.keymaps or {}

  if keymaps.next_chapter then
    vim.keymap.set("n", keymaps.next_chapter, function() require("ink.ui").next_chapter() end,
      { buffer = buf, noremap = true, silent = true, desc = "Next chapter" })
  end
  if keymaps.prev_chapter then
    vim.keymap.set("n", keymaps.prev_chapter, function() require("ink.ui").prev_chapter() end,
      { buffer = buf, noremap = true, silent = true, desc = "Previous chapter" })
  end
  if keymaps.activate then
    vim.keymap.set("n", keymaps.activate, function() require("ink.ui").handle_enter() end,
      { buffer = buf, noremap = true, silent = true, desc = "Activate (footnote/link/image)" })
  end
  local jump_key = keymaps.jump_to_link or "g<CR>"
  vim.keymap.set("n", jump_key, function() require("ink.ui").jump_to_link() end,
    { buffer = buf, noremap = true, silent = true, desc = "Jump to link" })
  if keymaps.search_toc then
    vim.keymap.set("n", keymaps.search_toc, function() require("ink.ui").search_toc() end,
      { buffer = buf, noremap = true, silent = true, desc = "Search TOC" })
  end
  if keymaps.search_content then
    vim.keymap.set("n", keymaps.search_content, function() require("ink.ui").search_content() end,
      { buffer = buf, noremap = true, silent = true, desc = "Search content" })
  end
  if keymaps.width_increase then
    vim.keymap.set("n", keymaps.width_increase, function() require("ink.ui").increase_width() end,
      { buffer = buf, noremap = true, silent = true, desc = "Increase width" })
  end
  if keymaps.width_decrease then
    vim.keymap.set("n", keymaps.width_decrease, function() require("ink.ui").decrease_width() end,
      { buffer = buf, noremap = true, silent = true, desc = "Decrease width" })
  end
  if keymaps.width_reset then
    vim.keymap.set("n", keymaps.width_reset, function() require("ink.ui").reset_width() end,
      { buffer = buf, noremap = true, silent = true, desc = "Reset width" })
  end
  if keymaps.toggle_justify then
    vim.keymap.set("n", keymaps.toggle_justify, function() require("ink.ui").toggle_justify() end,
      { buffer = buf, noremap = true, silent = true, desc = "Toggle text justification" })
  end

  -- Typography keymaps
  local typography_keymaps = context.config.typography_keymaps or {}
  if typography_keymaps.line_spacing_increase then
    vim.keymap.set("n", typography_keymaps.line_spacing_increase, function() require("ink.ui").increase_line_spacing() end,
      { buffer = buf, noremap = true, silent = true, desc = "Increase line spacing" })
  end
  if typography_keymaps.line_spacing_decrease then
    vim.keymap.set("n", typography_keymaps.line_spacing_decrease, function() require("ink.ui").decrease_line_spacing() end,
      { buffer = buf, noremap = true, silent = true, desc = "Decrease line spacing" })
  end
  if typography_keymaps.line_spacing_reset then
    vim.keymap.set("n", typography_keymaps.line_spacing_reset, function() require("ink.ui").reset_line_spacing() end,
      { buffer = buf, noremap = true, silent = true, desc = "Reset line spacing" })
  end
  if typography_keymaps.paragraph_spacing_increase then
    vim.keymap.set("n", typography_keymaps.paragraph_spacing_increase, function() require("ink.ui").increase_paragraph_spacing() end,
      { buffer = buf, noremap = true, silent = true, desc = "Increase paragraph spacing" })
  end
  if typography_keymaps.paragraph_spacing_decrease then
    vim.keymap.set("n", typography_keymaps.paragraph_spacing_decrease, function() require("ink.ui").decrease_paragraph_spacing() end,
      { buffer = buf, noremap = true, silent = true, desc = "Decrease paragraph spacing" })
  end
  if typography_keymaps.paragraph_spacing_reset then
    vim.keymap.set("n", typography_keymaps.paragraph_spacing_reset, function() require("ink.ui").reset_paragraph_spacing() end,
      { buffer = buf, noremap = true, silent = true, desc = "Reset paragraph spacing" })
  end
end

-- Setup all book-specific keymaps
function M.setup_book_keymaps(content_buf)
  local keymaps = context.config.keymaps or {}

  -- Setup basic keymaps for both buffers
  M.setup_basic_keymaps(content_buf)

  -- TOC toggle keymap
  if keymaps.toggle_toc then
    vim.keymap.set("n", keymaps.toggle_toc, function() require("ink.ui.floating_toc").toggle_floating_toc() end,
      { buffer = content_buf, noremap = true, silent = true, desc = "Toggle TOC" })
  end

  -- TOC rebuild keymap
  local toc_keymaps = context.config.toc_keymaps or {}
  if toc_keymaps.rebuild then
    vim.keymap.set("n", toc_keymaps.rebuild, ":InkRebuildTOC<CR>",
      { buffer = content_buf, noremap = true, silent = true, desc = "Rebuild TOC" })
  end

  -- Highlight keymaps (content buffer only)
  local highlight_keymaps = context.config.highlight_keymaps or {}
  for color_name, keymap in pairs(highlight_keymaps) do
    if color_name == "remove" then
      vim.keymap.set("n", keymap, function() require("ink.ui").remove_highlight() end,
        { buffer = content_buf, noremap = true, silent = true, desc = "Remove highlight" })
    else
      vim.keymap.set("v", keymap, function() require("ink.ui").add_highlight(color_name) end,
        { buffer = content_buf, noremap = true, silent = true, desc = "Highlight " .. color_name })
    end
  end

  -- Change highlight color keymaps (content buffer only)
  local highlight_change_color_keymaps = context.config.highlight_change_color_keymaps or {}
  for color_name, keymap in pairs(highlight_change_color_keymaps) do
    vim.keymap.set("n", keymap, function() require("ink.ui").change_highlight_color(color_name) end,
      { buffer = content_buf, noremap = true, silent = true, desc = "Change highlight to " .. color_name })
  end

  -- Note keymaps (content buffer only)
  local note_keymaps = context.config.note_keymaps or {}
  if note_keymaps.add then
    vim.keymap.set("n", note_keymaps.add, function() require("ink.ui").add_note() end,
      { buffer = content_buf, noremap = true, silent = true, desc = "Add/edit note" })
    vim.keymap.set("v", note_keymaps.add, function() require("ink.ui").add_note_on_selection() end,
      { buffer = content_buf, noremap = true, silent = true, desc = "Add note on selection" })
  end
  if note_keymaps.edit then
    vim.keymap.set("n", note_keymaps.edit, function() require("ink.ui").edit_note() end,
      { buffer = content_buf, noremap = true, silent = true, desc = "Edit note" })
  end
  if note_keymaps.remove then
    vim.keymap.set("n", note_keymaps.remove, function() require("ink.ui").remove_note() end,
      { buffer = content_buf, noremap = true, silent = true, desc = "Remove note" })
  end
  if note_keymaps.toggle_display then
    vim.keymap.set("n", note_keymaps.toggle_display, function() require("ink.ui").toggle_note_display() end,
      { buffer = content_buf, noremap = true, silent = true, desc = "Toggle note display" })
  end

  -- Bookmark keymaps (content buffer only)
  local bookmark_keymaps = context.config.bookmark_keymaps or {}
  if bookmark_keymaps.add then
    vim.keymap.set("n", bookmark_keymaps.add, function() require("ink.ui").add_bookmark() end,
      { buffer = content_buf, noremap = true, silent = true, desc = "Add bookmark" })
  end
  if bookmark_keymaps.edit then
    vim.keymap.set("n", bookmark_keymaps.edit, function() require("ink.ui").edit_bookmark() end,
      { buffer = content_buf, noremap = true, silent = true, desc = "Edit bookmark" })
  end
  if bookmark_keymaps.remove then
    vim.keymap.set("n", bookmark_keymaps.remove, function() require("ink.ui").remove_bookmark() end,
      { buffer = content_buf, noremap = true, silent = true, desc = "Remove bookmark" })
  end
  if bookmark_keymaps.next then
    vim.keymap.set("n", bookmark_keymaps.next, function() require("ink.ui").goto_next_bookmark() end,
      { buffer = content_buf, noremap = true, silent = true, desc = "Next bookmark" })
  end
  if bookmark_keymaps.prev then
    vim.keymap.set("n", bookmark_keymaps.prev, function() require("ink.ui").goto_prev_bookmark() end,
      { buffer = content_buf, noremap = true, silent = true, desc = "Previous bookmark" })
  end

  -- Glossary keymaps (content buffer only)
  local glossary_keymaps = context.config.glossary_keymaps or {}
  if glossary_keymaps.add then
    vim.keymap.set("v", glossary_keymaps.add, function() require("ink.ui").add_glossary_from_selection() end,
      { buffer = content_buf, noremap = true, silent = true, desc = "Add glossary from selection" })
    vim.keymap.set("n", glossary_keymaps.add, function() require("ink.ui").add_glossary_under_cursor() end,
      { buffer = content_buf, noremap = true, silent = true, desc = "Add glossary entry" })
  end
  if glossary_keymaps.edit then
    vim.keymap.set("n", glossary_keymaps.edit, function() require("ink.ui").edit_glossary_under_cursor() end,
      { buffer = content_buf, noremap = true, silent = true, desc = "Edit glossary entry" })
  end
  if glossary_keymaps.remove then
    vim.keymap.set("n", glossary_keymaps.remove, function() require("ink.ui").remove_glossary_under_cursor() end,
      { buffer = content_buf, noremap = true, silent = true, desc = "Remove glossary entry" })
  end
  if glossary_keymaps.preview then
    vim.keymap.set("n", glossary_keymaps.preview, function() require("ink.ui").preview_glossary() end,
      { buffer = content_buf, noremap = true, silent = true, desc = "Preview glossary entry" })
  end
  if glossary_keymaps.browser then
    vim.keymap.set("n", glossary_keymaps.browser, function() require("ink.ui").show_glossary_browser() end,
      { buffer = content_buf, noremap = true, silent = true, desc = "Browse glossary" })
  end
  if glossary_keymaps.show_related then
    vim.keymap.set("n", glossary_keymaps.show_related, function() require("ink.ui").show_term_graph_under_cursor() end,
      { buffer = content_buf, noremap = true, silent = true, desc = "Show related terms" })
  end
  if glossary_keymaps.show_graph then
    vim.keymap.set("n", glossary_keymaps.show_graph, function() require("ink.ui").show_glossary_graph() end,
      { buffer = content_buf, noremap = true, silent = true, desc = "Show glossary graph" })
  end
  if glossary_keymaps.toggle_display then
    vim.keymap.set("n", glossary_keymaps.toggle_display, function() require("ink.ui").toggle_glossary_display() end,
      { buffer = content_buf, noremap = true, silent = true, desc = "Toggle glossary display" })
  end
end

-- Setup autocmds for book
function M.setup_book_autocmds(content_buf, slug)
  local augroup = vim.api.nvim_create_augroup("Ink_" .. slug, { clear = true })

  -- Window resize handler
  vim.api.nvim_create_autocmd("WinResized", {
    group = augroup,
    callback = function()
      local current_ctx = context.get(content_buf)

      -- Check initialization status first (fast check, no API calls)
      if not current_ctx or current_ctx._is_initializing then
        return
      end

      -- Now check window validity (safer order)
      if current_ctx.content_win and vim.api.nvim_win_is_valid(current_ctx.content_win) then
        local resized_wins = vim.v.event.windows or {}
        for _, win_id in ipairs(resized_wins) do
          if win_id == current_ctx.content_win then
            -- Save viewport position (text-based, survives word wrap changes)
            local viewport_ctx = render.get_viewport_text_context(current_ctx)

            -- Adaptive width: adjust max_width based on window size (per-context)
            local new_max_width = calculate_adaptive_width(current_ctx)
            if new_max_width and current_ctx.current_max_width ~= new_max_width then
              current_ctx.current_max_width = new_max_width

              -- Invalidate caches when width changes
              current_ctx.parsed_chapters = require("ink.cache.lru").new(15)
              current_ctx.search_index = nil
            end

            -- Invalidate glossary cache since positions depend on window width
            render.invalidate_glossary_cache(current_ctx)

            -- Invalidate highlight positions cache since they depend on width
            require("ink.user_highlights").clear_positions_cache(current_ctx.data.slug)

            render.render_chapter(current_ctx.current_chapter_idx, nil, current_ctx)

            -- Restore viewport immediately (render_chapter is synchronous)
            if vim.api.nvim_win_is_valid(current_ctx.content_win) then
              vim.api.nvim_set_current_win(current_ctx.content_win)
              render.restore_viewport_from_context(current_ctx, viewport_ctx)
            end

            break
          end
        end
      end
    end,
  })

  -- Cursor move handler for statusline updates
  vim.api.nvim_create_autocmd({"CursorMoved", "CursorMovedI"}, {
    group = augroup,
    buffer = content_buf,
    callback = function()
      local current_ctx = context.get(content_buf)
      if not current_ctx or not current_ctx.content_win or not vim.api.nvim_win_is_valid(current_ctx.content_win) then return end
      local cursor = vim.api.nvim_win_get_cursor(current_ctx.content_win)
      local current_line = cursor[1]
      local total_lines = vim.api.nvim_buf_line_count(current_ctx.content_buf)
      local percent = math.floor((current_line / total_lines) * 100)
      if math.abs(percent - current_ctx.last_statusline_percent) >= 10 then
        current_ctx.last_statusline_percent = percent
        render.update_statusline(current_ctx)
      end
    end,
  })

  -- Periodic save on cursor hold (after 4 seconds of inactivity)
  vim.api.nvim_create_autocmd("CursorHold", {
    group = augroup,
    buffer = content_buf,
    callback = function()
      local current_ctx = context.get(content_buf)
      if not current_ctx or current_ctx._is_initializing or not current_ctx.rendered_lines then
        return
      end

      if not current_ctx.content_win or not vim.api.nvim_win_is_valid(current_ctx.content_win) then
        return
      end

      -- Only save from content buffer
      local win_buf = vim.api.nvim_win_get_buf(current_ctx.content_win)
      if win_buf ~= content_buf then
        return
      end
      local cursor = vim.api.nvim_win_get_cursor(current_ctx.content_win)
      local cursor_line = cursor[1]

      local get_position_ctx = render.get_current_position_context
      if get_position_ctx then
        local position_ctx = get_position_ctx(current_ctx, cursor_line)
        local state_module = require("ink.state")
        local library_module = require("ink.library")

        local state_data = { chapter = current_ctx.current_chapter_idx }
        if position_ctx then
          state_data.text = position_ctx.text
          state_data.context_before = position_ctx.context_before
          state_data.context_after = position_ctx.context_after
          state_data.line = position_ctx.line_fallback
        else
          state_data.line = cursor_line
        end

        state_module.save(current_ctx.data.slug, state_data)
        library_module.update_progress(current_ctx.data.slug, current_ctx.current_chapter_idx, #current_ctx.data.spine)
      end
    end,
  })

  -- Buffer delete handler for content buffer
  vim.api.nvim_create_autocmd("BufDelete", {
    group = augroup,
    buffer = content_buf,
    callback = function(ev)
      -- Only process if the buffer being deleted is the content buffer
      if ev.buf ~= content_buf then
        return
      end

      local current_ctx = context.get(content_buf)
      if current_ctx then
        -- Cleanup padnote before closing book
        if current_ctx.padnote_buf and vim.api.nvim_buf_is_valid(current_ctx.padnote_buf) then
          local padnotes = require("ink.padnotes")
          padnotes.close(true)  -- Save before closing
        end
        
        -- Save current reading position before closing (only from content buffer)
        if current_ctx.content_win and vim.api.nvim_win_is_valid(current_ctx.content_win) and current_ctx.rendered_lines then
          -- Verify the window is still showing the content buffer (not switched to TOC)
          local win_buf = vim.api.nvim_win_get_buf(current_ctx.content_win)
          if win_buf == content_buf then
            local cursor = vim.api.nvim_win_get_cursor(current_ctx.content_win)
            local cursor_line = cursor[1]

            -- Extract position with text context
            local get_position_ctx = render.get_current_position_context
            if get_position_ctx then
              local position_ctx = get_position_ctx(current_ctx, cursor_line)
              local state_module = require("ink.state")
              local library_module = require("ink.library")

              local state_data = { chapter = current_ctx.current_chapter_idx }
              if position_ctx then
                state_data.text = position_ctx.text
                state_data.context_before = position_ctx.context_before
                state_data.context_after = position_ctx.context_after
                state_data.line = position_ctx.line_fallback
              else
                state_data.line = cursor_line
              end

              state_module.save(current_ctx.data.slug, state_data)
              library_module.update_progress(current_ctx.data.slug, current_ctx.current_chapter_idx, #current_ctx.data.spine)
            end
          end
        end
      end

      -- End reading session
      local reading_sessions = require("ink.reading_sessions")
      reading_sessions.end_session(slug)

      context.remove(content_buf)
    end,
  })

  -- VimLeavePre: Save position before Vim closes (safety net)
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = augroup,
    callback = function()
      local current_ctx = context.get(content_buf)
      if not current_ctx or not current_ctx.content_win or not current_ctx.rendered_lines then
        return
      end

      -- Only save if the content window is still valid and showing content buffer
      if vim.api.nvim_win_is_valid(current_ctx.content_win) then
        local win_buf = vim.api.nvim_win_get_buf(current_ctx.content_win)
        if win_buf == content_buf then
          local cursor = vim.api.nvim_win_get_cursor(current_ctx.content_win)
          local cursor_line = cursor[1]

          local get_position_ctx = render.get_current_position_context
          if get_position_ctx then
            local position_ctx = get_position_ctx(current_ctx, cursor_line)
            local state_module = require("ink.state")
            local library_module = require("ink.library")

            local state_data = { chapter = current_ctx.current_chapter_idx }
            if position_ctx then
              state_data.text = position_ctx.text
              state_data.context_before = position_ctx.context_before
              state_data.context_after = position_ctx.context_after
              state_data.line = position_ctx.line_fallback
            else
              state_data.line = cursor_line
            end

            state_module.save(current_ctx.data.slug, state_data)
            library_module.update_progress(current_ctx.data.slug, current_ctx.current_chapter_idx, #current_ctx.data.spine)
          end
        end
      end
    end,
  })
end

-- Main function to open a book
-- @param book_data: book data structure
-- @param opts: optional table with:
--   - position: "right" | "left" | "top" | "bottom" (default: opens in current window or new tab)
--   - show_toc: boolean (default: true)
function M.open_book(book_data, opts)
  opts = opts or {}
  local position = opts.position
  local show_toc = opts.show_toc
  if show_toc == nil then show_toc = true end

  -- Register book in library
  library.add_book({
    slug = book_data.slug,
    title = book_data.title,
    author = book_data.author,
    language = book_data.language,
    date = book_data.date,
    description = book_data.description,
    path = book_data.path,
    format = book_data.format or "epub",
    chapter = 1,
    total_chapters = #book_data.spine
  })

  -- Start reading session
  local reading_sessions = require("ink.reading_sessions")
  reading_sessions.start_session(book_data.slug, 1)

  -- Create buffer
  local content_buf = M.create_book_buffer()

  -- Setup context
  local ctx = M.setup_book_context(content_buf, book_data)

  -- Flag to prevent state saving during book initialization
  ctx._is_initializing = true

  local empty_buffer

  -- Open book in specified position
  if position == "right" then
    vim.cmd("rightbelow vsplit")
  elseif position == "left" then
    vim.cmd("leftabove vsplit")
  elseif position == "top" then
    vim.cmd("leftabove split")
  elseif position == "bottom" then
    vim.cmd("rightbelow split")
  else
    -- No position specified: create new tab only if current buffer is not empty
    if not utils.is_current_buffer_empty() then
      vim.cmd("tabnew")
      empty_buffer = vim.api.nvim_get_current_buf()
    end
  end
  ctx.content_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(ctx.content_win, content_buf)

  if empty_buffer and vim.api.nvim_buf_is_valid(empty_buffer) then
    vim.api.nvim_buf_delete(empty_buffer, {force = true})
  end

  -- Render TOC and toggle it open only if show_toc is true
  if show_toc then
    floating_toc.toggle_floating_toc(ctx)
  end

  -- Schedule chapter rendering to ensure window has been resized after TOC toggle
  -- This prevents glossary marks from being calculated with incorrect window width
  vim.schedule(function()
    -- Calculate initial adaptive width based on actual window size after TOC is created
    local initial_width = calculate_adaptive_width(ctx)
    if initial_width then
      ctx.current_max_width = initial_width
    end

    -- Load saved position or render first chapter
    local saved = state.load(book_data.slug)
    if saved then
      -- First render the chapter
      render.render_chapter(saved.chapter, saved.line, ctx)

      -- If we have text-based position data, find the exact position
      if saved.text and saved.text ~= "" and ctx.rendered_lines then
        local util = require("ink.ui.util")
        local start_line = util.find_text_position(
          ctx.rendered_lines,
          saved.text,
          saved.context_before,
          saved.context_after
        )

        -- If found, update cursor to exact position
        if start_line and ctx.content_win and vim.api.nvim_win_is_valid(ctx.content_win) then
          vim.api.nvim_win_set_cursor(ctx.content_win, {start_line, 0})
        end
      end

    else
      render.render_chapter(1, nil, ctx)
    end

    -- Book initialization complete, allow state saving
    ctx._is_initializing = false
  end)

  -- Setup keymaps and autocmds
  M.setup_book_keymaps(content_buf)
  M.setup_book_autocmds(content_buf, book_data.slug)
end

-- Export calculate_adaptive_width for use in other modules (e.g., reset_width)
M.calculate_adaptive_width = calculate_adaptive_width

return M
