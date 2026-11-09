local M = {}

-- Replacement character, used for invalid or control code points
local REPLACEMENT = "\239\191\189" -- U+FFFD

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

-- Encode a code point as UTF-8
-- (utf8.char is not available in LuaJIT, so do it by hand)
local function encode_utf8(cp)
	if cp < 0x80 then
		return string.char(cp)
	elseif cp < 0x800 then
		return string.char(0xC0 + math.floor(cp / 64), 0x80 + cp % 64)
	elseif cp < 0x10000 then
		return string.char(0xE0 + math.floor(cp / 4096), 0x80 + math.floor(cp / 64) % 64, 0x80 + cp % 64)
	end
	return string.char(
		0xF0 + math.floor(cp / 262144),
		0x80 + math.floor(cp / 4096) % 64,
		0x80 + math.floor(cp / 64) % 64,
		0x80 + cp % 64
	)
end

-- Safe character conversion with bounds checking
-- Invalid code points become U+FFFD instead of disappearing or
-- injecting control characters into the buffer
local function safe_char(num)
	if not num then
		return REPLACEMENT
	end

	-- Map Windows-1252 characters (128-159) to proper Unicode
	if cp1252_map[num] then
		num = cp1252_map[num]
	end

	-- Out of Unicode range (0x0000 to 0x10FFFF) or NUL
	if num <= 0 or num > 0x10FFFF then
		return REPLACEMENT
	end
	-- Surrogates: 0xD800 to 0xDFFF
	if num >= 0xD800 and num <= 0xDFFF then
		return REPLACEMENT
	end
	-- C0 controls (except tab, LF, CR), DEL and unmapped C1 controls (129, 141, 143, 144, 157)
	if (num < 32 and num ~= 9 and num ~= 10 and num ~= 13) or (num >= 127 and num <= 159) then
		return REPLACEMENT
	end
	-- Noncharacters: U+FDD0-U+FDEF and U+xFFFE/U+xFFFF in every plane
	if (num >= 0xFDD0 and num <= 0xFDEF) or num % 0x10000 >= 0xFFFE then
		return REPLACEMENT
	end

	return encode_utf8(num)
end

-- Named entities (name -> code point)
-- nbsp and typographic spaces map to a regular space to keep buffer text simple
local named_entities = {
	-- Markup-significant
	lt = 60,
	gt = 62,
	amp = 38,
	quot = 34,
	apos = 39,

	-- Spaces and invisibles
	nbsp = 32,
	ensp = 32,
	emsp = 32,
	thinsp = 32,
	zwnj = 8204,
	zwj = 8205,
	lrm = 8206,
	rlm = 8207,
	shy = 173,

	-- Latin-1 symbols
	iexcl = 161,
	cent = 162,
	pound = 163,
	curren = 164,
	yen = 165,
	brvbar = 166,
	sect = 167,
	uml = 168,
	copy = 169,
	ordf = 170,
	laquo = 171,
	["not"] = 172,
	reg = 174,
	macr = 175,
	deg = 176,
	plusmn = 177,
	sup2 = 178,
	sup3 = 179,
	acute = 180,
	micro = 181,
	para = 182,
	middot = 183,
	cedil = 184,
	sup1 = 185,
	ordm = 186,
	raquo = 187,
	frac14 = 188,
	frac12 = 189,
	frac34 = 190,
	iquest = 191,
	times = 215,
	divide = 247,

	-- Latin-1 uppercase letters
	Agrave = 192,
	Aacute = 193,
	Acirc = 194,
	Atilde = 195,
	Auml = 196,
	Aring = 197,
	AElig = 198,
	Ccedil = 199,
	Egrave = 200,
	Eacute = 201,
	Ecirc = 202,
	Euml = 203,
	Igrave = 204,
	Iacute = 205,
	Icirc = 206,
	Iuml = 207,
	ETH = 208,
	Ntilde = 209,
	Ograve = 210,
	Oacute = 211,
	Ocirc = 212,
	Otilde = 213,
	Ouml = 214,
	Oslash = 216,
	Ugrave = 217,
	Uacute = 218,
	Ucirc = 219,
	Uuml = 220,
	Yacute = 221,
	THORN = 222,

	-- Latin-1 lowercase letters
	szlig = 223,
	agrave = 224,
	aacute = 225,
	acirc = 226,
	atilde = 227,
	auml = 228,
	aring = 229,
	aelig = 230,
	ccedil = 231,
	egrave = 232,
	eacute = 233,
	ecirc = 234,
	euml = 235,
	igrave = 236,
	iacute = 237,
	icirc = 238,
	iuml = 239,
	eth = 240,
	ntilde = 241,
	ograve = 242,
	oacute = 243,
	ocirc = 244,
	otilde = 245,
	ouml = 246,
	oslash = 248,
	ugrave = 249,
	uacute = 250,
	ucirc = 251,
	uuml = 252,
	yacute = 253,
	thorn = 254,
	yuml = 255,

	-- Latin extended and modifiers
	OElig = 338,
	oelig = 339,
	Scaron = 352,
	scaron = 353,
	Yuml = 376,
	fnof = 402,
	circ = 710,
	tilde = 732,

	-- Punctuation and symbols
	ndash = 8211,
	mdash = 8212,
	lsquo = 8216,
	rsquo = 8217,
	sbquo = 8218,
	ldquo = 8220,
	rdquo = 8221,
	bdquo = 8222,
	dagger = 8224,
	Dagger = 8225,
	bull = 8226,
	hellip = 8230,
	permil = 8240,
	lsaquo = 8249,
	rsaquo = 8250,
	euro = 8364,
	trade = 8482,
	larr = 8592,
	rarr = 8594,
	minus = 8722,
}

-- Optimized: single gsub pass instead of multiple sequential gsub calls
-- Returns only the decoded string (not gsub's match count)
function M.decode_entities(str)
	-- Single gsub with pattern that matches all entity types
	return (
		str:gsub("&(#?)(%w+);", function(prefix, value)
			local full_entity = "&" .. prefix .. value .. ";"

			if prefix == "" then
				-- Named entity (e.g., &lt;)
				local cp = named_entities[value]
				if cp then
					return safe_char(cp)
				end
				return full_entity
			end

			-- Hex numeric entity (e.g., &#x41;)
			local hex = value:match("^[xX](%x+)$")
			if hex then
				return safe_char(tonumber(hex, 16))
			end

			-- Decimal numeric entity (e.g., &#65;)
			if value:match("^%d+$") then
				return safe_char(tonumber(value))
			end

			-- Malformed numeric entity: leave as is
			return full_entity
		end)
	)
end

return M

