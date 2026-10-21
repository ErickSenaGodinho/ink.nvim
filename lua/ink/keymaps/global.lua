local M = {}

--- Declarative list of global keymaps.
--- `group` is the key inside the plugin config that holds the lhs table,
--- `key` is the entry inside that table, `cmd` is the Ex command to run.
local specs = {
  { group = "keymaps", key = "library", cmd = "InkLibrary", desc = "Open library" },
  { group = "keymaps", key = "last_book", cmd = "InkLast", desc = "Open last book" },
  { group = "bookmark_keymaps", key = "list_all", cmd = "InkBookmarks", desc = "List all bookmarks" },
  { group = "notes_list_keymaps", key = "list_all", cmd = "InkNotes", desc = "List all notes" },
  { group = "keymaps", key = "dashboard", cmd = "InkDashboard", desc = "Open dashboard" },
}

---@param config table plugin config (M.config)
function M.setup(config)
  config = config or {}

  for _, spec in ipairs(specs) do
    local group = config[spec.group] or {}
    local lhs = group[spec.key]

    if lhs then
      vim.keymap.set("n", lhs, ":" .. spec.cmd .. "<CR>", {
        noremap = true,
        silent = true,
        desc = spec.desc,
      })
    end
  end
end

return M
