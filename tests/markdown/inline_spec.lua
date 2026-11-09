local inline = require("ink.markdown.inline")

local function check(cases)
  for _, c in ipairs(cases) do
    it("renders " .. vim.inspect(c[1]), function()
      assert.are.equal(c[2], inline.process_inline(c[1]))
    end)
  end
end

describe("markdown.inline", function()
  describe("underscore emphasis", function()
    check({
      { "a_b", "a_b" },
      { "a_b _c_", "a_b <em>c</em>" },
      { "_abc_", "<em>abc</em>" },
      { "abc_def_ghi", "abc_def_ghi" },
      { "hello _world_", "hello <em>world</em>" },
      { "snake_case_name", "snake_case_name" },
      { "_a_.", "<em>a</em>." },
      { "(_a_)", "(<em>a</em>)" },
      { "_a_b", "_a_b" },
      { "ação_x_", "ação_x_" },
      { "__bold__", "<strong>bold</strong>" },
      { "___ambos___", "<strong><em>ambos</em></strong>" },
    })
  end)

  describe("asterisk emphasis", function()
    check({
      { "*italic*", "<em>italic</em>" },
      { "**bold**", "<strong>bold</strong>" },
      { "***both***", "<strong><em>both</em></strong>" },
    })
  end)

  describe("code", function()
    check({
      { "`a_b_c`", "<code>a_b_c</code>" },
      { "`*x*`", "<code>*x*</code>" },
    })
  end)

  describe("links and images", function()
    check({
      { "[x](http://a.com/a_b_c)", '<a href="http://a.com/a_b_c">x</a>' },
      { "[x](a>b)", '<a href="a%3Eb">x</a>' },
      { "[x](a b)", '<a href="a%20b">x</a>' },
      { "[x](a?b=1&c=2)", '<a href="a?b=1&amp;c=2">x</a>' },
      { "[x](a%20b)", '<a href="a%20b">x</a>' },
      { "![i](a'b.png)", '<img src="a%27b.png" alt="i" />' },
    })
  end)

  describe("edge cases", function()
    it("returns an empty string for nil", function()
      assert.are.equal("", inline.process_inline(nil))
    end)

    it("returns an empty string for empty input", function()
      assert.are.equal("", inline.process_inline(""))
    end)

    it("parse delegates to process_inline", function()
      assert.are.equal(inline.process_inline("_a_"), inline.parse("_a_"))
    end)
  end)
end)
