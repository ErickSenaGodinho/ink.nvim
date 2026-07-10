local context = require("ink.ui.context")
local user_highlights = require("ink.user_highlights")
local bookmarks_data = require("ink.bookmarks")
local util = require("ink.ui.util")

local M = {}

-- Track which chapters have already shown orphan warnings (per session)
local orphan_warnings_shown = {}

-- Helper: extract the buffer text covered by a [start_line, start_col, end_line, end_col)
-- range (1-indexed lines, 0-indexed cols) from an in-memory lines table.
-- Used to validate cached highlight positions before trusting them.
local function get_text_for_range(lines, start_line, start_col, end_line, end_col)
    if not lines[start_line] then return nil end

    if start_line == end_line then
        return lines[start_line]:sub(start_col + 1, end_col)
    end

    local parts = { lines[start_line]:sub(start_col + 1) }
    for l = start_line + 1, end_line - 1 do
        if not lines[l] then return nil end
        table.insert(parts, lines[l])
    end
    if not lines[end_line] then return nil end
    table.insert(parts, lines[end_line]:sub(1, end_col))

    return table.concat(parts, "\n")
end

function M.apply_syntax_highlights(buf, highlights, ns_id, padding)
    padding = padding or 0
    if not highlights or #highlights == 0 then return end

    -- Get all lines once (batch read)
    local line_count = vim.api.nvim_buf_line_count(buf)
    local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    -- Prepare extmarks in batch
    local extmarks_to_apply = {}

    for _, hl in ipairs(highlights) do
        local line_idx = hl[1] - 1
        local start_col = hl[2]
        local end_col = hl[3]

        if line_idx >= 0 and line_idx < line_count then
            local line_length = #all_lines[line_idx + 1]
            -- Columns are 0-indexed: valid range is [0, line_length)
            -- Skip highlight if start position is beyond line length (invalid data)
            if start_col < line_length then
                -- Clamp valid positions to line bounds
                start_col = math.max(0, start_col)
                end_col = math.min(end_col, line_length)

                if start_col < end_col then
                    table.insert(extmarks_to_apply, {
                        line_idx = line_idx,
                        col = start_col,
                        opts = {
                            end_col = end_col,
                            hl_group = hl[4],
                            priority = 1000,
                            hl_mode = "combine"
                        }
                    })
                end
            end
        end
    end

    -- Apply all extmarks (still sequential but with pre-validated data)
    for _, mark in ipairs(extmarks_to_apply) do
        vim.api.nvim_buf_set_extmark(buf, ns_id, mark.line_idx, mark.col, mark.opts)
    end
end

