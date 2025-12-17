-- lua/ink/css_cache.lua
-- Cache parsed CSS styles to disk for faster book opening

local fs = require("ink.fs")
local data = require("ink.data")

local M = {}

-- Get cache file path for CSS styles
local function get_cache_path(slug)
  return data.get_book_dir(slug) .. "/css_cache.json"
end

-- Load cached CSS styles from disk
function M.load(slug)
  local path = get_cache_path(slug)

  if not fs.exists(path) then
    return nil
  end

  local content = fs.read_file(path)
  if not content or content == "" then
    return nil
  end

  local ok, styles = pcall(vim.json.decode, content)
  if not ok or not styles then
    -- Remove corrupted cache
    os.remove(path)
    return nil
  end

  return styles
end

-- Save CSS styles to cache
function M.save(slug, styles)
  if not styles or type(styles) ~= "table" then
    return false
  end

  local book_dir = data.get_book_dir(slug)
  fs.ensure_dir(book_dir)

  local path = get_cache_path(slug)
  local json = data.json_encode(styles)

  local file = io.open(path, "w")
  if not file then
    return false
  end

  file:write(json)
  file:close()
  return true
end

-- Clear CSS cache for a book
function M.clear(slug)
  local path = get_cache_path(slug)
  if fs.exists(path) then
    os.remove(path)
    return true
  end
  return false
end

return M
