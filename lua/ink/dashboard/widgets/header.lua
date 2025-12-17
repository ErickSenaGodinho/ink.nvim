-- lua/ink/dashboard/widgets/header.lua
-- Header widget with title

local base = require("ink.dashboard.widgets.base")

local M = {}

-- Create a new header widget
-- @param opts: table - Widget options
-- @return widget: table
function M.new(opts)
	local widget = base.new({
		id = opts.id,
		type = "header",
		title = opts.title or "Ink.Nvim",
		width = opts.width or 80,
		height = opts.height or 3,
		row = opts.row,
		col = opts.col,
		opts = opts.opts or {},
		render = M.render,
		get_highlights = M.get_highlights,
	})

	return widget
end

-- Render widget
-- @param self: table - Widget instance
-- @return lines: string[]
function M:render()
	local lines = {}

	-- Top border with double lines
	table.insert(lines, "╔" .. string.rep("═", self.width - 2) .. "╗")

	-- Title line (centered)
	local title_text = self.title:upper()
	local padding = self.width - 2 - vim.fn.strwidth(title_text)
	local left_pad = math.floor(padding / 2)
	local right_pad = padding - left_pad

	local title_line = "║" .. string.rep(" ", left_pad) .. title_text .. string.rep(" ", right_pad) .. "║"
	table.insert(lines, title_line)

	-- Bottom border
	table.insert(lines, "╚" .. string.rep("═", self.width - 2) .. "╝")

	return lines
end

-- Get highlights for widget
-- @param self: table - Widget instance
-- @return highlights: table[]
function M:get_highlights()
	-- Highlight the title text
	local title_text = self.title:upper()
	local padding = self.width - 2 - vim.fn.strwidth(title_text)
	local left_pad = math.floor(padding / 2)

	return {
		{
			line = 2,
			col_start = 1 + left_pad,
			col_end = 1 + left_pad + vim.fn.strwidth(title_text),
			hl_group = "InkTitle",
		},
	}
end

return M
