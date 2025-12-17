-- lua/ink/dashboard/stats_dashboard.lua
-- Statistics-focused dashboard

local M = {}

local state = {
	buffer = nil,
	data = {},
}

-- Show stats dashboard
function M.show()
	-- Create buffer
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, "ink://dashboard/stats")

	-- Buffer options
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(buf, "swapfile", false)
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
	vim.api.nvim_buf_set_option(buf, "filetype", "ink-dashboard")

	-- Show in current window
	local win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(win, buf)

	-- Store state
	state.buffer = buf

	-- Load data and render
	M.load_data()
	M.render()

	-- Setup keymaps
	M.setup_keymaps(buf)

	-- Setup autocmds
	M.setup_autocmds(buf)
end

-- Load statistics data
function M.load_data()
	local library = require("ink.library")
	local sessions = require("ink.reading_sessions")
	local collections = require("ink.collections")

	local books = library.get_books()

	-- Reading statistics
	local total_books = #books
	local completed = 0
	local reading = 0
	local to_read = 0

	for _, book in ipairs(books) do
		if book.status == "completed" then
			completed = completed + 1
		elseif book.status == "reading" then
			reading = reading + 1
		elseif book.status == "to-read" then
			to_read = to_read + 1
		end
	end

	-- Time statistics
	local total_time = sessions.get_total_reading_time()
	local week_sessions = sessions.get_reading_by_day(7)
	local month_sessions = sessions.get_reading_by_day(30)

	local week_time = 0
	for _, session in ipairs(week_sessions) do
		week_time = week_time + (session.duration or 0)
	end

	local month_time = 0
	for _, session in ipairs(month_sessions) do
		month_time = month_time + (session.duration or 0)
	end

	-- Calculate daily average (last 30 days)
	local daily_avg = month_sessions and #month_sessions > 0 and (month_time / 30) or 0

	-- Progress statistics
	local total_chapters = 0
	local current_chapters = 0
	for _, book in ipairs(books) do
		if book.total_chapters and book.total_chapters > 0 then
			total_chapters = total_chapters + book.total_chapters
			current_chapters = current_chapters + (book.chapter or 1)
		end
	end
	local overall_completion = total_chapters > 0 and math.floor((current_chapters / total_chapters) * 100) or 0

	-- Collections
	local all_collections = collections.get_all() or {}
	local collection_stats = {}
	for _, coll in ipairs(all_collections) do
		table.insert(collection_stats, {
			name = coll.name,
			count = #(coll.books or {}),
		})
	end
	-- Sort by count descending
	table.sort(collection_stats, function(a, b)
		return a.count > b.count
	end)

	state.data = {
		total_books = total_books,
		completed = completed,
		reading = reading,
		to_read = to_read,
		total_time = total_time,
		week_time = week_time,
		month_time = month_time,
		daily_avg = daily_avg,
		overall_completion = overall_completion,
		collections = collection_stats,
	}
end

