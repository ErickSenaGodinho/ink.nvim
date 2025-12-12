# Markdown Support in Ink.nvim

## Overview

Ink.nvim now supports reading Markdown files (.md and .markdown) with **identical functionality** to EPUB files.

## Architecture

```
Markdown File (.md)
    ↓
markdown/parser.lua (MD → HTML)
    ↓
html/parser.lua (HTML → plain text + extmarks)
    ↓
ui/render.lua (same rendering as EPUB)
```

## Implementation Details

### Modules

**lua/ink/markdown/** (~800 lines across 5 files):

1. **init.lua** - Main interface
   - `open(filepath)` - Returns EPUB-compatible data structure
   - `is_markdown()` - File format detection
   - Generates slug and metadata

2. **util.lua** - Utility functions
   - `slugify()`, `trim()`, `escape_html()`
   - Heading, list, blockquote, code fence detection
   - Indentation parsing

3. **toc.lua** - Chapter splitting and TOC generation
   - `split_by_h1()` - Splits document by H1 headings
   - `split_by_h2()` - Fallback when no H1 found
   - `build_toc()` - Generates EPUB-compatible TOC

4. **parser.lua** - MD → HTML converter
   - Parses headings, paragraphs, lists, blockquotes, code blocks
   - Proper handling of nested lists and blockquotes
   - State machine with support for mixed content

5. **inline.lua** - Inline element processor
   - Bold, italic, bold+italic
   - Links, images
   - Inline code, strikethrough

### Data Structure

Markdown files are converted to the same structure as EPUBs:

```lua
{
  title = "document",
  author = "Unknown",
  language = "en",
  spine = {
    {
      content = "<html>...</html>",  -- HTML content (MD specific)
      href = "chapter-1",            -- Virtual href for compatibility
      title = "Chapter Title",
      index = 1
    },
    ...
  },
  toc = {
    {
      label = "Chapter Title",
      href = "chapter-1",
      level = 1,
      chapter_index = 1
    },
    ...
  },
  slug = "document-md",
  base_dir = "/path/to/directory",
  path = "/path/to/document.md",
  format = "markdown"
}
```

### Chapter Division

- Documents are split by **H1 headings** (`# Heading`)
- If no H1 found, falls back to **H2 headings** (`## Heading`)
- Each heading becomes a separate "chapter" for navigation

### Supported Markdown Features

**Text Formatting**:
- Bold: `**text**` or `__text__`
- Italic: `*text*` or `_text_`
- Bold + Italic: `***text***` or `___text___`
- Strikethrough: `~~text~~`
- Inline code: `` `code` ``

**Headings**:
- H1-H6: `# ` through `###### `
- Auto-generated IDs for anchors

**Lists**:
- Unordered: `-`, `*`, `+`
- Ordered: `1.`, `2.`, etc.
- Nested lists (properly formatted)
- Mixed lists (ordered inside unordered, vice versa)

**Blockquotes**:
- Simple: `> quote`
- Nested: `> > nested`
- Multiple levels supported

**Code Blocks**:
- Fenced: ` ``` ` or `~~~`
- Language hints supported (e.g., ` ```lua `)

**Other**:
- Horizontal rules: `---`, `***`, `___`
- Links: `[text](url)`
- Images: `![alt](url)`
- Internal anchors: `[text](#anchor)`

### Feature Parity with EPUB

✅ **All EPUB features work with Markdown**:
- Highlights (yellow, green, red, blue)
- Notes/annotations
- Bookmarks
- Search (TOC and full-text)
- Export (Markdown and JSON)
- Text width adjustment
- Text justification
- Library management
- Reading progress tracking

### Commands

```vim
" Open Markdown file
:InkOpen document.md

" Scan directory for .md and .epub files
:InkAddLibrary ~/Documents/

" Open from library
:InkLibrary

" All other commands work identically to EPUB
```

### Keymaps

All keymaps work identically to EPUB files. See main documentation for full list.

### File Locations

**Data storage** (same as EPUB):
- Highlights: `~/.local/share/nvim/ink.nvim/books/{slug}/highlights.json`
- Bookmarks: `~/.local/share/nvim/ink.nvim/books/{slug}/bookmarks.json`
- Progress: `~/.local/share/nvim/ink.nvim/books/{slug}/state.json`
- Library: `~/.local/share/nvim/ink.nvim/library.json`

### Testing

Test file included: `test-markdown.md`

Demonstrates all supported features:
- Text formatting
- Headings (H1-H3)
- Lists (ordered, unordered, nested, mixed)
- Blockquotes (simple and nested)
- Code blocks and inline code
- Links and images
- Horizontal rules

## Implementation Notes

### Compatibility Approach

Instead of creating a separate rendering pipeline, Markdown support:
1. Converts MD → HTML at parse time
2. Reuses entire HTML → text rendering pipeline
3. Minimal changes to existing code (<50 lines modified)

### Virtual Hrefs

Markdown chapters use virtual `href` values (`chapter-1`, `chapter-2`, etc.) to maintain compatibility with EPUB navigation logic.

### Content vs File-based

- **EPUB**: `spine[].href` points to files, content read on demand
- **Markdown**: `spine[].content` contains HTML, no file I/O needed
- `ui/render.lua` detects which format and handles both

### Image Paths

- **EPUB**: Images relative to chapter HTML file
- **Markdown**: Images relative to .md file location
- Security check disabled for Markdown (no cache directory)

## Future Enhancements

Potential improvements:
- YAML frontmatter parsing for metadata (title, author, tags)
- GitHub Flavored Markdown extensions (tables, task lists)
- Custom CSS support via config
- Math rendering (KaTeX/MathJax)
- Mermaid diagram support

## Dependencies

None! Pure Lua implementation with no external dependencies.

## Performance

- Large files divided into chapters for fast rendering
- Parsed HTML cached per chapter
- Async directory scanning for library imports
