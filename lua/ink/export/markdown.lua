local util = require("ink.export.util")

local M = {}

-- Format metadata section (header)
local function format_metadata_section(metadata)
  local lines = {}

  table.insert(lines, "# " .. metadata.title)
  table.insert(lines, "**Autor**: " .. metadata.author)

  if metadata.language and metadata.language ~= "" then
    table.insert(lines, "**Idioma**: " .. metadata.language)
  end

  if metadata.date and metadata.date ~= "" then
    table.insert(lines, "**Publicado**: " .. metadata.date)
  end

  if metadata.tag and metadata.tag ~= "" then
    table.insert(lines, "**Tag**: " .. metadata.tag)
  end

  table.insert(lines, "**Exportado**: " .. util.format_timestamp(metadata.export_date))
  table.insert(lines, "")

  -- Description
  if metadata.description and metadata.description ~= "" then
    table.insert(lines, "## Descrição")
    table.insert(lines, util.word_wrap(metadata.description, 80))
    table.insert(lines, "")
  end

  return table.concat(lines, "\n")
end

-- Format statistics section
local function format_statistics_section(stats, total_chapters)
  local lines = {}

  table.insert(lines, "## Estatísticas")
  table.insert(lines, "- Capítulos totais: " .. (total_chapters or 0))
  table.insert(lines, string.format("- Highlights: %d (%d com notas)",
    stats.highlight_count or 0,
    stats.notes_count or 0))

  if stats.bookmark_count and stats.bookmark_count > 0 then
    table.insert(lines, "- Bookmarks: " .. stats.bookmark_count)
  end

  table.insert(lines, "")

  return table.concat(lines, "\n")
end

-- Format a single highlight
local function format_highlight(hl, chapter_num, chapter_title, idx, include_context)
  local lines = {}

  -- Capitalize color name
  local color = hl.color or "yellow"
  color = color:sub(1, 1):upper() .. color:sub(2)

  -- Highlight header
  table.insert(lines, string.format("#### Highlight %d (%s)", idx, color))

  -- Quote the highlighted text
  table.insert(lines, "> " .. (hl.text or ""))
  table.insert(lines, "")

  -- Context (if requested)
  if include_context then
    local context_before = hl.context_before or ""
    local context_after = hl.context_after or ""
    local text = hl.text or ""

    if context_before ~= "" or context_after ~= "" then
      table.insert(lines, "**Contexto**:")
      local context_line = context_before .. " **" .. text .. "** " .. context_after
      table.insert(lines, util.word_wrap(context_line, 80))
      table.insert(lines, "")
    end
  end

  -- Note (if exists)
  if hl.note and hl.note ~= "" then
    table.insert(lines, "**Nota**: " .. hl.note)
    table.insert(lines, "")
  end

  -- Location
  table.insert(lines, "**Localização**: Capítulo " .. chapter_num .. " - " .. chapter_title)
  table.insert(lines, "")
  table.insert(lines, "---")
  table.insert(lines, "")

  return table.concat(lines, "\n")
end

-- Format highlights section
local function format_highlights_section(highlights_grouped, chapter_map, include_context)
  local lines = {}

  table.insert(lines, "## Highlights")
  table.insert(lines, "")

  -- Get sorted chapter numbers
  local chapters = {}
  for ch, _ in pairs(highlights_grouped) do
    table.insert(chapters, ch)
  end
  table.sort(chapters)

  -- Process each chapter
  for _, ch in ipairs(chapters) do
    local chapter_title = chapter_map[ch] or ("Chapter " .. ch)
    local highlights = highlights_grouped[ch]

    -- Chapter header
    table.insert(lines, "### Capítulo " .. ch .. ": " .. chapter_title)
    table.insert(lines, "")

    -- Format each highlight in this chapter
    for idx, hl in ipairs(highlights) do
      table.insert(lines, format_highlight(hl, ch, chapter_title, idx, include_context))
    end
  end

  return table.concat(lines, "\n")
end

-- Format bookmarks section
local function format_bookmarks_section(bookmarks, chapter_map)
  if not bookmarks or #bookmarks == 0 then
    return ""
  end

  local lines = {}

  table.insert(lines, "## Bookmarks")
  table.insert(lines, "")

  for idx, bm in ipairs(bookmarks) do
    local chapter_title = chapter_map[bm.chapter] or ("Chapter " .. bm.chapter)

    table.insert(lines, string.format("### %d. %s", idx, bm.name or "Sem nome"))
    table.insert(lines, "**Capítulo**: " .. bm.chapter .. " - " .. chapter_title)

    if bm.text_preview and bm.text_preview ~= "" then
      table.insert(lines, "**Preview**: " .. util.word_wrap(bm.text_preview, 80))
    end

    if bm.created_at then
      table.insert(lines, "**Criado**: " .. util.format_timestamp(bm.created_at))
    end

    table.insert(lines, "")
    table.insert(lines, "---")
    table.insert(lines, "")
  end

  return table.concat(lines, "\n")
end

-- Main formatting function
function M.format(book_data, options)
  options = options or {}

  local sections = {}

  -- 1. Metadata (always)
  table.insert(sections, format_metadata_section(book_data.metadata))
  table.insert(sections, "---")
  table.insert(sections, "")

  -- 2. Statistics (always)
  table.insert(sections, format_statistics_section(book_data.stats, book_data.metadata.total_chapters))
  table.insert(sections, "---")
  table.insert(sections, "")

  -- 3. Highlights (default, even if empty)
  if book_data.highlights and next(book_data.highlights) ~= nil then
    table.insert(sections, format_highlights_section(
      book_data.highlights,
      book_data.chapter_map,
      options.include_context
    ))
  else
    table.insert(sections, "## Highlights")
    table.insert(sections, "")
    table.insert(sections, "*Nenhum highlight encontrado.*")
    table.insert(sections, "")
  end

  -- 4. Bookmarks (optional)
  if options.include_bookmarks then
    table.insert(sections, format_bookmarks_section(book_data.bookmarks, book_data.chapter_map))
  end

  return table.concat(sections, "\n")
end

return M
