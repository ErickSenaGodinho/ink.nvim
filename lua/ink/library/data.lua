-- lua/ink/library/data.lua
-- Persistence layer for library

local M = {}

local fs = require("ink.fs")
local data = require("ink.data")
local entities = require("ink.html.entities")

-- Get path to library.json
local function get_library_path()
  fs.ensure_dir(data.get_data_dir())
  return data.get_data_dir() .. "/library.json"
end

-- Migrate library data to decode HTML entities
-- Returns the library and whether anything was changed
local function migrate_decode_entities(library)
  -- Already migrated (v2 includes proper tag removal)
  if library.entities_decoded_v2 then
    return library, false
  end

  for _, book in ipairs(library.books or {}) do
    if book.title then
      book.title = entities.decode_entities(book.title)
    end
    if book.author then
      book.author = entities.decode_entities(book.author)
    end
    if book.description then
      -- Decode entities FIRST, then remove HTML tags
      book.description = entities.decode_entities(book.description)
      book.description = book.description:gsub("<[^>]+>", ""):gsub("%s+", " "):match("^%s*(.-)%s*$")
    end
  end

  library.entities_decoded_v2 = true
  library.entities_decoded = nil -- Remove old flag

  return library, true
end

function M.load()
  local path = get_library_path()

  if not fs.exists(path) then
    return { books = {}, entities_decoded_v2 = true }
  end

  local content = fs.read_file(path)
  if not content then
    return { books = {} }
  end

  local lib = data.json_decode_safe(content, path)
  if not lib then
    -- corrupted/empty: original was backed up and moved aside
    return { books = {} }
  end

  if type(lib.books) ~= "table" then
    lib.books = {}
  end

  local migrated
  lib, migrated = migrate_decode_entities(lib)

  -- Only touch the disk when the migration actually changed something
  if migrated then
    M.save(lib)
  end

  return lib
end

function M.save(library)
  local ok, json = pcall(vim.json.encode, library)
  if not ok then
    vim.notify("Failed to encode library: " .. tostring(json), vim.log.levels.ERROR)
    return false
  end

  return (fs.write_file(get_library_path(), json))
end

return M
