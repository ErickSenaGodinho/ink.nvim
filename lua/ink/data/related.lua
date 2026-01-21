local M = {}

local fs = require("ink.fs")
local data_module = require("ink.data")

-- Get path to related.json
local function get_related_path()
	fs.ensure_dir(data_module.get_data_dir())
	return data_module.get_data_dir() .. "/related.json"
end

-- Load related data from disk
function M.load()
	local path = get_related_path()

	if not fs.exists(path) then
		return {}
	end

	local content = fs.read_file(path)
	if not content then
		return {}
	end

	local ok, data = pcall(vim.json.decode, content)
	if not ok or not data then
		return {}
	end

	return data
end

-- Save related data to disk
function M.save(data)
	local path = get_related_path()
	local json = data_module.json_encode(data)

	local file = io.open(path, "w")
	if not file then
		return false
	end

	local ok = pcall(file.write, file, json)
	file:close()
	return ok
end

-- Add a related resource (reciprocal)
function M.add_related(book_slug, related_slug)
	local data = M.load()

	-- Initialize if not exists
	if not data[book_slug] then data[book_slug] = {} end
	if not data[related_slug] then data[related_slug] = {} end

	-- Add reciprocal relations
	data[book_slug][related_slug] = true
	data[related_slug][book_slug] = true

	return M.save(data)
end

-- Remove a related resource (reciprocal)
function M.remove_related(book_slug, related_slug)
	local data = M.load()

	if data[book_slug] then
		data[book_slug][related_slug] = nil
	end

	if data[related_slug] then
		data[related_slug][book_slug] = nil
	end

	return M.save(data)
end

-- Get related resources for a book
function M.get_related(book_slug)
	local data = M.load()
	return data[book_slug] or {}
end

-- Get all related resources as a set
function M.get_related_slugs(book_slug)
	local related = M.get_related(book_slug)
	local slugs = {}
	for slug, _ in pairs(related) do
		table.insert(slugs, slug)
	end
	return slugs
end

return M