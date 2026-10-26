local fs = require("ink.fs")
local paths = require("ink.data.paths")

local M = {}

-- Base data directory
function M.get_data_dir()
  return paths.root()
end

function M.validate_slug(slug)
  return paths.validate_slug(slug)
end

-- Book-specific directory (creates if needed)
function M.get_book_dir(slug)
  local dir = paths.book_dir(slug)
  fs.ensure_dir(dir)
  return dir
end

---Decode JSON safely. If the file is corrupted, back it up and move it aside
---so it is neither overwritten nor reported again on every load.
---@param content string|nil raw JSON text
---@param file_path string|nil file the content came from (used for backup/logging)
---@return table|nil result
---@return string|nil err
function M.json_decode_safe(content, file_path)
  local name = file_path and vim.fn.fnamemodify(file_path, ":t") or "<memory>"

  if not content or content == "" then
    return nil, name .. ": empty content"
  end

  local ok, result = pcall(vim.json.decode, content)
  if ok and type(result) == "table" then
    return result, nil
  end

  local err = ok and ("unexpected root type: " .. type(result)) or tostring(result)

  if file_path then
    local backup_path = file_path .. ".backup." .. os.time()
    if fs.write_file(backup_path, content) then
      os.remove(file_path)
      vim.notify(
        string.format("%s is corrupted (%s). Backed up to %s", name, err, vim.fn.fnamemodify(backup_path, ":t")),
        vim.log.levels.WARN
      )
    else
      vim.notify(string.format("%s is corrupted (%s) and backup failed", name, err), vim.log.levels.ERROR)
    end
  end

  return nil, name .. ": " .. err
end

-- Pretty-print JSON encoder
function M.json_encode(data, indent)
  indent = indent or 0
  local spacing = string.rep("  ", indent)
  local spacing_inner = string.rep("  ", indent + 1)

  if type(data) == "table" then
    local is_array = #data > 0 or next(data) == nil
    if is_array and #data > 0 then
      for k, _ in pairs(data) do
        if type(k) ~= "number" then
          is_array = false
          break
        end
      end
    end

    if is_array then
      if #data == 0 then
        return "[]"
      end
      local items = {}
      for _, v in ipairs(data) do
        table.insert(items, spacing_inner .. M.json_encode(v, indent + 1))
      end
      return "[\n" .. table.concat(items, ",\n") .. "\n" .. spacing .. "]"
    else
      local items = {}
      for k, v in pairs(data) do
        local key = '"' .. tostring(k) .. '"'
        table.insert(items, spacing_inner .. key .. ": " .. M.json_encode(v, indent + 1))
      end
      if #items == 0 then
        return "{}"
      end
      table.sort(items)
      return "{\n" .. table.concat(items, ",\n") .. "\n" .. spacing .. "}"
    end
  elseif type(data) == "string" then
    local escaped = data:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
    return '"' .. escaped .. '"'
  elseif type(data) == "number" then
    return tostring(data)
  elseif type(data) == "boolean" then
    return data and "true" or "false"
  elseif data == nil then
    return "null"
  else
    return '"' .. tostring(data) .. '"'
  end
end

return M
