--- Runs `callback(ctx)` only if a book is currently open.
local function with_book(callback)
  local context = require("ink.ui.context")
  local ctx = context.current()
  if ctx and ctx.data then
    callback(ctx)
  else
    vim.notify("No book is currently open", vim.log.levels.WARN)
  end
end

return {
  {
    name = "InkGlossary",
    fn = function()
      with_book(function(ctx)
        require("ink.glossary.ui").show_glossary_browser(ctx.data.slug)
      end)
    end,
  },

  {
    name = "InkGlossaryFloating",
    fn = function()
      with_book(function(ctx)
        require("ink.glossary.ui").show_glossary_browser(ctx.data.slug, true) -- Force floating
      end)
    end,
  },

  {
    name = "InkGlossaryAdd",
    fn = function(args)
      with_book(function(ctx)
        local glossary_ui = require("ink.glossary.ui")
        local term = args.args ~= "" and args.args or nil

        glossary_ui.show_add_entry_modal(ctx.data.slug, term, function(entry)
          if entry then
            vim.notify("Glossary entry '" .. entry.term .. "' added", vim.log.levels.INFO)

            -- Re-render to show new glossary marks
            local render = require("ink.ui.render")
            render.invalidate_glossary_cache(ctx)
            local cursor = vim.api.nvim_win_get_cursor(ctx.content_win)
            render.render_chapter(ctx.current_chapter_idx, cursor[1], ctx)
          end
        end)
      end)
    end,
    opts = { nargs = "?" },
  },

  {
    name = "InkGlossaryGraph",
    fn = function()
      with_book(function(ctx)
        require("ink.glossary.ui").show_full_graph(ctx.data.slug)
      end)
    end,
  },
}
