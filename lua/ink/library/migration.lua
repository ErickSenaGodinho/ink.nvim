-- lua/ink/library/migration.lua
-- Data migration for library

local M = {}

-- Migrate library data to new format with additional fields
function M.migrate(library, save_fn)
	local migrated = false
	local now = os.time()

	for i, book in ipairs(library.books) do
		-- Add first_opened if missing
		if not book.first_opened then
			-- Use last_opened as best estimate
			book.first_opened = book.last_opened or now
			migrated = true
		end

		-- Add completed_date if missing but book is completed
		if not book.completed_date and book.chapter and book.total_chapters then
			if book.chapter >= book.total_chapters then
				-- Use last_opened as estimate
				book.completed_date = book.last_opened or now
				migrated = true
			end
		end

		-- Calculate status if missing
		if not book.status then
			book.status = M.calculate_status(book)
			migrated = true
		end

		-- Ensure chapter and total_chapters have defaults
		if not book.chapter then
			book.chapter = 1
			migrated = true
		end
		if not book.total_chapters then
			book.total_chapters = 1
			migrated = true
		end
	end

	if migrated and save_fn then
		save_fn(library)
	end

	return library
end

-- Calculate book status based on progress
function M.calculate_status(book)
	if not book.chapter or not book.total_chapters then
		return "to-read"
	end

	if book.chapter == 0 then
		return "to-read"
	elseif book.chapter >= book.total_chapters then
		return "completed"
	else
		return "reading"
	end
end

return M
