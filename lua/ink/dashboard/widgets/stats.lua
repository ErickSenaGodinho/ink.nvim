-- lua/ink/dashboard/widgets/stats.lua
-- Statistics widget for dashboard

local base = require("ink.dashboard.widgets.base")
local box_drawing = require("ink.dashboard.utils.box_drawing")
local text_utils = require("ink.dashboard.utils.text")

local M = {}

-- Create a new stats widget
-- @param opts: table - Widget options
-- @return widget: table
function M.new(opts)
	local widget = base.new({
		id = opts.id,
		type = "stats",
		title = opts.title or "📊 Statistics",
		width = opts.width or 40,
		height = opts.height or 8,
		row = opts.row,
		col = opts.col,
		opts = opts.opts or {},
		render = M.render,
		update = M.update,
		get_highlights = M.get_highlights,
	})

	widget.data = {
		total_books = 0,
		completed = 0,
		reading = 0,
		reading_time_today = 0,
		reading_time_week = 0,
		streak = 0,
	}

	return widget
end

-- Update widget data
-- @param self: table - Widget instance
-- @param data: table|nil - Optional data to update
function M:update(data)
	if data then
		self.data = vim.tbl_extend("force", self.data, data)
		return
	end

	-- Fetch fresh data from library and reading sessions
	local library = require("ink.library")
	local sessions = require("ink.reading_sessions")

	local books = library.get_books()
	self.data.total_books = #books

	-- Count by status
	local completed = 0
	local reading = 0
	for _, book in ipairs(books) do
		if book.status == "completed" then
			completed = completed + 1
		elseif book.status == "reading" then
			reading = reading + 1
		end
	end
	self.data.completed = completed
	self.data.reading = reading

	-- Get reading time statistics
	local today_sessions = sessions.get_reading_by_day(1)
	local week_sessions = sessions.get_reading_by_day(7)

	local today_time = 0
	for _, session in ipairs(today_sessions) do
		today_time = today_time + (session.duration or 0)
	end

	local week_time = 0
	for _, session in ipairs(week_sessions) do
		week_time = week_time + (session.duration or 0)
	end

	self.data.reading_time_today = today_time
	self.data.reading_time_week = week_time

	-- Get streak
	self.data.streak = sessions.calculate_streak()
end

-- Render widget
-- @param self: table - Widget instance
-- @return lines: string[]
function M:render()
	local lines = box_drawing.create_box(self.width, self.height, self.title)

	-- Build stat lines
	local stats = {
		string.format("📚 Total Books: %d", self.data.total_books),
		string.format("✅ Completed: %d", self.data.completed),
		string.format("📖 Reading: %d", self.data.reading),
		"",
		string.format("⏱️  Today: %s", text_utils.format_time(self.data.reading_time_today)),
		string.format("📅 This Week: %s", text_utils.format_time(self.data.reading_time_week)),
		string.format("🔥 Streak: %d days", self.data.streak),
	}

	-- Insert stats into box (starting at line 2, after top border)
	local inner_width = self.width - 2
	for i, stat in ipairs(stats) do
		local line_idx = i + 1
		if line_idx < self.height then
			local padded = box_drawing.pad_text(stat, inner_width, "left")
			lines[line_idx] = "│" .. padded .. "│"
		end
	end

	return lines
end

-- Get highlights for widget
-- @param self: table - Widget instance
-- @return highlights: table[]
function M:get_highlights()
	return {}
end

return M
