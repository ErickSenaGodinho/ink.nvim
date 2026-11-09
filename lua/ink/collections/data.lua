-- lua/ink/collections/data.lua
-- Persistence layer for collections

local M = {}

-- Cache
local cache = {
  collections = nil, -- Cached collections data
}

-- Get path to collections.json
local function get_collections_file_path()
  local data = require("ink.data")
  return data.get_data_dir() .. "/collections.json"
end

-- Load collections from disk
function M.load()
  local path = get_collections_file_path()
  local fs = require("ink.fs")
  local ink_data = require("ink.data")

  local function default_data()
    return {
      version = 1,
      collections = {},
    }
  end

  local function validate_data(decoded)
    if type(decoded) ~= "table" then
      return nil
    end

    if type(decoded.version) ~= "number" then
      decoded.version = 1
    end

    if type(decoded.collections) ~= "table" then
      decoded.collections = {}
    end

    return decoded
  end

  -- Candidates, best first: the copy made by save(), then timestamped
  -- backups (newest first)
  local function find_backups()
    local backups = {}

    if fs.exists(path .. ".backup") then
      table.insert(backups, path .. ".backup")
    end

    local stamped = vim.fn.glob(path .. ".backup.*", false, true)
    table.sort(stamped, function(a, b)
      local timestamp_a = tonumber(a:match("%.backup%.(%d+)$")) or 0
      local timestamp_b = tonumber(b:match("%.backup%.(%d+)$")) or 0

      return timestamp_a > timestamp_b
    end)

    vim.list_extend(backups, stamped)
    return backups
  end

  if not fs.exists(path) then
    return default_data()
  end

  local content = fs.read_file(path)
  if not content or content == "" then
    return default_data()
  end

  -- On failure json_decode_safe already preserves the file (backup + remove)
  local decoded = ink_data.json_decode_safe(content, path)
  decoded = validate_data(decoded)
  if decoded then
    return decoded
  end

  vim.notify("Invalid collections file, attempting backup recovery", vim.log.levels.WARN)

  for _, backup_path in ipairs(find_backups()) do
    local backup_content = fs.read_file(backup_path)

    if backup_content and backup_content ~= "" then
      local backup_data = ink_data.json_decode_safe(backup_content)
      backup_data = validate_data(backup_data)

      if backup_data then
        -- The original was moved aside, so write the recovered data back
        -- (otherwise the next session would start empty)
        local ok, encoded = pcall(vim.json.encode, backup_data)
        if ok then
          fs.write_file(path, encoded)
        end

        vim.notify("Collections recovered from backup: " .. vim.fn.fnamemodify(backup_path, ":t"), vim.log.levels.INFO)

        return backup_data
      end
    end
  end

  return default_data()
end

-- Save collections to disk
function M.save(data)
  local fs = require("ink.fs")
  local ink_data = require("ink.data")
  local uv = vim.uv or vim.loop

  local path = get_collections_file_path()
  fs.ensure_dir(ink_data.get_data_dir())

  -- Encode first: if this fails, nothing on disk has been touched
  local ok, content = pcall(vim.json.encode, data)
  if not ok then
    vim.notify("Failed to encode collections: " .. tostring(content), vim.log.levels.ERROR)
    return false
  end

  -- Keep one backup as a COPY (overwrites; the original stays in place)
  if fs.exists(path) then
    uv.fs_copyfile(path, path .. ".backup")
  end

  -- Atomic write (.tmp + rename); original is only replaced on success
  local written = fs.write_file(path, content)
  if not written then
    return false -- write_file already notified
  end

  M.invalidate_cache()
  return true
end

-- Get cached collections or load from disk
function M.get_cached()
  if cache.collections then
    return cache.collections
  end

  cache.collections = M.load()
  return cache.collections
end

-- Invalidate cache
function M.invalidate_cache()
  cache.collections = nil
end

-- Generate ID from name
function M.generate_id(name)
  local id = name:lower()
  id = id:gsub("%s+", "-") -- Replace spaces with hyphens
  id = id:gsub("[^%w-]", "") -- Remove non-alphanumeric except hyphens
  return id
end

-- Check if ID exists
function M.id_exists(id)
  local data = M.get_cached()
  for _, coll in ipairs(data.collections) do
    if coll.id == id then
      return true
    end
  end
  return false
end

-- Make ID unique by adding suffix
function M.make_unique_id(id)
  if not M.id_exists(id) then
    return id
  end

  -- Add timestamp + random suffix to prevent collisions
  -- Random component ensures uniqueness even for rapid consecutive operations
  math.randomseed(os.time() + vim.loop.hrtime())
  local random_suffix = math.random(1000, 9999)
  return id .. "-" .. os.time() .. "-" .. random_suffix
end

return M
