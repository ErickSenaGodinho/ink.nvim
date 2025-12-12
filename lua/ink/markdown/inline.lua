local util = require("ink.markdown.util")

local M = {}

-- Process inline markdown elements (bold, italic, code, links, images)
-- Returns HTML string
function M.process_inline(text)
  if not text or text == "" then
    return ""
  end

  -- Images: ![alt](url) - must be before links (before escaping)
  text = text:gsub("!%[([^%]]*)%]%(([^%)]+)%)", function(alt, url)
    -- Escape alt text but not the tag itself
    alt = util.escape_html(alt)
    return string.format('<img src="%s" alt="%s" />', url, alt)
  end)

  -- Links: [text](url) (before escaping)
  text = text:gsub("%[([^%]]-)%]%(([^%)]+)%)", function(link_text, url)
    -- Escape link text but not the tag itself
    link_text = util.escape_html(link_text)
    -- Check if it's an anchor link
    if url:match("^#") then
      return string.format('<a href="%s" id="%s">%s</a>', url, url:gsub("#", ""), link_text)
    else
      return string.format('<a href="%s">%s</a>', url, link_text)
    end
  end)

  -- Bold + Italic: ***text*** or ___text___ (before individual bold/italic)
  text = text:gsub("%*%*%*([^%*]+)%*%*%*", function(content)
    content = util.escape_html(content)
    return "<strong><em>" .. content .. "</em></strong>"
  end)
  text = text:gsub("___([^_]+)___", function(content)
    content = util.escape_html(content)
    return "<strong><em>" .. content .. "</em></strong>"
  end)

  -- Bold: **text** or __text__
  text = text:gsub("%*%*([^%*]+)%*%*", function(content)
    content = util.escape_html(content)
    return "<strong>" .. content .. "</strong>"
  end)
  text = text:gsub("__([^_]+)__", function(content)
    content = util.escape_html(content)
    return "<strong>" .. content .. "</strong>"
  end)

  -- Italic: *text* or _text_ (must be after bold to avoid conflicts)
  text = text:gsub("%*([^%*]+)%*", function(content)
    content = util.escape_html(content)
    return "<em>" .. content .. "</em>"
  end)
  text = text:gsub("_([^_]+)_", function(content)
    content = util.escape_html(content)
    return "<em>" .. content .. "</em>"
  end)

  -- Inline code: `code`
  text = text:gsub("`([^`]+)`", function(code)
    code = util.escape_html(code)
    return "<code>" .. code .. "</code>"
  end)

  -- Strikethrough: ~~text~~
  text = text:gsub("~~([^~]+)~~", function(content)
    content = util.escape_html(content)
    return "<del>" .. content .. "</del>"
  end)

  -- Escape remaining text (parts that weren't markdown)
  -- This needs special handling: escape only non-tag parts
  -- For simplicity, we'll trust that all markdown has been processed

  return text
end

-- Process bold/italic combinations
-- Handles cases like ***text*** (bold + italic)
function M.process_emphasis(text)
  -- Bold + Italic: ***text*** or ___text___
  text = text:gsub("%*%*%*([^%*]+)%*%*%*", "<strong><em>%1</em></strong>")
  text = text:gsub("___([^_]+)___", "<strong><em>%1</em></strong>")

  return text
end

-- Extract and process inline elements
function M.parse(text)
  if not text or text == "" then
    return ""
  end

  -- First handle emphasis combinations
  text = M.process_emphasis(text)

  -- Then process other inline elements
  text = M.process_inline(text)

  return text
end

return M
