-- lua/ink/library/data.lua
-- Persistence layer for library

local M = {}

local fs = require("ink.fs")
local data_module = require("ink.data")

-- Get path to library.json
local function get_library_path()
	fs.ensure_dir(data_module.get_data_dir())
	return data_module.get_data_dir() .. "/library.json"
end

-- Load library from disk
function M.load()
	local path = get_library_path()

	if not fs.exists(path) then
		return { books = {}, last_book_path = nil }
	end

	local content = fs.read_file(path)
	if not content then
		return { books = {}, last_book_path = nil }
	end

	local ok, lib = pcall(vim.json.decode, content)
	if not ok or not lib then
		return { books = {}, last_book_path = nil }
	end

	-- Ensure books array exists
	lib.books = lib.books or {}

	return lib
end

-- Save library to disk
function M.save(library)
	local path = get_library_path()
	local json = data_module.json_encode(library)

	local file = io.open(path, "w")
	if file then
		file:write(json)
		file:close()
		return true
	end
	return false
end

return M
