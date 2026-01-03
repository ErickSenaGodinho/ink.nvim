-- lua/ink/padnotes/ui.lua
-- Floating window para listar padnotes (padrão floating_toc.lua)

local context = require("ink.ui.context")
local data = require("ink.padnotes.data")
local actions = require("ink.padnotes.actions")

local M = {}

-- Track floating window state
local floating_state = {
  list_buf = nil,
  list_win = nil,
  preview_buf = nil,
  preview_win = nil,
  ctx = nil,
  padnotes = {},
}

-- Render list lines
local function render_list_lines(padnotes)
  local lines = {}
  
  for _, padnote in ipairs(padnotes) do
    local line = "  " .. padnote.title
    table.insert(lines, line)
  end
  
  return lines
end

-- Get preview lines for a padnote
local function get_preview_lines(padnote)
  if not padnote then
    return { "", "  No preview available", "" }
  end
  
  -- Read preview from file
  local preview_lines = data.read_padnote_preview(padnote.path, 15)
  
  -- Format with indentation
  local formatted_lines = {}
  table.insert(formatted_lines, "")
  
  for _, line in ipairs(preview_lines) do
    table.insert(formatted_lines, "  " .. line)
  end
  
  table.insert(formatted_lines, "")
  table.insert(formatted_lines, "  [Preview - first " .. #preview_lines .. " lines]")
  
  return formatted_lines
end

-- Update preview based on cursor position
local function update_preview(line_num)
  if not floating_state.preview_buf or not vim.api.nvim_buf_is_valid(floating_state.preview_buf) then
    return
  end
  
  if line_num < 1 or line_num > #floating_state.padnotes then
    return
  end
  
  local padnote = floating_state.padnotes[line_num]
  local preview_lines = get_preview_lines(padnote)
  
  vim.api.nvim_set_option_value("modifiable", true, { buf = floating_state.preview_buf })
  vim.api.nvim_buf_set_lines(floating_state.preview_buf, 0, -1, false, preview_lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = floating_state.preview_buf })
  
  -- Reset scroll to top
  if floating_state.preview_win and vim.api.nvim_win_is_valid(floating_state.preview_win) then
    vim.api.nvim_win_set_cursor(floating_state.preview_win, {1, 0})
  end
end

-- Calculate window dimensions (split layout like floating_toc)
local function get_window_configs()
  local ui_width = vim.o.columns
  local ui_height = vim.o.lines
  
  -- Total window size
  local total_width = math.floor(ui_width * 0.70)
  local total_height = math.floor(ui_height * 0.70)
  
  -- Center position
  local row = math.floor((ui_height - total_height) / 2)
  local col = math.floor((ui_width - total_width) / 2)
  
  -- Split widths: List 30%, Preview 70%
  local list_width = math.floor(total_width * 0.30)
  local preview_width = total_width - list_width - 1
  
  local list_config = {
    relative = "editor",
    width = list_width,
    height = total_height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Padnotes ",
    title_pos = "center",
  }
  
  local preview_config = {
    relative = "editor",
    width = preview_width,
    height = total_height,
    row = row,
    col = col + list_width + 1,
    style = "minimal",
    border = "rounded",
    title = " Preview ",
    title_pos = "center",
  }
  
  return list_config, preview_config
end

-- Open selected padnote
local function open_selected_padnote(line_num)
  if line_num < 1 or line_num > #floating_state.padnotes then
    return
  end
  
  local padnote = floating_state.padnotes[line_num]
  if not padnote then
    return
  end
  
  -- Close floating windows
  M.close_floating_windows()
  
  -- Get context
  local ctx = context.current()
  if not ctx then
    return
  end
  
  -- If there's a padnote open, close it first
  if ctx.padnote_buf and vim.api.nvim_buf_is_valid(ctx.padnote_buf) then
    actions.close(true)
  end
  
  -- Open selected padnote
  actions.open(padnote.chapter_idx)
end

-- Close floating windows
function M.close_floating_windows()
  if floating_state.list_win and vim.api.nvim_win_is_valid(floating_state.list_win) then
    vim.api.nvim_win_close(floating_state.list_win, true)
  end
  
  if floating_state.preview_win and vim.api.nvim_win_is_valid(floating_state.preview_win) then
    vim.api.nvim_win_close(floating_state.preview_win, true)
  end
  
  floating_state.list_win = nil
  floating_state.list_buf = nil
  floating_state.preview_win = nil
  floating_state.preview_buf = nil
  floating_state.ctx = nil
  floating_state.padnotes = {}
end

-- Setup keymaps
local function setup_keymaps(list_buf)
  local opts = { buffer = list_buf, noremap = true, silent = true }
  
  -- Close
  vim.keymap.set("n", "q", M.close_floating_windows, opts)
  vim.keymap.set("n", "<Esc>", M.close_floating_windows, opts)
  
  -- Open padnote
  vim.keymap.set("n", "<CR>", function()
    if floating_state.list_win and vim.api.nvim_win_is_valid(floating_state.list_win) then
      local cursor = vim.api.nvim_win_get_cursor(floating_state.list_win)
      open_selected_padnote(cursor[1])
    end
  end, opts)
  
  -- Update preview on cursor move
  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = list_buf,
    callback = function()
      if floating_state.list_win and vim.api.nvim_win_is_valid(floating_state.list_win) then
        local cursor = vim.api.nvim_win_get_cursor(floating_state.list_win)
        update_preview(cursor[1])
      end
    end,
  })
end

-- Main entry point
function M.list_all()
  local ctx = context.current()
  if not ctx then
    vim.notify("No active book", vim.log.levels.WARN)
    return
  end
  
  -- Load padnotes
  local padnotes = data.list_padnotes(ctx.data.slug, ctx.data)
  
  if #padnotes == 0 then
    vim.notify("No padnotes found for this book", vim.log.levels.INFO)
    return
  end
  
  -- Store state
  floating_state.ctx = ctx
  floating_state.padnotes = padnotes
  
  -- Get window configs
  local list_config, preview_config = get_window_configs()
  
  -- Create list buffer
  local list_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = list_buf })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = list_buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = list_buf })
  vim.api.nvim_set_option_value("filetype", "ink-padnotes", { buf = list_buf })
  
  -- Render list
  local lines = render_list_lines(padnotes)
  vim.api.nvim_buf_set_lines(list_buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = list_buf })
  
  -- Create preview buffer
  local preview_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = preview_buf })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = preview_buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = preview_buf })
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = preview_buf })
  
  -- Create floating windows
  local list_win = vim.api.nvim_open_win(list_buf, true, list_config)
  local preview_win = vim.api.nvim_open_win(preview_buf, false, preview_config)
  
  -- Window options
  vim.api.nvim_set_option_value("cursorline", true, { win = list_win })
  vim.api.nvim_set_option_value("wrap", false, { win = list_win })
  vim.api.nvim_set_option_value("wrap", true, { win = preview_win })
  
  -- Store window/buffer references
  floating_state.list_buf = list_buf
  floating_state.list_win = list_win
  floating_state.preview_buf = preview_buf
  floating_state.preview_win = preview_win
  
  -- Setup keymaps
  setup_keymaps(list_buf)
  
  -- Auto-close when leaving buffer
  vim.api.nvim_create_autocmd({"BufLeave", "WinLeave"}, {
    buffer = list_buf,
    callback = M.close_floating_windows,
    once = true,
  })
  
  -- Show initial preview
  update_preview(1)
  
  -- Focus list window
  vim.api.nvim_set_current_win(list_win)
end

return M
