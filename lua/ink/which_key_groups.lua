local M = {}

-- Longest common prefix among a list of key strings (e.g. {"<leader>ma", "<leader>me", ...})
local function longest_common_prefix(strings)
    if #strings == 0 then return nil end
    local prefix = strings[1]
    for i = 2, #strings do
        local s = strings[i]
        local j = 1
        while j <= #prefix and j <= #s and prefix:sub(j, j) == s:sub(j, j) do
            j = j + 1
        end
        prefix = prefix:sub(1, j - 1)
        if prefix == "" then break end
    end
    return prefix ~= "" and prefix or nil
end

-- Collect every string value out of a flat keymap table (e.g. config.bookmark_keymaps)
local function collect_keys(tbl)
    local keys = {}
    for _, v in pairs(tbl) do
        if type(v) == "string" then
            table.insert(keys, v)
        end
    end
    return keys
end

-- The character immediately after "<leader>" (or "<localleader>"), if any.
-- e.g. "<leader>itf" -> "i", "<leader>+" -> "+", "gh" -> nil (no leader at all)
local function leader_first_char(key)
    local rest = key:match("^<[Ll]eader>(.+)$") or key:match("^<[Ll]ocalleader>(.+)$")
    if not rest or rest == "" then return nil end
    return rest:sub(1, 1)
end

-- Registers which-key group labels for each ink keymap family, based on whatever
-- prefix the user's *actual* config resolves to (defaults or overridden via setup(opts)).
-- Safe to call even if which-key isn't installed (no-op via pcall).
function M.register(config)
    local ok, wk = pcall(require, "which-key")
    if not ok then return end

    -- name -> keymap table to inspect
    local families = {
        { name = "Ink",            tbl = config.keymaps },
        { name = "Ink Highlights", tbl = config.highlight_keymaps },
        { name = "Ink Notes",      tbl = config.note_keymaps },
        { name = "Ink Bookmarks",  tbl = config.bookmark_keymaps },
        { name = "Ink Glossary",   tbl = config.glossary_keymaps },
        { name = "Ink Padnotes",   tbl = config.padnotes_keymaps },
        { name = "Ink Typography", tbl = config.typography_keymaps },
    }

    local spec = {}
    local seen_prefixes = {}

    for _, family in ipairs(families) do
        if family.tbl then
            local buckets = {}
            for _, key in ipairs(collect_keys(family.tbl)) do
                local first_char = leader_first_char(key)
                if first_char then
                    buckets[first_char] = buckets[first_char] or {}
                    table.insert(buckets[first_char], key)
                end
            end

            for _, bucket_keys in pairs(buckets) do
                if #bucket_keys >= 2 then
                    local prefix = longest_common_prefix(bucket_keys)
                    if prefix and #prefix > #"<leader>" and not seen_prefixes[prefix] then
                        table.insert(spec, { prefix, group = family.name })
                        seen_prefixes[prefix] = true
                    end
                end
                -- Buckets of size 1 are standalone leaves (e.g. toggle_toc) —
                -- they just need their own `desc` on vim.keymap.set, not a group.
            end
        end
    end

    if #spec > 0 then
        wk.add(spec)
    end
end

return M