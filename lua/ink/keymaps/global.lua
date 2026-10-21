local M = {}

function M.setup(config)
  local keymaps = config.keymaps or {}

  -- Global keymaps for library features
  if keymaps.library then
    vim.keymap.set("n", keymaps.library, ":InkLibrary<CR>", { noremap = true, silent = true, desc = "Open library" })
  end

  if keymaps.last_book then
    vim.keymap.set("n", keymaps.last_book, ":InkLast<CR>", { noremap = true, silent = true, desc = "Open last book" })
  end

  -- Global keymaps for bookmarks
  local bookmark_keymaps = config.bookmark_keymaps or {}
  if bookmark_keymaps.list_all then
    vim.keymap.set(
      "n",
      bookmark_keymaps.list_all,
      ":InkBookmarks<CR>",
      { noremap = true, silent = true, desc = "List all bookmarks" }
    )
  end

  -- Global keymaps for notes
  local notes_list_keymaps = config.notes_list_keymaps or {}
  if notes_list_keymaps.list_all then
    vim.keymap.set(
      "n",
      notes_list_keymaps.list_all,
      ":InkNotes<CR>",
      { noremap = true, silent = true, desc = "List all notes" }
    )
  end

  -- Global keymap for dashboard
  if keymaps.dashboard then
    vim.keymap.set(
      "n",
      keymaps.dashboard,
      ":InkDashboard<CR>",
      { noremap = true, silent = true, desc = "Open dashboard" }
    )
  end
end

return M
