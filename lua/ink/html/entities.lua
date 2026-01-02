local M = {}

-- Safe character conversion with bounds checking
local function safe_char(num)
  -- Valid Unicode range: 0x0000 to 0x10FFFF (1114111 decimal)
  -- Exclude surrogate pairs: 0xD800 to 0xDFFF
  if not num or num < 0 or num > 0x10FFFF then
    return ""
  end
  if num >= 0xD800 and num <= 0xDFFF then
    return ""
  end

  -- Try utf8.char first (Neovim 0.10+)
  if utf8 and utf8.char then
    local ok, result = pcall(utf8.char, num)
    if ok then
      return result
    end
  end

  -- Fallback to string.char for ASCII range (0-127)
  if num <= 127 then
    return string.char(num)
  end

  -- For non-ASCII, return empty string (better than crash)
  -- Most common HTML entities are ASCII anyway
  return ""
end

-- Entity lookup table for faster replacement
local entity_map = {
  ["&lt;"] = "<",
  ["&gt;"] = ">",
  ["&amp;"] = "&",
  ["&quot;"] = '"',
  ["&apos;"] = "'",
  ["&nbsp;"] = " ",
}

-- Optimized: single gsub pass instead of multiple sequential gsub calls
function M.decode_entities(str)
  -- Single gsub with pattern that matches all entity types
  return str:gsub("&(#?x?)([%w]+);", function(prefix, value)
    if prefix == "" then
      -- Named entity (e.g., &lt;)
      local full_entity = "&" .. value .. ";"
      return entity_map[full_entity] or full_entity
    elseif prefix == "#" then
      -- Decimal numeric entity (e.g., &#65;)
      return safe_char(tonumber(value))
    elseif prefix == "#x" then
      -- Hex numeric entity (e.g., &#x41;)
      return safe_char(tonumber(value, 16))
    end
    return "&" .. prefix .. value .. ";"
  end)
end

return M