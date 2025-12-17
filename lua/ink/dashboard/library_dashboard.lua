-- lua/ink/dashboard/library_dashboard.lua
-- Main library-focused dashboard

local M = {}

local state = {
	buffer = nil,
	current_page = 1,
	items_per_page = 15,
	current_collection = nil, -- nil = All Books
	collection_index = 0, -- 0 = All Books, 1+ = collection index
	books = {},
	collections = {},
}

-- Show library dashboard
function M.show()
	-- Create buffer
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, "ink://dashboard/library")

	-- Buffer options
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(buf, "swapfile", false)
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
	vim.api.nvim_buf_set_option(buf, "filetype", "ink-dashboard")

	-- Show in current window
	local win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(win, buf)

	-- Store state
	state.buffer = buf
	state.current_page = 1

	-- Load data and render
	M.load_data()
	M.render()

	-- Setup keymaps
	M.setup_keymaps(buf)

	-- Setup autocmds
	M.setup_autocmds(buf)
end

-- Load book and collection data
function M.load_data()
	local library = require("ink.library")
	local collections = require("ink.collections")

	-- Get all books
	if state.current_collection then
		-- Filter by collection
		state.books = collections.get_collection_books(state.current_collection)
	else
		-- All books
		state.books = library.get_books()
	end

	-- Get all collections
	state.collections = collections.get_all() or {}
end

