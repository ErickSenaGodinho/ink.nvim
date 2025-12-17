-- lua/ink/dashboard/utils/box_drawing.lua
-- Box drawing utilities for dashboard widgets

local M = {}

-- Box drawing characters
M.chars = {
	corner_tl = "┌",
	corner_tr = "┐",
	corner_bl = "└",
	corner_br = "┘",
	horizontal = "─",
	vertical = "│",
	sep_left = "├",
	sep_right = "┤",
	sep_horizontal = "─",
}

-- Create a box with title
-- @param width: number - Total width including borders
-- @param height: number - Total height including borders
-- @param title: string|nil - Optional title
-- @return lines: string[]
function M.create_box(width, height, title)
	local lines = {}
	local inner_width = width - 2

	-- Top border
	local top_line = M.chars.corner_tl
	if title then
		local title_text = " " .. title .. " "
		local remaining = inner_width - #title_text
		if remaining > 0 then
			top_line = top_line
				.. title_text
				.. string.rep(M.chars.horizontal, remaining)
				.. M.chars.corner_tr
		else
			-- Title too long, truncate
			title_text = title_text:sub(1, inner_width)
			top_line = top_line .. title_text .. M.chars.corner_tr
		end
	else
		top_line = top_line .. string.rep(M.chars.horizontal, inner_width) .. M.chars.corner_tr
	end
	table.insert(lines, top_line)

	-- Middle lines (empty)
	for i = 2, height - 1 do
		table.insert(lines, M.chars.vertical .. string.rep(" ", inner_width) .. M.chars.vertical)
	end

	-- Bottom border
	table.insert(
		lines,
		M.chars.corner_bl .. string.rep(M.chars.horizontal, inner_width) .. M.chars.corner_br
	)

	return lines
end

-- Create horizontal separator line
-- @param width: number - Total width including borders
-- @return line: string
function M.create_separator(width)
	local inner_width = width - 2
	return M.chars.sep_left .. string.rep(M.chars.sep_horizontal, inner_width) .. M.chars.sep_right
end

-- Pad text to specific width with alignment
-- @param text: string - Text to pad
-- @param width: number - Target width
-- @param align: string - "left", "center", or "right"
-- @return padded: string
function M.pad_text(text, width, align)
	align = align or "left"
	local text_len = vim.fn.strwidth(text)

	if text_len >= width then
		return text:sub(1, width)
	end

	local padding = width - text_len

	if align == "center" then
		local left_pad = math.floor(padding / 2)
		local right_pad = padding - left_pad
		return string.rep(" ", left_pad) .. text .. string.rep(" ", right_pad)
	elseif align == "right" then
		return string.rep(" ", padding) .. text
	else -- left
		return text .. string.rep(" ", padding)
	end
end

-- Truncate text if too long
-- @param text: string - Text to truncate
-- @param max_width: number - Maximum width
-- @return truncated: string
function M.truncate_text(text, max_width)
	local text_len = vim.fn.strwidth(text)
	if text_len <= max_width then
		return text
	end

	if max_width <= 3 then
		return text:sub(1, max_width)
	end

	return text:sub(1, max_width - 3) .. "..."
end

return M
