-- lua/ink/utils.lua
-- General utility functions for ink.nvim

local M = {}

--- Check if the current buffer/window is empty and can be reused
--- A buffer is considered reusable if:
--- - It has no name (or empty name)
--- - It's not modified
--- - It has no content (empty or only blank lines)
--- - It's not a special buffer (normal buftype)
--- - There's only ONE window in the current tab (to avoid messing up splits)
--- @return boolean - true if buffer can be reused, false otherwise
function M.is_current_buffer_empty()
	-- If there are multiple windows in current tab, don't reuse
	-- (opening a book creates splits that would mess up the layout)
	local tabpage = vim.api.nvim_get_current_tabpage()
	local windows = vim.api.nvim_tabpage_list_wins(tabpage)
	if #windows > 1 then
		return false
	end

	local buf = vim.api.nvim_get_current_buf()

	-- Check if buffer has a name
	local bufname = vim.api.nvim_buf_get_name(buf)
	if bufname ~= "" then
		return false
	end

	-- Check if buffer is modified
	if vim.api.nvim_get_option_value("modified", { buf = buf }) then
		return false
	end

	-- Check if it's a special buffer type (should be empty/normal)
	local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })
	if buftype ~= "" then
		return false
	end

	-- Check if buffer has any content
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	if #lines == 0 then
		return true
	end

	-- Check if all lines are empty or contain only whitespace
	for _, line in ipairs(lines) do
		-- Match any non-whitespace character
		if line:match("%S") then
			return false
		end
	end

	return true
end

return M
