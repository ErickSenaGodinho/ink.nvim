local data = require("ink.bookmarks.data")

local M = {}

function M.get_by_book(slug)
  local loaded = data.load(slug)
  local bookmarks = loaded.bookmarks or {}
  table.sort(bookmarks, function(a, b)
    if a.chapter ~= b.chapter then
      return a.chapter < b.chapter
    end
    -- For bookmarks in the same chapter, sort by ID (chronological order)
    -- This works because IDs are timestamp-based
    local a_line = a.paragraph_line or 0
    local b_line = b.paragraph_line or 0
    if a_line ~= b_line and (a_line > 0 or b_line > 0) then
      return a_line < b_line
    end
    -- Fallback to ID-based sorting (timestamp)
    return (a.id or "") < (b.id or "")
  end)
  return bookmarks
end

function M.get_chapter_bookmarks(slug, chapter)
  local bookmarks = M.get_by_book(slug)
  local result = {}
  for _, bm in ipairs(bookmarks) do
    if bm.chapter == chapter then
      table.insert(result, bm)
    end
  end
  return result
end

function M.find_by_id(slug, id)
  local bookmarks = M.get_by_book(slug)
  for _, bm in ipairs(bookmarks) do
    if bm.id == id then
      return bm
    end
  end
  return nil
end

function M.find_at_line(slug, chapter, line)
  local bookmarks = M.get_chapter_bookmarks(slug, chapter)
  for _, bm in ipairs(bookmarks) do
    if bm.paragraph_line == line then
      return bm
    end
  end
  return nil
end

function M.get_next(slug, current_chapter, current_line)
  local bookmarks = M.get_by_book(slug)
  for _, bm in ipairs(bookmarks) do
    if bm.chapter > current_chapter then
      return bm
    elseif bm.chapter == current_chapter then
      -- Use cached _line_idx if available, otherwise paragraph_line
      local bm_line = bm._line_idx or bm.paragraph_line
      if bm_line and bm_line > current_line then
        return bm
      end
    end
  end
  return nil
end

function M.get_prev(slug, current_chapter, current_line)
  local bookmarks = M.get_by_book(slug)
  local prev = nil
  for _, bm in ipairs(bookmarks) do
    if bm.chapter < current_chapter then
      prev = bm
    elseif bm.chapter == current_chapter then
      -- Use cached _line_idx if available, otherwise paragraph_line
      local bm_line = bm._line_idx or bm.paragraph_line
      if bm_line and bm_line < current_line then
        prev = bm
      else
        break
      end
    else
      break
    end
  end
  return prev
end

return M
