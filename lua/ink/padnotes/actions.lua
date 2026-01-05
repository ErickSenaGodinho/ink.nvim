-- lua/ink/padnotes/actions.lua
-- Responsabilidade: Lógica de negócio para toggle, open, close

local context = require("ink.ui.context")
local data = require("ink.padnotes.data")
local template = require("ink.padnotes.template")

local M = {}

-- Stop auto-save timer
local function stop_auto_save(ctx)
  if ctx.padnote_auto_save_timer then
    ctx.padnote_auto_save_timer:stop()
    ctx.padnote_auto_save_timer:close()
    ctx.padnote_auto_save_timer = nil
  end
end

-- Setup auto-save timer for a padnote buffer
local function setup_auto_save(ctx)
  -- Stop any existing timer first to prevent memory leaks
  stop_auto_save(ctx)

  local config = require("ink.padnotes").config
  local interval = config.auto_save_interval or 120

  -- Create timer
  local timer = vim.loop.new_timer()
  if not timer then
    vim.notify("Failed to create auto-save timer", vim.log.levels.WARN)
    return
  end

  -- Start repeating timer (interval in milliseconds)
  timer:start(interval * 1000, interval * 1000, vim.schedule_wrap(function()
    -- Check if context still exists
    if not ctx then
      stop_auto_save(ctx)
      return
    end

    -- Check if buffer is still valid
    if not ctx.padnote_buf or not vim.api.nvim_buf_is_valid(ctx.padnote_buf) then
      stop_auto_save(ctx)
      return
    end

    -- Double-check buffer exists in system (race condition protection)
    local buf_exists = false
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if buf == ctx.padnote_buf then
        buf_exists = true
        break
      end
    end

    if not buf_exists then
      stop_auto_save(ctx)
      return
    end

    -- Check if buffer is modified
    local ok_modified, modified = pcall(vim.api.nvim_get_option_value, "modified", { buf = ctx.padnote_buf })
    if not ok_modified or not modified then
      return
    end

    -- Save buffer
    local ok, err = pcall(vim.api.nvim_buf_call, ctx.padnote_buf, function()
      vim.cmd("silent! write")
    end)

    if ok then
      vim.notify("Padnote auto-saved", vim.log.levels.INFO)
    else
      vim.notify("Failed to auto-save padnote: " .. tostring(err), vim.log.levels.WARN)
    end
  end))

  ctx.padnote_auto_save_timer = timer
end

-- Open padnote for a specific chapter (or current chapter if not specified)
function M.open(force_chapter_idx)
  local ctx = context.current()
  if not ctx then
    vim.notify("No active book", vim.log.levels.WARN)
    return false
  end

  local chapter_idx = force_chapter_idx or ctx.current_chapter_idx

  -- Check if padnote is already open for this chapter
  if ctx.padnote_buf and vim.api.nvim_buf_is_valid(ctx.padnote_buf) and ctx.padnote_chapter == chapter_idx then
    -- Padnote already open for this chapter, close it (toggle behavior)
    return M.close(true)
  end

  -- If there's a padnote open for a different chapter, close it first
  if ctx.padnote_buf and vim.api.nvim_buf_is_valid(ctx.padnote_buf) and ctx.padnote_chapter ~= chapter_idx then
    M.close(true)
  end

  -- Get padnote path
  local path = data.get_padnote_path(ctx.data.slug, chapter_idx, ctx.data)
  local is_new = not data.padnote_exists(ctx.data.slug, chapter_idx, ctx.data)
  
  -- Create file if it doesn't exist
  if is_new then
    data.create_padnote(ctx.data.slug, chapter_idx, ctx.data)
  end
  
  -- Create buffer for the file
  -- Use file-backed buffer (listed=false to not clutter buffer list, but file=true for persistence)
  local buf = vim.fn.bufadd(path)
  if not buf or buf == 0 then
    vim.notify("Failed to create buffer for padnote", vim.log.levels.ERROR)
    return false
  end
  
  -- Load buffer content from file
  vim.fn.bufload(buf)
  
  -- Set buffer options
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })
  vim.api.nvim_set_option_value("buflisted", false, { buf = buf })
  
  -- Get content window width to calculate split size
  -- Try to recover window if invalid
  if not ctx.content_win or not vim.api.nvim_win_is_valid(ctx.content_win) then
    -- Search for window with content buffer
    local found = false
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == ctx.content_buf then
        ctx.content_win = win
        found = true
        break
      end
    end
    
    if not found then
      vim.notify("Content window not found. Please reopen the book.", vim.log.levels.WARN)
      return false
    end
  end
  
  -- Get padnote configuration
  local config = require("ink.padnotes").config
  local position = config.position or "right"
  local size = config.size or 0.5

  -- Validate and normalize position
  local valid_positions = { right = true, left = true, top = true, bottom = true }
  if not valid_positions[position] then
    vim.notify(string.format("Invalid padnote position '%s', using 'right'", position), vim.log.levels.WARN)
    position = "right"
  end

  -- Validate size (must be positive)
  if type(size) ~= "number" or size <= 0 then
    vim.notify(string.format("Invalid padnote size '%s', using 0.5", tostring(size)), vim.log.levels.WARN)
    size = 0.5
  end

  -- Determine split orientation AFTER normalizing position
  local is_vertical = (position == "left" or position == "right")
  local content_width = vim.api.nvim_win_get_width(ctx.content_win)
  local content_height = vim.api.nvim_win_get_height(ctx.content_win)

  -- Calculate split size
  local split_size
  if is_vertical then
    -- For vertical splits, use width
    if size < 1 then
      -- Percentage mode: size between 0 and 1 (exclusive)
      split_size = math.floor(content_width * size + 0.5)
    else
      -- Absolute mode: size >= 1
      split_size = math.floor(size)
    end
    -- Enforce minimum and maximum, handling small windows
    local min_size = 10
    local max_size = content_width - 10
    if max_size < min_size then
      -- Window too small for minimum requirement, use 50% as fallback
      split_size = math.floor(content_width * 0.5 + 0.5)
      vim.notify("Content window too small for padnote minimum size, using 50%", vim.log.levels.WARN)
    else
      split_size = math.max(min_size, math.min(split_size, max_size))
    end
  else
    -- For horizontal splits, use height
    if size < 1 then
      -- Percentage mode: size between 0 and 1 (exclusive)
      split_size = math.floor(content_height * size + 0.5)
    else
      -- Absolute mode: size >= 1
      split_size = math.floor(size)
    end
    -- Enforce minimum and maximum, handling small windows
    local min_size = 5
    local max_size = content_height - 5
    if max_size < min_size then
      -- Window too small for minimum requirement, use 50% as fallback
      split_size = math.floor(content_height * 0.5 + 0.5)
      vim.notify("Content window too small for padnote minimum size, using 50%", vim.log.levels.WARN)
    else
      split_size = math.max(min_size, math.min(split_size, max_size))
    end
  end

  -- First, focus content window
  vim.api.nvim_set_current_win(ctx.content_win)

  -- Create split based on position (now guaranteed to be valid)
  if position == "right" then
    vim.cmd("rightbelow vsplit")
  elseif position == "left" then
    vim.cmd("leftabove vsplit")
  elseif position == "bottom" then
    vim.cmd("rightbelow split")
  else -- position == "top"
    vim.cmd("leftabove split")
  end

  local padnote_win = vim.api.nvim_get_current_win()

  -- Set buffer in new window
  vim.api.nvim_win_set_buf(padnote_win, buf)

  -- Set window size (now guaranteed to match split orientation)
  if is_vertical then
    vim.api.nvim_win_set_width(padnote_win, split_size)
  else
    vim.api.nvim_win_set_height(padnote_win, split_size)
  end
  
  -- Update context
  ctx.padnote_buf = buf
  ctx.padnote_win = padnote_win
  ctx.padnote_chapter = chapter_idx
  
  -- Setup auto-save
  setup_auto_save(ctx)
  
  -- If new file, insert header and position cursor
  if is_new then
    vim.api.nvim_buf_call(buf, function()
      local cursor_line = template.insert_header_to_buffer(buf, ctx.data, chapter_idx)
      vim.api.nvim_set_option_value("modified", true, { buf = buf })
    end)
    vim.api.nvim_win_set_cursor(padnote_win, {6, 0})
  end
  
  -- Ensure we're in normal mode (scheduled to avoid race conditions)
  vim.schedule(function()
    if vim.api.nvim_win_is_valid(padnote_win) then
      vim.cmd("stopinsert")
    end
  end)
  
  vim.notify("Padnote opened: Chapter " .. chapter_idx, vim.log.levels.INFO)
  return true
