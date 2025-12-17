-- lua/ink/html/patterns.lua
-- Pre-compiled regex patterns for HTML parsing
-- Avoids recompiling patterns on every use

local M = {}

-- Pre-compiled patterns (compiled once on module load)
M.TAG_PATTERN = "<[^>]+>"
M.ID_PATTERN = 'id=["\']([^"\']+)["\']'
M.HREF_PATTERN = 'href=["\']([^"\']+)["\']'
M.SRC_PATTERN = 'src=["\']([^"\']+)["\']'
M.CLASS_PATTERN = 'class=["\']([^"\']+)["\']'
M.STYLE_PATTERN = 'style=["\']([^"\']+)["\']'
M.TITLE_PATTERN = 'title=["\']([^"\']+)["\']'
M.NAME_PATTERN = 'name=["\']([^"\']+)["\']'
M.ALT_PATTERN = 'alt=["\']([^"\']+)["\']'

-- Pattern for extracting tag name from tag content
M.TAG_NAME_PATTERN = "^/?([%w]+)"

-- Pattern for whitespace normalization
M.WHITESPACE_PATTERN = "[\n\r\t]"

-- Pattern for word splitting
M.WORD_PATTERN = "%S+"

-- Helper function to extract attribute value from tag content
function M.get_attribute(tag_content, pattern)
  return tag_content:match(pattern)
end

-- Extract multiple attributes at once (more efficient)
function M.extract_attributes(tag_content)
  return {
    id = tag_content:match(M.ID_PATTERN),
    href = tag_content:match(M.HREF_PATTERN),
    src = tag_content:match(M.SRC_PATTERN),
    class = tag_content:match(M.CLASS_PATTERN),
    style = tag_content:match(M.STYLE_PATTERN),
    title = tag_content:match(M.TITLE_PATTERN),
    name = tag_content:match(M.NAME_PATTERN),
    alt = tag_content:match(M.ALT_PATTERN)
  }
end

return M
