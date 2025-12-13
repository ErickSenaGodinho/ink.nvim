-- lua/ink/ui/cache.lua
-- Responsabilidade: UI para gerenciamento de cache

local M = {}

-- Show cache management UI
function M.show_clear_cache_ui()
  local epub = require("ink.epub")
  local library = require("ink.library")

  local cached_books = epub.get_cached_books()

  if #cached_books == 0 then
    vim.notify("No cached books found", vim.log.levels.INFO)
    return
  end

  -- Match cached books with library entries to get titles
  local library_books = library.get_books()
  local cache_entries = {}

  for _, cached in ipairs(cached_books) do
    local title = nil
    for _, lib_book in ipairs(library_books) do
      if lib_book.slug == cached.slug then
        title = lib_book.title
        break
      end
    end

    table.insert(cache_entries, {
      slug = cached.slug,
      title = title or cached.slug,
      path = cached.path
    })
  end

  -- Try Telescope first
  local has_telescope, telescope = pcall(require, "telescope")
  if has_telescope then
    M.show_cache_telescope(cache_entries)
  else
    M.show_cache_floating(cache_entries)
  end
end

-- Telescope picker for cache management
function M.show_cache_telescope(cache_entries)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers.new({}, {
    prompt_title = "Clear Book Cache",
    finder = finders.new_table({
      results = cache_entries,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.title,
          ordinal = entry.title .. " " .. entry.slug,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)

        if selection then
          M.clear_book_cache(selection.value.slug, selection.value.title)
        end
      end)

      -- Add keymap to clear all
      map("i", "<C-a>", function()
        actions.close(prompt_bufnr)
        M.clear_all_cache()
      end)

      map("n", "<C-a>", function()
        actions.close(prompt_bufnr)
        M.clear_all_cache()
      end)

      return true
    end,
  }):find()
end

-- Fallback floating window for cache management
function M.show_cache_floating(cache_entries)
  local buf = vim.api.nvim_create_buf(false, true)
  local lines = {}

  table.insert(lines, "  Clear Book Cache")
  table.insert(lines, "  ──────────────────")
  table.insert(lines, "")

  for i, entry in ipairs(cache_entries) do
    table.insert(lines, string.format("  [%d] %s", i, entry.title))
  end

  table.insert(lines, "")
  table.insert(lines, "  [a] Clear all cache")
  table.insert(lines, "  [q] Cancel")

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  local width = 60
  local height = math.min(#lines, 20)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = (vim.o.columns - width) / 2,
    row = (vim.o.lines - height) / 2,
    style = "minimal",
    border = "rounded",
  })

  -- Keymaps
  local function close_window()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  -- Number keys to select book
  for i = 1, math.min(#cache_entries, 9) do
    vim.keymap.set("n", tostring(i), function()
      close_window()
      M.clear_book_cache(cache_entries[i].slug, cache_entries[i].title)
    end, { buffer = buf })
  end

  -- 'a' to clear all
  vim.keymap.set("n", "a", function()
    close_window()
    M.clear_all_cache()
  end, { buffer = buf })

  -- 'q' or Esc to cancel
  vim.keymap.set("n", "q", close_window, { buffer = buf })
  vim.keymap.set("n", "<Esc>", close_window, { buffer = buf })
end

-- Clear cache for specific book
function M.clear_book_cache(slug, title)
  local epub = require("ink.epub")
  local success, message = epub.clear_cache(slug)

  if success then
    vim.notify(string.format("Cleared cache for: %s", title or slug), vim.log.levels.INFO)
  else
    vim.notify(message, vim.log.levels.ERROR)
  end
end

-- Clear all cache
function M.clear_all_cache()
  local choice = vim.fn.confirm("Clear ALL book cache?", "&Yes\n&No", 2, "Question")

  if choice == 1 then
    local epub = require("ink.epub")
    local success, message = epub.clear_cache(nil)

    if success then
      vim.notify(message, vim.log.levels.INFO)
    else
      vim.notify(message, vim.log.levels.ERROR)
    end
  end
end

return M
