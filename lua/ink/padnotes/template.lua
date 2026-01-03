-- lua/ink/padnotes/template.lua
-- Responsabilidade: Gerar cabeçalhos de padnotes

local data_module = require("ink.padnotes.data")

local M = {}

-- Generate header for a new padnote
-- Format: # {book_title} - Chapter {idx}: {chapter_title}
--         *Created: {date}*
--         
--         ---
--         
--         
function M.generate_header(book_data, chapter_idx)
  local lines = {}
  
  -- Get book title
  local book_title = book_data.title or "Unknown Book"
  
  -- Get chapter title from TOC
  local chapter_title = ""
  if book_data.toc then
    local spine_href = book_data.spine[chapter_idx] and book_data.spine[chapter_idx].href
    if spine_href then
      for _, toc_item in ipairs(book_data.toc) do
        local toc_href = toc_item.href and toc_item.href:match("^([^#]+)") or toc_item.href
        if toc_href == spine_href then
          chapter_title = toc_item.label or ""
          break
        end
      end
    end
  end
  
  -- Fallback to generic chapter name
  if chapter_title == "" then
    chapter_title = "Chapter " .. chapter_idx
  end
  
  -- Format date
  local date = data_module.format_date_ptbr()
  
  -- Build header
  table.insert(lines, "# " .. book_title .. " - Chapter " .. chapter_idx .. ": " .. chapter_title)
  table.insert(lines, "*Created: " .. date .. "*")
  table.insert(lines, "")
  table.insert(lines, "---")
  table.insert(lines, "")
  table.insert(lines, "")
  
  return lines
end

-- Insert header into a buffer
-- Used when padnote is first created
function M.insert_header_to_buffer(buf, book_data, chapter_idx)
  local lines = M.generate_header(book_data, chapter_idx)
  
  -- Set lines in buffer
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  
  -- Position cursor after header (line 6, column 0)
  -- User can start typing immediately
  return 6
end

return M
