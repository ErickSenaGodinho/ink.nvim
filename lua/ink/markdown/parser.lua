local util = require("ink.markdown.util")
local inline = require("ink.markdown.inline")

local M = {}

-- Parse state
local ParserState = {}
ParserState.__index = ParserState

function ParserState:new()
  local state = {
    html = {},           -- Output HTML lines
    in_code_block = false,
    in_list = false,
    list_stack = {},     -- Stack of list types (ul/ol)
    in_blockquote = false,
    blockquote_level = 0,
    prev_was_blank = true
  }
  setmetatable(state, ParserState)
  return state
end

function ParserState:append(line)
  table.insert(self.html, line)
end

function ParserState:close_lists()
  while #self.list_stack > 0 do
    self:append("</li>")
    local list_type = table.remove(self.list_stack)
    self:append("</" .. list_type .. ">")
  end
  self.in_list = false
end

function ParserState:close_blockquote()
  if self.in_blockquote then
    for _ = 1, self.blockquote_level do
      self:append("</blockquote>")
    end
    self.blockquote_level = 0
    self.in_blockquote = false
  end
end

function ParserState:get_html()
  return table.concat(self.html, "\n")
end

-- Parse heading
local function parse_heading(line, state)
  local level, text = util.parse_heading(line)
  if not level then
    return false
  end

  state:close_lists()
  state:close_blockquote()

  local id = util.slugify(text)
  local processed_text = inline.parse(text)
  state:append(string.format('<h%d id="%s">%s</h%d>', level, id, processed_text, level))
  state.prev_was_blank = false

  return true
end

-- Parse horizontal rule
local function parse_horizontal_rule(line, state)
  if not util.is_horizontal_rule(line) then
    return false
  end

  state:close_lists()
  state:close_blockquote()
  state:append("<hr />")
  state.prev_was_blank = false

  return true
end

-- Parse code block fence
local function parse_code_fence(line, state)
  if not util.is_code_fence(line) then
    return false
  end

  if not state.in_code_block then
    -- Start code block
    state:close_lists()
    state:close_blockquote()
    state.in_code_block = true
    state:append("<pre><code>")
  else
    -- End code block
    state:append("</code></pre>")
    state.in_code_block = false
  end

  state.prev_was_blank = false
  return true
end

-- Parse blockquote
local function parse_blockquote(line, state)
  if not util.is_blockquote(line) then
    -- Close blockquote if we were in one
    if state.in_blockquote and not line:match("^%s*$") then
      state:close_blockquote()
    end
    return false
  end

  state:close_lists()

  local level, content = util.parse_blockquote(line)

  -- Adjust blockquote nesting
  if not state.in_blockquote then
    state.in_blockquote = true
    state.blockquote_level = 0
  end

  -- Open new blockquote levels if needed
  while state.blockquote_level < level do
    state:append("<blockquote>")
    state.blockquote_level = state.blockquote_level + 1
  end

  -- Close blockquote levels if needed
  while state.blockquote_level > level do
    state:append("</blockquote>")
    state.blockquote_level = state.blockquote_level - 1
  end

  -- Process content
  local processed = inline.parse(content)
  if processed and processed ~= "" then
    state:append("<p>" .. processed .. "</p>")
  end

  state.prev_was_blank = false
  return true
end

-- Parse list item
local function parse_list_item(line, state)
  local list_type, indent, content = util.is_list_item(line)

  if not list_type then
    -- Close lists if we're not in a blank line
    if state.in_list and not line:match("^%s*$") then
      state:close_lists()
    end
    return false
  end

  state:close_blockquote()

  local indent_level = util.get_indent_level(indent)
  local current_level = #state.list_stack

  -- Going back to shallower level: close nested lists
  while current_level > indent_level + 1 do
    state:append("</li>")
    local closed_type = table.remove(state.list_stack)
    state:append("</" .. closed_type .. ">")
    current_level = #state.list_stack
  end

  -- Same level: close previous item
  if current_level == indent_level + 1 then
    state:append("</li>")
  end

  -- Going deeper: open new nested list (don't close parent li)
  if current_level == indent_level then
    state:append("<" .. list_type .. ">")
    table.insert(state.list_stack, list_type)
  end

  -- Add new list item
  local processed = inline.parse(content)
  state:append("<li>" .. processed)
  state.in_list = true
  state.prev_was_blank = false

  return true
end

-- Parse paragraph
local function parse_paragraph(line, state)
  if line:match("^%s*$") then
    -- Blank line
    if not state.prev_was_blank then
      state:close_lists()
      state:close_blockquote()
    end
    state.prev_was_blank = true
    return true
  end

  -- Regular text line
  if not state.in_code_block and not state.in_list then
    state:close_blockquote()
    local processed = inline.parse(line)
    state:append("<p>" .. processed .. "</p>")
    state.prev_was_blank = false
    return true
  end

  return false
end

-- Main parse function
function M.parse(content)
  if not content or content == "" then
    return "<html><body></body></html>"
  end

  local state = ParserState:new()
  local lines = util.split_lines(content)

  for _, line in ipairs(lines) do
    if state.in_code_block then
      -- Inside code block, add line verbatim until closing fence
      if util.is_code_fence(line) then
        parse_code_fence(line, state)
      else
        state:append(util.escape_html(line))
      end
    else
      -- Try to parse different block types
      local parsed = parse_heading(line, state)
        or parse_horizontal_rule(line, state)
        or parse_code_fence(line, state)
        or parse_blockquote(line, state)
        or parse_list_item(line, state)
        or parse_paragraph(line, state)

      if not parsed then
        -- Unhandled line, treat as text
        if not line:match("^%s*$") then
          local processed = inline.parse(line)
          state:append(processed)
        end
      end
    end
  end

  -- Close any open blocks
  state:close_lists()
  state:close_blockquote()

  if state.in_code_block then
    state:append("</code></pre>")
  end

  -- Wrap in HTML structure
  local html = state:get_html()
  return string.format("<html><body>%s</body></html>", html)
end

return M
