-- lua/ink/library/queries.lua
-- Query functions for library

local M = {}

local data = require("ink.library.data")
local migration = require("ink.library.migration")

-- Get all books sorted by last opened (most recent first)
function M.get_books()
	local library = data.load()

	-- Apply migration if needed
	library = migration.migrate(library, data.save)

	local books = library.books or {}

	-- Sort by last_opened descending
	table.sort(books, function(a, b)
		return (a.last_opened or 0) > (b.last_opened or 0)
	end)

	return books
end

-- Get completed books
-- @param limit: number|nil - Limit number of results (nil = all)
-- @return books: table[]
function M.get_completed_books(limit)
	local library = data.load()

	-- Apply migration if needed
	library = migration.migrate(library, data.save)

	local completed = {}

	for _, book in ipairs(library.books) do
		if book.status == "completed" then
			table.insert(completed, book)
		end
	end

	-- Sort by completed_date (most recent first)
	table.sort(completed, function(a, b)
		return (a.completed_date or 0) > (b.completed_date or 0)
	end)

	if limit then
		local limited = {}
		for i = 1, math.min(limit, #completed) do
			table.insert(limited, completed[i])
		end
		return limited
	end

	return completed
end

-- Get books currently being read
-- @return books: table[]
function M.get_reading_books()
	local library = data.load()

	-- Apply migration if needed
	library = migration.migrate(library, data.save)

	local reading = {}

	for _, book in ipairs(library.books) do
		if book.status == "reading" then
			table.insert(reading, book)
		end
	end

	-- Sort by last_opened (most recent first)
	table.sort(reading, function(a, b)
		return (a.last_opened or 0) > (b.last_opened or 0)
	end)

	return reading
end

-- Get books not yet started
-- @return books: table[]
function M.get_to_read_books()
	local library = data.load()

	-- Apply migration if needed
	library = migration.migrate(library, data.save)

	local to_read = {}

	for _, book in ipairs(library.books) do
		if book.status == "to-read" then
			table.insert(to_read, book)
		end
	end

	-- Sort by first_opened (recently added first)
	table.sort(to_read, function(a, b)
		return (a.first_opened or 0) > (b.first_opened or 0)
	end)

	return to_read
end

-- Get last opened book path
function M.get_last_book_path()
	local library = data.load()
	return library.last_book_path
end

return M
