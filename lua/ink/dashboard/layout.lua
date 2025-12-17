-- lua/ink/dashboard/layout.lua
-- Layout engine for dashboard widgets

local M = {}

-- Create a new layout instance
-- @param opts: table - Layout options
-- @return layout: table
function M.new(opts)
	local layout = {
		widgets = {},
		buffer = nil,
		total_width = 0,
		total_height = 0,
		type = opts.type or "grid",
		columns = opts.columns or 2,
		padding = opts.padding or 2,
		current_row = 0,
		current_col = 0,
		column_widths = {},
	}

	setmetatable(layout, { __index = M })
	return layout
end

-- Add a widget to the layout
-- @param widget: table - Widget instance
-- @param position: string|{row, col} - "auto" or explicit position
function M:add_widget(widget, position)
	if position == "auto" then
		local pos = self:calculate_next_position(widget.width, widget.height)
		widget.row = pos.row
		widget.col = pos.col
	else
		widget.row = position.row or 0
		widget.col = position.col or 0
	end

	table.insert(self.widgets, widget)
end

-- Calculate next automatic position for a widget
-- @param width: number - Widget width
-- @param height: number - Widget height
-- @return position: {row, col}
function M:calculate_next_position(width, height)
	if self.type == "grid" then
		return self:calculate_grid_position(width, height)
	else
		-- Custom layout - arrange widgets intelligently
		-- Try to place side-by-side if there's room, otherwise stack vertically
		local pos = { row = self.current_row, col = self.current_col }

		-- Check if this widget can fit on the current row
		local total_width_needed = self.current_col + width

		-- If we're starting at column 0 or if adding this widget would be too wide,
		-- place it on the current row and update current_col
		if self.current_col == 0 or total_width_needed > 140 then
			-- Place at current position
			pos = { row = self.current_row, col = self.current_col }

			-- If current_col is 0, this is the first widget in the row
			-- Move current_col to the right for potential side-by-side placement
			if self.current_col == 0 then
				self.current_col = width + self.padding
				-- Track row height for later
				if not self.row_heights then
					self.row_heights = {}
				end
				self.row_heights[self.current_row] = height
			else
				-- This widget doesn't fit side-by-side, move to next row
				self.current_row = self.current_row + (self.row_heights[self.current_row] or 0) + self.padding
				self.current_col = 0
				pos = { row = self.current_row, col = 0 }
				self.current_col = width + self.padding
				self.row_heights[self.current_row] = height
			end
		else
			-- Place side-by-side
			pos = { row = self.current_row, col = self.current_col }
			self.current_col = self.current_col + width + self.padding
			-- Update row height if this widget is taller
			self.row_heights[self.current_row] = math.max(self.row_heights[self.current_row] or 0, height)
		end

		return pos
	end
end

