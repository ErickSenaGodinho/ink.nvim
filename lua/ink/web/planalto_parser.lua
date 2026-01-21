local entities = require("ink.html.entities")

local M = {}

-- Helper function to clean and normalize text
-- Consolidates multiple gsub operations that are repeated throughout the code
local function clean_text(text)
  if not text then return nil end
  -- Decode HTML entities, normalize whitespace, and trim in one pass
  text = entities.decode_entities(text)
  text = text:gsub("%s+", " ")  -- Normalize multiple whitespace to single space
  text = text:gsub("^%s+", "")  -- Trim leading whitespace
  text = text:gsub("%s+$", "")  -- Trim trailing whitespace
  return text
end

-- Extract page number and year from URL or title
local function extract_page_info(url, html)
  local year, number = url:match("/(%d%d%d%d)/lei/l(%d+)%.htm")
  if not year then
    number = url:match("/lei/l(%d+)%.htm")
  end

  local title = html:match("<title>([^<]+)</title>")
  if title then
    title = clean_text(title)
  end

  if title and not number then
    number = title:match("Lei%s+n?º?%s*(%d+%.?%d*)")
    if number then
      number = number:gsub("%.", "")
    end
  end

  if title and not year then
    year = title:match("de%s+(%d%d%d%d)")
  end

  return {
    number = number or "unknown",
    year = year or "unknown",
    title = title or "Página Web"
  }
end

-- Extract ementa (summary) from HTML
local function extract_ementa(html)
  local ementa = html:match('<p[^>]*class="ementa"[^>]*>(.-)</p>')
  if ementa then
    ementa = ementa:gsub("<[^>]+>", "")  -- Remove HTML tags
    return clean_text(ementa)
  end
  return nil
end

-- Normalize strikethrough: convert CSS text-decoration:line-through to <strike> tags
-- This ensures consistent handling in both rendering and removal
-- Optimized version using simpler pattern matching
local function normalize_strikethrough(html)
  local result = html
  local max_iterations = 1000  -- Safety limit to prevent infinite loops
  local iterations = 0

  -- Process one tag at a time to avoid complex backtracking
  while iterations < max_iterations do
    iterations = iterations + 1

    -- Find next occurrence of text-decoration:line-through
    local style_start, style_end = result:find("text%-decoration%s*:%s*line%-through", 1)
    if not style_start then break end

    -- Search backwards to find the opening tag
    local tag_start = nil
    for i = style_start, 1, -1 do
      if result:sub(i, i) == '<' then
        tag_start = i
        break
      end
    end

    if not tag_start then
      -- Couldn't find opening tag, skip this occurrence
      break
    end

    -- Extract tag name
    local tag_name = result:sub(tag_start + 1):match("^([%w]+)")
    if not tag_name then
      break
    end

    -- Find end of opening tag
    local opening_end = result:find(">", tag_start, true)
    if not opening_end then
      break
    end

    -- Find the matching closing tag using plain text search (more efficient)
    local close_pattern = "</" .. tag_name .. ">"
    local close_start = result:find(close_pattern, opening_end + 1, true)
    if not close_start then
      -- No closing tag found, skip
      break
    end

    local close_end = close_start + #close_pattern - 1

    -- Extract parts
    local opening_tag = result:sub(tag_start, opening_end)
    local content = result:sub(opening_end + 1, close_start - 1)
    local closing_tag = result:sub(close_start, close_end)

    -- Don't double-wrap if already has <strike>
    if not content:match("^%s*<strike>") then
      local replacement = opening_tag .. "<strike>" .. content .. "</strike>" .. closing_tag
      result = result:sub(1, tag_start - 1) .. replacement .. result:sub(close_end + 1)
    else
      -- Already wrapped, just move past it to avoid infinite loop
      -- Replace the style portion to avoid matching it again
      local before = result:sub(1, style_start - 1)
      local after = result:sub(style_end + 1)
      result = before .. "text-decoration-processed" .. after
    end
  end

  -- Clean up the processed markers
  result = result:gsub("text%-decoration%-processed", "text-decoration:line-through")

  return result
