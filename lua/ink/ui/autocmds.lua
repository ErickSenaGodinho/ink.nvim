local context = require("ink.ui.context")
local render = require("ink.ui.render")
local state = require("ink.state")

local M = {}

local registered = false

function M.save_position(ctx)
  if not ctx or not ctx.content_win or not ctx.rendered_lines then
    return
  end
  if not vim.api.nvim_win_is_valid(ctx.content_win) then
    return
  end
  if vim.api.nvim_win_get_buf(ctx.content_win) ~= ctx.content_buf then
    return
  end

  local get_position_ctx = render.get_current_position_context
  if not get_position_ctx then
    return
  end

  local cursor_line = vim.api.nvim_win_get_cursor(ctx.content_win)[1]
  local position_ctx = get_position_ctx(ctx, cursor_line)

  local state_data = { chapter = ctx.current_chapter_idx }
  if position_ctx then
    state_data.text = position_ctx.text
    state_data.context_before = position_ctx.context_before
    state_data.context_after = position_ctx.context_after
    state_data.line = position_ctx.line_fallback
  else
    state_data.line = cursor_line
  end

  state.save(ctx.data.slug, state_data)
  require("ink.library").update_progress(ctx.data.slug, ctx.current_chapter_idx, #ctx.data.spine)
end

local function handle_book_resize(ctx)
  local book_loader = require("ink.ui.book_loader")
  local new_max_width = book_loader.calculate_adaptive_width(ctx)

  if new_max_width and ctx.current_max_width ~= new_max_width then
    ctx.current_max_width = new_max_width

    ctx.parsed_chapters = require("ink.cache.lru").new(15)
    ctx.search_index = nil

    render.invalidate_glossary_cache(ctx)
    require("ink.user_highlights").clear_positions_cache(ctx.data.slug)
    render.rerender_preserving_viewport(ctx)
  end
end

function M.setup()
  if registered then
    return
  end
  registered = true

  local group = vim.api.nvim_create_augroup("Ink_Global", { clear = true })

  vim.api.nvim_create_autocmd("WinResized", {
    group = group,
    callback = function()
      for _, win_id in ipairs(vim.v.event.windows or {}) do
        if vim.api.nvim_win_is_valid(win_id) then
          local buf = vim.api.nvim_win_get_buf(win_id)
          local ctx = context.get(buf)
          if ctx and ctx.content_buf == buf and ctx.content_win == win_id and not ctx._is_initializing then
            handle_book_resize(ctx)
          end
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
    group = group,
    callback = function()
      local buf = vim.api.nvim_get_current_buf()
      local ctx = context.get(buf)
      if not ctx or ctx.content_buf ~= buf then
        return
      end
      vim.schedule(function()
        local win = vim.api.nvim_get_current_win()
        local current_buf = vim.api.nvim_win_get_buf(win)
        local current_ctx = context.get(current_buf)
        if current_ctx and current_ctx.content_buf == current_buf then
          current_ctx.content_win = win
        end
      end)
    end,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      for _, ctx in pairs(context.all()) do
        M.save_position(ctx)
      end
    end,
  })
end

return M
