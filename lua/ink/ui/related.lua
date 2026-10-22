local M = {}

local related = require("ink.data.related")
local library = require("ink.library")
local context = require("ink.ui.context")

local FORMAT_ICONS = {
  epub = "📚",
  markdown = "📝",
  web = "🌐",
}
local DEFAULT_ICON = "📄"

-- Column widths for picker rows
local COL_TITLE = 28
local COL_AUTHOR = 20
local COL_TAG = 15
local DESCRIPTION_WRAP = 60

-- Truncate (with ellipsis) and pad a string to an exact display width
local function fit_string(str, width)
  str = str or ""
  local vw = vim.fn.strdisplaywidth(str)
  if vw <= width then
    return str .. string.rep(" ", width - vw)
  end

  -- Truncate by characters, single pass
  local out, w = {}, 0
  for _, ch in ipairs(vim.fn.split(str, "\\zs")) do
    local cw = vim.fn.strdisplaywidth(ch)
    if w + cw > width - 1 then
      break
    end
    table.insert(out, ch)
    w = w + cw
  end
  return table.concat(out) .. "…" .. string.rep(" ", width - w - 1)
end

-- Reading progress as 0-100, safe against nil and zero chapters
local function progress_percent(book)
  local total = tonumber(book.total_chapters) or 0
  if total <= 0 then
    return 0
  end
  local chapter = tonumber(book.chapter) or 0
  return math.min(100, math.floor(chapter / total * 100))
end

-- Simple word wrap for the preview description
local function wrap_text(text, width)
  local lines, line = {}, ""
  for word in text:gmatch("%S+") do
    if line == "" then
      line = word
    elseif #line + 1 + #word <= width then
      line = line .. " " .. word
    else
      table.insert(lines, line)
      line = word
    end
  end
  if line ~= "" then
    table.insert(lines, line)
  end
  return lines
end

-- One-line picker row for a book
local function format_row(book)
  local icon = FORMAT_ICONS[book.format or "epub"] or DEFAULT_ICON
  return string.format(
    "%s %s │ %s │ %s │ %3d%% │ %s",
    icon,
    fit_string(book.title or "Untitled", COL_TITLE),
    fit_string(book.author or "Unknown", COL_AUTHOR),
    fit_string(book.tag or "", COL_TAG),
    progress_percent(book),
    library.format_last_opened(book.last_opened)
  )
end

-- Preview lines for the "Book Info" pane
local function preview_lines(book)
  local format = book.format or "epub"
  local lines = {
    "Title: " .. (book.title or "Untitled"),
    "Author: " .. (book.author or "Unknown"),
    "Format: " .. (FORMAT_ICONS[format] or DEFAULT_ICON) .. " " .. format:upper(),
  }
  if book.language then
    table.insert(lines, "Language: " .. book.language)
  end
  if book.date then
    table.insert(lines, "Date: " .. book.date)
  end

  table.insert(lines, "")
  table.insert(
    lines,
    string.format(
      "Progress: %d%% (Chapter %s/%s)",
      progress_percent(book),
      tostring(book.chapter or 0),
      tostring(book.total_chapters or 0)
    )
  )
  table.insert(lines, "Last opened: " .. library.format_last_opened(book.last_opened))

  if book.description and book.description ~= "" then
    table.insert(lines, "")
    table.insert(lines, "Description:")
    for _, l in ipairs(wrap_text(book.description, DESCRIPTION_WRAP)) do
      table.insert(lines, "  " .. l)
    end
  end

  table.insert(lines, "")
  table.insert(lines, "Path: " .. tostring(book.path))
  return lines
end

-- Generic book picker.
-- opts: { title, books, on_select(book), mappings = { [key] = fn(book, prompt_bufnr) } }
-- Uses Telescope when available, vim.ui.select otherwise (mappings are ignored there).
local function open_book_picker(opts)
  local has_telescope = pcall(require, "telescope")
  if not has_telescope then
    vim.ui.select(opts.books, {
      prompt = opts.title,
      format_item = format_row,
    }, function(book)
      if book then
        opts.on_select(book)
      end
    end)
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config")
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local previewers = require("telescope.previewers")

  pickers
    .new({}, {
      prompt_title = opts.title,
      finder = finders.new_table({
        results = opts.books,
        entry_maker = function(book)
          return {
            value = book,
            book = book,
            display = format_row(book),
            ordinal = (book.title or "") .. " " .. (book.author or "") .. " " .. (book.tag or ""),
          }
        end,
      }),
      previewer = previewers.new_buffer_previewer({
        title = "Book Info",
        define_preview = function(self, entry)
          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, preview_lines(entry.book))
        end,
      }),
      sorter = conf.values.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          if not selection then
            return -- empty filtered list
          end
          actions.close(prompt_bufnr)
          opts.on_select(selection.book)
        end)

        for key, handler in pairs(opts.mappings or {}) do
          local function run()
            local selection = action_state.get_selected_entry()
            if selection then
              handler(selection.book, prompt_bufnr)
            end
          end
          map("i", key, run)
          map("n", key, run)
        end

        return true
      end,
    })
    :find()
