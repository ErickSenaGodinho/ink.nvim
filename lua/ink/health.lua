-- lua/ink/health.lua
-- Health check diagnostics for ink.nvim

local M = {}

local fs = require("ink.fs")
local data = require("ink.data")

-- Check results storage
local results = {
  ok = {},
  warn = {},
  error = {},
}

-- Add result
local function add_result(level, message)
  table.insert(results[level], message)
end

-- Check if unzip command is available
local function check_unzip()
  if vim.fn.executable("unzip") == 1 then
    add_result("ok", "unzip command is available")
    return true
  else
    add_result("error", "unzip command not found - required for reading EPUB files")
    add_result("error", "  Install: sudo apt install unzip (Debian/Ubuntu) or brew install unzip (macOS)")
    return false
  end
end

-- Check data directory permissions
local function check_data_dir()
  local data_dir = data.get_data_dir()

  -- Check if directory exists
  if not fs.dir_exists(data_dir) then
    add_result("warn", "Data directory doesn't exist: " .. data_dir)
    add_result("warn", "  It will be created automatically when needed")
    return true
  end

  -- Check if writable by trying to create a test file
  local test_file = data_dir .. "/.health_check_test"
  local ok = fs.write_file(test_file, "test")

  if ok then
    vim.fn.delete(test_file)
    add_result("ok", "Data directory is writable: " .. data_dir)
    return true
  else
    add_result("error", "Data directory is not writable: " .. data_dir)
    add_result("error", "  Check permissions: chmod 755 " .. data_dir)
    return false
  end
end