end

-- Remove blockquotes but keep their text content
-- This prevents content from being styled with InkComment
local function remove_blockquotes(html)
  -- Remove <blockquote> tags but keep the content inside
  local result = html:gsub("<[bB][lL][oO][cC][kK][qQ][uU][oO][tT][eE][^>]*>", "")
  result = result:gsub("</[bB][lL][oO][cC][kK][qQ][uU][oO][tT][eE]>", "")
  return result
end

-- Fix malformed inline tags (unclosed <b>, <strong>, <i>, etc.)
-- This prevents inline styles from leaking across block boundaries
-- Simple approach: remove orphaned opening tags (tags that appear alone between/after paragraphs)
local function fix_malformed_inline_tags(html)
  local result = html

  -- Remove orphaned inline opening tags (tags that are alone with only whitespace around them)
  -- Pattern: tag followed by optional whitespace and newlines, but no actual content before </p> or next <p>
  result = result:gsub("(<[bB]>)%s*\n?%s*(</[pP]>)", "%2")
  result = result:gsub("(</[pP]>)%s*\n?%s*(<[bB]>)%s*\n?%s*(<[pP])", "%1%3")
  result = result:gsub("(</[pP]>)%s*\n?%s*(<[bB]>)%s*$", "%1")

  -- Same for </b> tags - remove empty bold pairs
  result = result:gsub("(<[bB]>)%s*(</[bB]>)", "")

  -- NOTE: Removed the problematic pattern that caused catastrophic backtracking:
  -- "(</[pP]>.-)<[bB]>%s*$" - this pattern with .- followed by $ can freeze on large documents
  -- The simpler patterns above handle the common cases without performance issues

  return result
end

-- Remove strike-through content (for compiled version)
-- Uses non-greedy matching and handles potential malformed tags
-- Optimized to avoid catastrophic backtracking
local function remove_strikethrough(html)
  local result = html

  -- Use iterative approach instead of global pattern matching to avoid backtracking issues
  -- This is safer for large HTML documents
  local strike_pattern = "<[sS][tT][rR][iI][kK][eE]>"
  local strike_end_pattern = "</[sS][tT][rR][iI][kK][eE]>"

  while true do
    local start_pos = result:find(strike_pattern)
    if not start_pos then break end

    local tag_end = result:find(">", start_pos, true)
    if not tag_end then break end

    local end_pos = result:find(strike_end_pattern, tag_end + 1, true)
    if not end_pos then
      -- Orphaned opening tag - remove it
      result = result:sub(1, start_pos - 1) .. result:sub(tag_end + 1)
    else
      -- Found pair - remove everything from <strike> to </strike>
      local close_tag_end = result:find(">", end_pos, true)
      result = result:sub(1, start_pos - 1) .. result:sub(close_tag_end + 1)
    end
  end

  -- Clean up any remaining orphaned closing tags
  result = result:gsub("</[sS][tT][rR][iI][kK][eE]>", "")

  return result
end

