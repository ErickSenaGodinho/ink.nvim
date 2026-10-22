local M = {}

local fs = require("ink.fs")
local data_module = require("ink.data")
local uv = vim.uv or vim.loop

-- Get path to related.json
local function get_related_path()
  fs.ensure_dir(data_module.get_data_dir())
  return data_module.get_data_dir() .. "/related.json"
end

-- Load related data from disk
-- Returns table on success, or nil, err when the file exists but cannot be read.
-- Callers that WRITE must use this, so a read failure never turns into an overwrite.
local function load_checked()
  local path = get_related_path()

  if not fs.exists(path) then
    return {}
  end

  local content = fs.read_file(path)
  if content == nil then
    return nil, "could not read " .. path
  end

  if content:match("^%s*$") then
    return {}
  end

  local result = data_module.json_decode_safe(content, path)
  if type(result) ~= "table" then
    -- Corrupted: json_decode_safe already backed up and moved the file aside,
    -- so starting fresh does not destroy anything
    return {}
  end

  return result
end

-- Load related data (read-only callers): never fails, falls back to empty
function M.load()
  return load_checked() or {}
end

-- Save related data to disk (atomic: write .tmp, then rename over the target)
-- Returns true, or false, err
function M.save(data)
  local path = get_related_path()

  -- vim.json.encode would turn an empty table into []
  if next(data) == nil then
    data = vim.empty_dict()
  end

  local ok_enc, json = pcall(vim.json.encode, data)
  if not ok_enc then
    return false, tostring(json)
  end

  local tmp = path .. ".tmp"
  local file, open_err = io.open(tmp, "wb")
  if not file then
    return false, open_err
  end

  local ok_write, write_err = pcall(file.write, file, json)
  file:close()
  if not ok_write then
    os.remove(tmp)
    return false, tostring(write_err)
  end

  local renamed, rename_err = uv.fs_rename(tmp, path)
  if not renamed then
    os.remove(tmp)
    return false, rename_err
  end

  return true
end

-- Add a related resource (reciprocal)
function M.add_related(book_slug, related_slug)
  if not book_slug or not related_slug then
    return false, "missing slug"
  end
  if book_slug == related_slug then
    return false, "a book cannot be related to itself"
  end

  local data, err = load_checked()
  if not data then
    return false, err
  end

  data[book_slug] = data[book_slug] or {}
  data[related_slug] = data[related_slug] or {}

  data[book_slug][related_slug] = true
  data[related_slug][book_slug] = true

  return M.save(data)
end

-- Remove a related resource (reciprocal)
function M.remove_related(book_slug, related_slug)
  local data, err = load_checked()
  if not data then
    return false, err
  end

  local removed = false

  if data[book_slug] and data[book_slug][related_slug] then
    data[book_slug][related_slug] = nil
    removed = true
  end

  -- Reciprocal side
  if data[related_slug] and data[related_slug][book_slug] then
    data[related_slug][book_slug] = nil
    removed = true
  end

  if not removed then
    return false, "relation not found"
  end

  -- Prune entries left empty, so the store never keeps { a = {}, b = {} }
  for _, slug in ipairs({ book_slug, related_slug }) do
    if data[slug] and next(data[slug]) == nil then
      data[slug] = nil
    end
  end

  return M.save(data)
end

-- Get related resources for a book (set: { [slug] = true })
function M.get_related(book_slug)
  return M.load()[book_slug] or {}
end

-- Get related resources for a book as a sorted list of slugs
function M.get_related_slugs(book_slug)
  local slugs = vim.tbl_keys(M.get_related(book_slug))
  table.sort(slugs)
  return slugs
end

-- Remove all relations for a specific book
-- Should be called when a book is deleted from the library
function M.remove_all_for_book(book_slug)
  local data, err = load_checked()
  if not data then
    return false, err
  end

  -- Drop the book's own entry
  data[book_slug] = nil

  -- Drop it from every other entry (also covers inconsistent, non-reciprocal data)
  for slug, relations in pairs(data) do
    relations[book_slug] = nil
    if next(relations) == nil then
      data[slug] = nil
    end
  end

  return M.save(data)
end

-- Build a set of slugs that exist in the library
local function get_valid_slugs()
  -- lazy: this module does not import library at load time, so there is no cycle;
  -- keeping it inline avoids loading the library until it is needed
  local library = require("ink.library").load()
  local valid = {}
  for _, book in ipairs(library.books or {}) do
    valid[book.slug] = true
  end
  return valid
end

-- Get list of orphan references (slugs that don't exist in library)
-- Returns a list of { slug = string, referenced_by = string[] }
function M.get_orphan_references()
  local valid = get_valid_slugs()
  local orphans = {} -- slug -> set of referencing slugs

  local function mark(orphan, referrer)
    orphans[orphan] = orphans[orphan] or {}
    orphans[orphan][referrer] = true
  end

  for slug, relations in pairs(M.load()) do
    if not valid[slug] then
      mark(slug, slug)
      for related_slug in pairs(relations) do
        mark(slug, related_slug)
      end
    end
    for related_slug in pairs(relations) do
      if not valid[related_slug] then
        mark(related_slug, slug)
      end
    end
  end

  local result = {}
  for slug, referrers in pairs(orphans) do
    referrers[slug] = nil -- an orphan does not "reference" itself
    local list = vim.tbl_keys(referrers)
    table.sort(list)
    table.insert(result, { slug = slug, referenced_by = list })
  end
  table.sort(result, function(a, b)
    return a.slug < b.slug
  end)

  return result
end

-- Clean up orphan references
-- Removes every reference to books that no longer exist in the library
-- Returns number of orphan entries removed and the list of cleaned slugs
function M.cleanup_orphans()
  local valid = get_valid_slugs()

  local data, err = load_checked()
  if not data then
    return 0, {}, err
  end

  local cleaned_slugs = {}
  local seen = {}
  local cleaned_count = 0
  local changed = false

  local function record(slug)
    if not seen[slug] then
      seen[slug] = true
      table.insert(cleaned_slugs, slug)
    end
  end

  for slug, relations in pairs(data) do
    if not valid[slug] then
      -- The entire entry is orphaned
      record(slug)
      data[slug] = nil
      cleaned_count = cleaned_count + 1
      changed = true
    else
      -- Valid book that references invalid ones
      for related_slug in pairs(relations) do
        if not valid[related_slug] then
          relations[related_slug] = nil
          record(related_slug)
          changed = true
        end
      end

      -- Remove entry if it has no relations left
      if next(relations) == nil then
        data[slug] = nil
        changed = true
      end
    end
  end

  if changed then
    local ok, save_err = M.save(data)
    if not ok then
      return 0, {}, save_err
    end
  end

  table.sort(cleaned_slugs)
  return cleaned_count, cleaned_slugs
end

return M
