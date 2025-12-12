local data_encoder = require("ink.data")
local util = require("ink.export.util")

local M = {}

-- Flatten grouped highlights into array with chapter titles
local function flatten_highlights(highlights_grouped, chapter_map, include_context)
  local flattened = {}

  -- Get sorted chapter numbers
  local chapters = {}
  for ch, _ in pairs(highlights_grouped) do
    table.insert(chapters, ch)
  end
  table.sort(chapters)

  -- Process each chapter
  for _, ch in ipairs(chapters) do
    local highlights = highlights_grouped[ch]
    for _, hl in ipairs(highlights) do
      local entry = {
        chapter = ch,
        chapter_title = chapter_map[ch] or ("Chapter " .. ch),
        text = hl.text or "",
        color = hl.color or "yellow"
      }

      -- Add context if requested
      if include_context then
        entry.context_before = hl.context_before or ""
        entry.context_after = hl.context_after or ""
      end

      -- Add note if exists
      if hl.note and hl.note ~= "" then
        entry.note = hl.note
        entry.created_at = hl.created_at
        entry.updated_at = hl.updated_at
      end

      table.insert(flattened, entry)
    end
  end

  return flattened
end

-- Enrich bookmarks with chapter titles
local function enrich_bookmarks(bookmarks, chapter_map)
  local enriched = {}

  for _, bm in ipairs(bookmarks) do
    local entry = {
      id = bm.id,
      name = bm.name or "",
      chapter = bm.chapter,
      chapter_title = chapter_map[bm.chapter] or ("Chapter " .. bm.chapter),
      paragraph_line = bm.paragraph_line or 0,
      text_preview = bm.text_preview or "",
      created_at = bm.created_at
    }

    if bm.updated_at then
      entry.updated_at = bm.updated_at
    end

    table.insert(enriched, entry)
  end

  return enriched
end

-- Main formatting function
function M.format(book_data, options)
  options = options or {}

  -- Build export structure
  local export = {
    metadata = {
      title = book_data.metadata.title,
      author = book_data.metadata.author,
      language = book_data.metadata.language,
      date = book_data.metadata.date,
      description = book_data.metadata.description,
      tag = book_data.metadata.tag,
      slug = book_data.metadata.slug,
      export_date = book_data.metadata.export_date,
      export_date_formatted = util.format_timestamp(book_data.metadata.export_date),
      total_chapters = book_data.metadata.total_chapters
    },
    statistics = book_data.stats
  }

  -- Always include highlights (default export)
  export.highlights = flatten_highlights(
    book_data.highlights,
    book_data.chapter_map,
    options.include_context
  )

  -- Optional: bookmarks
  if options.include_bookmarks and book_data.bookmarks and #book_data.bookmarks > 0 then
    export.bookmarks = enrich_bookmarks(book_data.bookmarks, book_data.chapter_map)
  end

  -- Use pretty-print JSON encoder
  return data_encoder.json_encode(export)
end

return M
