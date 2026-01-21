local M = {}

local related = require("ink.data.related")
local library = require("ink.library")
local context = require("ink.ui.context")

-- Helper function to get visual width of string
local function visual_width(str)
	return vim.fn.strdisplaywidth(str)
end

-- Helper function to truncate and pad string to exact width
local function fit_string(str, width)
	if not str or str == "" then
		return string.rep(" ", width)
	end

	local vw = visual_width(str)
	if vw > width then
		-- Truncate: keep removing chars until it fits
		local result = str
		while visual_width(result) > width do
			result = result:sub(1, vim.fn.byteidx(result, vim.fn.strchars(result) - 1))
		end
		return result
	else
		-- Pad with spaces
		return str .. string.rep(" ", width - vw)
	end
end

-- Show related resources for current book in telescope
function M.show_related_resources()
	local ctx = context.current()
	if not ctx or not ctx.data then
		vim.notify("No book currently open", vim.log.levels.WARN)
		return
	end

	local book_slug = ctx.data.slug
	local related_slugs = related.get_related_slugs(book_slug)

	if #related_slugs == 0 then
		vim.notify("No related resources for this book", vim.log.levels.INFO)
		return
	end

	-- Get full book info for each related slug
	local books = library.get_books()
	local related_books = {}

	for _, slug in ipairs(related_slugs) do
		for _, book in ipairs(books) do
			if book.slug == slug then
				table.insert(related_books, book)
				break
			end
		end
	end

	M.show_related_telescope(related_books)
end

-- Show related books in telescope picker (same format as library)
function M.show_related_telescope(related_books)
	local pickers = require('telescope.pickers')
	local finders = require('telescope.finders')
	local conf = require('telescope.config')
	local actions = require('telescope.actions')
	local action_state = require('telescope.actions.state')
	local previewers = require('telescope.previewers')

	local entries = {}
	for _, book in ipairs(related_books) do
		local progress = math.floor((book.chapter / book.total_chapters) * 100)
		local last_opened = library.format_last_opened(book.last_opened)
		local author = book.author or "Unknown"
		local tag = book.tag or ""
		local title_str = fit_string(book.title, 30)
		local author_str = fit_string(author, 20)
		local tag_str = fit_string(tag, 15)
		local progress_str = string.format("%3d%%", progress)

		table.insert(entries, {
			display = string.format("%s │ %s │ %s │ %s │ %s", title_str, author_str, tag_str, progress_str, last_opened),
			ordinal = book.title .. " " .. author .. " " .. tag,
			book = book,
			progress = progress,
			last_opened = last_opened,
			author = author
		})
	end

	pickers.new({}, {
		prompt_title = "Related Resources (Enter: open)",
		finder = finders.new_table({
			results = entries,
			entry_maker = function(entry)
				return { value = entry, display = entry.display, ordinal = entry.ordinal, book = entry.book }
			end
		}),
		previewer = previewers.new_buffer_previewer({
			title = "Book Info",
			define_preview = function(self, entry)
				local book = entry.book
				local lines = { "Title: " .. book.title, "Author: " .. (book.author or "Unknown") }
				if book.language then table.insert(lines, "Language: " .. book.language) end
				if book.date then table.insert(lines, "Date: " .. book.date) end
				table.insert(lines, "")
				table.insert(lines, "Progress: " .. entry.value.progress .. "% (Chapter " .. book.chapter .. "/" .. book.total_chapters .. ")")
				table.insert(lines, "Last opened: " .. entry.value.last_opened)
				if book.description and book.description ~= "" then
					table.insert(lines, ""); table.insert(lines, "Description:")
					local desc = book.description; local wrap_width = 60
					while #desc > 0 do
						if #desc <= wrap_width then table.insert(lines, "  " .. desc); break
						else
							local break_pos = desc:sub(1, wrap_width):match(".*()%s") or wrap_width
							table.insert(lines, "  " .. desc:sub(1, break_pos))
							desc = desc:sub(break_pos + 1):match("^%s*(.*)$") or ""
						end
					end
				end
				table.insert(lines, ""); table.insert(lines, "Path: " .. book.path)
				vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
			end
		}),
		sorter = conf.values.generic_sorter({}),
		attach_mappings = function(prompt_bufnr, map)
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				local book = selection.book
				M.open_related_book(book)
			end)
			return true
		end,
	}):find()
