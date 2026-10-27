local M = {}

-- Command modules grouped by domain. Each one returns a list of commands
-- or a function(deps) that returns that list.
local modules = {
  "library",
  "cache",
  "related",
  "glossary",
  "web",
  "export",
  "notes",
  "bookmarks",
  "toc",
  "stats",
}

--- Registers a declarative command.
---@param cmd { name: string, fn: function, opts?: table, complete?: string|function }
local function register(cmd)
  assert(type(cmd.name) == "string", "command requires 'name'")
  assert(type(cmd.fn) == "function", "command '" .. cmd.name .. "' requires 'fn'")

  local opts = vim.tbl_extend("force", {}, cmd.opts or {})
  if cmd.complete ~= nil then
    opts.complete = cmd.complete
  end

  vim.api.nvim_create_user_command(cmd.name, cmd.fn, opts)
end

--- General commands that don't belong to any specific domain.
---@param deps { config: table }
local function core_commands(deps)
  return {
    {
      name = "InkOpen",
      fn = function(args)
        local path = args.args
        if path == "" then
          vim.notify("Please provide a file path (EPUB or Markdown)", vim.log.levels.ERROR)
          return
        end

        path = vim.fn.expand(path)

        local ui = require("ink.ui")
        local ok, data

        if path:match("^https?://") then
          local web = require("ink.web")
          ok, data = pcall(web.open, path)
          if not ok then
            vim.notify("Failed to open web page: " .. tostring(data), vim.log.levels.ERROR)
            return
          end
        elseif path:match("%.epub$") then
          local epub = require("ink.epub")
          ok, data = pcall(epub.open, path, { force_content_toc = deps.config.force_content_toc })
          if not ok then
            vim.notify("Failed to open EPUB: " .. tostring(data), vim.log.levels.ERROR)
            return
          end
        elseif path:match("%.md$") or path:match("%.markdown$") then
          local markdown = require("ink.markdown")
          ok, data = pcall(markdown.open, path)
          if not ok then
            vim.notify("Failed to open Markdown: " .. tostring(data), vim.log.levels.ERROR)
            return
          end
        else
          vim.notify("Unsupported file format. Please use .epub, .md files, or URLs", vim.log.levels.ERROR)
          return
        end

        ui.open_book(data)
      end,
      opts = { nargs = 1 },
      complete = "file",
    },

    {
      name = "InkLast",
      fn = function()
        require("ink.ui").open_last_book()
      end,
    },

    {
      name = "InkHealth",
      fn = function()
        require("ink.health").check()
      end,
      opts = { desc = "Run health check diagnostics for ink.nvim" },
    },

    {
      name = "InkToggleFocusedMode",
      fn = function()
        require("ink.ui").toggle_focused_mode()
      end,
    },

    {
      name = "InkToggleParagraphMode",
      fn = function()
        require("ink.ui.extmarks").toggle_reading_paragraph_mode()
      end,
    },

    {
      name = "InkSetWidth",
      fn = function(args)
        local navigation = require("ink.ui.navigation")
        local context = require("ink.ui.context")

        if args.args and args.args ~= "" then
          navigation.set_width(args.args)
        else
          local ctx = context.current()
          local current = ctx and (ctx.current_max_width or context.config.max_width or 120) or 120
          vim.notify("Usage: InkSetWidth 'value'. Current: " .. current, vim.log.levels.INFO)
        end
      end,
      opts = { nargs = "?" },
    },
  }
end

--- Registers all plugin commands.
function M.setup()
  local deps = { config = require("ink.config").get() or {} }

  -- General commands
  for _, cmd in ipairs(core_commands(deps)) do
    register(cmd)
  end

  -- Domain commands
  for _, name in ipairs(modules) do
    local mod = require("ink.commands." .. name)
    local list = type(mod) == "function" and mod(deps) or mod
    for _, cmd in ipairs(list) do
      register(cmd)
    end
  end
end

return M
