-- lua/ink/collections/associations.lua
-- Book-Collection association operations

local M = {}

local data = require("ink.collections.data")
local management = require("ink.collections.management")

-- Check if book exists in library
local function book_exists(book_slug)
	local library = require("ink.library")
	local books = library.get_books()

	for _, book in ipairs(books) do
		if book.slug == book_slug then
			return true
		end
	end
	return false
end

-- Add book to collection
-- @param collection_id: string
-- @param book_slug: string
-- @return success: boolean
function M.add_book(collection_id, book_slug)
	-- Verify collection exists
	local coll = management.get(collection_id)
	if not coll then
		vim.notify("Collection not found: " .. collection_id, vim.log.levels.ERROR)
		return false
	end

	-- Verify book exists
	if not book_exists(book_slug) then
		vim.notify("Book not found in library: " .. book_slug, vim.log.levels.WARN)
		return false
	end

	-- Check if already in collection (idempotent)
	if M.has_book(collection_id, book_slug) then
		return true
	end

	-- Add book
	local collections_data = data.load()
	for _, c in ipairs(collections_data.collections) do
		if c.id == collection_id then
			table.insert(c.books, book_slug)
			break
		end
	end

	return data.save(collections_data)
end

-- Remove book from collection
-- @param collection_id: string
-- @param book_slug: string
-- @return success: boolean
function M.remove_book(collection_id, book_slug)
	local collections_data = data.load()
	local found = false

	for _, coll in ipairs(collections_data.collections) do
		if coll.id == collection_id then
			local new_books = {}
			for _, slug in ipairs(coll.books) do
				if slug ~= book_slug then
					table.insert(new_books, slug)
				else
					found = true
				end
			end
			coll.books = new_books
			break
		end
	end

	if not found then
		return true -- Idempotent
	end

	return data.save(collections_data)
end

-- Check if book is in collection
-- @param collection_id: string
-- @param book_slug: string
-- @return is_in: boolean
function M.has_book(collection_id, book_slug)
	local coll = management.get(collection_id)
	if not coll then
		return false
	end

	for _, slug in ipairs(coll.books) do
		if slug == book_slug then
			return true
		end
	end
	return false
end

-- Get all collections that contain a book
-- @param book_slug: string
-- @return collection_ids: string[]
function M.get_book_collections(book_slug)
	local result = {}
	local all = management.get_all()

	for _, coll in ipairs(all) do
		if M.has_book(coll.id, book_slug) then
			table.insert(result, coll.id)
		end
	end

	return result
end

-- Move book from one collection to another
-- @param book_slug: string
-- @param from_collection: string
-- @param to_collection: string
-- @return success: boolean
function M.move_book(book_slug, from_collection, to_collection)
	local success1 = M.remove_book(from_collection, book_slug)
	if not success1 then
		return false
	end

	local success2 = M.add_book(to_collection, book_slug)
	return success2
end

-- Remove book from all collections (used when book is deleted from library)
-- @param book_slug: string
-- @return removed_count: number
function M.remove_book_from_all(book_slug)
	local collections_data = data.load()
	local removed_count = 0

	for _, coll in ipairs(collections_data.collections) do
		local new_books = {}
		for _, slug in ipairs(coll.books) do
			if slug ~= book_slug then
				table.insert(new_books, slug)
			else
				removed_count = removed_count + 1
			end
		end
		coll.books = new_books
	end

	if removed_count > 0 then
		data.save(collections_data)
	end

	return removed_count
end

return M
