-- lua/ink/collections/queries.lua
-- Query functions for collections

local M = {}

local management = require("ink.collections.management")

-- Stats cache
local stats_cache = {}

-- Invalidate stats cache for a collection
function M.invalidate_stats(collection_id)
	if collection_id then
		stats_cache[collection_id] = nil
	else
		stats_cache = {}
	end
end

-- Get books from a collection with full library data
-- @param collection_id: string
-- @return books: table[]
function M.get_collection_books(collection_id)
	local coll = management.get(collection_id)
	if not coll then
		return {}
	end

	local library = require("ink.library")
	local all_books = library.get_books()

	-- Create lookup table for efficiency
	local books_by_slug = {}
	for _, book in ipairs(all_books) do
		books_by_slug[book.slug] = book
	end

	-- Get books in collection
	local result = {}
	for _, book_slug in ipairs(coll.books) do
		local book = books_by_slug[book_slug]
		if book then
			table.insert(result, book)
		else
			-- Orphaned book (exists in collection but not in library)
			vim.notify(
				string.format("Orphaned book in collection %s: %s", collection_id, book_slug),
				vim.log.levels.WARN
			)
		end
	end

	return result
end

-- Count books in collection
-- @param collection_id: string
-- @return count: number
function M.count_books(collection_id)
	local coll = management.get(collection_id)
	return coll and #coll.books or 0
end

-- Calculate average reading progress for collection
-- @param collection_id: string
-- @return progress: number (0-100)
function M.get_collection_progress(collection_id)
	-- Check cache
	if stats_cache[collection_id] and stats_cache[collection_id].progress then
		return stats_cache[collection_id].progress
	end

	local books = M.get_collection_books(collection_id)

	if #books == 0 then
		return 0
	end

	local total_progress = 0
	for _, book in ipairs(books) do
		if book.total_chapters and book.total_chapters > 0 then
			local book_progress = (book.chapter / book.total_chapters) * 100
			total_progress = total_progress + book_progress
		end
	end

	local avg_progress = math.floor(total_progress / #books)

	-- Cache result
	stats_cache[collection_id] = stats_cache[collection_id] or {}
	stats_cache[collection_id].progress = avg_progress

	return avg_progress
end

-- Filter books by multiple collections (AND or OR mode)
-- @param collection_ids: string[]
-- @param mode: "and"|"or" - Default: "or"
-- @return books: table[]
function M.filter_books(collection_ids, mode)
	mode = mode or "or"

	if #collection_ids == 0 then
		return {}
	end

	if mode == "or" then
		-- Union: books in ANY collection
		local seen = {}
		local result = {}

		for _, cid in ipairs(collection_ids) do
			local books = M.get_collection_books(cid)
			for _, book in ipairs(books) do
				if not seen[book.slug] then
					seen[book.slug] = true
					table.insert(result, book)
				end
			end
		end

		return result
	elseif mode == "and" then
		-- Intersection: books in ALL collections
		if #collection_ids == 1 then
			return M.get_collection_books(collection_ids[1])
		end

		local result = M.get_collection_books(collection_ids[1])

		for i = 2, #collection_ids do
			local filtered = {}
			local coll_books = M.get_collection_books(collection_ids[i])
			local slugs = {}

			for _, b in ipairs(coll_books) do
				slugs[b.slug] = true
			end

			for _, book in ipairs(result) do
				if slugs[book.slug] then
					table.insert(filtered, book)
				end
			end

			result = filtered
		end

		return result
	end

	return {}
end

-- Get empty collections (no books)
-- @return collection_ids: string[]
function M.get_empty_collections()
	local result = {}
	local all = management.get_all()

	for _, coll in ipairs(all) do
		if #coll.books == 0 then
			table.insert(result, coll.id)
		end
	end

	return result
end

-- Search collections by name or description
-- @param term: string
-- @return collections: table[]
function M.search(term)
	term = term:lower()
	local result = {}
	local all = management.get_all()

	for _, coll in ipairs(all) do
		local name_match = coll.name:lower():find(term, 1, true)
		local desc_match = coll.description and coll.description:lower():find(term, 1, true)

		if name_match or desc_match then
			table.insert(result, coll)
		end
	end

	return result
end

return M
