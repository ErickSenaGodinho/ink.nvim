local data = require("ink.export.data")
local markdown = require("ink.export.markdown")
local json = require("ink.export.json")
local util = require("ink.export.util")
local fs = require("ink.fs")

local M = {}

-- Export book to file
-- @param slug: book slug identifier
-- @param format: "markdown" or "json"
-- @param options: { include_bookmarks, include_context }
-- @param output_path: full path to output file
-- @return boolean: success status
function M.export_book(slug, format, options, output_path)
  -- Validate inputs
  if not slug or slug == "" then
    vim.notify("Invalid book slug", vim.log.levels.ERROR)
    return false
  end

  if not output_path or output_path == "" then
    vim.notify("Invalid output path", vim.log.levels.ERROR)
    return false
  end

  format = format or "markdown"
  options = options or {}

  -- Collect data
  local book_data = data.collect_book_data(slug, options)
  if not book_data then
    -- Error already notified by collect_book_data
    return false
  end

  -- Format content
  local content
  if format == "markdown" then
    content = markdown.format(book_data, options)
  elseif format == "json" then
    content = json.format(book_data, options)
  else
    vim.notify("Unknown export format: " .. format, vim.log.levels.ERROR)
    return false
  end

  -- Ensure export directory exists
  local export_dir = vim.fn.fnamemodify(output_path, ":h")
  fs.ensure_dir(export_dir)

  -- Write file
  local file, err = io.open(output_path, "w")
  if not file then
    vim.notify("Failed to write export file: " .. (err or "unknown error"), vim.log.levels.ERROR)
    return false
  end

  file:write(content)
  file:close()

  return true
end

-- Re-export data collection (for advanced usage)
M.collect_book_data = data.collect_book_data

-- Re-export formatters (for advanced usage)
M.format_markdown = markdown.format
M.format_json = json.format

-- Re-export utilities
M.util = util

return M
