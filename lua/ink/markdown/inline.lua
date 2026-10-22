local util = require("ink.markdown.util")

local M = {}

-- Restore protected HTML fragments (code spans, links, images)
-- Placeholders can be nested (e.g. code inside link text), so loop a few times
local function restore(text, protected)
  local guard = 0
  while text:find("\1", 1, true) and guard < 5 do
    text = text:gsub("\1(%d+)\2", function(n)
      return protected[tonumber(n)]
    end)
    guard = guard + 1
  end
  return text
end

-- Underscore emphasis requires word boundaries (snake_case_name stays intact)
local function underscore_emphasis(text, delim, open, close)
  local pat = "(.?)" .. delim .. "([^_]+)" .. delim .. "(.?)"
  return (
    text:gsub(pat, function(pre, content, post)
      -- Delimiter glued to a word character: keep the original text
      if pre:match("%w") or post:match("%w") then
        return nil
      end
      return pre .. open .. content .. close .. post
    end)
  )
end

-- Process inline markdown elements (bold, italic, code, links, images)
-- Returns HTML string
function M.process_inline(text)
  if not text or text == "" then
    return ""
  end

  -- Placeholders use \1 and \2, so strip them from the input to avoid collisions
  text = text:gsub("[\1\2]", "")

  -- Store HTML fragments to protect them from markdown processing
  local protected = {}
  local function protect(html)
    protected[#protected + 1] = html
    return "\1" .. #protected .. "\2"
  end

  -- Escape quotes in URLs so they can't break out of the attribute
  local function safe_url(url)
    return (url:gsub('"', "%%22"))
  end

  -- Inline code: `code` - first, nothing inside a code span is processed
  text = text:gsub("`([^`]+)`", function(code)
    return protect("<code>" .. util.escape_html(code) .. "</code>")
  end)

  -- Images: ![alt](url) - must be before links
  -- A function is used as replacement so "%" in the URL is safe
  text = text:gsub("!%[([^%]]*)%]%(([^%)]+)%)", function(alt, url)
    return protect(string.format('<img src="%s" alt="%s" />', safe_url(url), util.escape_html(alt)))
  end)

  -- Links: [text](url)
  text = text:gsub("%[([^%]]-)%]%(([^%)]+)%)", function(link_text, url)
    return protect(string.format('<a href="%s">%s</a>', safe_url(url), util.escape_html(link_text)))
  end)

  -- Escape all remaining plain text ONCE
  text = util.escape_html(text)

  -- Bold + Italic: ***text*** or ___text___ (before individual bold/italic)
  -- Content is already escaped, so no further escaping here
  text = text:gsub("%*%*%*([^%*]+)%*%*%*", "<strong><em>%1</em></strong>")
  text = underscore_emphasis(text, "___", "<strong><em>", "</em></strong>")

  -- Bold: **text** or __text__
  text = text:gsub("%*%*([^%*]+)%*%*", "<strong>%1</strong>")
  text = underscore_emphasis(text, "__", "<strong>", "</strong>")

  -- Italic: *text* or _text_ (must be after bold to avoid conflicts)
  text = text:gsub("%*([^%*]+)%*", "<em>%1</em>")
  text = underscore_emphasis(text, "_", "<em>", "</em>")

  -- Strikethrough: ~~text~~
  text = text:gsub("~~([^~]+)~~", "<del>%1</del>")

  -- Restore protected fragments
  return restore(text, protected)
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

  return M.process_inline(text)
end

return M