end

-- Open a related book
function M.open_related_book(book)
	local ui = require("ink.ui")
	local ok, data = library.open_book(book.path, book.format)
	if ok then
		ui.open_book(data, { in_new_tab = true })
	else
		vim.notify("Failed to open related book: " .. book.title .. " (" .. tostring(data) .. ")", vim.log.levels.ERROR)
	end
end

-- Show library telescope for adding related books
function M.add_related_resource()
	local ctx = context.current()
	if not ctx or not ctx.data then
		vim.notify("No book currently open", vim.log.levels.WARN)
		return
	end

	local current_book_slug = ctx.data.slug
	local books = library.get_books()

	-- Filter out current book
	local other_books = {}
	for _, book in ipairs(books) do
		if book.slug ~= current_book_slug then
			table.insert(other_books, book)
		end
	end

	local pickers = require('telescope.pickers')
	local finders = require('telescope.finders')
	local conf = require('telescope.config')
	local actions = require('telescope.actions')
	local action_state = require('telescope.actions.state')
	local previewers = require('telescope.previewers')

	local entries = {}
	for _, book in ipairs(other_books) do
		local progress = math.floor((book.chapter / book.total_chapters) * 100)
		local last_opened = library.format_last_opened(book.last_opened)
		local author = book.author or "Unknown"
		local tag = book.tag or ""
		local title_str = fit_string(book.title, 30)
		local author_str = fit_string(author, 20)
		local tag_str = fit_string(tag, 15)
		local progress_str = string.format("%3d%%", progress)

		table.insert(entries, {
			display = string.format("%s │ %s │ %s │ %s │ %s", title_str, author_str, tag_str, progress_str, last_opened),
			ordinal = book.title .. " " .. author .. " " .. tag,
			book = book,
			progress = progress,
			last_opened = last_opened,
			author = author
		})
	end

	pickers.new({}, {
		prompt_title = "Add Related Resource (Enter: add)",
		finder = finders.new_table({
			results = entries,
			entry_maker = function(entry)
				return { value = entry, display = entry.display, ordinal = entry.ordinal, book = entry.book }
			end
		}),
		previewer = previewers.new_buffer_previewer({
			title = "Book Info",
			define_preview = function(self, entry)
				local book = entry.book
				local lines = { "Title: " .. book.title, "Author: " .. (book.author or "Unknown") }
				if book.language then table.insert(lines, "Language: " .. book.language) end
				if book.date then table.insert(lines, "Date: " .. book.date) end
				table.insert(lines, "")
				table.insert(lines, "Progress: " .. entry.value.progress .. "% (Chapter " .. book.chapter .. "/" .. book.total_chapters .. ")")
				table.insert(lines, "Last opened: " .. entry.value.last_opened)
				if book.description and book.description ~= "" then
					table.insert(lines, ""); table.insert(lines, "Description:")
					local desc = book.description; local wrap_width = 60
					while #desc > 0 do
						if #desc <= wrap_width then table.insert(lines, "  " .. desc); break
						else
							local break_pos = desc:sub(1, wrap_width):match(".*()%s") or wrap_width
							table.insert(lines, "  " .. desc:sub(1, break_pos))
							desc = desc:sub(break_pos + 1):match("^%s*(.*)$") or ""
						end
					end
				end
				table.insert(lines, ""); table.insert(lines, "Path: " .. book.path)
				vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
			end
		}),
		sorter = conf.values.generic_sorter({}),
		attach_mappings = function(prompt_bufnr, map)
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				local book = selection.book
				local success = related.add_related(current_book_slug, book.slug)
				if success then
					vim.notify("Added related resource: " .. book.title, vim.log.levels.INFO)
				else
					vim.notify("Failed to add related resource", vim.log.levels.ERROR)
				end
			end)
			return true
		end,
	}):find()
end

return M