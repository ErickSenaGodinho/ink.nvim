# Debug Mode

## Performance Profiling

Para debugar performance e verificar cache, descomente as linhas marcadas com `-- DEBUG` nos arquivos:

### EPUB (`lua/ink/epub/init.lua`)

**Linha ~117** - Timer inicial:
```lua
function M.open(epub_path, opts)
  local start_time = vim.loop.hrtime()  -- DEBUG: Start timing
```

**Linhas ~154-162** - Mensagens de cache:
```lua
if needs_extraction then
  vim.notify("📦 Extracting EPUB to cache...", vim.log.levels.INFO)  -- DEBUG
  local success = fs.unzip(epub_path, cache_dir)
  if not success then error("Failed to unzip epub") end

  fs.write_file(extraction_flag, tostring(os.time()))
  vim.notify("✅ EPUB extracted to cache", vim.log.levels.INFO)  -- DEBUG
else
  vim.notify("⚡ Using cached EPUB (no extraction needed)", vim.log.levels.INFO)  -- DEBUG
end
```

**Linhas ~228-230** - Timer final:
```lua
-- DEBUG: Calculate elapsed time
local end_time = vim.loop.hrtime()
local elapsed_ms = (end_time - start_time) / 1000000
vim.notify(string.format("⏱️  EPUB parsing took %.0f ms", elapsed_ms), vim.log.levels.INFO)
```

### Markdown (`lua/ink/markdown/init.lua`)

**Linha ~21** - Timer inicial:
```lua
function M.open(filepath)
  local start_time = vim.loop.hrtime()  -- DEBUG: Start timing
```

**Linhas ~64-66** - Timer final:
```lua
-- DEBUG: Calculate elapsed time
local end_time = vim.loop.hrtime()
local elapsed_ms = (end_time - start_time) / 1000000
vim.notify(string.format("⏱️  Markdown parsing took %.0f ms", elapsed_ms), vim.log.levels.INFO)
```

## Como Habilitar

1. Abra o arquivo apropriado
2. Descomente as linhas marcadas com `-- DEBUG`
3. Salve e recarregue Neovim

## Output Esperado

### EPUB (primeira vez):
```
📦 Extracting EPUB to cache...
✅ EPUB extracted to cache
⏱️  EPUB parsing took 2500 ms
```

### EPUB (com cache):
```
⚡ Using cached EPUB (no extraction needed)
⏱️  EPUB parsing took 800 ms
```

### Markdown:
```
⏱️  Markdown parsing took 50 ms
```

## Análise de Performance

### Tempos Normais

| Operação | Tempo Esperado | Notas |
|----------|----------------|-------|
| EPUB extração (primeira vez) | 1000-3000 ms | Depende do tamanho do arquivo |
| EPUB parsing (cache) | 500-1500 ms | Parsing XML + TOC |
| Markdown parsing | 20-200 ms | Depende do tamanho do arquivo |

### Gargalos Comuns

**EPUB lento mesmo com cache:**
- Muitos capítulos (>100)
- TOC generation from content (sem TOC no EPUB)
- CSS parsing complexo

**Markdown lento:**
- Arquivo muito grande (>10 MB)
- Muitos capítulos (>50 H1s)
- HTML conversion pesado

**Renderização lenta:**
- Não aparece nos timers acima
- Medida na `ui/render.lua`
- Depende de `max_width` e justificação

## Desabilitar Debug

Comente novamente as linhas para produção (performance mínima overhead).
