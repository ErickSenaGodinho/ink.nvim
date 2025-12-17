-- lua/ink/dashboard/config.lua
-- Dashboard configuration system

local M = {}

-- Default configuration
local default_config = {
	layout = {
		type = "custom", -- "grid" or "custom"
		columns = 2,
		padding = 2,
	},

	widgets = {
		{
			type = "header",
			title = "Ink.Nvim",
			width = 100,
			height = 3,
			position = { row = 0, col = 0 },
		},
		{
			type = "stats",
			title = "📊 Statistics",
			width = 40,
			height = 10,
			position = { row = 5, col = 0 },
		},
		{
			type = "library",
			title = "📚 Library",
			width = 40,
			height = 14,
			position = { row = 5, col = 42 },
		},
		{
			type = "recent",
			title = "📖 Recent Books",
			width = 82,
			height = 14,
			position = { row = 17, col = 0 },
			opts = {
				limit = 5,
			},
		},
	},

	keymaps = {
		refresh = "r",
		close = "q",
		open = "<CR>",
		telescope = "l",
		help = "?",
	},
}

local current_config = nil

-- Setup configuration with user overrides
-- @param user_config: table|nil - User configuration
-- @return config: table - Merged configuration
function M.setup(user_config)
	current_config = vim.tbl_deep_extend("force", default_config, user_config or {})
	return current_config
end

-- Get current configuration
-- @return config: table
function M.get()
	return current_config or default_config
end

return M
