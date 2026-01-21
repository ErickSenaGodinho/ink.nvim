local M = {}

-- Windows-1252 to Unicode mapping for characters 128-159
-- These are often incorrectly used in HTML entities (e.g., &#150; instead of &#8211;)
local cp1252_map = {
  [128] = 8364, -- € Euro sign
  [130] = 8218, -- ‚ Single low-9 quotation mark
  [131] = 402,  -- ƒ Latin small letter f with hook
  [132] = 8222, -- „ Double low-9 quotation mark
  [133] = 8230, -- … Horizontal ellipsis
  [134] = 8224, -- † Dagger
  [135] = 8225, -- ‡ Double dagger
  [136] = 710,  -- ˆ Modifier letter circumflex accent
  [137] = 8240, -- ‰ Per mille sign
  [138] = 352,  -- Š Latin capital letter S with caron
  [139] = 8249, -- ‹ Single left-pointing angle quotation mark
  [140] = 338,  -- Œ Latin capital ligature OE
  [142] = 381,  -- Ž Latin capital letter Z with caron
  [145] = 8216, -- ' Left single quotation mark
  [146] = 8217, -- ' Right single quotation mark
  [147] = 8220, -- " Left double quotation mark
  [148] = 8221, -- " Right double quotation mark
  [149] = 8226, -- • Bullet
  [150] = 8211, -- – En dash
  [151] = 8212, -- — Em dash
  [152] = 732,  -- ˜ Small tilde
  [153] = 8482, -- ™ Trade mark sign
  [154] = 353,  -- š Latin small letter s with caron
  [155] = 8250, -- › Single right-pointing angle quotation mark
  [156] = 339,  -- œ Latin small ligature oe
  [158] = 382,  -- ž Latin small letter z with caron
  [159] = 376,  -- Ÿ Latin capital letter Y with diaeresis
}

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

  -- Map Windows-1252 characters (128-159) to proper Unicode
  if num >= 128 and num <= 159 and cp1252_map[num] then
    num = cp1252_map[num]
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