-- Render dashboard
function M.render()
	if not state.buffer or not vim.api.nvim_buf_is_valid(state.buffer) then
		return
	end

	local lines = {}
	local win_width = vim.api.nvim_win_get_width(0)

	-- Title
	local title = "Ink.Nvim"
	local title_padding = math.floor((win_width - #title) / 2)
	table.insert(lines, string.rep(" ", title_padding) .. title)

	-- Subtitle
	local subtitle = "Statistics"
	local subtitle_padding = math.floor((win_width - #subtitle) / 2)
	table.insert(lines, string.rep(" ", subtitle_padding) .. subtitle)
	table.insert(lines, "")

	-- Calculate box width
	local box_width = math.min(win_width - 4, 120)
	local box_padding = math.floor((win_width - box_width) / 2)
	local box_prefix = string.rep(" ", box_padding)

	-- Reading Statistics box
	M.render_reading_stats(lines, box_width, box_prefix)
	table.insert(lines, "")

	-- Time Statistics box
	M.render_time_stats(lines, box_width, box_prefix)
	table.insert(lines, "")

	-- Progress box
	M.render_progress(lines, box_width, box_prefix)
	table.insert(lines, "")

	-- Collections box
	M.render_collections(lines, box_width, box_prefix)

	-- Help
	table.insert(lines, "")
	local help = "s library    r refresh    q quit"
	local help_padding = math.floor((win_width - vim.fn.strwidth(help)) / 2)
	table.insert(lines, string.rep(" ", help_padding) .. help)

	-- Set buffer content
	vim.api.nvim_buf_set_option(state.buffer, "modifiable", true)
	vim.api.nvim_buf_set_lines(state.buffer, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(state.buffer, "modifiable", false)
end

-- Render reading statistics box
function M.render_reading_stats(lines, box_width, box_prefix)
	-- Top border
	table.insert(lines, box_prefix .. "┌" .. string.rep("─", box_width - 2) .. "┐")

	-- Header
	table.insert(lines, box_prefix .. "│READING STATISTICS" .. string.rep(" ", box_width - 2 - 18) .. "│")

	-- Empty line
	table.insert(lines, box_prefix .. "│" .. string.rep(" ", box_width - 2) .. "│")

	-- Stats in 4 columns
	local col_width = math.floor((box_width - 2) / 4)
	local stats = {
		{ value = tostring(state.data.total_books), label = "Total Books" },
		{ value = tostring(state.data.completed), label = "Completed" },
		{ value = tostring(state.data.reading), label = "In Progress" },
		{ value = tostring(state.data.to_read), label = "Not Started" },
	}

	-- Values line
	local values_line = "│"
	for _, stat in ipairs(stats) do
		local padding = math.floor((col_width - vim.fn.strwidth(stat.value)) / 2)
		values_line = values_line .. string.rep(" ", padding) .. stat.value .. string.rep(" ", col_width - padding - vim.fn.strwidth(stat.value))
	end
	table.insert(lines, box_prefix .. values_line .. "│")

	-- Labels line
	local labels_line = "│"
	for _, stat in ipairs(stats) do
		local padding = math.floor((col_width - vim.fn.strwidth(stat.label)) / 2)
		labels_line = labels_line .. string.rep(" ", padding) .. stat.label .. string.rep(" ", col_width - padding - vim.fn.strwidth(stat.label))
	end
	table.insert(lines, box_prefix .. labels_line .. "│")

	-- Bottom border
	table.insert(lines, box_prefix .. "└" .. string.rep("─", box_width - 2) .. "┘")
end

-- Render time statistics box
function M.render_time_stats(lines, box_width, box_prefix)
	local text_utils = require("ink.dashboard.utils.text")

	-- Top border
	table.insert(lines, box_prefix .. "┌" .. string.rep("─", box_width - 2) .. "┐")

	-- Header
	table.insert(lines, box_prefix .. "│TIME STATISTICS" .. string.rep(" ", box_width - 2 - 15) .. "│")

	-- Empty line
	table.insert(lines, box_prefix .. "│" .. string.rep(" ", box_width - 2) .. "│")

	-- Stats in 4 columns
	local col_width = math.floor((box_width - 2) / 4)
	local stats = {
		{ value = text_utils.format_time(state.data.total_time), label = "Total Reading Time" },
		{ value = text_utils.format_time(state.data.week_time), label = "This Week" },
		{ value = text_utils.format_time(state.data.month_time), label = "This Month" },
		{ value = text_utils.format_time(state.data.daily_avg), label = "Daily Average" },
	}

	-- Values line
	local values_line = "│"
	for _, stat in ipairs(stats) do
		local padding = math.floor((col_width - vim.fn.strwidth(stat.value)) / 2)
		values_line = values_line .. string.rep(" ", padding) .. stat.value .. string.rep(" ", col_width - padding - vim.fn.strwidth(stat.value))
	end
	table.insert(lines, box_prefix .. values_line .. "│")

	-- Labels line
	local labels_line = "│"
	for _, stat in ipairs(stats) do
		local padding = math.floor((col_width - vim.fn.strwidth(stat.label)) / 2)
		labels_line = labels_line .. string.rep(" ", padding) .. stat.label .. string.rep(" ", col_width - padding - vim.fn.strwidth(stat.label))
	end
	table.insert(lines, box_prefix .. labels_line .. "│")

	-- Bottom border
	table.insert(lines, box_prefix .. "└" .. string.rep("─", box_width - 2) .. "┘")
end

-- Render progress box
function M.render_progress(lines, box_width, box_prefix)
	-- Top border
	table.insert(lines, box_prefix .. "┌" .. string.rep("─", box_width - 2) .. "┐")

	-- Header
	table.insert(lines, box_prefix .. "│PROGRESS" .. string.rep(" ", box_width - 2 - 8) .. "│")

	-- Empty line
	table.insert(lines, box_prefix .. "│" .. string.rep(" ", box_width - 2) .. "│")

	-- Overall Completion
	local completion_text = "Overall Completion"
	local completion_line = "│" .. completion_text .. string.rep(" ", box_width - 2 - vim.fn.strwidth(completion_text)) .. "│"
	table.insert(lines, box_prefix .. completion_line)

	-- Progress bar
	local bar_width = box_width - 10
	local filled = math.floor((state.data.overall_completion / 100) * bar_width)
	local empty = bar_width - filled
	local bar = "│  " .. string.rep("█", filled) .. string.rep("░", empty) .. "  " .. state.data.overall_completion .. "%│"
	table.insert(lines, box_prefix .. bar)

	-- Empty line
	table.insert(lines, box_prefix .. "│" .. string.rep(" ", box_width - 2) .. "│")

	-- Pages Read placeholder
	local pages_text = "Pages Read"
	local pages_value = "N/A"
	local pages_line = "│" .. pages_text .. string.rep(" ", box_width - 2 - vim.fn.strwidth(pages_text) - vim.fn.strwidth(pages_value)) .. pages_value .. "│"
	table.insert(lines, box_prefix .. pages_line)

	-- Bottom border
	table.insert(lines, box_prefix .. "└" .. string.rep("─", box_width - 2) .. "┘")
end

-- Render collections box
function M.render_collections(lines, box_width, box_prefix)
	-- Top border
	table.insert(lines, box_prefix .. "┌" .. string.rep("─", box_width - 2) .. "┐")

	-- Header
	table.insert(lines, box_prefix .. "│COLLECTIONS" .. string.rep(" ", box_width - 2 - 11) .. "│")

	-- Empty line
	table.insert(lines, box_prefix .. "│" .. string.rep(" ", box_width - 2) .. "│")

	-- Collections (limit to 6)
	local max_collections = 6
	for i = 1, math.min(max_collections, #state.data.collections) do
		local coll = state.data.collections[i]
		local count_text = coll.count .. " books"
		local name_width = box_width - 2 - vim.fn.strwidth(count_text) - 4
		local name = coll.name
		if vim.fn.strwidth(name) > name_width then
			name = name:sub(1, name_width - 3) .. "..."
		end
		local spacing = box_width - 2 - vim.fn.strwidth(name) - vim.fn.strwidth(count_text) - 2
		local line = "│ " .. name .. string.rep(" ", spacing) .. count_text .. " │"
		table.insert(lines, box_prefix .. line)
	end

	-- Fill empty lines if less than max
	for i = #state.data.collections + 1, max_collections do
		table.insert(lines, box_prefix .. "│" .. string.rep(" ", box_width - 2) .. "│")
	end

	-- Bottom border
	table.insert(lines, box_prefix .. "└" .. string.rep("─", box_width - 2) .. "┘")
end

-- Setup keymaps
function M.setup_keymaps(buf)
	local opts = { noremap = true, silent = true, buffer = buf }

	-- Toggle back to library
	vim.keymap.set("n", "s", function()
		local library_dashboard = require("ink.dashboard.library_dashboard")
		library_dashboard.show()
	end, opts)

	-- Refresh
	vim.keymap.set("n", "r", function()
		M.load_data()
		M.render()
		vim.notify("Dashboard Reloaded", vim.log.levels.INFO)
	end, opts)

	-- Quit
	vim.keymap.set("n", "q", function()
		vim.api.nvim_buf_delete(buf, { force = true })
	end, opts)
end

-- Setup autocmds
function M.setup_autocmds(buf)
	local group = vim.api.nvim_create_augroup("InkStatsDashboard", { clear = false })

	vim.api.nvim_create_autocmd("BufDelete", {
		group = group,
		buffer = buf,
		callback = function()
			state.buffer = nil
		end,
	})
end

return M
