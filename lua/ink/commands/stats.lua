return {
  {
    name = "InkDashboard",
    fn = function(args)
      local dashboard_type = args.args ~= "" and args.args or "library"
      require("ink.dashboard").show(dashboard_type)
    end,
    opts = { nargs = "?" },
    complete = function()
      return { "library", "stats" }
    end,
  },

  {
    name = "InkResetStats",
    fn = function(args)
      local sessions = require("ink.reading_sessions")

      if args.bang then
        -- Force reset without confirmation
        sessions.reset_all_statistics()
        vim.notify("All reading statistics have been reset", vim.log.levels.WARN)
        return
      end

      local confirm = vim.fn.input("Reset all reading statistics? This cannot be undone. (y/N): ")
      if confirm:lower() == "y" or confirm:lower() == "yes" then
        sessions.reset_all_statistics()
        vim.notify("All reading statistics have been reset", vim.log.levels.WARN)
      else
        vim.notify("Reset cancelled", vim.log.levels.INFO)
      end
    end,
    opts = {
      bang = true,
      desc = "Reset all reading statistics (use ! to skip confirmation)",
    },
  },
}
