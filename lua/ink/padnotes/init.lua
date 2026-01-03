-- lua/ink/padnotes/init.lua
-- Module interface for padnotes management

local M = {}

-- Default configuration
M.config = {
  enabled = true,
  path = "default",  -- "default" or custom path template
  auto_save_interval = 120,  -- seconds
  template = "default",
}

-- Setup function
function M.setup(config)
  M.config = vim.tbl_deep_extend("force", M.config, config or {})
end

-- Re-export action functions (lazy-loaded)
function M.toggle()
  return require("ink.padnotes.actions").toggle()
end

function M.open(force_chapter_idx)
  return require("ink.padnotes.actions").open(force_chapter_idx)
end

function M.close(save_first)
  return require("ink.padnotes.actions").close(save_first)
end

-- Re-export UI functions (lazy-loaded)
function M.list_all()
  return require("ink.padnotes.ui").list_all()
end

return M
