--- Central place for ink.nvim data paths.
local M = {}

---@return string
function M.root()
  return vim.fn.stdpath("data") .. "/ink.nvim"
end

---@return boolean ok
---@return string? err
function M.validate_slug(slug)
  if not slug or type(slug) ~= "string" or slug == "" then
    return false, "Invalid slug: empty or not a string"
  end
  if not slug:match("^[%w_-]+$") then
    return false, "Invalid slug: contains unsafe characters"
  end
  if slug:match("%.%.") or slug:match("^%.") then
    return false, "Invalid slug: contains path traversal"
  end
  return true, nil
end

--- <root>/books/<slug>. Does not create the directory.
---@param slug string
---@return string
function M.book_dir(slug)
  local ok, err = M.validate_slug(slug)
  if not ok then
    error("book_dir: " .. err)
  end
  return M.root() .. "/books/" .. slug
end

return M
