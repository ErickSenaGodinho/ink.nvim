-- lua/ink/collections/maintenance.lua
-- Maintenance and cleanup utilities

local M = {}

local data = require("ink.collections.data")
local queries = require("ink.collections.queries")

-- Remove books that no longer exist in library (orphaned books)
-- @return removed_count: number
function M.cleanup_orphaned_books()
	local library = require("ink.library")
	local all_books = library.get_books()

	-- Create set of valid slugs
	local valid_slugs = {}
	for _, book in ipairs(all_books) do
		valid_slugs[book.slug] = true
	end

	-- Remove orphans from collections
	local collections_data = data.load()
	local removed_count = 0

	for _, coll in ipairs(collections_data.collections) do
		local cleaned_books = {}
		for _, slug in ipairs(coll.books) do
			if valid_slugs[slug] then
				table.insert(cleaned_books, slug)
			else
				removed_count = removed_count + 1
			end
		end
		coll.books = cleaned_books
	end

	if removed_count > 0 then
		data.save(collections_data)
		vim.notify(
			string.format("Removed %d orphaned book(s) from collections", removed_count),
			vim.log.levels.INFO
		)
	end

	return removed_count
end

-- Recalculate all cached statistics
function M.recalculate_stats()
	queries.invalidate_stats()
end

-- Export collections to JSON file
-- @param path: string - Output file path
-- @return success: boolean
function M.export(path)
	local collections_data = data.load()

	-- Expand path
	path = vim.fn.expand(path)

	-- Encode to JSON
	local ink_data = require("ink.data")
	local content = ink_data.json_encode(collections_data)

	-- Write file
	local file = io.open(path, "w")
	if not file then
		vim.notify("Failed to export collections to: " .. path, vim.log.levels.ERROR)
		return false
	end

	file:write(content)
	file:close()

	vim.notify("Collections exported to: " .. path, vim.log.levels.INFO)
	return true
end

-- Import collections from JSON file
-- @param path: string - Input file path
-- @param merge: boolean - If true, merge with existing collections (default: false)
-- @return success: boolean
function M.import(path, merge)
	merge = merge or false

	-- Expand path
	path = vim.fn.expand(path)

	-- Read file
	local file = io.open(path, "r")
	if not file then
		vim.notify("Failed to read file: " .. path, vim.log.levels.ERROR)
		return false
	end

	local content = file:read("*a")
	file:close()

	-- Parse JSON
	local ok, import_data = pcall(vim.json.decode, content)
	if not ok then
		vim.notify("Invalid JSON in file: " .. path, vim.log.levels.ERROR)
		return false
	end

	-- Validate structure
	if not import_data.collections then
		vim.notify("Invalid collections file structure", vim.log.levels.ERROR)
		return false
	end

	if merge then
		-- Merge with existing collections
		local existing = data.load()
		local existing_ids = {}

		-- Build set of existing IDs
		for _, coll in ipairs(existing.collections) do
			existing_ids[coll.id] = true
		end

		-- Add new collections
		local added = 0
		for _, coll in ipairs(import_data.collections) do
			if not existing_ids[coll.id] then
				table.insert(existing.collections, coll)
				added = added + 1
			end
		end

		data.save(existing)
		vim.notify(string.format("Imported %d new collection(s)", added), vim.log.levels.INFO)
	else
		-- Replace existing collections
		data.save(import_data)
		vim.notify(
			string.format("Imported %d collection(s) (replaced existing)", #import_data.collections),
			vim.log.levels.INFO
		)
	end

	return true
end

-- Get statistics about collections
-- @return stats: table
function M.get_statistics()
	local all = require("ink.collections.management").get_all()

	local total_collections = #all
	local total_books = 0
	local empty_collections = 0
	local largest_collection = { name = "", count = 0 }

	for _, coll in ipairs(all) do
		local count = #coll.books
		total_books = total_books + count

		if count == 0 then
			empty_collections = empty_collections + 1
		end

		if count > largest_collection.count then
			largest_collection.name = coll.name
			largest_collection.count = count
		end
	end

	return {
		total_collections = total_collections,
		total_books = total_books,
		empty_collections = empty_collections,
		largest_collection = largest_collection,
	}
end

return M
