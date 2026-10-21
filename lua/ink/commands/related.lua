local function current_book_ctx()
  local context = require("ink.ui.context")
  local ctx = context.current()
  if not ctx or not ctx.data then
    vim.notify("No book currently open", vim.log.levels.WARN)
    return nil
  end
  return ctx
end

return {
  {
    name = "InkAddRelated",
    fn = function()
      require("ink.ui").add_related_resource()
    end,
    opts = { desc = "Add a related resource to the current book via telescope picker" },
  },

  {
    name = "InkRemoveRelated",
    fn = function(args)
      local related = require("ink.data.related")

      local ctx = current_book_ctx()
      if not ctx then
        return
      end

      local related_slug = args.args
      if related_slug == "" then
        vim.notify("Usage: InkRemoveRelated <slug>", vim.log.levels.WARN)
        return
      end

      local success = related.remove_related(ctx.data.slug, related_slug)

      if success then
        vim.notify("Related resource removed", vim.log.levels.INFO)
      else
        vim.notify("Failed to remove related resource", vim.log.levels.WARN)
      end
    end,
    opts = {
      nargs = 1,
      desc = "Remove a related resource from the current book",
    },
  },

  {
    name = "InkListRelated",
    fn = function()
      require("ink.ui").show_related_resources()
    end,
    opts = { desc = "Show related resources for the current book in telescope" },
  },

  {
    name = "InkCleanupRelated",
    fn = function(args)
      local related = require("ink.data.related")

      -- First check if there are orphans
      local orphans = related.get_orphan_references()

      if #orphans == 0 then
        vim.notify("No orphan references found. All related resources are valid.", vim.log.levels.INFO)
        return
      end

      vim.notify(string.format("Found %d orphan reference(s) to deleted books", #orphans), vim.log.levels.WARN)

      if not args.bang then
        local confirm = vim.fn.input(
          string.format(
            "Clean up %d orphan reference(s)? This will remove references to deleted books. (y/N): ",
            #orphans
          )
        )

        if confirm:lower() ~= "y" and confirm:lower() ~= "yes" then
          vim.notify("Cleanup cancelled", vim.log.levels.INFO)
          return
        end
      end

      local cleaned_count, cleaned_slugs = related.cleanup_orphans()

      if cleaned_count > 0 or #cleaned_slugs > 0 then
        vim.notify(
          string.format(
            "Cleanup complete: removed %d orphan entries and references to %d deleted books",
            cleaned_count,
            #cleaned_slugs
          ),
          vim.log.levels.INFO
        )
      else
        vim.notify("Cleanup complete: no changes needed", vim.log.levels.INFO)
      end
    end,
    opts = {
      bang = true,
      desc = "Clean up orphan references in related.json (use ! to skip confirmation)",
    },
  },
}
