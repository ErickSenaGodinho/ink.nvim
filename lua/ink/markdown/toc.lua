local util = require("ink.markdown.util")

local M = {}

-- Split markdown content into chapters based on H1 headings
-- Returns: { {title = "Chapter 1", content = "...", start_line = 1}, ... }
function M.split_by_h1(content)
  local lines = util.split_lines(content)
  local chapters = {}
  local current_chapter = nil

  for line_num, line in ipairs(lines) do
    local level, text = util.parse_heading(line)

    if level == 1 then
      -- Save previous chapter
      if current_chapter then
        table.insert(chapters, current_chapter)
      end

      -- Start new chapter
      current_chapter = {
        title = text,
        lines = {},
        start_line = line_num
      }
    end

    -- Add line to current chapter
    if current_chapter then
      table.insert(current_chapter.lines, line)
    else
      -- Lines before first H1 go into an "Introduction" chapter
      if not current_chapter then
        current_chapter = {
          title = "Introduction",
          lines = {},
          start_line = 1
        }
      end
      table.insert(current_chapter.lines, line)
    end
  end

  -- Add last chapter
  if current_chapter and #current_chapter.lines > 0 then
    table.insert(chapters, current_chapter)
  end

  -- Convert lines array to content string
  for _, chapter in ipairs(chapters) do
    chapter.content = table.concat(chapter.lines, "\n")
    chapter.lines = nil
  end

  return chapters
end

-- Split markdown content into chapters based on H2 headings
-- Used when no H1 headings are found
function M.split_by_h2(content)
  local lines = util.split_lines(content)
  local chapters = {}
  local current_chapter = nil

  for line_num, line in ipairs(lines) do
    local level, text = util.parse_heading(line)

    if level == 2 then
      -- Save previous chapter
      if current_chapter then
        table.insert(chapters, current_chapter)
      end

      -- Start new chapter
      current_chapter = {
        title = text,
        lines = {},
        start_line = line_num
      }
    end

    -- Add line to current chapter
    if current_chapter then
      table.insert(current_chapter.lines, line)
    else
      -- Lines before first H2 go into default chapter
      if not current_chapter then
        current_chapter = {
          title = "Content",
          lines = {},
          start_line = 1
        }
      end
      table.insert(current_chapter.lines, line)
    end
  end

  -- Add last chapter
  if current_chapter and #current_chapter.lines > 0 then
    table.insert(chapters, current_chapter)
  end

  -- Convert lines array to content string
  for _, chapter in ipairs(chapters) do
    chapter.content = table.concat(chapter.lines, "\n")
    chapter.lines = nil
  end

  return chapters
end

-- Main function to split content into chapters
-- Tries H1 first, falls back to H2 if no H1 found
function M.split_into_chapters(content)
  local chapters = M.split_by_h1(content)

  -- If only one chapter found (no H1s), try splitting by H2
  if #chapters <= 1 then
    local h2_chapters = M.split_by_h2(content)
    if #h2_chapters > 1 then
      return h2_chapters
    end
  end

  -- If still only one chapter, return it
  if #chapters == 0 then
    chapters = {{
      title = "Content",
      content = content,
      start_line = 1
    }}
  end

  return chapters
end

-- Extract all headings from content for TOC
-- Returns: { {level = 1, text = "...", line = 1, id = "..."}, ... }
function M.extract_headings(content, max_level)
  max_level = max_level or 2  -- Default: H1 and H2 only
  local lines = util.split_lines(content)
  local headings = {}

  for line_num, line in ipairs(lines) do
    local level, text = util.parse_heading(line)

    if level and level <= max_level then
      table.insert(headings, {
        level = level,
        text = text,
        line = line_num,
        id = util.slugify(text)
      })
    end
  end

  return headings
end

-- Build TOC from chapters
-- Returns structure compatible with EPUB TOC
function M.build_toc(chapters, max_level)
  max_level = max_level or 2
  local toc = {}

  for chapter_idx, chapter in ipairs(chapters) do
    local chapter_id = "chapter-" .. chapter_idx

    -- Add chapter heading (H1 or H2 depending on how it was split)
    table.insert(toc, {
      label = chapter.title,
      href = chapter_id,
      level = 1,
      chapter_index = chapter_idx
    })

    -- Extract sub-headings within this chapter
    if max_level > 1 then
      local headings = M.extract_headings(chapter.content, max_level)

      for _, heading in ipairs(headings) do
        -- Skip the first heading if it's the chapter title
        if heading.level > 1 or heading.text ~= chapter.title then
          table.insert(toc, {
            label = heading.text,
            href = chapter_id .. "#" .. heading.id,
            level = heading.level,
            chapter_index = chapter_idx
          })
        end
      end
    end
  end

  return toc
end

-- Build simplified TOC (only chapter titles)
function M.build_simple_toc(chapters)
  local toc = {}

  for chapter_idx, chapter in ipairs(chapters) do
    table.insert(toc, {
      label = chapter.title,
      href = "chapter-" .. chapter_idx,
      level = 1,
      chapter_index = chapter_idx
    })
  end

  return toc
end

return M
