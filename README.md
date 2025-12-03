# ink.nvim

A minimalist, distraction-free EPUB reader for Neovim.

## Features
- Read EPUB files inside Neovim buffers
- Continuous scrolling per chapter
- Navigable table of contents
- Syntax-highlighted text rendered from HTML
- Progress tracking and restoration
- Image extraction and external viewing

## Requirements

- Neovim 0.7+
- `unzip` command (for extracting EPUB files)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "DanielPonte01/ink.nvim",
  config = function()
    require("ink").setup({
      -- Optional configuration (these are the defaults)
      focused_mode = true,
      image_open = true,
      max_width = 120,
      keymaps = {}
    })
  end
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "DanielPonte01/ink.nvim",
  config = function()
    require("ink").setup({
      -- Optional configuration (these are the defaults)
      focused_mode = true,
      image_open = true,
      max_width = 120,
      keymaps = {}
    })
  end
}
```

## Configuration

### Default Configuration

```lua
require("ink").setup({
  focused_mode = true,
  image_open = true,
  max_width = 120,
  keymaps = {}
})
```

### Sample Configuration

Here's a more complete example with custom settings:

```lua
require("ink").setup({
  focused_mode = true,
  image_open = true,
  max_width = 100,
  keymaps = {}
})

vim.keymap.set("n", "<leader>eo", ":InkOpen ", { desc = "Open EPUB file" })

```

## Usage

- `:InkOpen <path/to/book.epub>`: Open an EPUB file.
- `]c`: Next chapter
- `[c`: Previous chapter
- `<leader>t`: Toggle TOC
- `<CR>`: In TOC, jump to chapter; on image, open in viewer

## Testing

A comprehensive test EPUB (`ink-test.epub`) is included to demonstrate all features:

The test book includes:
- Lists (ordered, unordered, nested, mixed)
- Text formatting (bold, italic, underline, strikethrough, highlight)
- Code blocks and inline code
- Blockquotes (simple and nested)
- Definition lists
- Links and anchors
- Images
- Horizontal rules
- All heading levels
