-- lua/ink/collections/management.lua
-- CRUD operations for collections

local M = {}

local data = require("ink.collections.data")

-- Create new collection
-- @param name: string - Name of collection
-- @param opts: table - { icon = "📚", description = "..." }
-- @return collection_id: string|nil
function M.create(name, opts)
	opts = opts or {}

	-- Validate name
	if not name or name:match("^%s*$") then
		vim.notify("Collection name cannot be empty", vim.log.levels.ERROR)
		return nil
	end

	-- Generate unique ID
	local id = data.generate_id(name)
	id = data.make_unique_id(id)

	-- Create collection object
	local collection = {
		id = id,
		name = name,
		icon = opts.icon or "📚",
		description = opts.description or "",
		created_at = os.time(),
		books = {},
	}

	-- Load, add, and save
	local collections_data = data.load()
	table.insert(collections_data.collections, collection)

	if not data.save(collections_data) then
		return nil
	end

	return id
end

-- Rename collection
-- @param collection_id: string
-- @param new_name: string
-- @return success: boolean
function M.rename(collection_id, new_name)
	if not new_name or new_name:match("^%s*$") then
		vim.notify("Collection name cannot be empty", vim.log.levels.ERROR)
		return false
	end

	local collections_data = data.load()
	local found = false

	for _, coll in ipairs(collections_data.collections) do
		if coll.id == collection_id then
			coll.name = new_name
			found = true
			break
		end
	end

	if not found then
		vim.notify("Collection not found: " .. collection_id, vim.log.levels.ERROR)
		return false
	end

	return data.save(collections_data)
end

-- Update collection metadata (icon, description)
-- @param collection_id: string
-- @param opts: table - { icon = "...", description = "..." }
-- @return success: boolean
function M.update(collection_id, opts)
	opts = opts or {}

	local collections_data = data.load()
	local found = false

	for _, coll in ipairs(collections_data.collections) do
		if coll.id == collection_id then
			if opts.icon then
				coll.icon = opts.icon
			end
			if opts.description ~= nil then
				coll.description = opts.description
			end
			found = true
			break
		end
	end

	if not found then
		vim.notify("Collection not found: " .. collection_id, vim.log.levels.ERROR)
		return false
	end

	return data.save(collections_data)
end

-- Delete collection
-- @param collection_id: string
-- @param remove_books: boolean - If true, also remove books from library (not implemented yet)
-- @return success: boolean
function M.delete(collection_id, remove_books)
	local collections_data = data.load()
	local new_collections = {}
	local found = false

	for _, coll in ipairs(collections_data.collections) do
		if coll.id == collection_id then
			found = true
			-- TODO: Implement remove_books if true
		else
			table.insert(new_collections, coll)
		end
	end

	if not found then
		vim.notify("Collection not found: " .. collection_id, vim.log.levels.ERROR)
		return false
	end

	collections_data.collections = new_collections
	return data.save(collections_data)
end

-- Get collection by ID
-- @param collection_id: string
-- @return collection: table|nil
function M.get(collection_id)
	local collections_data = data.get_cached()
	for _, coll in ipairs(collections_data.collections) do
		if coll.id == collection_id then
			return coll
		end
	end
	return nil
end

-- Get all collections
-- @return collections: table[]
function M.get_all()
	local collections_data = data.get_cached()
	return collections_data.collections
end

return M
