local M = {}

-- Trim whitespace from string
function M.trim(s)
  return s:match("^%s*(.-)%s*$")
end

-- Convert string to slug (lowercase, replace spaces with dashes)
function M.slugify(str)
  str = str:lower()
  str = str:gsub("%s+", "-")
  str = str:gsub("[^a-z0-9%-]", "")
  str = str:gsub("%-+", "-")
  str = str:gsub("^%-", "")
  str = str:gsub("%-$", "")
  return str
end

-- Escape HTML special characters
function M.escape_html(text)
  local replacements = {
    ["&"] = "&amp;",
    ["<"] = "&lt;",
    [">"] = "&gt;",
    ['"'] = "&quot;",
    ["'"] = "&#39;"
  }
  return (text:gsub("[&<>\"']", replacements))
end

-- Detect heading level (returns level and text, or nil if not a heading)
function M.parse_heading(line)
  local hashes, text = line:match("^(#+)%s+(.+)$")
  if hashes then
    local level = #hashes
    if level >= 1 and level <= 6 then
      return level, M.trim(text)
    end
  end
  return nil
end

-- Check if line is horizontal rule
function M.is_horizontal_rule(line)
  local trimmed = M.trim(line)
  return trimmed:match("^%-%-%-+$") ~= nil
    or trimmed:match("^%*%*%*+$") ~= nil
    or trimmed:match("^___+$") ~= nil
end

-- Check if line starts a code block
function M.is_code_fence(line)
  local trimmed = M.trim(line)
  return trimmed:match("^```") ~= nil or trimmed:match("^~~~") ~= nil
end

-- Check if line is blockquote
function M.is_blockquote(line)
  return line:match("^>%s*") ~= nil
end

-- Get blockquote level and content
function M.parse_blockquote(line)
  local level = 0
  local content = line

  while content:match("^>%s*") do
    level = level + 1
    content = content:gsub("^>%s*", "", 1)
  end

  return level, content
end

-- Check if line is list item
function M.is_list_item(line)
  -- Unordered: -, *, +
  if line:match("^%s*[%-%*%+]%s+") then
    return "ul", line:match("^(%s*)[%-%*%+]%s+"), line:gsub("^%s*[%-%*%+]%s+", "")
  end

  -- Ordered: 1., 2., etc
  if line:match("^%s*%d+%.%s+") then
    return "ol", line:match("^(%s*)%d+%.%s+"), line:gsub("^%s*%d+%.%s+", "")
  end

  return nil
end

-- Calculate list indentation level (each 2 spaces = 1 level)
function M.get_indent_level(indent_str)
  return math.floor(#indent_str / 2)
end

-- Split string into lines
function M.split_lines(str)
  local lines = {}
  for line in (str .. "\n"):gmatch("([^\n]*)\n") do
    table.insert(lines, line)
  end
  return lines
end

-- Read file contents
function M.read_file(path)
  local file = io.open(path, "r")
  if not file then
    return nil, "Could not open file: " .. path
  end

  local content = file:read("*all")
  file:close()

  return content
end

-- Generate unique ID for anchors
local id_counter = 0
function M.generate_id(prefix)
  id_counter = id_counter + 1
  return (prefix or "id") .. "-" .. id_counter
end

return M