end

-- Close padnote
function M.close(save_first)
  local ctx = context.current()
  if not ctx then
    return false
  end
  
  -- Check if padnote is open
  if not ctx.padnote_buf or not vim.api.nvim_buf_is_valid(ctx.padnote_buf) then
    vim.notify("No padnote open", vim.log.levels.WARN)
    return false
  end
  
  local buf = ctx.padnote_buf
  
  -- Save if requested
  if save_first then
    local modified = vim.api.nvim_get_option_value("modified", { buf = buf })
    if modified then
      local ok, err = pcall(vim.api.nvim_buf_call, buf, function()
        vim.cmd("write")
      end)
      
      if not ok then
        vim.notify("Failed to save padnote: " .. tostring(err), vim.log.levels.ERROR)
        return false
      end
    end
  end
  
  -- Stop auto-save timer
  stop_auto_save(ctx)
  
  -- Close window if valid
  if ctx.padnote_win and vim.api.nvim_win_is_valid(ctx.padnote_win) then
    vim.api.nvim_win_close(ctx.padnote_win, false)
  end
  
  -- Delete buffer (wipe to unload from memory)
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = false })
  end
  
  -- Clear context
  ctx.padnote_buf = nil
  ctx.padnote_win = nil
  ctx.padnote_chapter = nil
  
  vim.notify("Padnote closed", vim.log.levels.INFO)
  return true
end

-- Toggle padnote (complex logic)
function M.toggle()
  local ctx = context.current()
  if not ctx then
    vim.notify("No active book", vim.log.levels.WARN)
    return false
  end
  
  local current_chapter = ctx.current_chapter_idx
  local pad_exists = data.padnote_exists(ctx.data.slug, current_chapter, ctx.data)
  local pad_is_open = ctx.padnote_buf and vim.api.nvim_buf_is_valid(ctx.padnote_buf)
  
  -- Caso 1: Sem pad → criar e abrir
  if not pad_exists then
    return M.open()  -- M.open() will create the file with template
  end
  
  -- Caso 2: Pad existe, fechado → abrir
  if not pad_is_open then
    return M.open()
  end
  
  -- Caso 3: Pad aberto, mesmo capítulo → fechar e salvar
  if ctx.padnote_chapter == current_chapter then
    return M.close(true)  -- save_first = true
  end
  
  -- Caso 4: Pad aberto, capítulo diferente → trocar automaticamente
  -- Salva e fecha o anterior
  M.close(true)

  -- Abre o novo (will create file with template if needed)
  return M.open()
end

return M
