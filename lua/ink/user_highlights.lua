local fs = require("ink.fs")
local data = require("ink.data")
local migrate = require("ink.data.migrate")

local M = {}

-- In-memory cache for highlights: slug -> { highlights = {...}, by_chapter = {...} }
local highlights_cache = {}

local function get_highlights_path(slug)
  migrate.migrate_book(slug)
  return data.get_book_dir(slug) .. "/highlights.json"
end

function M.save(slug, highlights)
  local path = get_highlights_path(slug)
  local json = data.json_encode({ highlights = highlights })

  local file = io.open(path, "w")
  if not file then
    return false
  end

  -- Ensure file is always closed, even on error
  local ok = pcall(file.write, file, json)
  file:close()

  -- Invalidate cache on save
  if ok then
    highlights_cache[slug] = nil
  end

  return ok
end

-- Load highlights from disk (or cache)
function M.load(slug)
  -- Check cache first
  if highlights_cache[slug] then
    return highlights_cache[slug].data
  end

  local path = get_highlights_path(slug)

  if not fs.exists(path) then
    local empty = { highlights = {} }
    highlights_cache[slug] = { data = empty, by_chapter = {} }
    return empty
  end

  local content = fs.read_file(path)
  if not content then
    local empty = { highlights = {} }
    highlights_cache[slug] = { data = empty, by_chapter = {} }
    return empty
  end

  local ok, loaded = pcall(vim.json.decode, content)
  if not ok or not loaded then
    local empty = { highlights = {} }
    highlights_cache[slug] = { data = empty, by_chapter = {} }
    return empty
  end

  -- Build chapter index for fast lookup
  local by_chapter = {}
  for _, hl in ipairs(loaded.highlights or {}) do
    if hl.chapter then
      if not by_chapter[hl.chapter] then
        by_chapter[hl.chapter] = {}
      end
      table.insert(by_chapter[hl.chapter], hl)
    end
  end

  -- Cache loaded data with chapter index
  highlights_cache[slug] = { data = loaded, by_chapter = by_chapter }

  return loaded
end

-- Add a new highlight
function M.add_highlight(slug, highlight)
  local data = M.load(slug)
  table.insert(data.highlights, highlight)
  M.save(slug, data.highlights)
  return data.highlights
end

-- Remove highlight by text matching
function M.remove_highlight_by_text(slug, highlight)
  local data = M.load(slug)
  local new_highlights = {}

  for _, hl in ipairs(data.highlights) do
    -- Match by chapter and text content
    local is_match = hl.chapter == highlight.chapter and
                     hl.text == highlight.text and
                     hl.context_before == highlight.context_before and
                     hl.context_after == highlight.context_after

    if not is_match then
      table.insert(new_highlights, hl)
    end
  end

  M.save(slug, new_highlights)
  return new_highlights
end

-- Get highlights for a specific chapter (optimized with cache)
function M.get_chapter_highlights(slug, chapter)
  -- Load will use cache if available
  M.load(slug)

  -- Use cached chapter index if available
  local cache = highlights_cache[slug]
  if cache and cache.by_chapter[chapter] then
    return cache.by_chapter[chapter]
  end

  -- Return empty if chapter has no highlights
  return {}
end

-- Get cached highlights (for benchmark testing)
function M.get_cached(slug, chapter)
  return M.get_chapter_highlights(slug, chapter)
end

-- Update note on a highlight (match by text)
function M.update_note(slug, highlight, note_text)
  local data = M.load(slug)

  for _, hl in ipairs(data.highlights) do
    -- Match by chapter and text content
    if hl.chapter == highlight.chapter and
       hl.text == highlight.text and
       hl.context_before == highlight.context_before and
       hl.context_after == highlight.context_after then
      -- Update note
      if note_text and note_text ~= "" then
        hl.note = note_text
        hl.updated_at = os.time()
        if not hl.created_at then
          hl.created_at = os.time()
        end
      else
        -- Remove note if empty
        hl.note = nil
        hl.created_at = nil
        hl.updated_at = nil
      end
      break
    end
  end

  M.save(slug, data.highlights)
  return data.highlights
end

-- Update color on a highlight (match by text)
function M.update_color(slug, highlight, new_color)
  local data = M.load(slug)

  for _, hl in ipairs(data.highlights) do
    -- Match by chapter and text content
    if hl.chapter == highlight.chapter and
       hl.text == highlight.text and
       hl.context_before == highlight.context_before and
       hl.context_after == highlight.context_after then
      -- Update color
      hl.color = new_color
      hl.updated_at = os.time()
      if not hl.created_at then
        hl.created_at = os.time()
      end
      break
    end
  end

  M.save(slug, data.highlights)
  return data.highlights
end

return M