function M.apply_user_highlights(buf, chapter_highlights, ns_id, lines, slug, chapter_idx)
    local orphaned_count = 0
    local rendered_count = 0

    -- Get buffer line count for bounds validation
    local buf_line_count = vim.api.nvim_buf_line_count(buf)

    for _, hl in ipairs(chapter_highlights) do
        local start_line, start_col, end_line, end_col

        -- Try to get cached position first (avoids expensive text search on refresh)
        local cached = user_highlights.get_cached_position(slug, chapter_idx, hl)
        if cached and cached.start_line and cached.end_line then
            -- Validate the cache against current buffer contents before trusting it.
            -- If the underlying text changed (re-fetch, edit, translation swap, etc.)
            -- the cached coordinates may now point at unrelated text.
            local cached_text = get_text_for_range(
                lines, cached.start_line, cached.start_col, cached.end_line, cached.end_col
            )
            if cached_text == hl.text then
                start_line = cached.start_line
                start_col = cached.start_col
                end_line = cached.end_line
                end_col = cached.end_col
            end
        end

        -- If no valid cached position, calculate via text matching
        if not start_line or type(start_line) ~= "number" or start_line < 1 then
            start_line, start_col, end_line, end_col = util.find_text_position(
                lines, hl.text, hl.context_before, hl.context_after, false
            )
            -- Cache the calculated position if valid
            if start_line and start_line >= 1 then
                user_highlights.cache_position(slug, chapter_idx, hl, start_line, start_col, end_line, end_col)
            end
        end

        if start_line and type(start_line) == "number" and type(end_line) == "number" then
            -- Relaxed validation: only check basic requirements
            if start_line > 0 and start_line <= buf_line_count and end_line > 0 and end_line <= buf_line_count then
                -- Store position for note indicators
                hl._start_line = start_line
                hl._start_col = start_col
                hl._end_line = end_line
                hl._end_col = end_col

                local hl_group = "InkUserHighlight_" .. hl.color
                vim.api.nvim_buf_set_extmark(buf, ns_id, start_line - 1, start_col, {
                    end_line = end_line - 1, end_col = end_col, hl_group = hl_group, priority = 2000
                })
                rendered_count = rendered_count + 1
            else
                orphaned_count = orphaned_count + 1
            end
        else
            orphaned_count = orphaned_count + 1
        end
    end

    -- Notify user if some highlights could not be rendered (once per chapter per session)
    if slug and chapter_idx then
        local warning_key = slug .. ":" .. chapter_idx
        if orphaned_count > 0 then
            if not orphan_warnings_shown[warning_key] then
                orphan_warnings_shown[warning_key] = true
                vim.notify(
                    string.format(
                        "One or more highlights could not be rendered (%d/%d). Text may have been modified or removed.",
                        orphaned_count,
                        orphaned_count + rendered_count
                    ),
                    vim.log.levels.WARN
                )
            end
        else
            -- All highlights rendered cleanly this pass: clear any stale warning flag
            -- so a future regression for this chapter is surfaced again.
            orphan_warnings_shown[warning_key] = nil
        end
    end

    return { rendered = rendered_count, orphaned = orphaned_count }
end

-- Helper: draw the inline "●" indicator for a note at a validated position.
local function draw_note_dot(buf, ns_id, line_idx, end_col)
    vim.api.nvim_buf_set_extmark(buf, ns_id, line_idx, end_col, {
        virt_text = { { "●", "InkNoteIndicator" } }, virt_text_pos = "inline", priority = 3000
    })
end

function M.apply_note_indicators(buf, chapter_highlights, note_display_mode, padding, max_width, ns_id)
    if note_display_mode == "off" then return end

    local notes_by_line = {}
    for _, hl in ipairs(chapter_highlights) do
        if hl.note and hl.note ~= "" and hl._end_line and hl._end_col then
            local end_line = hl._end_line
            local end_col = hl._end_col
            -- Validate the position is reasonable
            if end_line > 0 and end_col >= 0 then
                if not notes_by_line[end_line] then notes_by_line[end_line] = {} end
                table.insert(notes_by_line[end_line], { hl = hl, end_col = end_col })
            end
        end
    end

    for line, notes in pairs(notes_by_line) do
        table.sort(notes, function(a, b) return a.end_col < b.end_col end)
    end

    for line, notes in pairs(notes_by_line) do
        local line_idx = line - 1
        local line_count = vim.api.nvim_buf_line_count(buf)
        if line_idx >= 0 and line_idx < line_count then
            -- Get actual line length for validation
            local buf_lines = vim.api.nvim_buf_get_lines(buf, line_idx, line_idx + 1, false)
            local line_len = buf_lines and #buf_lines[1] or 0

            if note_display_mode == "indicator" then
                for _, note_info in ipairs(notes) do
                    -- Validate column is within line bounds
                    if note_info.end_col >= 0 and note_info.end_col <= line_len then
                        draw_note_dot(buf, ns_id, line_idx, note_info.end_col)
                    end
                end
            elseif note_display_mode == "expanded" then
                for _, note_info in ipairs(notes) do
                    -- Validate column is within line bounds
                    if note_info.end_col >= 0 and note_info.end_col <= line_len then
                        draw_note_dot(buf, ns_id, line_idx, note_info.end_col)
                    end
                end
                local virt_lines = {}
                for i, note_info in ipairs(notes) do
                    local bars = string.rep("│", i)
                    local note_text = note_info.hl.note:gsub("\n", " ")
                    local max_note_len = max_width - #bars - 2
                    if #note_text > max_note_len then note_text = note_text:sub(1, max_note_len - 3) .. "..." end
                    local pad = string.rep(" ", padding)
                    table.insert(virt_lines, { { pad .. bars .. " " .. note_text, "InkNoteText" } })
                end
                if #virt_lines > 0 then
                    vim.api.nvim_buf_set_extmark(buf, ns_id, line_idx, 0, {
                        virt_lines = virt_lines, virt_lines_above = false, priority = 3000
                    })
                end
            end
        end
    end
