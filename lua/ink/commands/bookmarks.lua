return {
  {
    name = "InkBookmarks",
    fn = function()
      require("ink.ui").show_all_bookmarks()
    end,
  },

  {
    name = "InkBookmarksBook",
    fn = function()
      require("ink.ui").show_book_bookmarks()
    end,
  },
}
