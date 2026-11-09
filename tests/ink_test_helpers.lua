local M = {}

-- Redirect the plugin data dir to a temporary folder
-- Returns the folder path and a function that restores everything
function M.use_temp_data_dir()
  local ink_data = require("ink.data")
  local original = ink_data.get_data_dir
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")

  ink_data.get_data_dir = function()
    return dir
  end

  return dir, function()
    ink_data.get_data_dir = original
    vim.fn.delete(dir, "rf")
  end
end

-- Write a file with raw content
function M.write(path, content)
  local f = assert(io.open(path, "wb"))
  f:write(content)
  f:close()
end

-- Silence vim.notify during a test
-- Returns the list of captured messages and a restore function
function M.capture_notify()
  local original = vim.notify
  local messages = {}

  vim.notify = function(msg, level)
    table.insert(messages, { msg = msg, level = level })
  end

  return messages, function()
    vim.notify = original
  end
end

return M
