-- lua/ink/ui/floating_toc.lua
-- Floating Table of Contents - experimental centered TOC

local context = require("ink.ui.context")
local render = require("ink.ui.render")

local M = {}

-- Track floating TOC state
local floating_state = {
  buf = nil,
  win = nil,
  toc_items = {},
  current_line = 1,
}

-- Find TOC item index for current chapter
local function find_current_toc_index(ctx)
  local current_spine_href = ctx.data.spine[ctx.current_chapter_idx].href

  for i, item in ipairs(ctx.data.toc) do
    if item.href then
      local item_href = item.href:match("^([^#]+)") or item.href
      if item_href == current_spine_href then
        return i
      end
    end
  end

  return 1
end

-- Render TOC lines with current position indicator
local function render_toc_lines(ctx)
  local lines = {}
  local current_idx = find_current_toc_index(ctx)

  -- Title
  table.insert(lines, "")

  for i, item in ipairs(ctx.data.toc) do
    local indent = string.rep(" ", (item.level or 0) + 2)
    local label = item.label:gsub("[\r\n]+", " ")

    -- Add indicator for current position
    local indicator = ""
    if i == current_idx then
      indicator = "  ← Here"
    end

    table.insert(lines, indent .. label .. indicator)
  end

  -- Footer
  table.insert(lines, "")
  table.insert(lines, "  [j/k: navigate | Enter: jump | q: close]")

  return lines, current_idx
end

-- Calculate window dimensions
local function get_window_config()
  local ui_width = vim.o.columns
  local ui_height = vim.o.lines

  -- Window size: 60% width, 70% height
  local width = math.floor(ui_width * 0.6)
  local height = math.floor(ui_height * 0.7)

  -- Center position
  local row = math.floor((ui_height - height) / 2)
  local col = math.floor((ui_width - width) / 2)

  return {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Table of Contents ",
    title_pos = "center",
  }
end

-- Navigate to selected TOC item
local function navigate_to_item(line_num, ctx)
  -- Adjust for title line (skip first line)
  local toc_idx = line_num - 1

  if toc_idx < 1 or toc_idx > #ctx.data.toc then
    return
  end

  local toc_item = ctx.data.toc[toc_idx]
  if not toc_item or not toc_item.href then
    return
  end

  -- Parse href
  local target_href = toc_item.href:match("^([^#]+)") or toc_item.href
  local anchor = toc_item.href:match("#(.+)$")

  -- Find chapter in spine
  for i, spine_item in ipairs(ctx.data.spine) do
    if spine_item.href == target_href then
      render.render_chapter(i, nil, ctx)

      -- Jump to anchor if present
      if anchor and ctx.content_win and vim.api.nvim_win_is_valid(ctx.content_win) then
        vim.schedule(function()
          if ctx.anchors[anchor] then
            vim.api.nvim_win_set_cursor(ctx.content_win, {ctx.anchors[anchor], 0})
            vim.cmd("normal! zz")
          end
        end)
      end

      break
    end
  end
end

-- Close floating TOC
local function close_floating_toc()
  if floating_state.win and vim.api.nvim_win_is_valid(floating_state.win) then
    vim.api.nvim_win_close(floating_state.win, true)
  end

  floating_state.win = nil
  floating_state.buf = nil
end

-- Setup buffer keymaps
local function setup_keymaps(buf, ctx)
  local opts = { buffer = buf, noremap = true, silent = true }

  -- Close with q or Esc
  vim.keymap.set("n", "q", close_floating_toc, opts)
  vim.keymap.set("n", "<Esc>", close_floating_toc, opts)

  -- Navigate and jump
  vim.keymap.set("n", "<CR>", function()
    local cursor = vim.api.nvim_win_get_cursor(floating_state.win)
    navigate_to_item(cursor[1], ctx)
    close_floating_toc()
  end, opts)

  -- Auto-close when leaving buffer
  vim.api.nvim_create_autocmd({"BufLeave", "WinLeave"}, {
    buffer = buf,
    callback = close_floating_toc,
    once = true,
  })
end

-- Show floating TOC
function M.show_floating_toc(ctx)
  ctx = ctx or context.current()
  if not ctx then return end

  -- Close if already open
  if floating_state.win and vim.api.nvim_win_is_valid(floating_state.win) then
    close_floating_toc()
    return
  end

  -- Check if TOC is empty
  if #ctx.data.toc == 0 then
    vim.notify("Table of contents is empty", vim.log.levels.WARN)
    return
  end

  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
  vim.api.nvim_set_option_value("filetype", "ink-toc", { buf = buf })

  -- Render TOC content
  local lines, current_idx = render_toc_lines(ctx)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  -- Create floating window
  local win_config = get_window_config()
  local win = vim.api.nvim_open_win(buf, true, win_config)

  -- Window options
  vim.api.nvim_set_option_value("number", false, { win = win })
  vim.api.nvim_set_option_value("relativenumber", false, { win = win })
  vim.api.nvim_set_option_value("cursorline", true, { win = win })
  vim.api.nvim_set_option_value("wrap", false, { win = win })

  -- Set cursor to current chapter (adjust for title line)
  vim.api.nvim_win_set_cursor(win, {current_idx + 1, 0})

  -- Setup keymaps
  setup_keymaps(buf, ctx)

  -- Save state
  floating_state.buf = buf
  floating_state.win = win
end

-- Toggle floating TOC
function M.toggle_floating_toc(ctx)
  ctx = ctx or context.current()
  if not ctx then return end

  if floating_state.win and vim.api.nvim_win_is_valid(floating_state.win) then
    close_floating_toc()
  else
    M.show_floating_toc(ctx)
  end
end

return M