-- Check library.json integrity
local function check_library_integrity()
  local library_path = data.get_data_dir() .. "/library.json"

  if not fs.exists(library_path) then
    add_result("ok", "No library.json yet (will be created when you add books)")
    return true
  end

  local content = fs.read_file(library_path)
  if not content or content == "" then
    add_result("error", "library.json exists but is empty")
    return false
  end

  local ok, library = pcall(vim.json.decode, content)

  if not ok or type(library) ~= "table" then
    add_result("error", "library.json is corrupted or has invalid structure")

    local backups = vim.fn.glob(library_path .. ".backup.*", false, true)

    if #backups > 0 then
      table.sort(backups, function(a, b)
        local ta = tonumber(a:match("%.backup%.(%d+)$")) or 0
        local tb = tonumber(b:match("%.backup%.(%d+)$")) or 0
        return ta > tb
      end)

      add_result("warn", "  Available backup: " .. vim.fn.fnamemodify(backups[1], ":t"))
    else
      add_result("warn", "  No backup file found")
    end

    return false
  end

  -- Check structure
  if not library.books or type(library.books) ~= "table" then
    add_result("error", "library.json has invalid structure (missing 'books' array)")
    return false
  end

  add_result("ok", string.format("library.json is valid (%d books)", #library.books))
  return true
end

-- Check for broken book paths in library
local function check_broken_paths()
  local library_path = data.get_data_dir() .. "/library.json"

  if not fs.exists(library_path) then
    add_result("ok", "No library.json yet (will be created when you add books)")
    return true
  end

  local content = fs.read_file(library_path)

  if not content or content == "" then
    add_result("warn", "library.json is empty, skipping path checks")
    return true
  end

  -- Read-only JSON decoding: never create backups or modify files
  local ok, library = pcall(vim.json.decode, content)

  if not ok or type(library) ~= "table" then
    add_result("warn", "Cannot check book paths: library.json is invalid")
    return true
  end

  if type(library.books) ~= "table" then
    add_result("warn", "Cannot check book paths: library.json has invalid structure")
    return true
  end

  if #library.books == 0 then
    add_result("ok", "No books in library to check")
    return true
  end

  local broken_count = 0
  local broken_books = {}
  local local_count = 0
  local web_count = 0

  for _, book in ipairs(library.books) do
    if type(book) == "table" then
      local is_web = book.path and (book.path:match("^https?://") or book.format == "web")

      if is_web then
        web_count = web_count + 1
      else
        local_count = local_count + 1

        if book.path and not fs.exists(book.path) then
          broken_count = broken_count + 1
          table.insert(broken_books, book.title or book.slug or "Unknown book")
        end
      end
    end
  end

  if broken_count == 0 then
    if web_count > 0 then
      add_result(
        "ok",
        string.format("All %d local book paths are valid (%d web resources skipped)", local_count, web_count)
      )
    else
      add_result("ok", string.format("All %d book paths are valid", local_count))
    end

    return true
  end

  add_result("warn", string.format("%d local books have broken paths:", broken_count))

  for i, title in ipairs(broken_books) do
    if i <= 5 then
      add_result("warn", "  - " .. title)
    end
  end

  if broken_count > 5 then
    add_result("warn", string.format("  ... and %d more", broken_count - 5))
  end

  add_result("warn", "  Use :InkEditLibrary to remove broken entries")

  return true
end

-- Check cache directory
local function check_cache()
  local cache_dir = data.get_data_dir() .. "/cache"

  if not fs.dir_exists(cache_dir) then
    add_result("ok", "No cache directory yet (created when EPUBs are opened)")
    return true
  end

  -- Count cache entries
  local handle = vim.loop.fs_scandir(cache_dir)
  if not handle then
    add_result("warn", "Cannot scan cache directory")
    return true
  end

  local count = 0
  while true do
    local name, type = vim.loop.fs_scandir_next(handle)
    if not name then
      break
    end
    if type == "directory" then
      count = count + 1
    end
  end

  add_result("ok", string.format("Cache directory contains %d extracted EPUBs", count))

  -- Calculate cache size
  local size_output = vim.fn.system({ "du", "-sh", cache_dir })
  local size = size_output:match("^(%S+)")
  if size then
    add_result("ok", "Cache size: " .. size)
    add_result("ok", "  To clear cache: rm -rf " .. cache_dir)
  end

  return true
end

-- Check collections.json integrity
local function check_collections_integrity()
  local collections_path = data.get_data_dir() .. "/collections.json"

  if not fs.exists(collections_path) then
    add_result("ok", "No collections.json yet (will be created when you create collections)")
    return true
  end

  local content = fs.read_file(collections_path)
  if not content or content == "" then
    add_result("error", "collections.json exists but is empty")
    return false
  end

  local ok, collections_data = pcall(vim.json.decode, content)
  if not ok then
    add_result("error", "collections.json is corrupted")
    return false
  end

  -- Root must be an object (not null, number, string...)
  if type(collections_data) ~= "table" then
    add_result("error", "collections.json has invalid structure (root is not an object)")
    return false
  end

  -- Check structure
  if not collections_data.collections or type(collections_data.collections) ~= "table" then
    add_result("error", "collections.json has invalid structure")
    return false
  end

  add_result("ok", string.format("collections.json is valid (%d collections)", #collections_data.collections))
  return true
end

-- Check related.json integrity and orphan references
local function check_related_integrity()
  local related_path = data.get_data_dir() .. "/related.json"

  if not fs.exists(related_path) then
    add_result("ok", "No related.json yet (will be created when you link books)")
    return true
  end

  local content = fs.read_file(related_path)
  if not content or content == "" then
    add_result("warn", "related.json exists but is empty")
    return true
  end

  -- Check if valid JSON
  local ok, related_data = pcall(vim.json.decode, content)
  if not ok then
    add_result("error", "related.json is corrupted (invalid JSON)")
    return false
  end

  -- Root must be an object (pairs() fails on null/non-table values)
  if type(related_data) ~= "table" then
    add_result("error", "related.json has invalid structure (root is not an object)")
    return false
  end

  -- Count total relationships
  local total_relationships = 0
  local books_with_relations = 0
  for slug, relations in pairs(related_data) do
    if type(relations) == "table" then
      books_with_relations = books_with_relations + 1
      total_relationships = total_relationships + vim.tbl_count(relations)
    end
  end

  add_result(
    "ok",
    string.format("related.json is valid (%d books with %d relationships)", books_with_relations, total_relationships)
  )

  -- Check for orphan references
  local ok_related, related_module = pcall(require, "ink.data.related")
  if not ok_related then
    add_result("warn", "Could not load related module to check orphans")
    return true
  end

  local orphans = related_module.get_orphan_references()
  if #orphans == 0 then
    add_result("ok", "No orphan references found (all references are valid)")
    return true
  end

  -- Found orphans - report them
  add_result("warn", string.format("Found %d orphan reference(s) to deleted books:", #orphans))
  for i, orphan in ipairs(orphans) do
    if i <= 3 then -- Show max 3
      add_result("warn", string.format("  - '%s' (referenced by %d book(s))", orphan.slug, #orphan.referenced_by))
    end
  end
  if #orphans > 3 then
    add_result("warn", string.format("  ... and %d more", #orphans - 3))
  end
  add_result("warn", "  Run :lua require('ink.data.related').cleanup_orphans() to fix")

  return true
end

-- Check Neovim version
local function check_neovim_version()
  local version = vim.version()
  local version_str = string.format("%d.%d.%d", version.major, version.minor, version.patch)

  -- Require Neovim 0.8.0+
  if version.major == 0 and version.minor < 8 then
    add_result("error", "Neovim version too old: " .. version_str)
    add_result("error", "  ink.nvim requires Neovim 0.8.0 or newer")
    return false
  end

  add_result("ok", "Neovim version: " .. version_str)
  return true
end

-- Check optional dependencies
local function check_optional_deps()
  -- Telescope
  local has_telescope = pcall(require, "telescope")
  if has_telescope then
    add_result("ok", "Telescope.nvim is installed (enhanced search/library UI)")
  else
    add_result("warn", "Telescope.nvim not found (fallback UI will be used)")
    add_result("warn", "  Install for better experience: https://github.com/nvim-telescope/telescope.nvim")
  end

  -- Plenary (usually comes with Telescope)
  local has_plenary = pcall(require, "plenary")
  if has_plenary then
    add_result("ok", "plenary.nvim is installed")
  end

  return true
end

-- Run all checks
function M.check()
  -- Reset results
  results = {
    ok = {},
    warn = {},
    error = {},
  }

  -- Run checks
  check_neovim_version()
  check_unzip()
  check_optional_deps()
  check_data_dir()
  check_library_integrity()
  check_broken_paths()
  check_collections_integrity()
  check_related_integrity()
  check_cache()

  -- Display results
  M.display_results()
end

function M.display_results()
  vim.health.start("ink.nvim")

  for _, msg in ipairs(results.ok) do
    vim.health.ok(msg)
  end

  for _, msg in ipairs(results.warn) do
    vim.health.warn(msg)
  end

  for _, msg in ipairs(results.error) do
    vim.health.error(msg)
  end
end

return M
