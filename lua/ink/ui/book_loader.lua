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
    return nil -- Adaptive width disabled, don't modify current_max_width
  end

  if ctx.manual_width_override then
    return nil -- User manually adjusted width, respect their choice until reset
  end

  if not ctx.content_win or not vim.api.nvim_win_is_valid(ctx.content_win) then
    return nil -- No valid window, can't calculate
  end

  local win_width = vim.api.nvim_win_get_width(ctx.content_win)
  local margin = context.config.adaptive_width_margin or 0.8

  -- Validate margin is within reasonable bounds (0.1 to 1.0)
  if margin < 0.1 or margin > 1.0 then
    if not margin_warning_shown then
      vim.notify(string.format("Invalid adaptive_width_margin (%.2f), using default 0.8", margin), vim.log.levels.WARN)
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
      if buf_name == name then
        return buf
      end
    end
  end
  return nil
end

-- Create content buffer
function M.create_book_buffer()
  -- Create content buffer
  local content_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("filetype", "ink_content", { buf = content_buf })
  vim.api.nvim_set_option_value("syntax", "off", { buf = content_buf })
  vim.api.nvim_set_option_value("undolevels", -1, { buf = content_buf })

  return content_buf
end

-- Setup context for book
function M.setup_book_context(content_buf, book_data)
  local ctx = context.create(content_buf)
  ctx.data = book_data
  ctx.content_buf = content_buf
  ctx.default_max_width = context.config.max_width
  ctx.current_max_width = context.config.max_width -- Initialize with default, will be adjusted by adaptive width

  return ctx
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
            render.rerender_preserving_viewport(current_ctx)
            break
          end
        end
      end
    end,
  })

  -- Cursor move handler for statusline updates
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = augroup,
    buffer = content_buf,
    callback = function()
      local current_ctx = context.get(content_buf)
      if not current_ctx or not current_ctx.content_win or not vim.api.nvim_win_is_valid(current_ctx.content_win) then
        return
      end
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

  vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
    callback = vim.schedule_wrap(function()
      local current_win = vim.api.nvim_get_current_win()
      local current_buf = vim.api.nvim_win_get_buf(current_win)
      local ctx = context.get(current_buf)

      if ctx then
        ctx.content_win = current_win
      end
    end),
  })

  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = augroup,
    buffer = content_buf,
    callback = function(args)
      vim.schedule(function()
        local ctx = context.get(args.buf)
        if not ctx then
          return
        end

        local win = vim.api.nvim_get_current_win()

        if ctx.focused_mode then
          require("ink.ui").enable_focused_mode(ctx, win)
        end

        if ctx.reading_paragraph_mode then
          require("ink.ui.extmarks").enable_reading_paragraph_mode(ctx)
        end
      end)
    end,
  })

  vim.api.nvim_create_autocmd("BufWinLeave", {
    group = augroup,
    buffer = content_buf,
    callback = function(args)
      local ctx = context.get(args.buf)
      if not ctx then
        return
      end

      local win = vim.api.nvim_get_current_win()

      require("ink.ui").disable_focused_mode(ctx, win)
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

        state.save(current_ctx.data.slug, state_data)
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
          padnotes.close(true) -- Save before closing
        end

        -- Save current reading position before closing (only from content buffer)
        if
          current_ctx.content_win
          and vim.api.nvim_win_is_valid(current_ctx.content_win)
          and current_ctx.rendered_lines
        then
          -- Verify the window is still showing the content buffer (not switched to TOC)
          local win_buf = vim.api.nvim_win_get_buf(current_ctx.content_win)
          if win_buf == content_buf then
            local cursor = vim.api.nvim_win_get_cursor(current_ctx.content_win)
            local cursor_line = cursor[1]

            -- Extract position with text context
            local get_position_ctx = render.get_current_position_context
            if get_position_ctx then
              local position_ctx = get_position_ctx(current_ctx, cursor_line)
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

              state.save(current_ctx.data.slug, state_data)
              library_module.update_progress(
                current_ctx.data.slug,
                current_ctx.current_chapter_idx,
                #current_ctx.data.spine
              )
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

            state.save(current_ctx.data.slug, state_data)
            library_module.update_progress(
              current_ctx.data.slug,
              current_ctx.current_chapter_idx,
              #current_ctx.data.spine
            )
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
  if show_toc == nil then
    show_toc = true
  end

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
    total_chapters = #book_data.spine,
  })

  local ctx = context.get_by_book_slug(book_data.slug)
  local content_buf

  if ctx then
    if vim.api.nvim_win_is_valid(ctx.content_win) and vim.api.nvim_win_get_buf(ctx.content_win) == ctx.content_buf then
      vim.api.nvim_set_current_win(ctx.content_win)
      return
    end
    content_buf = ctx.content_buf
  else
    content_buf = M.create_book_buffer()
    ctx = M.setup_book_context(content_buf, book_data)
  end

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

  require("ink.keymaps.reader").setup(content_buf, context.config)
  M.setup_book_autocmds(content_buf, book_data.slug)

  vim.api.nvim_win_set_buf(ctx.content_win, content_buf)

  if empty_buffer and vim.api.nvim_buf_is_valid(empty_buffer) then
    vim.api.nvim_buf_delete(empty_buffer, { force = true })
  end

  local state_data = state.load(book_data.slug)

  local function get_value(key)
    if state_data and state_data[key] ~= nil then
      return state_data[key]
    end
    return context.config[key]
  end

  ctx.justify_text = get_value("justify_text")
  ctx.focused_mode = get_value("focused_mode")
  ctx.reading_paragraph_mode = get_value("reading_paragraph_mode")

  -- Render TOC and toggle it open only if show_toc is true
  if show_toc then
    floating_toc.show_floating_toc(ctx)
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
    if state_data then
      -- First render the chapter
      render.render_chapter(state_data.chapter, state_data.line, ctx)

      -- If we have text-based position data, find the exact position
      if state_data.text and state_data.text ~= "" and ctx.rendered_lines then
        local util = require("ink.ui.util")
        local start_line = util.find_text_position(
          ctx.rendered_lines,
          state_data.text,
          state_data.context_before,
          state_data.context_after
        )

        -- If found, update cursor to exact position
        if start_line and ctx.content_win and vim.api.nvim_win_is_valid(ctx.content_win) then
          vim.api.nvim_win_set_cursor(ctx.content_win, { start_line, 0 })
        end
      end
    else
      render.render_chapter(1, nil, ctx)
    end

    -- Start reading session
    local reading_sessions = require("ink.reading_sessions")
    reading_sessions.start_session(book_data.slug, state_data and state_data.chapter or 1)

    -- Book initialization complete, allow state saving
    ctx._is_initializing = false
  end)
end

-- Export calculate_adaptive_width for use in other modules (e.g., reset_width)
M.calculate_adaptive_width = calculate_adaptive_width

return M