end

function M.apply_bookmarks(buf, chapter_bookmarks, padding, bookmark_icon, ns_id, lines, max_width)
    -- Group bookmarks by line
    local bookmarks_by_line = {}

    for _, bm in ipairs(chapter_bookmarks) do
        local line_idx = nil

        -- New bookmarks use text-matching for position independence
        if bm.paragraph_text then
            local start_line = util.find_text_position(
                lines,
                bm.paragraph_text,
                bm.context_before,
                bm.context_after
            )
            if start_line then
                line_idx = start_line - 1
                bm._line_idx = start_line  -- Cache for navigation
            end
        -- Legacy bookmarks use line-based positioning
        elseif bm.paragraph_line then
            line_idx = bm.paragraph_line - 1
            bm._line_idx = bm.paragraph_line
        end

        if line_idx and line_idx >= 0 and line_idx < #lines then
            if not bookmarks_by_line[line_idx] then
                bookmarks_by_line[line_idx] = {}
            end
            table.insert(bookmarks_by_line[line_idx], bm)
        end
    end

    -- Render bookmarks (multiple per line if needed)
    for line_idx, bms in pairs(bookmarks_by_line) do
        local pad = string.rep(" ", padding)

        -- If single bookmark, use simple format
        if #bms == 1 then
            vim.api.nvim_buf_set_extmark(buf, ns_id, line_idx, 0, {
                virt_lines = { { { pad .. bookmark_icon .. " " .. bms[1].name, "InkBookmark" } } },
                virt_lines_above = true,
                priority = 4000,
            })
        else
            -- Multiple bookmarks: join with " | " separator
            max_width = max_width or 120
            local available_width = max_width - 10  -- Reserve some margin
            local separator = " | "
            local prefix = bookmark_icon .. " "

            -- Calculate how much space each bookmark can use
            local separator_total = vim.fn.strwidth(separator) * (#bms - 1)
            local prefix_width = vim.fn.strwidth(prefix)
            local space_for_names = available_width - prefix_width - separator_total
            local max_name_width = math.floor(space_for_names / #bms)

            -- Ensure minimum width of 15 chars per bookmark
            if max_name_width < 15 then
                max_name_width = 15
            end

            -- Build bookmark text with truncation
            local bookmark_text = prefix
            for i, bm in ipairs(bms) do
                local name = bm.name
                local name_width = vim.fn.strwidth(name)

                -- Truncate if needed
                if name_width > max_name_width then
                    -- Truncate to fit with "..." (3 chars)
                    local target_width = max_name_width - 3
                    local truncated = ""
                    local current_width = 0

                    for j = 1, vim.fn.strchars(name) do
                        local char = vim.fn.strcharpart(name, j - 1, 1)
                        local char_width = vim.fn.strwidth(char)
                        if current_width + char_width > target_width then
                            break
                        end
                        truncated = truncated .. char
                        current_width = current_width + char_width
                    end

                    name = truncated .. "..."
                end

                bookmark_text = bookmark_text .. name
                if i < #bms then
                    bookmark_text = bookmark_text .. separator
                end
            end

            vim.api.nvim_buf_set_extmark(buf, ns_id, line_idx, 0, {
                virt_lines = { { { pad .. bookmark_text, "InkBookmark" } } },
                virt_lines_above = true,
                priority = 4000,
            })
        end
    end
end

-- Helper: Resolve note conflicts by separating left/right margins
local function resolve_note_conflicts(notes)
    -- Separate notes by side (left/right)
    local left_notes = {}
    local right_notes = {}

    for _, note_info in ipairs(notes) do
        if note_info.is_left then
            table.insert(left_notes, note_info)
        else
            table.insert(right_notes, note_info)
        end
    end

    -- Sort each side by start line
    table.sort(left_notes, function(a, b) return a.start_line < b.start_line end)
    table.sort(right_notes, function(a, b) return a.start_line < b.start_line end)

    -- Resolve conflicts on left side
    local last_left_end = -1
    for _, note_info in ipairs(left_notes) do
        local display_line = note_info.start_line

        -- Add 1 line gap between stacked notes
        if display_line <= last_left_end then
            display_line = last_left_end + 2
        end

        note_info.display_line = display_line
        last_left_end = display_line + note_info.lines_count - 1
    end

    -- Resolve conflicts on right side
    local last_right_end = -1
    for _, note_info in ipairs(right_notes) do
        local display_line = note_info.start_line

        -- Add 1 line gap between stacked notes
        if display_line <= last_right_end then
            display_line = last_right_end + 2
        end

        note_info.display_line = display_line
        last_right_end = display_line + note_info.lines_count - 1
    end

    -- Merge back (order doesn't matter)
    local adjusted = {}
    for _, note in ipairs(left_notes) do
        table.insert(adjusted, note)
    end
    for _, note in ipairs(right_notes) do
        table.insert(adjusted, note)
    end

    return adjusted
end

-- Helper: Apply a single margin note with numeric indicator
local function apply_single_margin_note(buf, note_info, margin_width, ns_id)
    local hl = note_info.hl
    local is_left = note_info.is_left
    local note_column = note_info.note_column
    local wrapped_lines = note_info.wrapped_lines
    local display_line = note_info.display_line
    local note_number = note_info.note_number

    -- Numeric indicator on the highlight line (at end of highlight)
    local indicator = "[^" .. note_number .. "]"
    vim.api.nvim_buf_set_extmark(buf, ns_id, hl._end_line - 1, hl._end_col, {
        virt_text = {{indicator, "InkNoteIndicator"}},
        virt_text_pos = "inline",
        priority = 3000
    })

    -- Note text lines in margin
    for i, line_text in ipairs(wrapped_lines) do
        -- First line uses display_line (adjusted for conflicts), continuation lines flow below
        local line_idx = display_line - 1 + (i - 1)

        -- Add note number prefix on first line, indent continuation lines
        local prefixed_text
        if i == 1 then
            prefixed_text = indicator .. " " .. line_text
        else
            -- Indent continuation lines to align with text after number
            prefixed_text = "    " .. line_text
        end

        -- Format text based on side
        local virt_text
        local text_column = note_column
        local line_width = vim.fn.strwidth(prefixed_text)

        if is_left then
            -- Left: align to the right (close to content)
            local padding_needed = margin_width - line_width
            if padding_needed > 0 then
                local pad = string.rep(" ", padding_needed)
                virt_text = {{pad .. prefixed_text, "InkNoteText"}}
            else
                virt_text = {{prefixed_text, "InkNoteText"}}
            end
        else
            -- Right: left-aligned (natural for reading)
            virt_text = {{prefixed_text, "InkNoteText"}}
        end

        vim.api.nvim_buf_set_extmark(buf, ns_id, line_idx, 0, {
            virt_text = virt_text,
            virt_text_win_col = text_column,
            priority = 2900
        })
    end
end

-- Main function: Apply margin notes using window columns
function M.apply_margin_notes(buf, highlights, padding, max_width, win_width, ns_id, notify_on_fail)
    -- Require Neovim 0.10+
    if vim.fn.has('nvim-0.10') == 0 then
        return false  -- fallback to expanded
    end

    local margin_width = context.config.margin_note_width or 35

    -- Calculate spacing proportional to available padding
    -- More padding (smaller max_width) = more spacing between text and notes
    -- Formula: 4 chars base + (padding / 40) adaptive spacing
    -- Examples (1366px screen):
    --   max_width=120, padding=623 → spacing = 4 + 15 = 19 chars
    --   max_width=100, padding=633 → spacing = 4 + 15 = 19 chars
    --   max_width=80,  padding=643 → spacing = 4 + 16 = 20 chars
    -- Limits: min 4 chars (tight), max 20 chars (comfortable)
    local spacing = math.max(4, math.min(20, 4 + math.floor(padding / 40)))

    -- Check if there's enough margin space for notes + spacing
    -- Need at least: margin_width + spacing
    local min_space_required = margin_width + spacing
    if padding < min_space_required then
        -- Only notify if user explicitly toggled to margin mode
        if notify_on_fail then
            vim.notify("Not enough space. Fallback to expanded mode", vim.log.levels.INFO)
        end
        return false  -- fallback to expanded
    end

    local notes_with_positions = {}

    -- Phase 1: Collect notes and calculate positions
    for _, hl in ipairs(highlights) do
        if hl.note and hl.note ~= "" and hl._start_line then
            local highlight_col = hl._start_col or 0
            local line_center = max_width / 2
            local is_left = highlight_col < line_center

            -- Calculate note column with proportional spacing
            local note_column
            if is_left then
                -- Left margin: padding - margin_width - spacing
                -- Ensure note doesn't go off-screen (column >= 0)
                note_column = math.max(0, padding - margin_width - spacing)
            else
                -- Right margin: padding + max_width + spacing
                -- Ensure note doesn't exceed window width
                local max_right_col = win_width - margin_width
                note_column = math.min(padding + max_width + spacing, max_right_col)
            end

            -- Word wrap the note (reserve 4 chars for "(N) " prefix on first line)
            local text_width = margin_width - 4
            local wrapped_lines = util.wrap_note_text(hl.note, text_width)

            -- Limit to 10 lines max
            local MAX_NOTE_LINES = 10
            if #wrapped_lines > MAX_NOTE_LINES then
                wrapped_lines = vim.list_slice(wrapped_lines, 1, MAX_NOTE_LINES)
                -- Add "..." on a separate line to avoid text overlap
                table.insert(wrapped_lines, "...")
            end

            table.insert(notes_with_positions, {
                hl = hl,
                is_left = is_left,
                note_column = note_column,
                wrapped_lines = wrapped_lines,
                start_line = hl._start_line,
                lines_count = #wrapped_lines
            })
        end
    end

    -- Phase 2: Sort by line order and assign sequential numbers
    table.sort(notes_with_positions, function(a, b)
        if a.start_line == b.start_line then
            -- Same line: left side first, then by column
            if a.is_left ~= b.is_left then
                return a.is_left
            end
            return (a.hl._start_col or 0) < (b.hl._start_col or 0)
        end
        return a.start_line < b.start_line
    end)

    -- Assign sequential note numbers
    for i, note_info in ipairs(notes_with_positions) do
        note_info.note_number = i
    end

    -- Phase 3: Conflict Detection & Adjustment
    notes_with_positions = resolve_note_conflicts(notes_with_positions)

    -- Phase 4: Apply extmarks
    for _, note_info in ipairs(notes_with_positions) do
        apply_single_margin_note(buf, note_info, margin_width, ns_id)
    end

    return true
end

function M.apply_glossary_marks(buf, matches, entries_map, custom_types, ns_id)
    if not matches or #matches == 0 then return end

    local context_config = require("ink.ui.context").config
    local types_config = vim.tbl_extend("force",
        context_config.glossary_types or {},
        custom_types or {}
    )

    -- Get all lines for bounds checking
    local line_count = vim.api.nvim_buf_line_count(buf)
    local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    for _, match in ipairs(matches) do
        local entry = entries_map[match.entry_id]
        if entry then
            local type_info = types_config[entry.type] or
                { icon = "📝", color = "InkGlossary" }

            -- Use different icon for aliases
            local icon = type_info.icon
            local color = type_info.color
            if match.is_alias then
                icon = "→"  -- Arrow icon for aliases
                color = "InkGlossaryAlias"
            end

            -- Convert from 1-based to 0-based (match.line is already correct for the buffer)
            -- DO NOT add padding here - padding is virtual and doesn't affect buffer positions
            local line_idx = match.line - 1

            -- Bounds checking
            if line_idx >= 0 and line_idx < line_count then
                local line_length = #all_lines[line_idx + 1]
                local start_col = math.min(match.start_col, line_length)
                local end_col = math.min(match.end_col, line_length)

                if start_col < end_col then
                    -- Apply underline to the term
                    vim.api.nvim_buf_set_extmark(buf, ns_id, line_idx, start_col, {
                        end_col = end_col,
                        hl_group = "InkGlossaryUnderline",
                        priority = 1500,  -- Between syntax (1000) and user highlights (2000)
                        hl_mode = "combine"
                    })

                    -- Apply icon inline after the term (only if end_col is valid)
                    if end_col <= line_length then
                        vim.api.nvim_buf_set_extmark(buf, ns_id, line_idx, end_col, {
                            virt_text = { { icon, color } },
                            virt_text_pos = "inline",
                            priority = 1500
                        })
                    end
                end
            end
        end
    end
end

local function apply_dim_all(buf, ns, lines)
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

    vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, {
        end_line = vim.api.nvim_buf_line_count(buf),
        end_col = 0,
        hl_group = "InkDimmed",
        priority = 50,
    })

    local ctx = context.current()

    local highlights = user_highlights.get_chapter_highlights(ctx.data.slug, ctx.current_chapter_idx)
    for _, hl in ipairs(highlights) do
        if hl._start_line and hl._start_col and hl._end_line and hl._end_col then
            hl.dimmed_id = vim.api.nvim_buf_set_extmark(ctx.content_buf, context.ns_reading, hl._start_line - 1, hl._start_col, {
                end_line = hl._end_line - 1,
                end_col = hl._end_col,
                hl_group = "InkUserHighlightDim",
                priority = 3000,
                hl_mode = "replace"
            })
        end
    end
end

local function apply_focus(buf, ns, start_l, end_l)
    vim.api.nvim_buf_set_extmark(buf, ns, start_l, 0, {
        end_line = end_l + 1,
        end_col = 0,
        hl_group = "Normal",
        hl_mode = "replace",
        priority = 200,
    })
end

local function update_reading_paragraph_mode(ctx)
    if not ctx then return end

    local cursor = vim.api.nvim_win_get_cursor(ctx.content_win)
    local line = cursor[1] - 1

    local start_l, end_l = util.get_paragraph(ctx.content_buf, line)

    -- Skip the full redraw if the cursor is still inside the same paragraph.
    if ctx._reading_para_start == start_l and ctx._reading_para_end == end_l then
        return
    end
    ctx._reading_para_start = start_l
    ctx._reading_para_end = end_l

    vim.api.nvim_buf_clear_namespace(ctx.content_buf, context.ns_reading, 0, -1)

    apply_dim_all(ctx.content_buf, context.ns_reading, lines)
    apply_focus(ctx.content_buf, context.ns_reading, start_l, end_l)

    local highlights = util.get_highlights_in_range(ctx, start_l, end_l)
    for _, hl in ipairs(highlights) do
        if hl.dimmed_id then
            vim.api.nvim_buf_del_extmark(ctx.content_buf, context.ns_reading, hl.dimmed_id)
        end
    end
end

local function enable_reading_paragraph_mode(ctx)
    -- Reset cached paragraph bounds so the first call after enabling always renders.
    ctx._reading_para_start = nil
    ctx._reading_para_end = nil

    update_reading_paragraph_mode(ctx)

    local buf = vim.api.nvim_win_get_buf(ctx.content_win)
    local group_name = "ReadingMode_Buf_" .. buf
    local group = vim.api.nvim_create_augroup(group_name, { clear = true })

    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        group = group,
        buffer = buf,
        callback = function()
            update_reading_paragraph_mode(ctx)
        end,
    })
end

local function disable_reading_paragraph_mode(ctx)
    if ctx then
        local buf = vim.api.nvim_win_get_buf(ctx.content_win)
        vim.api.nvim_buf_clear_namespace(buf, context.ns_reading, 0, -1)
        vim.api.nvim_del_augroup_by_name("ReadingMode_Buf_" .. buf)
        ctx._reading_para_start = nil
        ctx._reading_para_end = nil
    end
end

function M.toggle_reading_paragraph_mode()
    local ctx = context.current()
    if not ctx then
        vim.notify("No book is currently open", vim.log.levels.WARN)
        return
    end

    ctx.reading_paragraph_mode = not ctx.reading_paragraph_mode

    if ctx.reading_paragraph_mode then
        enable_reading_paragraph_mode(ctx)
    else
        disable_reading_paragraph_mode(ctx)
    end
end

return M