-- Parse articles from HTML using a text-based approach
-- Real Planalto structure: articles are in <p> tags with text starting with "Art. X"
-- Returns: articles table and header_content (everything before first article)
local function parse_articles(html)
  local articles = {}

  -- Normalize strikethrough styles to <strike> tags for consistent handling
  html = normalize_strikethrough(html)

  -- Fix malformed inline tags (unclosed <b>, <strong>, etc.)
  html = fix_malformed_inline_tags(html)

  -- Extract the body content
  local body = html:match("<body>(.-)</body>") or html

  -- Split into chunks at each "Art. X" pattern
  -- Pattern matches: Art. 1º, Art. 2, Art. 10., Art. 26-A, Art. 1º-AB, etc.
  local article_parts = {}
  local current_pos = 1

  -- Find all article markers with their positions
  -- Captures: Art. 1, Art. 1º, Art. 26-A, Art. 1º-B, Art. 26-ABC, etc.
  -- Pattern: Art. + spaces + digits + optional ordinal + optional (hyphen/dash + letters) + optional dot
  -- Note: [%-–—] matches hyphen, en-dash, and em-dash
  -- This searches in the full HTML including text inside <strike> tags
  for match_start, article_marker in body:gmatch("()Art%.%s*(%d+[ºo°]?[%-–—]?[A-Z]*%.?)") do
    -- Remove ordinal indicators (º, o, °) but keep hyphen and letters
    local article_num = article_marker:gsub("[ºo°]", ""):gsub("%.$", "")
    table.insert(article_parts, {
      pos = match_start,
      num = article_num,
      marker = article_marker
    })
  end

  -- Extract header content (everything before first article)
  local header_content = ""
  if #article_parts > 0 then
    local first_article_pos = article_parts[1].pos
    -- Look backwards to find the start of the paragraph containing the first article
    local before_first = body:sub(1, first_article_pos - 1)
    local last_tag_end = 1
    for i = #before_first, 1, -1 do
      if before_first:sub(i, i) == '>' then
        last_tag_end = i + 1
        break
      end
    end
    header_content = body:sub(1, last_tag_end - 1)
  else
    -- No articles found, everything is header
    header_content = body
  end

  -- Extract content between article markers
  for i, part in ipairs(article_parts) do
    local start_pos = part.pos
    local next_article_pos = article_parts[i + 1] and article_parts[i + 1].pos or #body

    -- Find where this article ends (before the next article starts)
    local end_pos
    if article_parts[i + 1] then
      -- Look backwards from next article to find the closing </p>
      local before_next = body:sub(start_pos, next_article_pos - 1)

      -- Find the last </p> before the next article
      local last_p_close = 0
      for match_pos in before_next:gmatch("()</[pP]>") do
        last_p_close = match_pos
      end

      if last_p_close > 0 then
        -- Position is relative to start_pos, convert to absolute
        end_pos = start_pos + last_p_close + 3 - 1 -- +3 for </p>, -1 for 0-indexing
      else
        -- Fallback: stop just before next article
        end_pos = next_article_pos - 1
      end
    else
      -- Last article - take everything to the end
      end_pos = #body
    end

    -- Look backwards to find the opening <p> tag for this article
    -- We want to capture the complete <p...> tag with all attributes
    local before = body:sub(math.max(1, start_pos - 2000), start_pos - 1)
    local p_start_distance = 0

    -- Find the opening <p (could have attributes)
    for j = #before, 1, -1 do
      if before:sub(j, j+1) == "<p" or before:sub(j, j+1) == "<P" then
        p_start_distance = #before - j + 1
        break
      end
    end

    -- Extract the full content starting from the <p> tag
    local content_start = p_start_distance > 0 and (start_pos - p_start_distance) or start_pos
    local full_content = body:sub(content_start, end_pos)

    -- Clean up and create article entry
    local article_num = part.num

    -- Ensure content is properly wrapped
    if not full_content:match("^%s*<") then
      full_content = "<div>" .. full_content .. "</div>"
    end

    local raw_content = full_content
    local compiled_content = remove_strikethrough(full_content)

    -- Extract title (first sentence without HTML tags)
    local text_only = compiled_content:gsub("<[^>]+>", "")
    text_only = clean_text(text_only)

    -- Remove the "Art. X" prefix from title if present
    -- Handles: Art. 1, Art. 1º, Art. 26-A, Art. 1º-AB, etc.
    -- Also removes optional dash/en-dash/em-dash after article number
    -- Pattern matches hyphen (-), en-dash (–), and em-dash (—)
    text_only = text_only:gsub("^Art%.%s*%d+[ºo°]?[%-–—]?[A-Z]*%.?%s*[%-–—]?%s*", "")

    -- Clean up any remaining replacement characters or stray ordinal markers at the start
    -- This handles cases where encoding issues cause � to appear instead of º
    text_only = text_only:gsub("^[ºo°�]+%s*[%-–—]?%s*", "")

    -- Additional cleanup: if text still starts with a dash, remove it (leftover from "Art. X - ")
    text_only = text_only:gsub("^[%-–—]+%s*", "")

    -- Also try to remove if there's a line break or tag between Art and number
    if text_only:match("^%s*$") or text_only == "" then
      -- Fallback: try to get content after the article marker more broadly
      text_only = compiled_content:gsub("<[^>]+>", "")
      text_only = clean_text(text_only)
      -- Try alternative patterns (greedy to handle edge cases)
      text_only = text_only:gsub("^.*Art%.%s*%d+[ºo°]?[%-–—]?[A-Z]*%.?%s*[%-–—]?%s*", "")
      -- Clean up any remaining replacement characters
      text_only = text_only:gsub("^[ºo°�]+%s*[%-–—]?%s*", "")
      -- Additional cleanup: remove leading dashes
      text_only = text_only:gsub("^[%-–—]+%s*", "")
    end

    -- Extract first 80 chars as title, or use placeholder if empty
    local title
    if text_only and text_only ~= "" and not text_only:match("^%s*$") then
      title = text_only:sub(1, math.min(#text_only, 80))
      if #text_only > 80 then
        title = title .. "..."
      end
    else
      -- Check if article is completely revoked (all content in strike)
      local raw_text = raw_content:gsub("<[^>]+>", "")
      raw_text = clean_text(raw_text)
      local compiled_text = compiled_content:gsub("<[^>]+>", ""):gsub("%s+", "")
      if raw_text ~= "" and compiled_text:match("^%s*$") then
        title = "Artigo " .. article_num .. " (Revogado)"
      else
        title = "Artigo " .. article_num
      end
    end

    -- Check for strikethrough content
    local has_strike_tag = raw_content:match("<strike>") or raw_content:match("<STRIKE>")
    local has_strike_css = raw_content:match("text%-decoration%s*:%s*line%-through")
    local has_any_strike = has_strike_tag or has_strike_css

    table.insert(articles, {
      number = article_num,
      title = title,
      raw = raw_content,
      compiled = compiled_content,
      has_modifications = has_any_strike
    })
  end

  return articles, header_content
end

-- Parse page structure from HTML
function M.parse(html, url)
  local page_info = extract_page_info(url, html)
  local ementa = extract_ementa(html)
  local articles, header = parse_articles(html)

  local page_id = "Lei " .. page_info.number
  if page_info.year ~= "unknown" then
    page_id = page_id .. "/" .. page_info.year
  end

  return {
    page_id = page_id,
    number = page_info.number,
    year = page_info.year,
    title = page_info.title,
    ementa = ementa,
    articles = articles,
    header = header,
    url = url
  }
end

-- Build spine structure for raw version
function M.build_raw_spine(parsed_page)
  -- Add CSS to preserve formatting
  local content_parts = {
    [[<style>
      .law-header { margin-bottom: 2em; }
      .law-header p[align="center"], .law-header p[style*="text-align:center"] {
        text-align: center;
        margin: 1em 0;
      }
      .law-header strong, .law-header b {
        font-weight: bold;
      }
      .article { margin: 2em 0; }
      .article h2 {
        font-weight: bold;
        margin: 1.5em 0 0.5em 0;
      }
      /* Preserve centered sections/titles within articles */
      p[align="center"], p[style*="text-align:center"] {
        text-align: center;
        font-weight: bold;
        margin: 1.5em 0;
      }
      /* Ensure strikethrough styling is preserved - multiple selectors for compatibility */
      strike,
      s,
      del,
      [style*="text-decoration: line-through"],
      [style*="text-decoration:line-through"],
      span[style*="line-through"],
      font[style*="line-through"] {
        text-decoration: line-through !important;
        color: #666 !important;
      }
    </style>]]
  }

  -- Start with header content (brasão, título, ementa, preâmbulo)
  if parsed_page.header and parsed_page.header ~= "" then
    -- Remove blockquotes from header
    local cleaned_header = remove_blockquotes(parsed_page.header)
    table.insert(content_parts, '<div class="law-header">')
    table.insert(content_parts, cleaned_header)
    table.insert(content_parts, '</div>')
  end

  -- Add all articles
  for _, article in ipairs(parsed_page.articles) do
    -- Remove blockquotes from raw content
    local cleaned_content = remove_blockquotes(article.raw)

    -- DEBUG: Log article 337-C to see raw HTML
    if article.number == "337-C" then
      local debug_file = io.open("/tmp/ink_debug_337c.html", "w")
      if debug_file then
        debug_file:write("=== RAW ARTICLE HTML ===\n")
        debug_file:write(article.raw)
        debug_file:write("\n\n=== CLEANED CONTENT ===\n")
        debug_file:write(cleaned_content)
        debug_file:close()
      end
    end

    -- Use concatenation to avoid string.format issues with % in content
    local article_html = '<div class="article" id="article-' .. article.number .. '">\n'
      .. '  <h2>Artigo ' .. article.number .. '</h2>\n'
      .. '  ' .. cleaned_content .. '\n'
      .. '</div>\n'
    table.insert(content_parts, article_html)
  end

  -- Create a single spine entry with all content
  local full_content = table.concat(content_parts, "\n")

  return {
    {
      content = full_content,
      href = "pagina-completa",
      title = parsed_page.title or "Página Completa",
      index = 1
    }
  }
end

-- Build spine structure for compiled version
function M.build_compiled_spine(parsed_page)
  -- Add CSS to preserve formatting
  local content_parts = {
    [[<style>
      .law-header { margin-bottom: 2em; }
      .law-header p[align="center"], .law-header p[style*="text-align:center"] {
        text-align: center;
        margin: 1em 0;
      }
      .law-header strong, .law-header b {
        font-weight: bold;
      }
      .article { margin: 2em 0; }
      .article h2 {
        font-weight: bold;
        margin: 1.5em 0 0.5em 0;
      }
      /* Preserve centered sections/titles within articles */
      p[align="center"], p[style*="text-align:center"] {
        text-align: center;
        font-weight: bold;
        margin: 1.5em 0;
      }
    </style>]]
  }

  -- Start with header content (brasão, título, ementa, preâmbulo)
  if parsed_page.header and parsed_page.header ~= "" then
    -- Apply strikethrough removal to header as well
    local compiled_header = remove_strikethrough(parsed_page.header)
    -- Remove blockquotes from header
    compiled_header = remove_blockquotes(compiled_header)
    table.insert(content_parts, '<div class="law-header">')
    table.insert(content_parts, compiled_header)
    table.insert(content_parts, '</div>')
  end

  -- Add all articles
  for _, article in ipairs(parsed_page.articles) do
    -- For compiled version, check if article content is empty after removing strikethrough
    local content_text = article.compiled:gsub("<[^>]+>", ""):gsub("%s+", "")
    local article_content

    if content_text == "" or content_text:match("^%s*$") then
      -- Article is completely revoked - show placeholder
      article_content = '<p><em>(Artigo revogado)</em></p>'
    else
      -- Remove blockquotes from compiled content
      article_content = remove_blockquotes(article.compiled)
    end

    -- Use concatenation to avoid string.format issues with % in content
    local article_html = '<div class="article" id="article-' .. article.number .. '">\n'
      .. '  <h2>Artigo ' .. article.number .. '</h2>\n'
      .. '  ' .. article_content .. '\n'
      .. '</div>\n'
    table.insert(content_parts, article_html)
  end

  -- Create a single spine entry with all content
  local full_content = table.concat(content_parts, "\n")

  return {
    {
      content = full_content,
      href = "pagina-completa",
      title = parsed_page.title or "Página Completa",
      index = 1
    }
  }
end

-- Build table of contents
function M.build_toc(parsed_page)
  local toc = {}

  for _, article in ipairs(parsed_page.articles) do
    table.insert(toc, {
      label = "Art. " .. article.number .. ": " .. article.title,
      href = "pagina-completa#article-" .. article.number,
      level = 1
    })
  end

  return toc
end

return M