-- Render dashboard
function M.render()
	if not state.buffer or not vim.api.nvim_buf_is_valid(state.buffer) then
		return
	end

	local lines = {}
	local win_width = vim.api.nvim_win_get_width(0)

	-- Title
	local title = "Ink.Nvim"
	local title_padding = math.floor((win_width - #title) / 2)
	table.insert(lines, string.rep(" ", title_padding) .. title)

	-- Collection name (subtitle)
	local collection_name = "All Books"
	if state.current_collection then
		-- Find collection name by ID
		for _, coll in ipairs(state.collections) do
			if coll.id == state.current_collection then
				collection_name = coll.name
				break
			end
		end
	end
	local subtitle_padding = math.floor((win_width - #collection_name) / 2)
	table.insert(lines, string.rep(" ", subtitle_padding) .. collection_name)
	table.insert(lines, "")

	-- Calculate pagination
	local total_books = #state.books
	local total_pages = math.ceil(total_books / state.items_per_page)
	local start_idx = (state.current_page - 1) * state.items_per_page + 1
	local end_idx = math.min(start_idx + state.items_per_page - 1, total_books)

	-- Box width (slightly narrower than window for margins)
	local box_width = math.min(win_width - 4, 120)
	local box_padding = math.floor((win_width - box_width) / 2)
	local box_prefix = string.rep(" ", box_padding)

	-- Top border
	table.insert(lines, box_prefix .. "┌" .. string.rep("─", box_width - 2) .. "┐")

	-- Header line: LIBRARY on left, Page info on right
	local page_info = string.format("Page %d/%d • %d books", state.current_page, total_pages, total_books)
	local header_text = "LIBRARY"
	local header_text_width = vim.fn.strwidth(header_text)
	local page_info_width = vim.fn.strwidth(page_info)
	local header_spacing = box_width - 2 - header_text_width - page_info_width
	local header_line = "│" .. header_text .. string.rep(" ", header_spacing) .. page_info .. "│"
	table.insert(lines, box_prefix .. header_line)

	-- Render books
	for i = start_idx, end_idx do
		local book = state.books[i]
		if book then
			local line = M.format_book_line(book, box_width - 2)
			table.insert(lines, box_prefix .. "│" .. line .. "│")
		end
	end

	-- Fill empty lines if less than items_per_page
	local rendered_count = end_idx - start_idx + 1
	for i = rendered_count + 1, state.items_per_page do
		table.insert(lines, box_prefix .. "│" .. string.rep(" ", box_width - 2) .. "│")
	end

	-- Bottom border
	table.insert(lines, box_prefix .. "└" .. string.rep("─", box_width - 2) .. "┘")

	-- Shortcuts help (2 lines)
	table.insert(lines, "")
	local help1 = "Enter open    j/k navigate    n/p page    c toggle collection    s stats"
	local help2 = "C new collection    D delete collection    a add to collection    r remove    q quit"
	local help1_padding = math.floor((win_width - vim.fn.strwidth(help1)) / 2)
	local help2_padding = math.floor((win_width - vim.fn.strwidth(help2)) / 2)
	table.insert(lines, string.rep(" ", help1_padding) .. help1)
	table.insert(lines, string.rep(" ", help2_padding) .. help2)

	-- Set buffer content
	vim.api.nvim_buf_set_option(state.buffer, "modifiable", true)
	vim.api.nvim_buf_set_lines(state.buffer, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(state.buffer, "modifiable", false)
end

-- Format a single book line
-- @param book: table - Book data
-- @param width: number - Available width
-- @return line: string
function M.format_book_line(book, width)
	local text_utils = require("ink.dashboard.utils.text")

	-- Extract data
	local title = book.title or "Unknown"
	local author = book.author or "Unknown"

	-- Get first collection name with indicator for multiple collections
	local collections = require("ink.collections")
	local collection_ids = collections.get_book_collections(book.slug) or {}
	local collection_text = "—"
	if #collection_ids > 0 then
		local first_collection = collections.get(collection_ids[1])
		if first_collection then
			collection_text = first_collection.name
			-- Add indicator if book is in multiple collections
			if #collection_ids == 2 then
				collection_text = collection_text .. "[+]"
			elseif #collection_ids > 2 then
				collection_text = collection_text .. "[+" .. (#collection_ids - 1) .. "]"
			end
		end
	end

	-- Last opened
	local last_opened = text_utils.format_date(book.last_opened)

	-- Completion
	local completion = "0%"
	if book.total_chapters and book.total_chapters > 0 then
		local current = book.chapter or 1
		local percent = math.floor((current / book.total_chapters) * 100)
		completion = string.format("%d%%", percent)
	end

	-- Fixed column widths for right side (visual width)
	local author_width = 20
	local collection_width = 15
	local time_width = 10
	local completion_width = 4

	-- Truncate and pad using visual width
	local function fit_string(str, target_width)
		local visual_width = vim.fn.strwidth(str)
		if visual_width > target_width then
			-- Truncate
			local result = ""
			local current_width = 0
			for i = 1, vim.fn.strchars(str) do
				local char = vim.fn.strcharpart(str, i - 1, 1)
				local char_width = vim.fn.strwidth(char)
				if current_width + char_width > target_width - 3 then
					return result .. "..."
				end
				result = result .. char
				current_width = current_width + char_width
			end
			return result
		else
			-- Pad
			return str .. string.rep(" ", target_width - visual_width)
		end
	end

	-- Format right side columns
	local author_padded = fit_string(author, author_width)
	local collection_padded = fit_string(collection_text, collection_width)
	local time_padded = fit_string(last_opened, time_width)
	local completion_padded = fit_string(completion, completion_width)

	local right_side = author_padded .. "  " .. collection_padded .. "  " .. time_padded .. "  " .. completion_padded

	-- Calculate title space
	local prefix = ">>>  "
	local prefix_width = vim.fn.strwidth(prefix)
	local right_side_width = vim.fn.strwidth(right_side)
	-- Total width calculation: prefix + title + spacing(2) + right_side
	local available_for_title = width - prefix_width - right_side_width - 2

	if available_for_title < 10 then
		available_for_title = 10
	end

	-- Format title
	local title_padded = fit_string(title, available_for_title)

	return prefix .. title_padded .. "  " .. right_side
end

-- Setup keymaps
function M.setup_keymaps(buf)
	local opts = { noremap = true, silent = true, buffer = buf }

	-- Open book
	vim.keymap.set("n", "<CR>", function()
		M.open_book_at_cursor()
	end, opts)

	-- Navigate
	vim.keymap.set("n", "j", "j", opts)
	vim.keymap.set("n", "k", "k", opts)

	-- Next page
	vim.keymap.set("n", "n", function()
		M.next_page()
	end, opts)

	-- Previous page
	vim.keymap.set("n", "p", function()
		M.prev_page()
	end, opts)

	-- Toggle collection
	vim.keymap.set("n", "c", function()
		M.toggle_collection()
	end, opts)

	-- Toggle stats dashboard
	vim.keymap.set("n", "s", function()
		M.show_stats_dashboard()
	end, opts)

	-- Create new collection
	vim.keymap.set("n", "C", function()
		M.create_collection()
	end, opts)

	-- Delete collection
	vim.keymap.set("n", "D", function()
		M.delete_collection()
	end, opts)

	-- Add book to collection
	vim.keymap.set("n", "a", function()
		M.add_book_to_collection()
	end, opts)

	-- Remove book from collection
	vim.keymap.set("n", "r", function()
		M.remove_book_from_collection()
	end, opts)

	-- Quit
	vim.keymap.set("n", "q", function()
		vim.api.nvim_buf_delete(buf, { force = true })
	end, opts)

	-- Refresh
	vim.keymap.set("n", "R", function()
		M.load_data()
		M.render()
		vim.notify("Dashboard Reloaded", vim.log.levels.INFO)
	end, opts)

	-- TODO: Implement these
	-- vim.keymap.set("n", "t", function() M.manage_tags() end, opts)
end

-- Setup autocmds
function M.setup_autocmds(buf)
	local group = vim.api.nvim_create_augroup("InkLibraryDashboard", { clear = false })

	vim.api.nvim_create_autocmd("BufDelete", {
		group = group,
		buffer = buf,
		callback = function()
			state.buffer = nil
		end,
	})
end

-- Open book at cursor
function M.open_book_at_cursor()
	local book = M.get_book_at_cursor()
	if not book or not book.path then
		return
	end

	-- Open book
	local epub = require("ink.epub")
	local ui = require("ink.ui")

	local book_data, err = epub.open(book.path)
	if not book_data then
		vim.notify("Failed to open book: " .. (err or "unknown error"), vim.log.levels.ERROR)
		return
	end

	ui.open_book(book_data)
end

-- Next page
function M.next_page()
	local total_pages = math.ceil(#state.books / state.items_per_page)
	if state.current_page < total_pages then
		state.current_page = state.current_page + 1
		M.render()
	end
end

-- Previous page
function M.prev_page()
	if state.current_page > 1 then
		state.current_page = state.current_page - 1
		M.render()
	end
end

-- Toggle collection
function M.toggle_collection()
	if #state.collections == 0 then
		vim.notify("No collections available", vim.log.levels.INFO)
		return
	end

	-- Cycle: All Books -> Collection 1 -> Collection 2 -> ... -> All Books
	state.collection_index = state.collection_index + 1

	if state.collection_index > #state.collections then
		-- Back to All Books
		state.collection_index = 0
		state.current_collection = nil
	else
		-- Select collection
		state.current_collection = state.collections[state.collection_index].id
	end

	-- Reset to first page
	state.current_page = 1

	-- Reload and render
	M.load_data()
	M.render()
end

-- Show stats dashboard
function M.show_stats_dashboard()
	local stats_dashboard = require("ink.dashboard.stats_dashboard")
	stats_dashboard.show()
end

-- Create new collection
function M.create_collection()
	-- Prompt for collection name
	vim.ui.input({ prompt = "Collection name: " }, function(name)
		if not name or name == "" then
			return
		end

		local collections = require("ink.collections")

		-- Create collection
		local success, err = pcall(collections.create, name, "")

		if success then
			vim.notify("Collection '" .. name .. "' created", vim.log.levels.INFO)
			-- Reload data and render
			M.load_data()
			M.render()
		else
			vim.notify("Failed to create collection: " .. tostring(err), vim.log.levels.ERROR)
		end
	end)
end

-- Delete collection
function M.delete_collection()
	local collections_module = require("ink.collections")

	-- Get all collections
	if #state.collections == 0 then
		vim.notify("No collections available", vim.log.levels.WARN)
		return
	end

	-- Build list of collection names
	local collection_names = {}
	for _, coll in ipairs(state.collections) do
		table.insert(collection_names, coll.name)
	end

	-- Use vim.ui.select to choose collection to delete
	vim.ui.select(collection_names, {
		prompt = "Delete which collection:",
	}, function(choice, idx)
		if not choice or not idx then
			return
		end

		local collection = state.collections[idx]

		-- Confirm deletion
		vim.ui.input({
			prompt = string.format("Delete collection '%s'? (y/N): ", collection.name),
		}, function(input)
			if not input or (input:lower() ~= "y" and input:lower() ~= "yes") then
				vim.notify("Cancelled", vim.log.levels.INFO)
				return
			end

			local success, err = pcall(collections_module.delete, collection.id)

			if success then
				vim.notify("Collection '" .. collection.name .. "' deleted", vim.log.levels.INFO)

				-- If currently viewing deleted collection, reset to All Books
				if state.current_collection == collection.id then
					state.current_collection = nil
					state.collection_index = 0
					state.current_page = 1
				end

				-- Reload data and render
				M.load_data()
				M.render()
			else
				vim.notify("Failed to delete collection: " .. tostring(err), vim.log.levels.ERROR)
			end
		end)
	end)
end

-- Get book at cursor
-- @return book: table|nil
function M.get_book_at_cursor()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local line_num = cursor[1]

	-- Books start at line 6
	if line_num < 6 then
		return nil
	end

	-- Calculate book offset
	local book_line_offset = line_num - 5

	-- Calculate absolute book index
	local start_idx = (state.current_page - 1) * state.items_per_page + 1
	local book_idx = start_idx + book_line_offset - 1

	if book_idx < 1 or book_idx > #state.books then
		return nil
	end

	return state.books[book_idx]
end

-- Add book to collection
function M.add_book_to_collection()
	local book = M.get_book_at_cursor()
	if not book then
		vim.notify("No book selected", vim.log.levels.WARN)
		return
	end

	local collections = require("ink.collections")

	-- Get all collections
	if #state.collections == 0 then
		vim.notify("No collections available. Create one with 'C'", vim.log.levels.WARN)
		return
	end

	-- Build list of collection names
	local collection_names = {}
	for _, coll in ipairs(state.collections) do
		table.insert(collection_names, coll.name)
	end

	-- Use vim.ui.select to choose collection
	vim.ui.select(collection_names, {
		prompt = "Add '" .. book.title .. "' to collection:",
	}, function(choice, idx)
		if not choice or not idx then
			return
		end

		local collection = state.collections[idx]
		local success, err = pcall(collections.add_book, collection.id, book.slug)

		if success then
			vim.notify("Added to '" .. collection.name .. "'", vim.log.levels.INFO)
			-- Reload data and render
			M.load_data()
			M.render()
		else
			vim.notify("Failed to add book: " .. tostring(err), vim.log.levels.ERROR)
		end
	end)
end

-- Remove book from collection
function M.remove_book_from_collection()
	local book = M.get_book_at_cursor()
	if not book then
		vim.notify("No book selected", vim.log.levels.WARN)
		return
	end

	local collections_module = require("ink.collections")

	-- Get collection IDs this book is in
	local collection_ids = collections_module.get_book_collections(book.slug) or {}

	if #collection_ids == 0 then
		vim.notify("Book is not in any collection", vim.log.levels.WARN)
		return
	end

	-- Get full collection objects
	local book_collections = {}
	for _, coll_id in ipairs(collection_ids) do
		local coll = collections_module.get(coll_id)
		if coll then
			table.insert(book_collections, coll)
		end
	end

	if #book_collections == 0 then
		vim.notify("Book is not in any collection", vim.log.levels.WARN)
		return
	end

	-- Function to confirm and remove from a collection
	local function confirm_and_remove(collection)
		vim.ui.input({
			prompt = string.format("Remove '%s' from '%s'? (y/N): ", book.title, collection.name),
		}, function(input)
			if not input or (input:lower() ~= "y" and input:lower() ~= "yes") then
				vim.notify("Cancelled", vim.log.levels.INFO)
				return
			end

			local success, err = pcall(collections_module.remove_book, collection.id, book.slug)

			if success then
				vim.notify("Removed from '" .. collection.name .. "'", vim.log.levels.INFO)
				-- Reload data and render
				M.load_data()
				M.render()
			else
				vim.notify("Failed to remove book: " .. tostring(err), vim.log.levels.ERROR)
			end
		end)
	end

	-- If only one collection, go straight to confirmation
	if #book_collections == 1 then
		confirm_and_remove(book_collections[1])
		return
	end

	-- Multiple collections - let user choose which one
	local collection_names = {}
	for _, coll in ipairs(book_collections) do
		table.insert(collection_names, coll.name)
	end

	vim.ui.select(collection_names, {
		prompt = "Remove from which collection:",
	}, function(choice, idx)
		if not choice or not idx then
			return
		end

		confirm_and_remove(book_collections[idx])
	end)
end

return M
