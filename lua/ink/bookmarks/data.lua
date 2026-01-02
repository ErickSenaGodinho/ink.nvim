local fs = require("ink.fs")
local data = require("ink.data")
local migrate = require("ink.data.migrate")

local M = {}

function M.get_file_path(slug)
  migrate.migrate_bookmarks()
  return data.get_book_dir(slug) .. "/bookmarks.json"
end

function M.save(slug, bookmarks)
  local path = M.get_file_path(slug)
  local json = data.json_encode({ bookmarks = bookmarks })
  local file = io.open(path, "w")
  if not file then
    return false
  end

  -- Ensure file is always closed, even on error
  local ok = pcall(file.write, file, json)
  file:close()
  return ok
end

function M.load(slug)
  local path = M.get_file_path(slug)
  if not fs.exists(path) then
    return { bookmarks = {} }
  end
  local content = fs.read_file(path)
  if not content then
    return { bookmarks = {} }
  end
  local ok, loaded = pcall(vim.json.decode, content)
  if not ok or not loaded then
    return { bookmarks = {} }
  end
  return loaded
end

return M
