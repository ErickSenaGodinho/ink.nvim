local library = require("ink.library")
local user_highlights = require("ink.user_highlights")
local bookmarks_data = require("ink.bookmarks.data")
local context = require("ink.ui.context")

local M = {}

-- Get book metadata from library
local function get_book_metadata(slug)
  local lib = library.load()

  for _, book in ipairs(lib.books) do
    if book.slug == slug then
      return book
    end
  end

  return nil
end

-- Get TOC for export (try current context first, then parse EPUB)
local function get_toc_for_export(slug, book_path)
  -- Check if book is currently open
  local ctx = context.current()
  if ctx and ctx.data and ctx.data.slug == slug then
    return ctx.data.toc or {}
  end

  -- Otherwise, need to parse EPUB minimally for TOC
  if not book_path then
    return {}
  end

  local epub = require("ink.epub")
  local ok, epub_data = pcall(epub.open, book_path)
  if ok and epub_data then
    return epub_data.toc or {}
  end

  return {}
end

-- Build chapter index to title mapping from TOC
local function build_chapter_map(toc, total_chapters)
  local chapter_map = {}

  if not toc or #toc == 0 then
    -- Fallback: use generic chapter names
    for i = 1, (total_chapters or 1) do
      chapter_map[i] = "Chapter " .. i
    end
    return chapter_map
  end

  -- Extract chapter titles from TOC
  for i, entry in ipairs(toc) do
    if entry.label then
      chapter_map[i] = entry.label
    else
      chapter_map[i] = "Chapter " .. i
    end
  end

  return chapter_map
end

-- Group highlights by chapter
local function group_highlights_by_chapter(highlights)
  local grouped = {}

  for _, hl in ipairs(highlights) do
    local ch = hl.chapter or 1
    if not grouped[ch] then
      grouped[ch] = {}
    end
    table.insert(grouped[ch], hl)
  end

  return grouped
end

-- Calculate statistics
local function calculate_stats(highlights, bookmarks)
  local highlight_count = #highlights
  local notes_count = 0

  for _, hl in ipairs(highlights) do
    if hl.note and hl.note ~= "" then
      notes_count = notes_count + 1
    end
  end

  return {
    highlight_count = highlight_count,
    bookmark_count = #bookmarks,
    notes_count = notes_count
  }
end

-- Main function: collect all book data for export
function M.collect_book_data(slug, options)
  options = options or {}

  -- Validate slug
  if not slug or slug == "" then
    vim.notify("Invalid book slug", vim.log.levels.ERROR)
    return nil
  end

  -- Get metadata
  local metadata = get_book_metadata(slug)
  if not metadata then
    vim.notify("Book not found in library: " .. slug, vim.log.levels.ERROR)
    return nil
  end

  -- Load highlights (always, even if empty)
  local highlights_data = user_highlights.load(slug)
  local highlights = highlights_data.highlights or {}

  -- Load bookmarks (if requested)
  local bookmarks = {}
  if options.include_bookmarks then
    local bookmarks_data_loaded = bookmarks_data.load(slug)
    bookmarks = bookmarks_data_loaded.bookmarks or {}

    -- Sort bookmarks by chapter, then by paragraph_line
    table.sort(bookmarks, function(a, b)
      if a.chapter == b.chapter then
        return (a.paragraph_line or 0) < (b.paragraph_line or 0)
      end
      return a.chapter < b.chapter
    end)
  end

  -- Get TOC
  local toc = get_toc_for_export(slug, metadata.path)

  -- Build chapter map
  local chapter_map = build_chapter_map(toc, metadata.total_chapters)

  -- Group highlights by chapter
  local highlights_grouped = group_highlights_by_chapter(highlights)

  -- Calculate statistics
  local stats = calculate_stats(highlights, bookmarks)

  -- Build and return complete data structure
  return {
    metadata = {
      title = metadata.title or "Unknown",
      author = metadata.author or "Unknown",
      language = metadata.language or "unknown",
      date = metadata.date or "",
      description = metadata.description or "",
      tag = metadata.tag or "",
      slug = slug,
      export_date = os.time(),
      total_chapters = metadata.total_chapters or 1
    },
    chapter_map = chapter_map,
    highlights = highlights_grouped,
    bookmarks = bookmarks,
    toc = toc,
    stats = stats
  }
end

return M