end

-- Open a related book
function M.open_related_book(book)
  local ui = require("ink.ui")
  local ok, data = library.open_book(book.path, book.format)
  if not ok then
    vim.notify(
      "Failed to open related book: " .. (book.title or "?") .. " (" .. tostring(data) .. ")",
      vim.log.levels.ERROR
    )
    return
  end

  local related_config = context.config.related_resources or {}
  local show_toc = related_config.show_toc
  if show_toc == nil then
    show_toc = false
  end

  ui.open_book(data, { position = related_config.position or "right", show_toc = show_toc })
end

-- Show related resources for the current book
function M.show_related_resources()
  local ctx = context.current()
  if not ctx or not ctx.data then
    vim.notify("No book currently open", vim.log.levels.WARN)
    return
  end

  local book_slug = ctx.data.slug
  local related_slugs = related.get_related_slugs(book_slug)

  if #related_slugs == 0 then
    vim.notify("No related resources for this book", vim.log.levels.INFO)
    return
  end

  -- Index library by slug once instead of scanning per related slug
  local by_slug = {}
  for _, book in ipairs(library.get_books()) do
    by_slug[book.slug] = book
  end

  local related_books, broken = {}, {}
  for _, slug in ipairs(related_slugs) do
    if by_slug[slug] then
      table.insert(related_books, by_slug[slug])
    else
      -- Slug exists in related.json but not in the library
      table.insert(broken, slug)
    end
  end

  if #broken > 0 then
    vim.notify(
      string.format(
        "%d broken related reference(s) (%s): book deleted from library. Run :InkHealth to clean up.",
        #broken,
        table.concat(broken, ", ")
      ),
      vim.log.levels.WARN
    )
  end

  if #related_books == 0 then
    vim.notify("All related resources have been deleted from library", vim.log.levels.WARN)
    return
  end

  open_book_picker({
    title = "Related Resources (Enter: open | Ctrl-d: remove)",
    books = related_books,
    on_select = M.open_related_book,
    mappings = {
      ["<C-d>"] = function(book, prompt_bufnr)
        local prompt = string.format("Remove related resource '%s'?", book.title or book.slug)
        if vim.fn.confirm(prompt, "&Yes\n&No", 2) ~= 1 then
          return
        end

        local ok, err = related.remove_related(book_slug, book.slug)
        if not ok then
          vim.notify("Failed to remove related resource: " .. tostring(err), vim.log.levels.ERROR)
          return
        end

        vim.notify("Removed related resource: " .. (book.title or book.slug), vim.log.levels.INFO)
        require("telescope.actions").close(prompt_bufnr)
        M.show_related_resources() -- refresh with the updated list
      end,
    },
  })
end

-- Pick a library book to relate to the current one
function M.add_related_resource()
  local ctx = context.current()
  if not ctx or not ctx.data then
    vim.notify("No book currently open", vim.log.levels.WARN)
    return
  end

  local current_slug = ctx.data.slug
  local already_related = related.get_related(current_slug)

  -- Exclude the current book and books that are already related
  local candidates = {}
  for _, book in ipairs(library.get_books()) do
    if book.slug ~= current_slug and not already_related[book.slug] then
      table.insert(candidates, book)
    end
  end

  if #candidates == 0 then
    vim.notify("No other books available to relate", vim.log.levels.INFO)
    return
  end

  open_book_picker({
    title = "Add Related Resource (Enter: add)",
    books = candidates,
    on_select = function(book)
      local ok, err = related.add_related(current_slug, book.slug)
      if ok then
        vim.notify("Added related resource: " .. (book.title or book.slug), vim.log.levels.INFO)
      else
        vim.notify("Failed to add related resource: " .. tostring(err), vim.log.levels.ERROR)
      end
    end,
  })
end

return M

