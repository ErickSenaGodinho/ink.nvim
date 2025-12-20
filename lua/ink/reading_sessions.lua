local M = {}

-- In-memory state
local active_sessions = {} -- { slug => session_id }
local cache = {} -- Cache for loaded data
local config = {
	enabled = true,
	auto_save_interval = 300, -- 5 minutes
	cleanup_after_days = 365,
	grace_period = 1,
}

-- === INTERNAL HELPERS ===

local function get_sessions_file_path(slug)
	local data = require("ink.data")
	return data.get_book_dir(slug) .. "/sessions.json"
end

local function generate_session_id()
	return "session-" .. os.time()
end

local function get_current_date()
	return os.date("%Y-%m-%d")
end

local function parse_date(date_str)
	local year, month, day = date_str:match("(%d+)-(%d+)-(%d+)")
	if year and month and day then
		return os.time({ year = tonumber(year), month = tonumber(month), day = tonumber(day) })
	end
	return nil
end

local function get_dates_between(start_date, end_date)
	local dates = {}
	local start_ts = parse_date(start_date)
	local end_ts = parse_date(end_date)

	if not start_ts or not end_ts then
		return dates
	end

	local current = start_ts
	while current <= end_ts do
		table.insert(dates, os.date("%Y-%m-%d", current))
		current = current + 86400 -- Add one day
	end

	return dates
end

local function load_sessions(slug)
	local path = get_sessions_file_path(slug)
	local fs = require("ink.fs")

	if not fs.exists(path) then
		return {
			sessions = {},
			total_time = 0,
			last_session = nil,
		}
	end

	local content = fs.read_file(path)
	if not content or content == "" then
		return {
			sessions = {},
			total_time = 0,
			last_session = nil,
		}
	end

	local ok, data = pcall(vim.json.decode, content)
	if not ok then
		-- Backup corrupted file
		vim.notify("Corrupted sessions file detected, creating backup", vim.log.levels.WARN)
		os.rename(path, path .. ".corrupt")
		return {
			sessions = {},
			total_time = 0,
			last_session = nil,
		}
	end

	-- Ensure structure
	data.sessions = data.sessions or {}
	data.total_time = data.total_time or 0
	data.last_session = data.last_session or nil

	return data
end

local function save_sessions(slug, data)
	local path = get_sessions_file_path(slug)
	local ink_data = require("ink.data")

	local content = ink_data.json_encode(data)
	local fs = require("ink.fs")

	-- Ensure directory exists
	local book_dir = ink_data.get_book_dir(slug)
	fs.ensure_dir(book_dir)

	-- Write file
	local file = io.open(path, "w")
	if not file then
		vim.notify("Failed to save sessions file: " .. path, vim.log.levels.ERROR)
		return false
	end

	file:write(content)
	file:close()

	-- Invalidate cache
	cache[slug] = nil

	return true
end

local function fix_orphaned_session(slug, session)
	-- Estimate duration: 1 hour or until next session
	local estimated_duration = 3600 -- 1 hour default
	session.end_time = session.start_time + estimated_duration
	session.duration = estimated_duration

	vim.notify(
		string.format(
			"Fixed orphaned session for %s (estimated duration: %d minutes)",
			slug,
			math.floor(estimated_duration / 60)
		),
		vim.log.levels.INFO
	)
end

-- === CORE FUNCTIONS ===

function M.start_session(slug, chapter)
	if not config.enabled then
		return nil
	end

	-- End any existing active session
	if active_sessions[slug] then
		M.end_session(slug)
	end

	-- Load existing sessions
	local data = load_sessions(slug)

	-- Check for orphaned session (end_time = null)
	if data.last_session then
		for _, session in ipairs(data.sessions) do
			if session.id == data.last_session and session.end_time == vim.NIL then
				fix_orphaned_session(slug, session)
			end
		end
	end

	-- Create new session
	local session_id = generate_session_id()
	local session = {
		id = session_id,
		start_time = os.time(),
		end_time = vim.NIL, -- JSON null
		duration = 0,
		chapter_start = chapter,
		chapter_end = chapter,
		date = get_current_date(),
	}

	-- Add to sessions array
	table.insert(data.sessions, session)
	data.last_session = session_id

	-- Save to file
	if not save_sessions(slug, data) then
		return nil
	end

	-- Store in memory
	active_sessions[slug] = session_id

	return session_id
end