-- Calculate grid layout position
-- @param width: number - Widget width
-- @param height: number - Widget height
-- @return position: {row, col}
function M:calculate_grid_position(width, height)
	local column_index = (#self.widgets % self.columns) + 1

	-- Track maximum width per column
	if not self.column_widths[column_index] then
		self.column_widths[column_index] = 0
	end
	self.column_widths[column_index] = math.max(self.column_widths[column_index], width)

	-- Calculate column position
	local col = 0
	for i = 1, column_index - 1 do
		col = col + (self.column_widths[i] or 0) + self.padding
	end

	-- If starting new row, move down
	if column_index == 1 and #self.widgets > 0 then
		self.current_row = self.current_row
			+ self:get_max_height_in_row(#self.widgets - self.columns + 1)
			+ self.padding
	end

	return { row = self.current_row, col = col }
end

-- Get maximum widget height in a row
-- @param start_idx: number - Starting widget index for row
-- @return max_height: number
function M:get_max_height_in_row(start_idx)
	local max_height = 0
	local end_idx = math.min(start_idx + self.columns - 1, #self.widgets)

	for i = start_idx, end_idx do
		if self.widgets[i] then
			max_height = math.max(max_height, self.widgets[i].height)
		end
	end

	return max_height
end

-- Render all widgets to buffer
-- @param buf: number - Buffer handle
function M:render_to_buffer(buf)
	self.buffer = buf

	-- Calculate total dimensions
	self:calculate_dimensions()

	-- Create empty buffer as 2D array (for proper positioning)
	local grid = {}
	for row = 1, self.total_height do
		grid[row] = {}
		for col = 1, self.total_width do
			grid[row][col] = " "
		end
	end

	-- Render each widget into the grid
	for _, widget in ipairs(self.widgets) do
		local widget_lines = widget:render()
		self:place_widget_in_grid(grid, widget_lines, widget.row, widget.col)
	end

	-- Convert grid to lines
	local lines = {}
	for row = 1, self.total_height do
		table.insert(lines, table.concat(grid[row]))
	end

	-- Set buffer content
	vim.api.nvim_buf_set_option(buf, "modifiable", true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(buf, "modifiable", false)

	-- Apply highlights
	local ns_id = vim.api.nvim_create_namespace("ink_dashboard")
	vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

	for _, widget in ipairs(self.widgets) do
		local highlights = widget:get_highlights()
		self:apply_widget_highlights(buf, ns_id, highlights, widget.row, widget.col)
	end
end

-- Calculate total layout dimensions
function M:calculate_dimensions()
	local max_row = 0
	local max_col = 0

	for _, widget in ipairs(self.widgets) do
		max_row = math.max(max_row, widget.row + widget.height)
		max_col = math.max(max_col, widget.col + widget.width)
	end

	self.total_width = max_col
	self.total_height = max_row
end

-- Place widget lines into grid
-- @param grid: table[][] - 2D character grid
-- @param widget_lines: string[] - Widget rendered lines
-- @param row: number - Starting row (0-indexed)
-- @param col: number - Starting column (0-indexed)
function M:place_widget_in_grid(grid, widget_lines, row, col)
	for line_offset, widget_line in ipairs(widget_lines) do
		local grid_row = row + line_offset
		if grid_row >= 1 and grid_row <= #grid then
			-- Convert widget line to characters respecting visual width
			local visual_col = col + 1
			local byte_idx = 1

			while byte_idx <= #widget_line do
				-- Get next character (may be multibyte)
				local char = vim.fn.strcharpart(widget_line, vim.fn.strchars(widget_line:sub(1, byte_idx - 1)), 1)
				if char == "" then
					break
				end

				-- Place character in grid
				if visual_col <= #grid[grid_row] then
					grid[grid_row][visual_col] = char
				end

				-- Advance by visual width
				local char_width = vim.fn.strwidth(char)
				visual_col = visual_col + char_width
				byte_idx = byte_idx + #char
			end
		end
	end
end

-- Apply widget highlights to buffer
-- @param buf: number - Buffer handle
-- @param ns_id: number - Namespace ID
-- @param highlights: table[] - Highlight specs
-- @param row_offset: number - Widget row offset
-- @param col_offset: number - Widget column offset
function M:apply_widget_highlights(buf, ns_id, highlights, row_offset, col_offset)
	for _, hl in ipairs(highlights) do
		if hl.line and hl.col_start and hl.col_end and hl.hl_group then
			pcall(
				vim.api.nvim_buf_set_extmark,
				buf,
				ns_id,
				row_offset + hl.line - 1,
				col_offset + hl.col_start,
				{
					end_col = col_offset + hl.col_end,
					hl_group = hl.hl_group,
				}
			)
		end
	end
end

-- Get widget at cursor position
-- @param line: number - Cursor line (1-indexed)
-- @param col: number - Cursor column (0-indexed)
-- @return widget: table|nil, line_offset: number|nil
function M:get_widget_at_cursor(line, col)
	for _, widget in ipairs(self.widgets) do
		local in_row = line >= widget.row + 1 and line < widget.row + widget.height + 1
		local in_col = col >= widget.col and col < widget.col + widget.width

		if in_row and in_col then
			local line_offset = line - widget.row - 1
			return widget, line_offset
		end
	end

	return nil, nil
end

-- Refresh layout (re-render all widgets)
function M:refresh()
	if self.buffer and vim.api.nvim_buf_is_valid(self.buffer) then
		self:render_to_buffer(self.buffer)
	end
end

return M
