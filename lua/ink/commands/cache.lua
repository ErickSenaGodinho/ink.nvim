return {
  {
    name = "InkClearCache",
    fn = function(args)
      local arg = args.args

      if arg == "" then
        -- No argument: show interactive UI
        local cache_ui = require("ink.ui.cache")
        cache_ui.show_clear_cache_ui()
      elseif arg == "--all" then
        -- --all flag: clear all cache with confirmation
        local cache_ui = require("ink.ui.cache")
        cache_ui.clear_all_cache()
      else
        -- Specific slug provided
        local success, message = require("ink.epub").clear_cache(arg)
        if success then
          vim.notify(message, vim.log.levels.INFO)
        else
          vim.notify(message, vim.log.levels.ERROR)
        end
      end
    end,
    opts = {
      nargs = "?",
      desc = "Clear EPUB cache (interactive, --all, or specific slug)",
    },
  },
  {
    name = "InkClearSearchIndex",
    fn = function(args)
      local context = require("ink.ui.context")
      local search_index = require("ink.ui.search_index")

      local slug = args.args

      if slug == "" then
        -- Clear for current book
        local ctx = context.current()
        if not ctx or not ctx.data then
          vim.notify("No book currently open", vim.log.levels.WARN)
          return
        end

        slug = ctx.data.slug
        ctx.search_index = nil -- Clear in-memory cache too
      end

      search_index.clear_cached_index(slug)
      vim.notify(string.format("Search index cleared for: %s", slug), vim.log.levels.INFO)
    end,
    opts = {
      nargs = "?",
      desc = "Clear search index cache for current book or specified slug",
    },
  },
  {
    name = "InkCacheInfo",
    fn = function()
      local info = require("ink.epub").get_cache_info()
      if info.exists then
        vim.notify(
          string.format("EPUB Cache: %d books cached\nLocation: %s", info.total_books, info.path),
          vim.log.levels.INFO
        )
      else
        vim.notify("No cache directory found", vim.log.levels.INFO)
      end
    end,
  },
}