function M.end_session(slug)
	if not config.enabled then
		return 0
	end

	local session_id = active_sessions[slug]
	if not session_id then
		return 0 -- No active session
	end

	-- Load sessions
	local data = load_sessions(slug)

	-- Find the session
	local session = nil
	for _, s in ipairs(data.sessions) do
		if s.id == session_id then
			session = s
			break
		end
	end

	if not session then
		vim.notify("Active session not found in file", vim.log.levels.WARN)
		active_sessions[slug] = nil
		return 0
	end

	-- Get current chapter from context
	local ctx = require("ink.ui.context")
	local current_chapter = ctx.ctx.chapter_idx or session.chapter_start

	-- Update session
	session.end_time = os.time()
	session.duration = session.end_time - session.start_time
	session.chapter_end = current_chapter

	-- Handle clock skew
	if session.duration < 0 then
		session.duration = 0
	end

	-- Update total time
	data.total_time = data.total_time + session.duration

	-- Save
	save_sessions(slug, data)

	-- Clear from memory
	active_sessions[slug] = nil

	return session.duration
end

function M.update_active_session(slug)
	if not config.enabled then
		return
	end

	local target_slug = slug
	if not target_slug then
		-- Update all active sessions
		for s, _ in pairs(active_sessions) do
			M.update_active_session(s)
		end
		return
	end

	local session_id = active_sessions[target_slug]
	if not session_id then
		return -- No active session
	end

	-- Load sessions
	local data = load_sessions(target_slug)

	-- Find the session
	local session = nil
	for _, s in ipairs(data.sessions) do
		if s.id == session_id then
			session = s
			break
		end
	end

	if not session then
		return
	end

	-- Get current chapter from context
	local ctx = require("ink.ui.context")
	local current_chapter = ctx.ctx.chapter_idx or session.chapter_start

	-- Update duration (without setting end_time)
	session.duration = os.time() - session.start_time
	session.chapter_end = current_chapter

	-- Handle clock skew
	if session.duration < 0 then
		session.duration = 0
	end

	-- Save
	save_sessions(target_slug, data)
end

function M.has_active_session(slug)
	return active_sessions[slug] ~= nil
end

-- === QUERY FUNCTIONS ===

function M.get_total_reading_time(slug)
	if not config.enabled then
		return 0
	end

	if slug then
		-- Single book
		local data = load_sessions(slug)
		return math.floor(data.total_time / 60) -- Return minutes
	else
		-- Global (all books)
		local library = require("ink.library")
		local books = library.get_books()
		local total = 0

		for _, book in ipairs(books) do
			local data = load_sessions(book.slug)
			total = total + data.total_time
		end

		return math.floor(total / 60) -- Return minutes
	end
end

function M.get_reading_by_day(days_back, slug)
	if not config.enabled then
		return {}
	end

	days_back = days_back or 90
	local result = {}

	-- Calculate start date
	local today = os.time()
	local start_ts = today - (days_back * 86400)
	local start_date = os.date("%Y-%m-%d", start_ts)

	local books_to_process = {}
	if slug then
		table.insert(books_to_process, slug)
	else
		-- All books
		local library = require("ink.library")
		local books = library.get_books()
		for _, book in ipairs(books) do
			table.insert(books_to_process, book.slug)
		end
	end

	-- Aggregate sessions by date
	for _, book_slug in ipairs(books_to_process) do
		local data = load_sessions(book_slug)
		for _, session in ipairs(data.sessions) do
			if session.date >= start_date then
				local minutes = math.floor(session.duration / 60)
				result[session.date] = (result[session.date] or 0) + minutes
			end
		end
	end

	return result
end

function M.calculate_streak()
	if not config.enabled then
		return 0, 0
	end

	-- Get all dates with reading activity
	local reading_data = M.get_reading_by_day(365, nil)

	-- Extract and sort dates
	local dates = {}
	for date, _ in pairs(reading_data) do
		table.insert(dates, date)
	end
	table.sort(dates, function(a, b)
		return a > b
	end) -- Descending order

	if #dates == 0 then
		return 0, 0
	end

	-- Calculate current streak
	local today = get_current_date()
	local yesterday = os.date("%Y-%m-%d", os.time() - 86400)

	local current_streak = 0
	local current_date = today

	-- Start from today or yesterday (grace period)
	local has_reading_today = reading_data[today] ~= nil
	if not has_reading_today and config.grace_period > 0 then
		-- Check if had reading yesterday
		if reading_data[yesterday] then
			current_date = yesterday
		else
			-- Streak is broken
			return 0, M.calculate_longest_streak(dates, reading_data)
		end
	end

	-- Count consecutive days backwards
	while reading_data[current_date] do
		current_streak = current_streak + 1
		local ts = parse_date(current_date)
		if not ts then
			break
		end
		current_date = os.date("%Y-%m-%d", ts - 86400) -- Previous day
	end

	-- Calculate longest streak
	local longest_streak = M.calculate_longest_streak(dates, reading_data)

	return current_streak, math.max(current_streak, longest_streak)
