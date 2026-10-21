return {
  {
    name = "InkNotes",
    fn = function()
      require("ink.notes").show_all_notes()
    end,
  },

  {
    name = "InkNotesBook",
    fn = function()
      require("ink.notes").show_book_notes()
    end,
  },
}
