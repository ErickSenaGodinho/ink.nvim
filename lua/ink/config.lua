local M = {}

local default_config = {
  -- Display settings
  focused_mode = true, -- Hide distractions (statusline, etc.) when reading
  reading_paragraph_mode = false, -- Highlight current paragraph for better focus
  image_open = true, -- Allow opening images in external viewer
  image_viewer = "nsxiv", -- Image viewer: "default", "feh", "sxiv", "imv", "eog", "gwenview", etc.
  justify_text = false, -- Enable text justification (adds spaces between words, affects copying)
  max_width = 120, -- Maximum text width in columns
  width_step = 10, -- Width change amount per keypress (+/-)
  adaptive_width = true, -- Auto-adjust width based on window size
  adaptive_width_margin = 0.8, -- Use 80% of window width (0.1-1.0, maintains margins on sides)

  -- Navigation and interaction keymaps
  keymaps = {
    next_chapter = "]c",
    prev_chapter = "[c",
    toggle_toc = "<leader>t",
    activate = "<CR>", -- Preview/open footnote, link, image, or TOC item
    jump_to_link = "g<CR>", -- Jump directly to link target
    search_toc = "<leader>pit",
    search_content = "<leader>pif",
    search_mode_toggle = "<C-f>", -- Switch between TOC and content search in Telescope
    width_increase = "<leader>+",
    width_decrease = "<leader>-",
    width_reset = "<leader>=", -- Reset to adaptive width
    toggle_justify = "<leader>jt",
    library = "<leader>iL",
    last_book = "<leader>il",
    dashboard = "<leader>id",
    toggle_focused_mode = "<leader>imf",
    toggle_reading_paragraph_mode = "<leader>imr",
    related_resources = "<leader>ir", -- List related books
  },
  -- Highlight colors (add custom colors: purple, orange, pink, etc.)
  highlight_colors = {
    yellow = { bg = "#E8C89F", fg = "#000000" },
    green = { bg = "#8BB894", fg = "#000000" },
    red = { bg = "#D97B73", fg = "#000000" },
    blue = { bg = "#7BA3D0", fg = "#000000" },
    none = { bg = "NONE", fg = "NONE" },
  },

  -- Highlight keymaps (in visual mode)
  highlight_keymaps = {
    yellow = "<leader>hy",
    green = "<leader>hg",
    red = "<leader>hr",
    blue = "<leader>hb",
    remove = "<leader>hd",
  },

  -- Change highlight color (preserves notes)
  highlight_change_color_keymaps = {
    yellow = "<leader>hcy",
    green = "<leader>hcg",
    red = "<leader>hcr",
    blue = "<leader>hcb",
  },

  -- Notes keymaps
  note_keymaps = {
    add = "<leader>na", -- Add/edit note on highlight
    remove = "<leader>nd",
    toggle_display = "<leader>nt", -- Cycle: off → indicator → margin → expanded
  },
  note_display_mode = "margin", -- Default display mode: "off" | "indicator" | "margin" | "expanded"
  margin_note_width = 35, -- Max width of margin notes (chars)
  margin_min_space = 30, -- Min margin space required for margin mode (chars)
  notes_list_keymaps = {
    list_all = "<leader>nl", -- List notes from all books
    list_book = "<leader>nb", -- List notes from current book
  },

  -- Bookmarks keymaps
  bookmark_keymaps = {
    add = "<leader>ma",
    edit = "<leader>me",
    remove = "<leader>md",
    next = "<leader>mn", -- Navigate across chapters
    prev = "<leader>mp",
    list_all = "<leader>ml", -- Global bookmarks list
    list_book = "<leader>mb", -- Current book bookmarks
  },
  bookmark_icon = "📑",

  -- Export keymaps
  export_keymaps = {
    current_book = "<leader>ix",
  },
  export_defaults = {
    format = "markdown", -- "markdown" | "json"
    include_bookmarks = false, -- Include bookmarks in export
    include_context = false, -- Include surrounding text for highlights
    include_glossary = false, -- Include glossary terms and relationships
    export_dir = "~/Documents",
  },

  -- Typography settings
  typography = {
    line_spacing = 1, -- Lines between text lines (1 = normal, 2 = double space)
    paragraph_spacing = 1, -- Lines between paragraphs
    indent_size = 4, -- Indent for blockquotes, code blocks, definitions
    list_indent = 2, -- Indent for nested lists
  },
  typography_keymaps = {
    line_spacing_increase = "<leader>l+",
    line_spacing_decrease = "<leader>l-",
    line_spacing_reset = "<leader>l=",
    paragraph_spacing_increase = "<leader>p+",
    paragraph_spacing_decrease = "<leader>p-",
    paragraph_spacing_reset = "<leader>p=",
  },

  -- Reading session tracking
  tracking = {
    enabled = true, -- Track reading time and sessions
    auto_save_interval = 300, -- Save interval in seconds (5 min)
    cleanup_after_days = 365, -- Clean old sessions (0 = never)
    grace_period = 1, -- Days of grace for streak continuation
  },

  -- Glossary term types (customize icons and colors)
  glossary_types = {
    character = { icon = "👤", color = "InkGlossaryCharacter" },
    place = { icon = "📍", color = "InkGlossaryPlace" },
    concept = { icon = "💡", color = "InkGlossaryConcept" },
    organization = { icon = "🏛️", color = "InkGlossaryOrg" },
    object = { icon = "⚔️", color = "InkGlossaryObject" },
    event = { icon = "⚡", color = "InkGlossaryEvent" },
    foreign_word = { icon = "🌐", color = "InkGlossaryForeign" },
    other = { icon = "📝", color = "InkGlossary" },
  },
  glossary_visible = true, -- Show glossary terms underlined in text
  glossary_keymaps = {
    add = "<leader>iga",
    edit = "<leader>ige",
    remove = "<leader>igd",
    preview = "<leader>igp", -- Show definition in floating window
    browser = "<leader>igl", -- Browse all entries with Telescope
    show_related = "<leader>igr", -- Show related terms (relationships)
    show_graph = "<leader>igg", -- Visualize term relationships (ASCII/HTML)
    toggle_display = "<leader>igt", -- Toggle term underlining on/off
  },

  -- TOC configuration
  force_content_toc = false, -- Build TOC from content headings instead of EPUB metadata

  -- Padnotes configuration (chapter-specific markdown notes)
  padnotes = {
    enabled = true,
    path = "default", -- "default" or custom with {slug}, {author}, {title} placeholders
    auto_save_interval = 120, -- Auto-save interval in seconds
    template = "default", -- Custom template (future feature)
    position = "right", -- "right" | "left" | "top" | "bottom"
    size = 0.5, -- < 1: percentage (0.5 = 50%), >= 1: absolute columns/lines
  },
  padnotes_keymaps = {
    toggle = "<leader>pa", -- Smart toggle: create/open/close/switch chapters
    open = "<leader>po",
    close = "<leader>pc",
    list_all = "<leader>pl", -- Browse all padnotes with Telescope
  },

  -- Related resources (link books together)
  related_resources = {
    position = "right", -- Where to open related book
    show_toc = false, -- Show TOC when opening (false to avoid clutter)
  },
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", default_config, opts or {})
  return M.config
end

function M.get()
  return M.config
end

return M
