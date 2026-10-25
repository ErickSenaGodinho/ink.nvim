return {
  {
    name = "InkTocFloat",
    fn = function()
      require("ink.ui.floating_toc").toggle_floating_toc()
    end,
    opts = { desc = "Toggle floating TOC (experimental)" },
  },

  {
    name = "InkRebuildTOC",
    fn = function()
      local context = require("ink.ui.context")
      local epub = require("ink.epub")
      local ctx = context.current()

      if not ctx or not ctx.data then
        vim.notify("No book is currently open", vim.log.levels.ERROR)
        return
      end

      -- Clear TOC cache
      local toc_cache = require("ink.cache.toc")
      toc_cache.clear(ctx.data.slug)

      -- Rebuild TOC from content
      local content_toc = epub.build_toc_from_content(ctx.data.spine, ctx.data.base_dir, ctx.data.class_styles)

      if #content_toc > 0 then
        ctx.data.toc = content_toc
        toc_cache.save(ctx.data.slug, content_toc)

        -- Re-render TOC if it's open
        if ctx.toc_win and vim.api.nvim_win_is_valid(ctx.toc_win) then
          local toc = require("ink.ui.floating_toc")
          toc.close_floating_toc(ctx)
          toc.show_floating_toc(ctx)
        end

        vim.notify(
          string.format("TOC rebuilt with %d entries from content headings", #content_toc),
          vim.log.levels.INFO
        )
      else
        vim.notify("No headings found in content to build TOC", vim.log.levels.WARN)
      end
    end,
  },
}
