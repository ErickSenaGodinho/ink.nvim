-- lua/ink/padnotes/data.lua
-- Responsabilidade: Gerenciamento de arquivos markdown (CRUD, sanitização, listagem)

local fs = require("ink.fs")
local data_module = require("ink.data")

local M = {}

-- Mapeamento de meses em português
local MONTHS_PT = {
  "Jan", "Fev", "Mar", "Abr", "Mai", "Jun",
  "Jul", "Ago", "Set", "Out", "Nov", "Dez"
}

-- Get padnotes directory based on config
function M.get_padnotes_dir(slug, book_data, config)
  config = config or require("ink.padnotes").config
  local path = config.path or "default"
  
  local dir
  if path == "default" then
    -- Default: ~/.local/share/nvim/ink.nvim/books/{slug}/padnotes/
    dir = data_module.get_book_dir(slug) .. "/padnotes"
  elseif type(path) == "string" then
    -- Template string: substitute {slug}, {title}, {author}
    dir = path
    dir = dir:gsub("{slug}", slug)
    if book_data then
      dir = dir:gsub("{title}", book_data.title or "")
      dir = dir:gsub("{author}", book_data.author or "")
    end
    -- Expand ~ to home directory
    dir = vim.fn.expand(dir)
  elseif type(path) == "function" then
    -- Custom function
    dir = path(slug, book_data)
  else
    -- Fallback to default
    dir = data_module.get_book_dir(slug) .. "/padnotes"
  end
  
  -- Ensure directory exists
  fs.ensure_dir(dir)
  
  return dir
end

-- Sanitize chapter title for filename
-- Removes/replaces invalid filesystem characters
-- Keeps UTF-8 characters for international support
function M.sanitize_chapter_title(title)
  if not title or title == "" then
    return ""
  end
  
  -- Remove/replace invalid filesystem characters: / \ : * ? " < > |
  local sanitized = title
  sanitized = sanitized:gsub('[/\\:*?"<>|]', '_')
  
  -- Replace spaces with underscores
  sanitized = sanitized:gsub('%s+', '_')
  
  -- Remove leading/trailing underscores
  sanitized = sanitized:gsub('^_+', '')
  sanitized = sanitized:gsub('_+$', '')
  
  -- Collapse multiple underscores
  sanitized = sanitized:gsub('_+', '_')
  
  return sanitized
end

-- Get padnote filename for a chapter
-- Format: chapter_{idx:02d}.md (index-only to avoid conflicts when TOC changes)
function M.get_padnote_filename(chapter_idx, chapter_title)
  -- Use index-only naming to prevent conflicts when TOC is rebuilt
  -- This ensures padnotes remain accessible even if chapter titles change
  local filename = string.format("chapter_%02d.md", chapter_idx)
  return filename
end

-- Get full path to padnote file
function M.get_padnote_path(slug, chapter_idx, book_data)
  local dir = M.get_padnotes_dir(slug, book_data)
  
  -- Get chapter title from TOC
  local chapter_title = ""
  if book_data and book_data.toc then
    -- Find TOC entry for this chapter
    local spine_href = book_data.spine[chapter_idx] and book_data.spine[chapter_idx].href
    if spine_href then
      for _, toc_item in ipairs(book_data.toc) do
        local toc_href = toc_item.href and toc_item.href:match("^([^#]+)") or toc_item.href
        if toc_href == spine_href then
          chapter_title = toc_item.label or ""
          break
        end
      end
    end
  end
  
  -- Fallback to generic chapter name
  if chapter_title == "" then
    chapter_title = "Chapter_" .. chapter_idx
  end
  
  local filename = M.get_padnote_filename(chapter_idx, chapter_title)
  return dir .. "/" .. filename
end

-- Check if padnote exists for a chapter
function M.padnote_exists(slug, chapter_idx, book_data)
  local path = M.get_padnote_path(slug, chapter_idx, book_data)
  return fs.exists(path)
end

-- Create new padnote file (empty, template added by actions module)
function M.create_padnote(slug, chapter_idx, book_data)
  local path = M.get_padnote_path(slug, chapter_idx, book_data)
  
  -- Check directory write permissions
  local dir = vim.fn.fnamemodify(path, ":h")
  local writable = vim.fn.filewritable(dir)
  
  if writable ~= 2 then
    vim.notify("Cannot write to directory: " .. dir, vim.log.levels.ERROR)
    vim.notify("Please check permissions or configure a different path", vim.log.levels.ERROR)
    return nil
  end
  
  -- Create empty file
  local file = io.open(path, "w")
  if not file then
    vim.notify("Failed to create padnote: " .. path, vim.log.levels.ERROR)
    return nil
  end
  
  file:close()
  return path
end

-- List all padnotes for a book
-- Returns array of { chapter_idx, filename, path, title }
function M.list_padnotes(slug, book_data)
  local dir = M.get_padnotes_dir(slug, book_data)
  local padnotes = {}
  
  -- Check if directory exists
  if not fs.dir_exists(dir) then
    return padnotes
  end
  
  -- Scan directory for .md files
  local handle = vim.loop.fs_scandir(dir)
  if not handle then
    return padnotes
  end
  
  while true do
    local name, type = vim.loop.fs_scandir_next(handle)
    if not name then break end
    
    -- Only process .md files
    if type == "file" and name:match("%.md$") then
      -- Parse filename to extract chapter_idx
      -- Expected format: chapter_{idx:02d}_{title}.md
      local chapter_idx = name:match("^chapter_(%d+)")
      if chapter_idx then
        chapter_idx = tonumber(chapter_idx)
        
        -- Extract title from filename (after chapter_XX_)
        local title = name:match("^chapter_%d+_(.+)%.md$")
        if not title then
          title = "Chapter " .. chapter_idx
        else
          -- Replace underscores with spaces for display
          title = title:gsub("_", " ")
        end
        
        table.insert(padnotes, {
          chapter_idx = chapter_idx,
          filename = name,
          path = dir .. "/" .. name,
          title = title,
        })
      end
    end
  end
  
  -- Sort by chapter_idx
  table.sort(padnotes, function(a, b)
    return a.chapter_idx < b.chapter_idx
  end)
  
  return padnotes
end

-- Read preview lines from a padnote
-- Skips header and empty lines, returns first max_lines of content
function M.read_padnote_preview(path, max_lines)
  max_lines = max_lines or 15
  
  local content = fs.read_file(path)
  if not content then
    return { "(Failed to read file)" }
  end
  
  local lines = {}
  local line_count = 0
  local skip_header = true
  
  for line in content:gmatch("[^\n]+") do
    -- Skip header section (until we hit ---)
    if skip_header then
      if line:match("^%-%-%-") then
        skip_header = false
      end
      goto continue
    end
    
    -- Skip empty lines at the beginning
    if line_count == 0 and line:match("^%s*$") then
      goto continue
    end
    
    table.insert(lines, line)
    line_count = line_count + 1
    
    if line_count >= max_lines then
      break
    end
    
    ::continue::
  end
  
  if #lines == 0 then
    return { "(Empty padnote)" }
  end
  
  return lines
end

-- Format date in pt-BR
function M.format_date_ptbr(timestamp)
  timestamp = timestamp or os.time()
  local date_table = os.date("*t", timestamp)
  local day = string.format("%02d", date_table.day)
  local month = MONTHS_PT[date_table.month]
  local year = date_table.year
  
  return string.format("%s %s %d", day, month, year)
end

return M
