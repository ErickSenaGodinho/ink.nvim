local entities = require("ink.html.entities")

local FFFD = "\239\191\189" -- U+FFFD

local function check(cases)
  for _, c in ipairs(cases) do
    it("decodes " .. vim.inspect(c[1]), function()
      assert.are.equal(c[2], entities.decode_entities(c[1]))
    end)
  end
end

describe("html.entities", function()
  describe("named entities", function()
    check({
      { "voc&ecirc;", "você" },
      { "&Atilde;&Otilde;&Ocirc;&Ecirc;", "ÃÕÔÊ" },
      { "&Iacute;&Uacute;&Agrave;&Acirc;", "ÍÚÀÂ" },
      { "&uuml;&ntilde;&szlig;&times;&euro;&sect;", "üñß×€§" },
      { "a&thinsp;b&emsp;c", "a b c" },
      { "&lt;&gt;&amp;&quot;&apos;", "<>&\"'" },
      { "&nbsp;", " " },
      { "&unknown;", "&unknown;" },
    })
  end)

  describe("numeric entities", function()
    check({
      { "&#233;", "é" },
      { "&#x41;", "A" },
      { "&#X41;", "A" },
      { "&#x1F600;", "😀" },
      { "&#150;", "–" }, -- cp1252 mapping
      { "&#xyz;", "&#xyz;" },
      { "&#6a;", "&#6a;" },
    })
  end)

  describe("invalid code points", function()
    check({
      { "&#0;", FFFD },
      { "&#1;", FFFD },
      { "&#129;", FFFD },
      { "&#xFFFE;", FFFD },
      { "&#xD800;", FFFD },
      { "&#x110000;", FFFD },
    })
  end)

  it("does not decode twice", function()
    assert.are.equal("&lt;", entities.decode_entities("&amp;lt;"))
  end)

  it("returns a single value (no gsub count)", function()
    assert.are.equal(1, select("#", entities.decode_entities("a &amp; b")))
  end)
end)
