local util = require("ink.markdown.util")
local toc = require("ink.markdown.toc")
local parser = require("ink.markdown.parser")

local M = {}

-- Generate slug from filepath
local function generate_slug(filepath)
  local filename = vim.fn.fnamemodify(filepath, ":t:r")  -- Get filename without extension
  return util.slugify(filename) .. "-md"
end

-- Generate title from filepath
local function generate_title(filepath)
  return vim.fn.fnamemodify(filepath, ":t:r")
end

-- Open and parse a markdown file
-- Returns data structure compatible with EPUB format
function M.open(filepath)
  -- local start_time = vim.loop.hrtime()  -- DEBUG: Start timing

  -- Convert to absolute path
  filepath = vim.fn.fnamemodify(filepath, ":p")

  -- Check if file exists
  if vim.fn.filereadable(filepath) ~= 1 then
    return nil, "File not found: " .. filepath
  end

  -- Read file content
  local content, err = util.read_file(filepath)
  if not content then
    return nil, err
  end

  -- Split into chapters
  local chapters = toc.split_into_chapters(content)

  if not chapters or #chapters == 0 then
    return nil, "Failed to parse markdown file"
  end

  -- Convert each chapter to HTML
  local spine = {}
  for idx, chapter in ipairs(chapters) do
    local html = parser.parse(chapter.content)
    table.insert(spine, {
      content = html,           -- HTML content (Markdown specific)
      href = "chapter-" .. idx, -- Virtual href for compatibility
      title = chapter.title,
      index = idx
    })
  end

  -- Build table of contents
  local table_of_contents = toc.build_simple_toc(chapters)

  -- Generate metadata
  local slug = generate_slug(filepath)
  local title = generate_title(filepath)

  -- DEBUG: Calculate elapsed time
  -- local end_time = vim.loop.hrtime()
  -- local elapsed_ms = (end_time - start_time) / 1000000  -- Convert nanoseconds to milliseconds
  -- vim.notify(string.format("⏱️  Markdown parsing took %.0f ms", elapsed_ms), vim.log.levels.INFO)

  -- Return structure compatible with EPUB
  return {
    title = title,
    author = "Unknown",  -- MD files don't have metadata by default
    language = "en",
    date = nil,
    description = nil,
    spine = spine,
    toc = table_of_contents,
    slug = slug,
    base_dir = vim.fn.fnamemodify(filepath, ":h"),  -- Directory containing the MD file
    cache_dir = nil,  -- MD doesn't need extraction/caching
    path = filepath,
    format = "markdown"  -- Flag to identify format
  }
end

-- Check if a file is a markdown file
function M.is_markdown(filepath)
  return filepath:match("%.md$") ~= nil
    or filepath:match("%.markdown$") ~= nil
end

-- Export parser for advanced usage
M.parser = parser
M.toc_builder = toc
M.util = util

return M
