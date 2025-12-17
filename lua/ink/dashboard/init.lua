-- lua/ink/dashboard/init.lua
-- Dashboard entry point

local M = {}

-- Show dashboard (defaults to library dashboard)
-- @param dashboard_type: string|nil - "library" (default) or "stats"
function M.show(dashboard_type)
	dashboard_type = dashboard_type or "library"

	if dashboard_type == "stats" then
		local stats_dashboard = require("ink.dashboard.stats_dashboard")
		stats_dashboard.show()
	else
		local library_dashboard = require("ink.dashboard.library_dashboard")
		library_dashboard.show()
	end
end

-- Show library dashboard
function M.show_library()
	local library_dashboard = require("ink.dashboard.library_dashboard")
	library_dashboard.show()
end

-- Show stats dashboard
function M.show_stats()
	local stats_dashboard = require("ink.dashboard.stats_dashboard")
	stats_dashboard.show()
end

return M
