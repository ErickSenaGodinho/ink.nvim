-- lua/ink/dashboard/widgets/base.lua
-- Base widget interface

local M = {}

-- Create a new widget instance
-- @param opts: table - Widget options
-- @return widget: table
function M.new(opts)
	local widget = {
		-- Metadata
		id = opts.id or "widget-" .. tostring(math.random(10000, 99999)),
		type = opts.type or "base",
		title = opts.title or "Widget",
		width = opts.width or 40,
		height = opts.height or 10,
		row = opts.row or 0,
		col = opts.col or 0,
		opts = opts.opts or {},
		state = {},
	}

	-- Methods that must be implemented by subclasses
	widget.render = opts.render
		or function(self)
			return { "Base widget - override render() method" }
		end

	widget.update = opts.update or function(self, data) end

	widget.on_cursor_enter = opts.on_cursor_enter or function(self) end

	widget.on_select = opts.on_select or function(self, line_offset)
		return nil
	end

	widget.get_highlights = opts.get_highlights or function(self)
		return {}
	end

	return widget
end

return M
