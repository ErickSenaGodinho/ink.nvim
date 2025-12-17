-- lua/ink/dashboard/utils/text.lua
-- Text formatting utilities

local M = {}

-- Format time in minutes to human readable string
-- @param minutes: number - Time in minutes
-- @return formatted: string - "2h 30m" or "45m"
function M.format_time(minutes)
	if minutes < 60 then
		return string.format("%dm", minutes)
	end

	local hours = math.floor(minutes / 60)
	local mins = minutes % 60

	if mins == 0 then
		return string.format("%dh", hours)
	end

	return string.format("%dh %dm", hours, mins)
end

-- Format date/timestamp relative to now
-- @param timestamp: number - Unix timestamp
-- @return formatted: string - "2 days ago", "3 weeks ago"
function M.format_date(timestamp)
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
		return days .. " day" .. (days > 1 and "s" or "") .. " ago"
	elseif diff < 2592000 then
		local weeks = math.floor(diff / 604800)
		return weeks .. " week" .. (weeks > 1 and "s" or "") .. " ago"
	else
		return os.date("%Y-%m-%d", timestamp)
	end
end

-- Get visual width of string (handles multi-byte characters)
-- @param str: string
-- @return width: number
function M.visual_width(str)
	return vim.fn.strwidth(str)
end

-- Fit string to width (truncate or pad)
-- @param str: string
-- @param width: number
-- @param align: string - "left", "center", "right"
-- @return fitted: string
function M.fit_string(str, width, align)
	align = align or "left"
	local str_width = M.visual_width(str)

	if str_width > width then
		-- Truncate
		if width <= 3 then
			return str:sub(1, width)
		end
		return str:sub(1, width - 3) .. "..."
	elseif str_width < width then
		-- Pad
		local padding = width - str_width
		if align == "center" then
			local left_pad = math.floor(padding / 2)
			local right_pad = padding - left_pad
			return string.rep(" ", left_pad) .. str .. string.rep(" ", right_pad)
		elseif align == "right" then
			return string.rep(" ", padding) .. str
		else
			return str .. string.rep(" ", padding)
		end
	end

	return str
end

-- Word wrap text to max width
-- @param text: string
-- @param max_width: number
-- @return lines: string[]
function M.word_wrap(text, max_width)
	local lines = {}
	local current_line = ""

	for word in text:gmatch("%S+") do
		if #current_line == 0 then
			current_line = word
		elseif #current_line + #word + 1 <= max_width then
			current_line = current_line .. " " .. word
		else
			table.insert(lines, current_line)
			current_line = word
		end
	end

	if #current_line > 0 then
		table.insert(lines, current_line)
	end

	return lines
end

return M
