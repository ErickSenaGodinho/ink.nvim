-- lua/ink/dashboard/widgets/recent.lua
-- Recent books widget for dashboard

local base = require("ink.dashboard.widgets.base")
local box_drawing = require("ink.dashboard.utils.box_drawing")
local text_utils = require("ink.dashboard.utils.text")

local M = {}

-- Create a new recent books widget
-- @param opts: table - Widget options
-- @return widget: table
function M.new(opts)
	local widget = base.new({
		id = opts.id,
		type = "recent",
		title = opts.title or "📚 Recent Books",
		width = opts.width or 57,
		height = opts.height or 12,
		row = opts.row,
		col = opts.col,
		opts = opts.opts or { limit = 5 },
		render = M.render,
		update = M.update,
		on_select = M.on_select,
		get_highlights = M.get_highlights,
	})

	widget.data = {
		books = {},
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

	-- Fetch recent books from library
	local library = require("ink.library")
	local all_books = library.get_books()

	-- Get limit from opts
	local limit = self.opts.limit or 5

	-- Take only the first N books (already sorted by last_opened desc)
	local recent = {}
	for i = 1, math.min(limit, #all_books) do
		table.insert(recent, all_books[i])
	end

	self.data.books = recent
end

-- Render widget
-- @param self: table - Widget instance
-- @return lines: string[]
function M:render()
	local lines = box_drawing.create_box(self.width, self.height, self.title)

	local inner_width = self.width - 2

	-- Render each book
	local line_idx = 2
	for i, book in ipairs(self.data.books) do
		if line_idx >= self.height then
			break
		end

		-- Book number and title line
		local title = box_drawing.truncate_text(book.title or "Unknown", inner_width - 8)
		local title_line = string.format("  [%d] %s", i, title)
		lines[line_idx] = "│" .. box_drawing.pad_text(title_line, inner_width, "left") .. "│"
		line_idx = line_idx + 1

		if line_idx >= self.height then
			break
		end

		-- Author line
		local author = box_drawing.truncate_text("      by " .. (book.author or "Unknown"), inner_width - 2)
		lines[line_idx] = "│" .. box_drawing.pad_text(author, inner_width, "left") .. "│"
		line_idx = line_idx + 1

		if line_idx >= self.height then
			break
		end

		-- Progress and last opened line
		local progress_text = ""
		if book.total_chapters and book.total_chapters > 0 then
			local current = book.chapter or 1
			local percent = math.floor((current / book.total_chapters) * 100)
			progress_text = string.format("%d%% • ", percent)
		end

		local last_opened = text_utils.format_date(book.last_opened)
		local info_line = string.format("      %s%s", progress_text, last_opened)
		lines[line_idx] = "│" .. box_drawing.pad_text(info_line, inner_width, "left") .. "│"
		line_idx = line_idx + 1

		-- Empty separator line (if not last book)
		if line_idx < self.height - 1 and i < #self.data.books then
			lines[line_idx] = "│" .. string.rep(" ", inner_width) .. "│"
			line_idx = line_idx + 1
		end
	end

	return lines
end

-- Handle selection (open book)
-- @param self: table - Widget instance
-- @param line_offset: number - Line offset within widget
-- @return action: table|nil
function M:on_select(line_offset)
	-- Calculate which book was selected
	-- Each book takes 4 lines: title, author, info, separator (or 3 if last)
	-- Line offset 1 = first line after box border
	local book_idx = math.floor((line_offset - 1) / 4) + 1

	if book_idx > 0 and book_idx <= #self.data.books then
		local book = self.data.books[book_idx]
		return {
			type = "open_book",
			path = book.path,
		}
	end

	return nil
end

-- Get highlights for widget
-- @param self: table - Widget instance
-- @return highlights: table[]
function M:get_highlights()
	return {}
end

return M
