local M = {}

-- Word wrap text at specified width
function M.word_wrap(text, width)
  if not text or text == "" then
    return ""
  end

  width = width or 80
  local lines = {}
  local current_line = ""

  for word in text:gmatch("%S+") do
    local test_line = current_line == "" and word or (current_line .. " " .. word)
    if #test_line > width and current_line ~= "" then
      table.insert(lines, current_line)
      current_line = word
    else
      current_line = test_line
    end
  end

  if current_line ~= "" then
    table.insert(lines, current_line)
  end

  return table.concat(lines, "\n")
end

-- Format Unix timestamp to readable string
function M.format_timestamp(timestamp, format)
  if not timestamp then
    return "Unknown"
  end

  format = format or "%Y-%m-%d %H:%M:%S"
  return os.date(format, timestamp)
end

-- Escape markdown special characters
function M.escape_markdown(text)
  if not text then
    return ""
  end

  -- Escape: \ ` * _ { } [ ] ( ) # + - . ! |
  local escaped = text:gsub("([\\`*_{}%[%]()#+%.!|-])", "\\%1")
  return escaped
end

-- Sanitize filename (remove invalid characters)
function M.sanitize_filename(filename)
  if not filename then
    return "export"
  end

  -- Replace invalid characters with dash
  local sanitized = filename:gsub('[<>:"/\\|?*]', "-")
  -- Remove leading/trailing spaces and dots
  sanitized = sanitized:gsub("^[%. ]+", ""):gsub("[%. ]+$", "")
  -- Collapse multiple dashes
  sanitized = sanitized:gsub("%-+", "-")

  return sanitized ~= "" and sanitized or "export"
end

-- Convert text to URL-safe slug for Markdown anchors
function M.slugify(text)
  if not text or text == "" then
    return ""
  end

  local slug = text:lower()
  
  -- Replace Portuguese characters (UTF-8 aware)
  local replacements = {
    ["à"] = "a", ["á"] = "a", ["â"] = "a", ["ã"] = "a", ["ä"] = "a",
    ["è"] = "e", ["é"] = "e", ["ê"] = "e", ["ë"] = "e",
    ["ì"] = "i", ["í"] = "i", ["î"] = "i", ["ï"] = "i",
    ["ò"] = "o", ["ó"] = "o", ["ô"] = "o", ["õ"] = "o", ["ö"] = "o",
    ["ù"] = "u", ["ú"] = "u", ["û"] = "u", ["ü"] = "u",
    ["ç"] = "c", ["ñ"] = "n"
  }
  
  for char, replacement in pairs(replacements) do
    slug = slug:gsub(char, replacement)
  end
  
  -- Remove special characters except spaces, hyphens, and alphanumeric
  slug = slug:gsub("[^%w%s%-]", "")
  
  -- Replace spaces with hyphens
  slug = slug:gsub("%s+", "-")
  
  -- Collapse multiple hyphens
  slug = slug:gsub("%-+", "-")
  
  -- Remove leading/trailing hyphens
  slug = slug:gsub("^%-+", ""):gsub("%-+$", "")
  
  return slug
end

-- Get Unicode symbol for highlight color
function M.get_color_symbol(color)
  local symbols = {
    yellow = "■",  -- Black Square
    green = "●",   -- Black Circle
    red = "▲",     -- Black Up-Pointing Triangle
    blue = "◆",    -- Black Diamond
  }
  
  return symbols[color] or "■"
end

return M