end

function M.calculate_longest_streak(dates, reading_data)
	if #dates == 0 then
		return 0
	end

	local longest = 0
	local current = 0
	local prev_ts = nil

	for _, date in ipairs(dates) do
		local ts = parse_date(date)
		if not ts then
			goto continue
		end

		if prev_ts then
			local diff_days = math.floor((prev_ts - ts) / 86400)
			if diff_days == 1 then
				-- Consecutive day
				current = current + 1
			else
				-- Gap detected
				longest = math.max(longest, current)
				current = 1
			end
		else
			current = 1
		end

		prev_ts = ts
		::continue::
	end

	longest = math.max(longest, current)
	return longest
end

function M.get_sessions(slug)
	if not config.enabled then
		return {}
	end

	local data = load_sessions(slug)
	return data.sessions
end

function M.get_sessions_range(slug, start_date, end_date)
	if not config.enabled then
		return {}
	end

	local data = load_sessions(slug)
	local result = {}

	for _, session in ipairs(data.sessions) do
		if session.date >= start_date and session.date <= end_date then
			table.insert(result, session)
		end
	end

	return result
end

-- === MAINTENANCE FUNCTIONS ===

function M.cleanup_old_sessions(days)
	if not config.enabled then
		return
	end

	days = days or config.cleanup_after_days
	if days == 0 then
		return -- Cleanup disabled
	end

	local cutoff_date = os.date("%Y-%m-%d", os.time() - (days * 86400))

	local library = require("ink.library")
	local books = library.get_books()

	for _, book in ipairs(books) do
		local data = load_sessions(book.slug)
		local new_sessions = {}
		local removed_time = 0

		for _, session in ipairs(data.sessions) do
			if session.date >= cutoff_date then
				table.insert(new_sessions, session)
			else
				removed_time = removed_time + session.duration
			end
		end

		if #new_sessions < #data.sessions then
			data.sessions = new_sessions
			data.total_time = data.total_time - removed_time
			save_sessions(book.slug, data)
		end
	end
end

function M.recalculate_totals(slug)
	if not config.enabled then
		return
	end

	local data = load_sessions(slug)
	local total = 0

	for _, session in ipairs(data.sessions) do
		total = total + (session.duration or 0)
	end

	data.total_time = total
	save_sessions(slug, data)
end

function M.get_statistics()
	if not config.enabled then
		return {
			total_books_tracked = 0,
			total_reading_time = 0,
			total_sessions = 0,
			current_streak = 0,
			longest_streak = 0,
		}
	end

	local library = require("ink.library")
	local books = library.get_books()

	local total_sessions = 0
	local total_time = 0

	for _, book in ipairs(books) do
		local data = load_sessions(book.slug)
		total_sessions = total_sessions + #data.sessions
		total_time = total_time + data.total_time
	end

	local current_streak, longest_streak = M.calculate_streak()

	return {
		total_books_tracked = #books,
		total_reading_time = math.floor(total_time / 60), -- minutes
		total_sessions = total_sessions,
		current_streak = current_streak,
		longest_streak = longest_streak,
	}
end

-- === RESET FUNCTIONS ===

function M.reset_statistics(slug)
	if not config.enabled then
		return false
	end

	-- End active session if exists
	if active_sessions[slug] then
		M.end_session(slug)
	end

	-- Reset sessions data
	local data = {
		sessions = {},
		total_time = 0,
		last_session = nil,
	}

	-- Save to file
	local success = save_sessions(slug, data)

	if success then
		vim.notify("Reading statistics reset for book", vim.log.levels.INFO)
	end

	return success
end

function M.reset_all_statistics()
	if not config.enabled then
		return false
	end

	-- End all active sessions first
	for slug, _ in pairs(active_sessions) do
		M.end_session(slug)
	end

	local library = require("ink.library")
	local books = library.get_books()

	local count = 0
	for _, book in ipairs(books) do
		if M.reset_statistics(book.slug) then
			count = count + 1
		end
	end

	vim.notify(string.format("Reset statistics for %d books", count), vim.log.levels.INFO)

	return true
end

-- === CONFIGURATION ===

function M.setup(opts)
	config = vim.tbl_deep_extend("force", config, opts or {})
end

function M.get_config()
	return config
end

return M
