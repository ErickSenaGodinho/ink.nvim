return {
  {
    name = "InkLibrary",
    fn = function()
      require("ink.ui").show_library()
    end,
    opts = { nargs = "?", desc = "Shows the library" },
  },
  {
    name = "InkEditLibrary",
    fn = function()
      local library_path = vim.fn.stdpath("data") .. "/ink.nvim/library.json"
      vim.cmd("edit " .. library_path)
    end,
    opts = { nargs = "?", desc = "Opens library.json for manual editing" },
  },
  {
    name = "InkAddLibrary",
    fn = function(args)
      local library = require("ink.library")
      local directory = args.args ~= "" and vim.fn.fnamemodify(vim.fn.expand(args.args), ":p") or vim.fn.getcwd()

      vim.notify("Scanning for EPUB files in " .. directory .. "...", vim.log.levels.INFO)

      -- Use async version with callback
      library.scan_directory(directory, function(result, err)
        if not result then
          vim.notify("Error: " .. err, vim.log.levels.ERROR)
          return
        end

        local message = string.format(
          "Scan complete:\n- Total EPUBs found: %d\n- Added to library: %d\n- Already in library: %d",
          result.total,
          result.added,
          result.skipped
        )

        if #result.errors > 0 then
          message = message .. "\n- Failed to parse: " .. #result.errors
          for i, error_info in ipairs(result.errors) do
            if i <= 3 then
              message = message .. "\n  * " .. vim.fn.fnamemodify(error_info.path, ":t")
            end
          end
          if #result.errors > 3 then
            message = message .. "\n  ... and " .. (#result.errors - 3) .. " more"
          end
        end

        vim.notify(message, vim.log.levels.INFO)
      end)
    end,
    opts = { nargs = "?", complete = "dir", desc = "Scans directory for EPUBs and adds them to library" },
  },
}
