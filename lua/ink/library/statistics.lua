-- lua/ink/library/statistics.lua
-- Statistics and aggregation functions

local M = {}

-- Get aggregated statistics for library
-- @param books: table[] - Array of books
-- @return stats: table
function M.get_statistics(books)
	local stats = {
		total_books = #books,
		to_read = 0,
		reading = 0,
		completed = 0,
		completed_this_month = 0,
		completed_this_year = 0,
		added_this_month = 0,
		added_this_year = 0,
	}

	local now = os.time()
	local month_ago = now - (30 * 24 * 60 * 60)
	local year_ago = now - (365 * 24 * 60 * 60)

	for _, book in ipairs(books) do
		-- Count by status
		if book.status == "to-read" then
			stats.to_read = stats.to_read + 1
		elseif book.status == "reading" then
			stats.reading = stats.reading + 1
		elseif book.status == "completed" then
			stats.completed = stats.completed + 1

			-- Count recently completed
			if book.completed_date and book.completed_date >= month_ago then
				stats.completed_this_month = stats.completed_this_month + 1
			end
			if book.completed_date and book.completed_date >= year_ago then
				stats.completed_this_year = stats.completed_this_year + 1
			end
		end

		-- Count recently added
		if book.first_opened and book.first_opened >= month_ago then
			stats.added_this_month = stats.added_this_month + 1
		end
		if book.first_opened and book.first_opened >= year_ago then
			stats.added_this_year = stats.added_this_year + 1
		end
	end

	return stats
end

-- Format timestamp as relative string
function M.format_last_opened(timestamp)
	if not timestamp then
		return "Never"
	end

	local now = os.time()
	local diff = now - timestamp

	if diff < 60 then
		return "Just now"
	elseif diff < 3600 then
		local mins = math.floor(diff / 60)
		return mins .. " min ago"
	elseif diff < 86400 then
		local hours = math.floor(diff / 3600)
		return hours .. "h ago"
	elseif diff < 604800 then
		local days = math.floor(diff / 86400)
		return days .. "d ago"
	else
		return os.date("%Y-%m-%d", timestamp)
	end
end

return M
