-- lua/ink/dashboard/widgets/library.lua
-- Library widget with collection toggle

local base = require("ink.dashboard.widgets.base")
local box_drawing = require("ink.dashboard.utils.box_drawing")
local text_utils = require("ink.dashboard.utils.text")

local M = {}

-- Create a new library widget
-- @param opts: table - Widget options
-- @return widget: table
function M.new(opts)
	local widget = base.new({
		id = opts.id,
		type = "library",
		title = opts.title or "📚 Library",
		width = opts.width or 40,
		height = opts.height or 12,
		row = opts.row,
		col = opts.col,
		opts = opts.opts or {},
		render = M.render,
		update = M.update,
		on_select = M.on_select,
		get_highlights = M.get_highlights,
	})

	widget.data = {
		total_books = 0,
		completed = 0,
		reading = 0,
		to_read = 0,
		collections = {},
		selected_collection = nil, -- nil = "All Books"
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

	-- Fetch data from library
	local library = require("ink.library")
	local collections = require("ink.collections")

	local books = library.get_books()
	self.data.total_books = #books

	-- Count by status
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

	self.data.completed = completed
	self.data.reading = reading
	self.data.to_read = to_read

	-- Get all collections
	self.data.collections = collections.list() or {}
end

-- Render widget
-- @param self: table - Widget instance
-- @return lines: string[]
function M:render()
	local lines = box_drawing.create_box(self.width, self.height, self.title)
	local inner_width = self.width - 2

	local line_idx = 2

	-- Collection selector line
	local collection_name = self.data.selected_collection or "All Books"
	local selector_line = string.format("  [%s] ↓", collection_name)
	selector_line = box_drawing.truncate_text(selector_line, inner_width - 2)
	lines[line_idx] = "│" .. box_drawing.pad_text(selector_line, inner_width, "left") .. "│"
	line_idx = line_idx + 1

	-- Separator
	if line_idx < self.height then
		lines[line_idx] = box_drawing.create_separator(self.width)
		line_idx = line_idx + 1
	end

	-- Statistics
	local stats = {
		string.format("📖 Total: %d", self.data.total_books),
		string.format("✓ Completed: %d", self.data.completed),
		string.format("⏳ Reading: %d", self.data.reading),
		string.format("📚 To Read: %d", self.data.to_read),
	}

	for _, stat in ipairs(stats) do
		if line_idx >= self.height then
			break
		end

		local padded = box_drawing.pad_text("  " .. stat, inner_width, "left")
		lines[line_idx] = "│" .. padded .. "│"
		line_idx = line_idx + 1
	end

	-- Add separator before collections list
	if line_idx < self.height - 1 and #self.data.collections > 0 then
		lines[line_idx] = "│" .. string.rep(" ", inner_width) .. "│"
		line_idx = line_idx + 1
	end

	-- Show available collections (limit to remaining space)
	if #self.data.collections > 0 then
		local remaining_lines = self.height - line_idx - 1

		for i = 1, math.min(#self.data.collections, remaining_lines) do
			local collection = self.data.collections[i]
			local book_count = #(collection.books or {})
			local coll_line = string.format("  • %s (%d)", collection.name, book_count)
			coll_line = box_drawing.truncate_text(coll_line, inner_width - 2)

			lines[line_idx] = "│" .. box_drawing.pad_text(coll_line, inner_width, "left") .. "│"
			line_idx = line_idx + 1
		end
	end

	return lines
end

-- Handle selection (toggle collections)
-- @param self: table - Widget instance
-- @param line_offset: number - Line offset within widget
-- @return action: table|nil
function M:on_select(line_offset)
	-- Line 1 is the collection selector
	if line_offset == 1 then
		return {
			type = "toggle_collection",
			widget = self,
		}
	end

	-- Check if clicking on a collection in the list
	local collections_start_line = 6 -- After stats
	local collection_idx = line_offset - collections_start_line

	if collection_idx >= 0 and collection_idx < #self.data.collections then
		local collection = self.data.collections[collection_idx + 1]
		return {
			type = "select_collection",
			widget = self,
			collection = collection,
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
