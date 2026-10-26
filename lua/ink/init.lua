local ui = require("ink.ui")
local autocmds = require("ink.ui.autocmds")
local config = require("ink.config")
local highlights = require("ink.highlights")
local commands = require("ink.commands")
local keymaps_global = require("ink.keymaps.global")

local M = {}

function M.setup(opts)
  M.config = config.setup(opts)
  ui.setup(M.config)

  -- Setup reading sessions tracking
  local reading_sessions = require("ink.reading_sessions")
  reading_sessions.setup(M.config.tracking)

  highlights.setup()
  commands.setup(M.config)
  keymaps_global.setup(M.config)
  autocmds.setup()

  -- Setup padnotes
  if M.config.padnotes and M.config.padnotes.enabled then
    local padnotes = require("ink.padnotes")
    padnotes.setup(M.config.padnotes)
  end

  -- Setup automatic tracking
  if M.config.tracking and M.config.tracking.enabled then
    require("ink.tracking").setup(M.config)
  end

  require("ink.which_key_groups").register(M.config)
end

return M
