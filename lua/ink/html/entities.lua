local M = {}

-- Windows-1252 to Unicode mapping for characters 128-159
-- These are often incorrectly used in HTML entities (e.g., &#150; instead of &#8211;)
local cp1252_map = {
  [128] = 8364, -- € Euro sign
  [130] = 8218, -- ‚ Single low-9 quotation mark
  [131] = 402, -- ƒ Latin small letter f with hook
  [132] = 8222, -- „ Double low-9 quotation mark
  [133] = 8230, -- … Horizontal ellipsis
  [134] = 8224, -- † Dagger
  [135] = 8225, -- ‡ Double dagger
  [136] = 710, -- ˆ Modifier letter circumflex accent
  [137] = 8240, -- ‰ Per mille sign
  [138] = 352, -- Š Latin capital letter S with caron
  [139] = 8249, -- ‹ Single left-pointing angle quotation mark
  [140] = 338, -- Œ Latin capital ligature OE
  [142] = 381, -- Ž Latin capital letter Z with caron
  [145] = 8216, -- ' Left single quotation mark
  [146] = 8217, -- ' Right single quotation mark
  [147] = 8220, -- " Left double quotation mark
  [148] = 8221, -- " Right double quotation mark
  [149] = 8226, -- • Bullet
  [150] = 8211, -- – En dash
  [151] = 8212, -- — Em dash
  [152] = 732, -- ˜ Small tilde
  [153] = 8482, -- ™ Trade mark sign
  [154] = 353, -- š Latin small letter s with caron
  [155] = 8250, -- › Single right-pointing angle quotation mark
  [156] = 339, -- œ Latin small ligature oe
  [158] = 382, -- ž Latin small letter z with caron
  [159] = 376, -- Ÿ Latin capital letter Y with diaeresis
}

-- Encode a Unicode code point as UTF-8 (LuaJIT has no utf8.char)
local function codepoint_to_utf8(cp)
  local floor = math.floor
  if cp < 0x80 then
    return string.char(cp)
  elseif cp < 0x800 then
    return string.char(0xC0 + floor(cp / 0x40), 0x80 + cp % 0x40)
  elseif cp < 0x10000 then
    return string.char(0xE0 + floor(cp / 0x1000), 0x80 + floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40)
  end
  return string.char(
    0xF0 + floor(cp / 0x40000),
    0x80 + floor(cp / 0x1000) % 0x40,
    0x80 + floor(cp / 0x40) % 0x40,
    0x80 + cp % 0x40
  )
end

-- Returns the UTF-8 character, or nil if the code point is invalid
-- (nil makes decode_entities keep the original text instead of deleting it)
local function safe_char(num)
  if not num or num == 0 or num > 0x10FFFF then
    return nil
  end
  if num >= 0xD800 and num <= 0xDFFF then -- surrogates
    return nil
  end

  -- Windows-1252 range (128-159) is mapped by browsers to real Unicode
  num = cp1252_map[num] or num

  return codepoint_to_utf8(num)
end

local entity_map = {
  lt = "<",
  gt = ">",
  amp = "&",
  quot = '"',
  apos = "'",
  nbsp = " ",
  mdash = "—",
  ndash = "–",
  hellip = "…",
  lsquo = "‘",
  rsquo = "’",
  ldquo = "“",
  rdquo = "”",
  laquo = "«",
  raquo = "»",
  bull = "•",
  middot = "·",
  copy = "©",
  reg = "®",
  trade = "™",
  deg = "°",
  eacute = "é",
  egrave = "è",
  aacute = "á",
  agrave = "à",
  acirc = "â",
  atilde = "ã",
  ccedil = "ç",
  iacute = "í",
  oacute = "ó",
  ocirc = "ô",
  otilde = "õ",
  uacute = "ú",
  Eacute = "É",
  Aacute = "Á",
  Ccedil = "Ç",
}

function M.decode_entities(str)
  -- Single pass, so "&amp;lt;" becomes "&lt;" and not "<".
  -- Returning nil from the callback keeps the original match.
  return (
    str:gsub("&(#?%w+);", function(body)
      if body:sub(1, 1) ~= "#" then
        return entity_map[body]
      end

      local hex = body:match("^#[xX](%x+)$")
      if hex then
        return safe_char(tonumber(hex, 16))
      end

      local dec = body:match("^#(%d+)$")
      if dec then
        return safe_char(tonumber(dec))
      end
    end)
  )
end

return M
