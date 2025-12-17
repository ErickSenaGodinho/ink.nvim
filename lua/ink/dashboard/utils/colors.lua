-- lua/ink/dashboard/utils/colors.lua
-- Color and highlight utilities

local M = {}

-- Create progress bar string
-- @param progress: number - Progress percentage (0-100)
-- @param width: number - Total width of bar
-- @param char_filled: string - Character for filled portion
-- @param char_empty: string - Character for empty portion
-- @return bar: string
function M.create_progress_bar(progress, width, char_filled, char_empty)
	char_filled = char_filled or "█"
	char_empty = char_empty or "░"

	local filled_count = math.floor((progress / 100) * width)
	local empty_count = width - filled_count

	return string.rep(char_filled, filled_count) .. string.rep(char_empty, empty_count)
end

-- Apply highlights to buffer
-- @param buf: number - Buffer handle
-- @param highlights: table[] - Array of highlight specs
-- @param ns_id: number - Namespace ID
function M.apply_highlights(buf, highlights, ns_id)
	for _, hl in ipairs(highlights) do
		if hl.line and hl.col_start and hl.col_end and hl.hl_group then
			pcall(vim.api.nvim_buf_set_extmark, buf, ns_id, hl.line - 1, hl.col_start, {
				end_col = hl.col_end,
				hl_group = hl.hl_group,
			})
		end
	end
end

return M
