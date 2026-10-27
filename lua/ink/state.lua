local fs = require("ink.fs")
local data = require("ink.data")
local migrate = require("ink.data.migrate")

local M = {}

function M.save(slug, state)
  state = vim.tbl_deep_extend("force", M.load(slug) or {}, state)
  local path = data.get_book_dir(slug) .. "/state.json"

  local ok, encoded = pcall(vim.json.encode, state)
  if not ok then
    vim.notify("Failed to encode state: " .. tostring(encoded), vim.log.levels.ERROR)
    return false
  end

  return (fs.write_file(path, encoded))
end

function M.load(slug)
  migrate.migrate_book(slug)
  local path = data.get_book_dir(slug) .. "/state.json"

  local content = fs.read_file(path)
  if content then
    local result, error_message = data.json_decode_safe(content, path)
    if result then
      return result
    elseif error_message then
      vim.notify(error_message, vim.log.levels.ERROR, {})
    end
  end
  return nil
end

return M
