# Análise de Código e Refatoração: ink.nvim

> Gerado em 2026-10-20 a partir do commit `7b6ac03`.
>
> **Escopo:** 110 arquivos Lua (~25 mil linhas) em `lua/ink/`, mais `README.md` e `ink-test.md`. Todos os arquivos foram lidos por inteiro.
>
> **Como a análise foi feita:**
> - Itens de "código morto" foram conferidos com grep em `lua/`.
> - Bugs marcados com **[testado]** foram reproduzidos com `nvim --headless -u NONE` (Neovim 0.12.5, Windows).
> - Nenhum arquivo do projeto foi alterado. Este documento é só para leitura e planejamento.
>
> **Notação:** `arquivo:linha` é relativo a `lua/ink/`, salvo quando indicado de outra forma.

---

## Sumário

1. [Resumo executivo](#1-resumo-executivo)
2. [Bugs encontrados (corrigir primeiro)](#2-bugs-encontrados-corrigir-primeiro)
3. [Padrões inconsistentes (transversais)](#3-padrões-inconsistentes-transversais)
4. [Código duplicado (transversal)](#4-código-duplicado-transversal)
5. [Código morto / não utilizado](#5-código-morto--não-utilizado)
6. [Organização de módulos e proposta de estrutura](#6-organização-de-módulos-e-proposta-de-estrutura)
7. [Análise por área](#7-análise-por-área)
8. [Desempenho](#8-desempenho)
9. [Números mágicos](#9-números-mágicos)
10. [Funções longas](#10-funções-longas)
11. [Segurança e portabilidade (Windows)](#11-segurança-e-portabilidade-windows)
12. [Divergências entre README e código](#12-divergências-entre-readme-e-código)
13. [Roteiro sugerido de refatoração](#13-roteiro-sugerido-de-refatoração)
14. [Apêndice: convenções por arquivo](#14-apêndice-convenções-por-arquivo)

---

## 1. Resumo executivo

A sensação de que o código está bagunçado se confirma. O que pesa não é a qualidade de cada função isolada, e sim **a falta de convenções comuns**. Cada área do plugin foi escrita com um estilo próprio e reimplementa as mesmas utilidades.

### Números que resumem o problema

| Métrica | Valor |
|---|---|
| Estilos de indentação | **3**: 75 arquivos com 2 espaços, 14 com 4 espaços, 21 com tab (e `ui/search_index.lua` mistura tab e 2 espaços no mesmo arquivo) |
| Arquivos com cabeçalho `-- lua/ink/...` | ~40%, sem critério. Parte deles com "Responsabilidade:" em **português**, o resto do código em inglês |
| Arquivos com anotações LuaCATS válidas (`---@param`) | **1** (`utils.lua`, e com sintaxe não padrão `--- @param`) |
| Implementações de leitura/escrita de JSON | **~17** com `io.open` direto, embora `fs.write_file` e `data.json_decode_safe` já existam |
| Encoders JSON diferentes | **3**: `vim.json.encode`, `data.json_encode` (com bugs) e `to_json` em `html_graph.lua` |
| Arquivos `util`/`utils` | **7**: `utils.lua`, `ui/util.lua`, `html/utils.lua`, `markdown/util.lua`, `epub/util.lua`, `web/util.lua`, `export/util.lua` |
| Implementações de `fit_string`/truncar texto | **5**, com comportamentos diferentes |
| Implementações de formatação de data | **6+** |
| Implementações de `slugify` | **3**, com algoritmos divergentes |
| Implementações de word-wrap | **5** |
| Implementações de `get_attribute` HTML | **5** |
| Implementações de LRU | **2** (uma delas, `chapter_cache.lua`, está morta) |
| Variações da mensagem "nenhum livro aberto" | **5**: "No book open", "No book currently open", "No book is currently open", "No active book", ... |
| `require` dentro de funções | `init.lua`: 41, `glossary/ui.lua`: 18, `library_dashboard.lua`: 16, `ui/book_loader.lua`: 40× só `require("ink.ui")` |
| Arquivos inteiros mortos | `chapter_cache.lua`, `html/pool.lua`, `html/string_builder.lua`, `dashboard/utils/box_drawing.lua`, `collections/maintenance.lua`, `web/test_migration.lua` |
| God-files (>800 linhas ou função >300 linhas) | `init.lua` (`setup` com ~720 linhas), `export/html_graph.lua` (função de ~1780 linhas), `dashboard/library_dashboard.lua`, `glossary/ui.lua`, `ui/render.lua` (`render_chapter` com ~380), `ui/book_loader.lua` (keymaps com ~315) |
| Bugs confirmados | **~60** (ver seção 2), vários deles graves |

### As 5 mudanças de maior impacto

1. **Adotar um formatador e convenções.** Criar `.stylua.toml` e `.editorconfig`, rodar em tudo, e escrever um `CONTRIBUTING.md` curto com as regras: idioma, cabeçalho, anotações, tratamento de erro e notify.
2. **Criar uma camada de persistência única** (`data/store.lua`) e um helper JSON. Isso elimina ~15 cópias de load/save, corrige riscos de perda de dados e dá cache a quem relê o disco a cada chamada.
3. **Criar um pacote de utilidades compartilhadas** (`ink/util/text.lua`, `ink/util/date.lua`, `ink/util/slug.lua`, `ink/ui/float.lua`, `ink/ui/picker.lua`, `ink/notify.lua`) e apagar as cópias espalhadas.
4. **Quebrar os god-files.** `init.lua` vira `config` + `commands/*` + `highlights` + `keymaps`. `render.lua`, `book_loader.lua` e `extmarks.lua` se dividem por responsabilidade. `html_graph.lua` passa a usar templates em arquivos.
5. **Reorganizar por feature.** Todo recurso (bookmarks, notes/highlights, glossary, padnotes, collections, search, related) passa a seguir o mesmo layout `init/store/query/actions/ui/browser`. Hoje bookmarks e notes têm a UI em `ui/` e o glossary tem a UI dentro da própria pasta.

---

## 2. Bugs encontrados (corrigir primeiro)

Os bugs estão ordenados por gravidade. **[testado]** = reproduzido em Neovim headless.

### 2.1 Críticos (crash, perda de dados ou funcionalidade quebrada)

| # | Local | Problema | Correção sugerida |
|---|---|---|---|
| C1 | `reading_sessions.lua:218-229` ← `tracking.lua:78` | **[testado]** No `VimLeavePre`, `end_session(nil)` executa `active_sessions[nil] = nil`, que lança *"table index is nil"*. Resultado: erro toda vez que o Neovim fecha com tracking ativo, e as sessões nunca são fechadas. Na próxima abertura, `fix_orphaned_session` atribui 1h fixa, o que distorce as estatísticas. | Se `slug == nil`, iterar sobre `active_sessions`. |
| C2 | `reading_sessions.lua:157` | Usa `ctx.ctx.chapter_idx` (proxy legado). O campo não existe (o certo é `current_chapter_idx`), então `chapter_end` é sempre igual a `chapter_start`. Também dispara WARN do proxy. | Passar o capítulo por parâmetro e remover o proxy `M.ctx` de `ui/context.lua:92-110`. |
| C3 | `html/entities.lua:52` | **[testado]** `utf8.char` é `nil` no LuaJIT. Entidades numéricas > 127 (`&#8217;`, `&#8212;`) **somem do texto**: `"A&#8212;B"` vira `"AB"`. Afeta EPUB, web e metadados. | Usar `vim.fn.nr2char(n)` ou um encoder UTF-8 manual. |
| C4 | `html/entities.lua:70-77` | **[testado]** Só 6 entidades nomeadas são reconhecidas. `&mdash;`, `&hellip;`, `&eacute;`, `&rsquo;` etc. aparecem literalmente no texto. | Incluir a tabela HTML5 completa (ou ao menos Latin-1 + pontuação tipográfica). |
| C5 | `web/planalto_parser.lua:198` | `find(pattern, init, true)` com `plain=true` aplicado a um **padrão**: o fechamento de `<strike>` nunca é encontrado e o texto riscado **não é removido**. A versão "Compilada" fica igual à "Crua", e a detecção de artigos revogados e o changelog ficam incorretos. | Remover o `true`. |
| C6 | `web/migrate_highlights.lua:262-269` | A migração de highlights é **um no-op em produção**. Ela espera spine com `id="article-N"`, mas os parsers retornam um único item sem `id`. Só funciona no `test_migration.lua`, que monta spines artificiais. | Alinhar a estrutura do spine ou mapear por âncora. |
| C7 | `init.lua:275,287,524,625`, `library/core.lua:241`, `library/scanning.lua:149` | `markdown.open` e `web.open` retornam `nil, err`, mas os chamadores usam `pcall(...)`. Assim `ok=true, data=nil` e o código quebra adiante em `book_loader.lua:696` (`book_data.slug`), perdendo a mensagem de erro original. `epub.open` usa `error()`. | Definir **um** contrato para os loaders (ver 3.4). |
| C8 | `markdown/inline.lua:84` | **[testado]** Um link Markdown com `%` na URL (ex.: `%20`) derruba o parser com `invalid capture index`: a tag é usada como string de substituição do `gsub`. | Usar uma função como substituição. |
| C9 | `markdown/inline.lua` | **[testado]** (a) O texto comum não é escapado: `a < b ... c > d` faz o parser HTML engolir o trecho. (b) `snake_case_name` vira `snake<em>case</em>name`. (c) Código inline é processado depois da ênfase, então `` `a*b*c` `` mostra `<em>` literal. | Escapar primeiro, proteger code spans, e exigir fronteira de palavra para `_`. |
| C10 | `epub/container.lua:4-9`, `epub/init.lua:198` | **[testado]** Um EPUB sem `<rootfile>` gera "attempt to index nil" e concatena `nil`. | Validar e lançar um erro amigável. |
| C11 | `user_highlights.lua:62-67`, `state.lua:28`, `library/data.lua:58-60`, `data/related.lua:25-27` | **Risco de perda de dados.** Se o JSON estiver corrompido, `load` retorna vazio e o próximo `save` **sobrescreve o arquivo**, apagando todos os highlights ou a biblioteca inteira. `health.lua:78` diz que existe um `library.json.backup`, mas nenhum código cria esse arquivo. | Usar `json_decode_safe` (que faz backup) e escrita atômica (`.tmp` + `os.rename`). |
| C12 | `collections/data.lua:66-83` | `save` faz `os.rename(path, backup)` antes de `io.open(path,"w")`, e o `write` não tem `pcall`. Se a escrita falhar, `collections.json` **some**, e `load` não lê o `.backup`. | Escrita atômica. |
| C13 | `library/init.lua:31,34,37` | `add_linked_resource`, `remove_linked_resource` e `get_linked_resources` apontam para funções que **não existem** em `core` (lá os nomes são `*_related_resource`). Os exports valem `nil`. | Remover (estão mortos de qualquer forma). |
| C14 | `library/core.lua:194` | Usa `link_slug`, uma global indefinida, em vez de `related_slug`. Nada é removido. | Corrigir ou remover (código morto). |
| C15 | `ui/render.lua:397` | `slug` é uma global indefinida. Se não houver título, a concatenação nas linhas 404/406 quebra. | `ctx.data.slug`. |
| C16 | `ui/render.lua:530` | `justify_text` é uma global indefinida, então o hash do cache de glossário ignora a justificação. | `ctx.justify_text`. |
| C17 | `ui/floating_toc.lua:259` | `function setup_keymaps(...)` sem `local` cria uma **função global** `setup_keymaps`. | Usar `local function`. |
| C18 | `ui/context.lua:26,39` | `M.config.focused_mode or true` e `glossary_visible or true` são **sempre `true`**: o usuário não consegue desligar essas opções pela config. | Usar `vim.F.if_nil(x, true)`. |
| C19 | `ui/book_loader.lua:786-788` + `ui/render.lua:261` | Se o `state.json` tiver só `{focused_mode=...}` (gravado antes do primeiro save de posição), `state_data.chapter` é `nil` e a comparação com número quebra. | `state_data.chapter or 1`. |
| C20 | `notes/ui.lua:40-47` | `goto_note` abre o livro com `require("ink.epub").open`. **Notas de livros Markdown ou web não abrem.** | Usar `library.open_book(path, format)`. |
| C21 | `ui/notes.lua:105,108,248,251` | **[testado]** A seleção visual **perde o último caractere**: selecionar "bcd" em "abcdef" grava `"bc"`. Com UTF-8, pode cortar no meio de um caractere. | `end_col + 1` ajustado ao caractere, ou `vim.fn.getregion`. |
| C22 | `dashboard/library_dashboard.lua:600`, `stats_dashboard.lua:797` | `q` executa `tabclose`. Se o dashboard foi aberto na janela atual (buffer vazio), dá `E784: Cannot close last tab page`, ou **fecha a aba do usuário**. | Lembrar se a aba foi criada pelo dashboard. |
| C23 | `dashboard/library_dashboard.lua:771,820,902,958` | `pcall(collections.create, name, "")` ignora o retorno (`nil`/`false` em falha) e sempre notifica sucesso. Além disso, `create` recebe a string `""` onde esperava a tabela `opts`. | Checar o retorno e passar `{}`. |
| C24 | `export/data.lua:44-65` | `build_chapter_map` usa o índice do TOC como se fosse o índice do spine, então os **títulos de capítulo saem errados no export** (TOC aninhado, capa, frontmatter). `padnotes/data.lua:86-99` já faz o mapeamento certo via `href`. | Reaproveitar o mapeamento por `href`. |
| C25 | `export/html_graph.lua:120-127,154,182,1125,1250` + `innerHTML` em 1367-1500 | **Injeção de HTML/JS no grafo exportado.** Uma definição com `</script><script>...` executa código ao abrir o arquivo. Títulos e termos vão para `innerHTML` sem escape. Chaves JSON não são escapadas. | Escapar `<`, `>`, `&`, U+2028 e U+2029 no JSON; usar `textContent`; escapar o título no Lua. |

### 2.2 Importantes (comportamento errado, sem crash imediato)

| # | Local | Problema |
|---|---|---|
| I1 | `ui/book_loader.lua:475-485` | Autocmd `WinEnter`/`BufEnter` **sem `group`**: cada `open_book` registra mais um, e eles nunca são removidos (vazamento). |
| I2 | `ui/book_loader.lua:434-443` | Todo `WinResized` invalida o cache de glossário **em disco** e re-renderiza, mesmo sem mudança de largura. Arrastar um split gera I/O a cada evento. |
| I3 | `ui/extmarks.lua:670,702,717,719` | `update/enable/disable_reading_paragraph` não validam `content_win`. `nvim_del_augroup_by_name` sem `pcall`. |
| I4 | `ui/init.lua:115,191,219,255` | `ctx.glossary_detection_index.entries` sem checagem de nil (o índice é zerado em `invalidate_glossary_cache`). |
| I5 | `ui/util.lua:298,305-311,462-466` | `get_highlight_at_cursor` e `get_highlights_in_range` confiam no cache de posição **sem validar o texto**, ao contrário de `extmarks.apply_user_highlights`. |
| I6 | `ui/init.lua:16` | `M.config = context.config` guarda uma referência antiga. `context.setup` **substitui** a tabela, então `ui.config` fica com os defaults. |
| I7 | `ui/book_loader.lua:318,329,343,397` | `bookmark_keymaps`, `notes_list_keymaps`, `pk` e `export_keymaps` sem `or {}`, ao contrário das linhas 92/145/185. |
| I8 | `ui/floating_toc.lua:304-307` | `get_current_chapter_name` usa `ctx.current_chapter_idx` **antes** de `ctx = ctx or context.current()`. |
| I9 | `ui/floating_toc.lua:292-300,384-400` | Fechar o TOC com `:q` deixa a janela de preview órfã (não há `WinClosed`). |
| I10 | `ui/modals.lua:15` | `opts.wrap ~= nil and opts.wrap or opts.multiline`: armadilha `and/or` (com `wrap=false` o resultado é `multiline`). |
| I11 | `ui/modals.lua:57,72-83,10` | Augroup com nome fixo apaga o autocmd de outro modal. Fechar com `:q` vaza o augroup e nunca chama o callback. Buffer sem `bufhidden=wipe`. |
| I12 | `ui/modals.lua:89` vs `ui/bookmarks.lua:263-267` | O título diz "empty to cancel", mas no `edit_bookmark` um nome vazio **apaga** o bookmark. Não há como cancelar sem salvar (`<Esc>` salva). |
| I13 | `ui/footnotes.lua:80-92` | `close_float` apaga os mapeamentos `q`/`<Esc>` **do buffer de conteúdo**, removendo mapeamentos do usuário. |
| I14 | `ui/library_view.lua:139-156,271-280`, `ui/bookmarks.lua:463-496`, `ui/linked_resources.lua:188-220` | Exclusão **sem confirmação**. O dashboard confirma; essas telas não. |
| I15 | `ui/library_view.lua:54,213`, `ui/linked_resources.lua:114,280` | `book.chapter / book.total_chapters` sem guarda (nil ou divisão por zero). |
| I16 | `ui/linked_resources.lua:181-184,346-350`, `ui/library_view.lua:121-123`, `ui/search.lua:72-74,289-292` | `selection` nil não tratado no `<CR>` com a lista filtrada vazia. |
| I17 | `ui/linked_resources.lua:98,264` | Usa Telescope **sem `pcall`**: quebra se o Telescope não estiver instalado. |
| I18 | `ui/search.lua:31`, `ui/search_index.lua:94`, `ui/navigation.lua:76,202` | `href:match` sem checar nil (itens de spine/TOC do markdown não têm `href`). |
| I19 | `glossary/ui.lua:717-736,446-447` | O preview do Telescope do glossário substitui `ctx.glossary_detection_index` por um índice com 1 entrada, então **todos os relacionamentos aparecem como "(not found)"**. |
| I20 | `glossary/ui.lua:911-912` | Depois de deletar no browser flutuante, reabre no Telescope (perde `force_floating`). |
| I21 | `glossary/ui.lua:754,775,890,919`, `ui/bookmarks.lua:472,489,556` | `nvim_win_get_cursor(ctx.content_win)` sem validar a janela. |
| I22 | `glossary/actions.lua:185-217` | Relações bidirecionais só são sincronizadas ao **adicionar**; remover ou renomear deixa relações órfãs. `term:lower()` quebra com `term` nil. |
| I23 | `glossary/detection.lua:97,120` | Detecção ASCII-only: "Éowyn" não casa sem diferenciar maiúsculas, e "C++" nunca casa (`%f[%W]`). |
| I24 | `library/data.lua:70-72` | `load()` **reescreve `library.json` em toda leitura**: a flag `entities_decoded_v2` é sempre `true` depois da migração. Dezenas de escritas por ação no dashboard. |
| I25 | `library/core.lua:37-38,90` | Compara `chapter >= total_chapters` sem checar nil (livros antigos). |
| I26 | `init.lua:273-295` vs `library/core.lua:229-237` | A detecção de formato diverge: `InkOpen` trata qualquer `https://` como web, mas a biblioteca só trata URLs do Planalto. **Uma URL genérica reaberta pela biblioteca vai para `epub.open`.** |
| I27 | `reading_sessions.lua:20-22` + `tracking.lua:22` | O id `"session-"..os.time()` colide no mesmo segundo. O padrão `ink://*` também casa buffers de TOC, preview e dashboard, gerando muitas sessões curtas e atualizando a sessão errada. |
| I28 | `reading_sessions.lua:122-136` | `fix_orphaned_session` não atualiza `total_time`. |
| I29 | `tracking.lua:85` | `setup` duplicado vaza o timer (não chama `stop()`). |
| I30 | `fs.lua:13-16` | Efeito colateral no carregamento: notifica a falta de `unzip` em **qualquer** `require("ink.fs")`, inclusive em fluxos de markdown e web. |
| I31 | `health.lua` | Não usa `vim.health.*`, então `:checkhealth ink` quebra o layout. Usa `du -sh` e `rm -rf` (inexistentes no Windows). Declara compatibilidade com 0.8, mas usa APIs 0.9+ e outras depreciadas. |
| I32 | `epub/init.lua:173-177` | Re-extrair um EPUB não limpa `css.json` nem o cache de TOC, que ficam desatualizados. `css_cache.clear` existe e nunca é chamada. |
| I33 | `epub/util.lua:12` | `validate_path` checa o prefixo sem separador: `/cache/abc` aceita `/cache/abcdef/...`. |
| I34 | `epub/init.lua:114`, `ui/render.lua:176` | Os `href` do spine não passam por `validate_path` nem por URL-decode (`%20`): EPUBs com espaço no nome de arquivo falham. |
| I35 | `epub/opf.lua:20,67` | `manifest[nil]` causa crash. `<item[^>]+>` também casa `<itemref>`. `props:match("nav")` casa substring. |
| I36 | `epub/nav.lua:10` | Lê todos os `<a>` (landmarks e page-list poluem o TOC). Nível sempre 1. Ignora links com `<span>`. Rótulos sem decodificação de entidades. |
| I37 | `epub/util.lua:3-6` | O slug usa só o nome do arquivo: dois livros com o mesmo nome em pastas diferentes **compartilham o cache e os highlights**. Acentos viram `__` (colisão). |
| I38 | `html/patterns.lua` e as 4 cópias de `get_attribute` | Sem fronteira de palavra: `id=` casa `data-id=`, `href=` casa `xlink:href=`. Um valor com apóstrofo é cortado. |
| I39 | `html/tokens.lua:7`, `html/blocks.lua:183` | `<br>` é tratado como bloco e gera `paragraph_break` em vez de quebra de linha. |
| I40 | `html/blocks.lua:192` | Elementos void (`br`, `img`, `meta`) são empilhados em `style_stack` e nunca desempilhados (a pilha cresce). |
| I41 | `html/formatter.lua:126-135` | Tabelas aninhadas: um único `table_state`, então a interna fecha a externa. |
| I42 | `html/parser.lua:80` | `<!-- a > b -->`, CDATA, `<script>` e `<style>` dentro do `<body>` são renderizados como texto. |
| I43 | `markdown/toc.lua:13,67` | A divisão em capítulos ignora blocos de código: `# comentário` dentro de um bloco cria um capítulo. |
| I44 | `markdown/parser.lua:205-210` | Cada linha vira um `<p>`: parágrafos quebrados manualmente viram vários parágrafos. |
| I45 | `web/init.lua:118-244` | A validação DNS acontece **antes** de consultar o cache: páginas em cache não abrem offline. |
| I46 | `web/planalto_parser.lua:248,250,377...` | Classes `[ºo°]` e `[%-–—]` casam **bytes**, não caracteres UTF-8: `Art. 26–A` vira `26\xE2`. |
| I47 | `web/planalto_parser.lua:248` | Divide os artigos em qualquer `Art. N`, inclusive dentro de citações de outras leis, gerando IDs duplicados. |
| I48 | `web/init.lua:21` | `l13140.htm` e `l13140compilado.htm` geram o mesmo slug. `web/util.lua:9` aceita `xplanalto.gov.br`. |
| I49 | `web/generic_parser.lua:345-481` | Os IDs `heading-N` do TOC são gerados a partir do conteúdo compilado, mas o default é RAW: o TOC aponta para títulos errados. |
| I50 | `web/generic_parser.lua:78-83` | `NEGATIVE_PATTERNS` por substring: `"ad"` casa "header" e "read"; `"nav"` casa "canvas". |
| I51 | `web/*` | Mudar `CACHE_VERSION` grava um changelog falso ("Página atualizada!"). |
| I52 | `init.lua:269` | `vim.fn.expand(path)` aplicado a URLs: `#` e `%` são expandidos como nomes de arquivo. |
| I53 | `export/html_graph.lua:1513` | `\\r\\n` dentro de long string `[[...]]` produz texto literal, e o **SVG exportado fica inválido**. |
| I54 | `export/util.lua:68-102` | `slugify` fora do padrão GitHub: as âncoras do índice Markdown exportado ficam quebradas. |
| I55 | `export/markdown.lua`, `export/glossary_md.lua` | Nenhum escape: `|` quebra tabelas, notas com várias linhas quebram o layout. |
| I56 | `export/init.lua:162` | O resultado de `export_glossary` é ignorado: a UI mostra "✓ Exported" mesmo quando falha. |
| I57 | `export/ui.lua:58-68,41,47-52` | O parser de flags é frágil (`--bogus` ativa `b`), um formato desconhecido cai silenciosamente em markdown, e caminhos com espaço são truncados. |
| I58 | `export/init.lua:12-40` | `validate_export_path` não protege nada no Windows (lista só de caminhos Unix, separador `/`). |
| I59 | `init.lua:97-101` | 4 das 5 chaves de `export_defaults` **não fazem nada** (só `export_dir` é lida). |
| I60 | `dashboard/library_dashboard.lua:434,462` | `find(vim.pesc(x), 1, true)` (escape + plain): nomes com `-` nunca recebem highlight. Há também um off-by-one em 464-465. |
| I61 | `dashboard/stats_dashboard.lua:149,155,161,267-280` | "This Week" soma 8 dias. A média diária divide só pelos dias com leitura. O sparkline normaliza pelo mínimo. "1 books". |
| I62 | `dashboard/*` | O cache de 30 ou 60 s não é invalidado ao ler um livro: o dashboard mostra o progresso antigo. |
| I63 | `dashboard/library_dashboard.lua:786-841` | Apagar uma coleção dessincroniza `collection_index`. |
| I64 | `dashboard/library_dashboard.lua:1189-1192` | O buffer de preview não usa `bufhidden=wipe` (vazamento). |
| I65 | `collections/queries.lua:46-49` | Emite WARN por livro órfão **a cada render** do dashboard (spam). |
| I66 | `padnotes/actions.lua:305-307` | `close(save_first=false)` com o buffer modificado lança erro sem `pcall`. |

---

## 3. Padrões inconsistentes (transversais)

### 3.1 Indentação: três estilos, sem formatador

| Estilo | Onde |
|---|---|
| **2 espaços** (maioria) | `bookmarks/`, `data/` (exceto `related.lua`), `epub/` (exceto `ncx.lua`), `export/` (exceto `html_graph`), `glossary/`, `markdown/`, `notes/`, `padnotes/`, `web/` (exceto `planalto_parser`), boa parte de `ui/`, `state`, `fs`, `health`, caches |
| **4 espaços** | `init.lua`, `which_key_groups.lua`, `css_parser/*`, `epub/ncx.lua`, `export/html_graph.lua`, `html/{blocks,formatter,parser,patterns,text}.lua`, `ui/context.lua`, `ui/footnotes.lua`, `web/planalto_parser.lua` |
| **Tab** | `collections/*`, `dashboard/*`, `library/*`, `data/related.lua`, `reading_sessions.lua`, `utils.lua`, `ui/{book_loader,extmarks,init,linked_resources,render}.lua` |
| **Misturado no mesmo arquivo** | `ui/search_index.lua` (tab em 1-85, 2 espaços em 87-282), `reading_sessions.lua:155-165`, `dashboard/library_dashboard.lua:80`, `stats_dashboard.lua:68,769`, `ui/util.lua:61-62` |

Há também espaços no fim de linhas (`epub/ncx.lua`, `export/markdown.lua`, `export/util.lua`, `padnotes/*`, `init.lua:889`) e arquivos sem newline final (`html/entities.lua`, `html/init.lua`, `html/parser.lua`, `epub/*.lua`, `css_parser/init.lua`, `ui/linked_resources.lua`).

**Proposta:** criar o `.stylua.toml` abaixo e rodar `stylua lua/` uma vez, em um commit separado ("style: format with stylua"), para não poluir o diff das refatorações.

```toml
column_width = 120
indent_type = "Spaces"   # ou "Tabs": escolha um
indent_width = 2
quote_style = "AutoPreferDouble"
```

### 3.2 Cabeçalho dos arquivos

Coexistem quatro estilos:
- `-- lua/ink/x.lua` + "Responsabilidade: ..." **em português**: `ui/book_loader.lua`, `ui/cache.lua`, `ui/search_index.lua`, `ui/modals.lua`, `html/{blocks,formatter,justification,text}.lua`, `padnotes/*`.
- `-- lua/ink/x.lua` + descrição em inglês: `library/*`, `collections/*`, `dashboard/*`, `cache/lru.lua`, `css_cache.lua`, `tracking.lua`, `health.lua`, `utils.lua`, `web/util.lua`, `ui/floating_toc.lua`.
- Uma linha de descrição sem caminho: `notes/*`, `glossary/cache.lua`, `web/migrate_highlights.lua`, `data/directory_migration.lua`.
- Sem cabeçalho: todo o resto (~60%).

**Proposta:** cabeçalho opcional de uma linha, **em inglês**, sem o caminho (o caminho já é o nome do arquivo):
```lua
--- Bookmark persistence (per-book JSON store).
```

### 3.3 Anotações e documentação

- **LuaCATS correto (`---@param nome tipo`)**: nenhum arquivo.
- `--- @param` (com espaço, tolerado pelo LuaLS): só `utils.lua`.
- `-- @param` (um hífen só, **ignorado pelo LuaLS**): `library/*`, `collections/*`, `dashboard/*`, `cache/lru.lua`, `chapter_cache.lua`, `data/init.lua`, `export/init.lua`, `export/glossary_md.lua`, `web/*`, `ui/book_loader.lua`, `ui/library_view.lua:307`.
- `-- @param x: tipo - desc` (formato próprio): dashboards.
- "Returns:" em texto livre: `markdown/toc.lua`, `notes/query.lua`, `glossary/detection.lua`.
- Comentários errados ou desatualizados: `library/core.lua:160` (`link_info` vs `related_info`), `glossary/ui.lua:205,489` ("70%" vs `0.5`), `bookmarks/query.lua:12-13`, `padnotes/data.lua:166`, `web/fetcher.lua:210`, `web/versions.lua:377,445,465` ("law"), `html/patterns.lua:2-3` ("pré-compilado"), `ui/search.lua:90-107` ("fuzzy"), `ui/context.lua:52`.

**Proposta:** padronizar em `---@param` e `---@return`, e criar um arquivo `lua/ink/types.lua` (só de anotações) com as classes principais:
```lua
---@class ink.Config ...
---@class ink.Context        -- ui/context.new_context(): o tipo mais usado do plugin
---@class ink.Book           -- retorno comum de epub/markdown/web.open
---@class ink.LibraryEntry
---@class ink.Highlight
---@class ink.Bookmark
---@class ink.GlossaryEntry
---@class ink.Session
```

### 3.4 Tratamento de erro: cinco convenções diferentes

| Convenção | Onde |
|---|---|
| `error()` | `epub.open`, `data.get_book_dir`, `web/planalto_parser.parse`, `web/fetcher.get_cache_dir` |
| `return nil, err` | `markdown.open`, `web.open`, `data.json_decode_safe`, `web.check_updates` |
| `return nil, nil, err` | `web/fetcher.*` |
| `return false` (o erro se perde) | `state.save`, `library/data.save`, `related.save`, `toc_cache.save`, `glossary/data.save` |
| `return false, msg` | `remove_related_resource`, `ui/cache.lua`, `epub.clear_cache` |
| `vim.notify` + `return` | `fs.write_file`, a maioria da UI |
| `pcall(require, "ink.xxx")` para módulos internos | `tracking.lua`, `stats_dashboard.lua` (esconde erros reais) |

Outros problemas:
- Chamadores usam `pcall` em funções que **não lançam erro** (C7, C23).
- Muitos `save` têm o retorno ignorado: `glossary/actions`, `bookmarks/actions`, `user_highlights`, `versions.save_preference`.
- Às vezes "nenhum livro aberto" é silencioso (`navigation`, `preview_glossary`), às vezes WARN, às vezes ERROR.

**Proposta de convenção:**
1. **Funções de I/O e de dados** retornam `ok, err` (ou `value, err`) e **não notificam**.
2. **Loaders de formato** (`epub/markdown/web.open`) retornam `book, err`, e o chamador **não** usa `pcall`. Alternativa: todos usam `error()` e o chamador usa `pcall`. Escolha uma das duas.
3. **Só a camada de comandos e UI** chama `ink.notify`.
4. `error()` só para bugs de programação (argumento inválido).
5. Nunca usar `pcall(require, ...)` em módulo interno.

### 3.5 Mensagens (`vim.notify`) e idioma

- 339 chamadas a `vim.notify`, **nenhuma** com `title` (há só um `fs.lua:15` com prefixo "ink.nvim:").
- Prefixos e estilos variados: "✓ ", "Warning: ", "AVISO: ", "Failed to...", Title Case ("Dashboard Reloaded"), espaço inicial (`ui/notes.lua:173`).
- Níveis inconsistentes para a mesma situação ("No collections available" é INFO em um lugar e WARN em outro).
- **Idiomas misturados**:
  - Mensagens em PT: `init.lua:527,563,568,570,606,614,624,631,635,638` ("Versão alterada para:", "Verificando atualizações..."), `web/init.lua:266,312-325`, `web/fetcher.lua:244`, `web/changelog.lua:150,227-239`, `web/versions.lua` (rótulos).
  - Comentários em PT: cabeçalhos "Responsabilidade", `ui/util.lua:455`, `padnotes/actions.lua:330-350`.
  - Todo o resto em inglês.
- Ruído: uma busca dispara até 5 notificações (`ui/search.lua` + `search_index.lua`); um download web dispara de 2 a 4.

**Proposta:** criar `lua/ink/notify.lua`:
```lua
local M = {}
function M.info(msg, ...)  vim.notify(msg:format(...), vim.log.levels.INFO,  { title = "ink.nvim" }) end
function M.warn(msg, ...)  ... end
function M.error(msg, ...) ... end
M.NO_BOOK = "No book is currently open"
return M
```
Escolher **um idioma** (inglês, coerente com o README e o restante). Se quiser i18n no futuro, centralizar as strings.

### 3.6 Acesso à configuração

Há pelo menos seis formas diferentes:
- `require("ink").config` (`export/ui.lua:17`).
- `require("ink.ui.context").config` (a maioria da UI). Também é feito `require` de novo quando já há `context` no topo (`extmarks.lua:579`, `linked_resources.lua:233`).
- `ui.config` (referência antiga, I6).
- Config recebida por parâmetro: `reading_sessions.setup(M.config.tracking)` vs `tracking.setup(M.config)` (a config inteira).
- Defaults duplicados:
  - `reading_sessions.lua:6-11` repete `init.lua:122-127`;
  - `padnotes/init.lua:7-12` repete `init.lua:156-163`;
  - a tipografia aparece em 7 lugares (`navigation` 6× + `render.lua:221-226` + `html/parser.lua:40-45` + `html/text.lua:12,53`);
  - `max_width or 120` aparece em ~8 lugares.
- **Configuração global mutada em tempo de execução**: `navigation` altera `context.config.typography`, o que afeta todos os livros abertos e não é persistido, enquanto `justify`/`width`/`focused` são por contexto e persistidos.

**Proposta:** criar `lua/ink/config.lua` com `defaults`, `setup(opts)` e `get()`. Os defaults ficam **num único lugar**. O estado por livro fica em `ctx` e é persistido via `state`.

### 3.7 `require` no topo vs inline

Hoje não há critério. Há quatro situações:
- **Ciclos reais**, documentados ou não: `ui/book_loader.lua` (40× `require("ink.ui")`), `data/related.lua` ↔ `library`, `ui/library_view.lua:7` (descrito como "Forward declaration", mas na verdade é um lazy require).
- **Inline sem motivo**: `reading_sessions.lua` (todos), `ui/bookmarks.lua` (`ink.ui.util` 4×), `ui/search_index.lua` (`ink.fs` 3×), `glossary/ui.lua` (`ink.ui.render` 5×, módulos redeclarados que sombreiam os do topo), `library_dashboard.lua` (`collections` 6×, com dois nomes diferentes), `ui/render.lua` (7 lazy getters de boilerplate + inline), `html/blocks.lua:210` (require **dentro de um laço**).
- **Carregamento eager pesado**: `init.lua:1-4` carrega epub, markdown, web e a UI inteira no `setup`. `export/init.lua` carrega `html_graph` (1955 linhas) sempre.
- Ordem `local M = {}` antes ou depois dos requires: varia (`library/core.lua`, `library/data.lua`, `linked_resources.lua`, `glossary/cache.lua`).

**Proposta:**
1. Requires no topo, por padrão.
2. Inline só para (a) quebrar ciclo, sempre com o comentário `-- lazy: avoid cycle with X`, ou (b) módulo pesado e opcional (telescope, html_graph).
3. Eliminar os ciclos: a maioria vem de `ui/init.lua` atuar como fachada **e** ser importado pelos próprios submódulos. Submódulos devem importar uns aos outros diretamente, nunca a fachada.

### 3.8 Nomenclatura

- **Mesmo conceito, nomes diferentes:**
  - "linked" / "related" / "link": `library/init.lua`, `ui/linked_resources.lua` (importado como `related_resources`), `data/related.lua`, `InkAddRelated`.
  - `query.lua` vs `queries.lua`.
  - `util` vs `utils`.
  - `get_by_book` / `get_book_notes` / `list_padnotes` / `get_all`.
  - `find_by_id` / `get_by_id` / `get`.
  - `remove` / `delete` / `remove_highlight_by_text`.
  - `epub_data` / `book_data` para qualquer formato.
- **Sombreamento:**
  - `local data = ...` sombreia o módulo `ink.data` (`state`, `user_highlights`, `reading_sessions`, `data/related`, `notes/query`, `collections/data`). O mesmo módulo aparece como `data`, `data_module`, `ink_data` e `data_encoder`.
  - `type` sombreia o builtin em `directory_migration`, `scanning`, `health` e `padnotes/data`.
  - `text` (módulo) é sombreado por parâmetros em `html/blocks.lua`.
- **Nomes enganosos:**
  - `ui/notes.lua` contém sobretudo **highlights**.
  - `toggle_collection` na verdade *cicla* entre coleções.
  - `migrate_highlights.migrate_highlights` repete o nome do módulo.
  - `get_changelog` retorna texto já formatado.
- **Campos privados do `ctx`** (`_is_initializing`, `_rerendering`, ...) são adicionados *ad hoc*, fora de `new_context()`.

### 3.9 APIs depreciadas do Neovim

| API depreciada | Onde | Substituir por |
|---|---|---|
| `nvim_buf_set_option` | `dashboard/*`, `health.lua` | `vim.bo[buf].x` / `nvim_set_option_value` |
| `nvim_get_option` | `library_dashboard.lua` | `vim.o.x` |
| `nvim_buf_add_highlight` | `ui/search.lua`, `health.lua` | `vim.hl.range` / extmarks |
| `vim.loop` | `epub/init.lua`, `web/init.lua` | `vim.uv` |
| Abertura de URL e imagem implementada à mão por SO (`ui/util.lua:95-180`) | — | `vim.ui.open` (0.10+) |

A versão mínima é declarada de forma inconsistente: o README diz 0.7+, `health.lua` exige 0.8, e o código usa `vim.system` (0.10+). **Proposta:** declarar 0.10+ em todos esses lugares.

### 3.10 Assinaturas e ordem de parâmetros

- `ctx` aparece em posições diferentes:
  - `render.render_chapter(idx, restore_line, ctx)`: no fim;
  - `get_link_at_cursor(line, col, ctx)`: no fim;
  - `enable_reading_paragraph_mode(ctx)`: obrigatório;
  - `toggle_reading_paragraph_mode()`: sem ctx.
  
  **Proposta:** `ctx` sempre como **primeiro** parâmetro e opcional (`ctx = ctx or context.current()`).
- Formatters de export: `markdown.format(book_data, options)` e `json.format(...)` contra `glossary_md.format(entries, title)` e `html_graph.generate(entries, title)`.
- Loaders retornam formatos diferentes de `Book` (ver 7.4).

### 3.11 Estilo de keymaps

- `vim.keymap.set(..., { noremap = true })`: o `noremap` é redundante.
- Strings `":InkLibrary<CR>"` em vez de funções (`init.lua:855-881`).
- Handlers envolvidos em `function() M.x() end` quando `M.x` poderia ser passado direto.
- A mesma ação é mapeada separadamente para `"i"` e `"n"` em todo picker do Telescope (corpos copiados).
- Teclas inconsistentes entre telas: refresh é `R` no library dashboard e `r` no stats.

---

## 4. Código duplicado (transversal)

Itens ordenados pelo ganho estimado de remoção.

### 4.1 Persistência JSON por arquivo (o maior ganho)

**O padrão repetido** `path → fs.exists → fs.read_file → pcall(vim.json.decode) → default` e `io.open("w") → pcall(file.write) → close` aparece em:

`state.lua:11-31`, `library/data.lua:49-90`, `data/related.lua:16-45`, `toc_cache.lua:16-44`, `css_cache.lua:20-56`, `user_highlights.lua:19-84`, `reading_sessions.lua:58-114`, `data/migrate.lua:23-68`, `data/directory_migration.lua:18-50`, `glossary/data.lua:12-46`, `glossary/cache.lua:14-69`, `bookmarks/data.lua:17-51`, `collections/data.lua:18-89`, `padnotes/data.lua`, `ui/search_index.lua:66-72`, `export/init.lua:76-156` (3×), `web/fetcher.lua:44-77`, `web/versions.lua:379-413`, `web/changelog.lua:17-60`.

Também há **releitura "na mão" de `highlights.json`**, sem passar por `user_highlights` (e portanto sem cache e sem migração), em `notes/query.lua:12-26`, `web/fetcher.lua:235-252`, `web/migrate_highlights.lua:294-315` e `init.lua:590-596`.

**O tratamento de JSON corrompido é diferente em cada lugar:** `css_cache` apaga o arquivo, `reading_sessions` renomeia para `.corrupt`, `json_decode_safe` cria `.backup.<ts>` e os demais ignoram (risco de perda de dados, C11).

**Os helpers já existem e quase ninguém os usa:** `fs.write_file` (`fs.lua:41`) e `data.json_decode_safe` (`data/init.lua:47`, só usado em `web/*`).

**Proposta:** criar `lua/ink/data/json.lua` e `lua/ink/data/store.lua`.

```lua
-- data/json.lua
M.read(path, default)        -- decode seguro com backup do corrompido
M.write(path, tbl, {pretty}) -- escrita atômica (.tmp + rename), retorna ok, err

-- data/store.lua
local store = require("ink.data.store")
local bookmarks = store.new({
  filename = "bookmarks.json",
  scope    = "book",               -- "book" (por slug) | "global"
  default  = function() return { bookmarks = {} } end,
  migrate  = migrate.migrate_bookmarks,  -- roda 1x por slug, memoizado
  cache    = true,
})
bookmarks:load(slug); bookmarks:save(slug, t)
bookmarks:update(slug, function(t) ... end)   -- load → mutate → save
bookmarks:invalidate(slug)
```

**Resultado esperado:**
- Remove ~15 cópias.
- Corrige C11 e C12.
- Dá cache para glossary, bookmarks e collections (ver seção 8).
- Elimina o padrão load → loop → mutate → save repetido em `glossary/actions` (8×), `bookmarks/actions` (3×), `user_highlights` (3×), `collections/management` (4×) e `associations` (3×).

**Encoder JSON:** hoje há três.
- `data/init.lua:80-125` (`json_encode`):
  - não escapa as chaves;
  - transforma `{}` em `[]` (objeto vazio vira array);
  - não trata `inf` nem `nan`.
- `export/html_graph.lua:120-167` (`to_json`) tem os mesmos problemas.
- `vim.json.encode`.

**Proposta:** usar só `vim.json.encode`, com `vim.empty_dict()` onde for necessário, e um pretty-printer opcional por cima.

### 4.2 Caminhos de dados e de cache

- `vim.fn.stdpath("data") .. "/ink.nvim"` é hardcoded fora de `data.get_data_dir()` em `init.lua:331`, `toc_cache.lua:7`, `css_cache.lua:11`, `directory_migration.lua` (4×), `epub/init.lua:12`, `glossary/cache.lua:8` e `ui/search_index.lua:12`.
- O caminho `".../cache/" .. slug` + `ensure_dir` é montado em 5 lugares, e **sem validar o slug**, ao contrário de `data.get_book_dir`.
- O cache web e o cache epub usam **o mesmo diretório**, então `epub.clear_cache()` apaga também o cache web.
- `ensure_dir` (`mkdir -p`) é executado em **toda leitura** (`get_book_dir`, `get_cache_path`, `get_padnotes_dir`, `get_index_cache_path`).

**Proposta:** criar `data.paths` com as funções abaixo, todas validando o slug e memoizando os diretórios já criados:
- `book_dir(slug)`
- `cache_dir(slug, kind)`, com `kind` = `"epub"`, `"web"`, `"toc"`, `"css"`, `"glossary"` ou `"search"`
- `library_file()`

### 4.3 Utilitários de texto

| Função | Implementações | Problema |
|---|---|---|
| **fit_string / truncate / pad** | `dashboard/utils/text.lua:66` (por bytes), `library_dashboard.lua:519` (por caracteres, com "..."), `ui/library_view.lua:13-35` e `ui/linked_resources.lua:8-30` (cópias literais, O(n²), sem "..."), `dashboard/utils/box_drawing.lua:75,100` (por bytes), `ui/extmarks.lua:235-236,319-333` (por bytes e por caractere) | Comportamentos divergentes; truncamento por bytes **corta caracteres UTF-8** (títulos com acento desalinham as molduras) |
| **display width** | `dashboard/utils/text.lua:57` (`strwidth`), `html/utils.lua:4` (`strdisplaywidth`), `library_view.lua:13`, `linked_resources.lua:8`, dezenas de chamadas inline | Três wrappers |
| **word wrap** | `html/text.lua:112-158`, `html/table.lua:100-132`, `export/util.lua:4-28` (por bytes), `ui/util.lua:341` (O(n²)), `dashboard/utils/text.lua:97` (morta) | 5 versões |
| **trim / normalizar espaços** | `markdown/util.lua:4-6`, `html/blocks.lua:48,57`, `epub/opf.lua:53`, `ui/util.lua:187-190`, `web/planalto_parser.lua:25-33`, `web/generic_parser.lua:97,106,464` | |
| **strip tags + decode + normalize** | `epub/opf.lua:51-53` (ordem invertida: decode antes do strip), `ui/render.lua:140-152`, `html/blocks.lua:12-15`, `web/*` (9×) | |
| **escape HTML** | `markdown/util.lua:25-34`, `web/generic_parser.lua:10-19`, `web/planalto_parser.lua:12-21` | `export/html_graph.lua` não escapa nada (C25) |
| **escape pattern** | `markdown/util.lua:130` e o `gsub` de escape repetido nos 4 `get_attribute` | |
| **slugify** | `markdown/util.lua:10-22` (mantém UTF-8), `export/util.lua:68-102` (transliteração PT, colapsa hífens), `epub/util.lua:3-6` (troca `[^%w]` por `_`, retorna 2 valores), `markdown/init.lua:8-11`, `web/init.lua:33` (web depende de markdown) | Algoritmos divergentes; âncoras quebradas (I54); colisões (I37) |
| **get_attribute HTML/XML** | `epub/container.lua:5-8`, `epub/nav.lua:3-6`, `epub/ncx.lua:3-6`, `epub/opf.lua:4-7`, `html/patterns.lua:28-44` (morto) | Sem fronteira de palavra (I38) |

**Proposta:** criar um pacote `lua/ink/text/` (funções puras, sem `vim.api`, fáceis de testar):
```
text/width.lua     display_width, truncate(str, w, {ellipsis}), pad(str, w, align), fit(str, w, align)
text/wrap.lua      wrap(text, width, {break_long_words})
text/strings.lua   trim, normalize_ws, split_lines, escape_pattern
text/html.lua      escape, decode_entities (entities.lua), strip_tags, to_plain
text/xml.lua       get_attr(tag, name)  (com %f[%w-] e aspas corretas)
text/slug.lua      book_slug(path) (nome + hash do caminho), anchor_slug(text, seen) (algoritmo GitHub)
```

### 4.4 Datas e tempo

| Implementação | Formato |
|---|---|
| `library/statistics.lua:56` (`format_last_opened`) | "3d ago" |
| `dashboard/utils/text.lua:27` (`format_date`) | "3 days ago" (o mesmo livro aparece de forma diferente em duas telas) |
| `export/util.lua:31` (`format_timestamp`) | — |
| `export/markdown.lua:6-26` | `MONTHS` + `format_date` |
| `padnotes/data.lua:10-13,244-252` | `MONTHS_PT` + `format_date_ptbr` (apresentação dentro de `data.lua`) |
| `notes/ui.lua:175,178`, `export/glossary_md.lua:13` | `os.date` direto |
| `export/init.lua:64`, `export/ui.lua:9` | `os.date("%Y%m%d-%H%M%S")` duplicado |
| `reading_sessions.lua` | constante `86400` literal 6× |
| `library/statistics.lua:22-23` | `30*24*60*60` |

**Proposta:** criar `lua/ink/util/date.lua` com `relative(ts, {short})`, `format(ts, style)`, `file_stamp()` e `SECONDS_PER_DAY`.

### 4.5 Janelas flutuantes

Existem ~15 cálculos manuais de `width`/`height`/`row`/`col` + `nvim_open_win` + mapeamento de `q`/`<Esc>`:
- `glossary/ui.lua:204-224,488-508,841-858,957-974,1019-1036` (com close keys em 515-525,861-871,980-990,1042-1052);
- `notes/ui.lua:239-269`;
- `ui/bookmarks.lua:521-538`;
- `ui/library_view.lua:231-245`;
- `ui/cache.lua:117-125`;
- `ui/modals.lua:32`;
- `ui/floating_toc.lua:177-218`;
- `padnotes/ui.lua:79-175`;
- `dashboard/library_dashboard.lua:1185-1205`;
- `health.lua:343-435`.

A medida da tela também diverge: `nvim_list_uis()[1]` em alguns lugares, `vim.o.columns` em outros.

O layout "lista + preview" está duplicado entre `ui/floating_toc.lua` e `padnotes/ui.lua` (o mesmo `floating_state` com `preview_buf`/`preview_win`).

**Proposta:** criar `lua/ink/ui/float.lua`:
```lua
float.open({ lines, title, width = 0.5, height = 0.6, wrap, filetype, modifiable = false,
             close_keys = { "q", "<Esc>" }, on_close }) -> buf, win, close
float.list({ items, format, actions = { ["<CR>"]=..., d=... } })     -- mapa linha→item embutido
float.split_preview({ list, preview_fn })                         -- TOC e padnotes
```
Com `bufhidden=wipe` e autocmd `WinClosed` embutidos, o que corrige I9, I11 e I64 de uma vez.

### 4.6 Pickers (Telescope com fallback)

São seis implementações completas: `glossary/ui.lua:572-925`, `notes/ui.lua:82-270`, `ui/bookmarks.lua:368-564`, `ui/library_view.lua:37-296`, `ui/linked_resources.lua:97-360` e `ui/search.lua:110-312`. Cada uma repete:
- a importação de `pickers`/`finders`/`conf`/`actions`/`action_state`/`previewers`;
- o `entry_maker`, o `new_buffer_previewer` e o `select_default:replace`;
- os mesmos mapeamentos copiados para `i` e `n`;
- um fallback em float (que **perde funcionalidades**, por exemplo o float de bookmarks não tem `<C-f>`/`<C-b>`).

A detecção do Telescope tem 5 variantes (I17: uma delas sem nenhuma checagem).

Dentro de `library_view.lua` e `linked_resources.lua`, o formato das entradas de livro e o previewer "Book Info" estão copiados **4 vezes**, e `format_icons` está definido **7 vezes**.

**Proposta:** criar `lua/ink/ui/picker.lua`:
```lua
picker.open({
  title, items,
  display = fn, ordinal = fn,
  preview = fn(item) -> lines,
  on_select = fn,
  mappings = { ["<C-d>"] = fn },     -- registrado em {"i","n"} automaticamente
  fallback = "float" | "select",
})
```
e `lua/ink/ui/format.lua` com `FORMAT_ICONS`, `book_entry(book)`, `book_preview_lines(book)` e `progress_percent(book)`.

### 4.7 Abrir livro e navegar até um item

Existem 5 implementações de "abrir um livro da biblioteca":

| Local | Particularidade |
|---|---|
| `ui/library_view.lua:125-137,256-268` | Duplicadas; checam URL e `fs.exists` |
| `ui/bookmarks.lua:583-600` | Não checa existência |
| `ui/linked_resources.lua:228-243` | — |
| `notes/ui.lua:40-47` | Só EPUB (bug C20) |
| `dashboard/library_dashboard.lua:690-707` | — |
| `ui/init.lua:269-299` | `open_last_book` |

O fluxo "abrir → `render_chapter` → `defer_fn(10/100ms)` → `find_text_position` → `set_cursor`" aparece 4 vezes em `ui/bookmarks.lua` e de novo em `notes/ui.lua`.

**Proposta:**
- `library.open(book, opts)`: um único fluxo, com detecção de formato (ver 4.10) e checagem de existência.
- `ui/navigation.goto_anchor({ slug, chapter, text, context_before, context_after, fallback_line })`, síncrono, sem `defer_fn`. Se o render precisar ser assíncrono, disparar um evento `User InkChapterRendered`.

### 4.8 "Pegar o ctx atual ou avisar"

O padrão `local ctx = context.current(); if not ctx then vim.notify("No book ...") return end` aparece:
- ~12× em `init.lua`;
- 7× em `ui/init.lua`;
- várias vezes em `ui/bookmarks.lua`, `ui/search.lua`, `ui/linked_resources.lua`, `notes/ui.lua` e `padnotes/*`.

Há 5 textos diferentes para a mesma mensagem.

**Proposta:** `context.require_current()` → `ctx | nil`, que notifica com o texto padrão. Para comandos, usar um wrapper `with_ctx(fn)`.

### 4.9 Captura de âncora textual (texto + contexto antes/depois)

Aparece em `ui/notes.lua:101-130` e `243-273` (idênticos), `ui/bookmarks.lua:98-122` e `ui/render.lua:63-127`. A constante `context_len = 30` está repetida 5 vezes.

**Proposta:** `text_anchor.capture(lines, s_line, s_col, e_line, e_col)` → `{text, context_before, context_after}`, e `text_anchor.resolve(lines, anchor)`, que unifica `find_text_position`, a validação do cache de posições (I5) e o predicado "mesmo highlight" (repetido 3× em `user_highlights.lua:136,176,207`).

### 4.10 Detecção de formato

A detecção de formato está espalhada, com regras divergentes:
- `init.lua:273-295`
- `library/core.lua:229-237`
- `library/scanning.lua:49,136-140`
- `markdown/init.lua:86-89` (`is_markdown`, morta)
- `web/util.lua:8` e `web/init.lua:18-29` (Planalto)

**Proposta:** `formats.detect(path_or_url)` → `"epub" | "markdown" | "web"`, usado por todos esses pontos.

### 4.11 Outras duplicações relevantes

| O quê | Onde | Proposta |
|---|---|---|
| Buscar livro por slug na biblioteca | `library/core.lua` (6×), `library/scanning.lua:172-177`, `notes/ui.lua:8-16`, `ui/bookmarks.lua:571-580`, `ui/linked_resources.lua:53-61`, `collections/associations.lua:10-20`, `export/data.lua:9-19` | `library.get_book(slug)` com índice |
| Iterar todos os livros e agregar | `notes/query.lua:51-126` (sync + async, mesmo corpo), `ui/bookmarks.lua:10-20` | `library.collect(fn, {async_threshold}, cb)` |
| Filtrar e ordenar livros | `library/queries.lua:29-167` (5 funções iguais) | `sorted_filter(pred, key)` |
| Confirmação y/N | `init.lua:665,813`, `ui/notes.lua:52,162`, `library_dashboard.lua:815,953,1258`, `glossary/ui.lua:537,905` (com `vim.fn.input` bloqueante) | `modals.confirm(prompt, on_yes)` ou `vim.fn.confirm` |
| Geração de ID | `glossary/actions.lua:9`, `bookmarks/actions.lua:7`, `collections/data.lua:133` (reseed do RNG global), `reading_sessions.lua:20` (colide, I27) | `util.new_id()` com `vim.uv.hrtime()` |
| Capitalizar rótulo (`_` → espaço, Title Case) | `glossary/ui.lua` (5×), `glossary/graph.lua:58`, `export/glossary_md.lua:59`, JS do `html_graph` | `glossary.util.humanize` |
| Lista de tipos e ícones do glossário | `glossary/ui.lua:285-302,350-367`, `init.lua:130`, `html_graph.lua:1258` (os modais ignoram `custom_types`) | `glossary/types.lua` |
| Resolver de termos e aliases do glossário | `glossary/graph.lua:24-48` (O(n²)), `export/html_graph.lua:4-51`, `glossary/ui.lua:426-464,651-687` | `glossary.query.build_resolver(entries)` |
| "Invalidar o cache do glossário + re-render" | `glossary/ui.lua` (5×), `ui/init.lua` (3×), `init.lua:481` | `glossary_ui.refresh(slug)` ou `render.rerender_preserving_viewport` |
| "Salvar viewport → invalidar → render → restaurar → notify" | `ui/navigation.lua` (**10×**, linhas 226-564) | `render.rerender_preserving_viewport` (já existe) + `invalidate_layout_caches(ctx)` |
| Funções de tipografia e largura | `ui/navigation.lua:218-567` (9 funções que diferem só no campo, no delta e no limite) | `adjust_typography(field, delta)`, `apply_width(ctx, w)` |
| Salvar a posição de leitura | `ui/book_loader.lua:544-568,599-624,650-674` (3×) | `save_reading_position(ctx)` |
| Barra de progresso (`█░`) | `library_dashboard.lua:1135`, `stats_dashboard.lua:603`, `ui/render.lua:242-247` | `widgets.progress_bar` |
| Percentual de progresso do livro | `library_dashboard.lua` (3×), `stats_dashboard.lua:164`, `library_view` e `linked_resources` (sem guarda) | `library.progress_percent(book)` |
| Mapeamento spine href → título no TOC | `padnotes/data.lua:88-100`, `padnotes/template.lua:22-34`, `ui/floating_toc.lua` (3×), `ui/search.lua:28-34`, `ui/search_index.lua:88-106`, `export/data.lua` (errado) | Índices `ctx.data.href_to_spine` / `spine_to_toc` construídos no load |
| Abrir URL e imagem por plataforma | `ui/util.lua:95-137` e `152-180` | `vim.ui.open` |
| Varredura de diretório (`fs_scandir`) | `directory_migration.lua` (4×), `health.lua:159-172`, `library/scanning.lua:33-54` | `fs.list_dir(path, filter)` |
| Invocação do curl | `web/fetcher.lua:112-154` (2×, com user-agent literal repetido) | `curl_get(url, opts)` |
| `build_raw_spine` / `build_compiled_spine` | `web/generic_parser.lua:362-421`, `web/planalto_parser.lua:494-659` (CSS copiado 4×) | `build_spine(parsed, variant)` + `BASE_CSS` |
| `split_by_h1` / `split_by_h2` | `markdown/toc.lua:7-111` | `split_by_level(content, level, default_title)` |
| Indexação de busca | `ui/search_index.lua:131-153` (async) e `174-199` (sync) | `index_chapter(ctx, idx, entries)` |
| Dashboards (framework) | `library_dashboard.lua` × `stats_dashboard.lua`: `find_buf_by_name`, `show()`, cache TTL, pipeline de render, ~25 bordas de box, autocmds, refresh, switch | `dashboard/framework.lua` + `widgets.lua` (veja 7.7) |

---

## 5. Código morto / não utilizado

Todos os itens foram conferidos com grep. **Antes de apagar**, confirme que não há uso externo (configuração do usuário chamando a API diretamente).

### 5.1 Arquivos inteiros

| Arquivo | Linhas | Situação |
|---|---|---|
| `chapter_cache.lua` | 174 | Nenhum `require`. Duplica `cache/lru.lua` com LRU O(n). |
| `html/pool.lua` | 70 | `require` em `html/parser.lua:7`, mas nunca usado ("don't pool them"). |
| `html/string_builder.lua` | 58 | Nenhum `require`. |
| `dashboard/utils/box_drawing.lua` | 113 | Nenhum `require`; os dashboards desenham bordas à mão. **Ou** adotá-lo como widget (7.7). |
| `collections/maintenance.lua` | 178 | Nenhuma função chamada (`cleanup_orphaned_books`, `recalculate_stats`, `export`, `import`, `get_statistics`). |
| `web/test_migration.lua` | 176 | Script manual com 40 `print`, no runtimepath, que **grava dados reais** em `stdpath("data")`. Mover para `tests/` ou remover. |
| `library.lua` | 4 | Shim desnecessário: `require("ink.library")` já resolve para `library/init.lua`. |

### 5.2 Funções exportadas sem chamador

| Módulo | Funções |
|---|---|
| `library/init.lua` | `get_completed_books`, `get_reading_books`, `get_to_read_books`, `get_books_grouped_by_format`, `get_statistics`, `process_files`, `process_epub_files`, `add/remove/get_linked_resource` (quebrados, C13) |
| `library/core.lua` | `add/remove/get_related_resource` (campo `book.related_resources` obsoleto) |
| `library/scanning.lua:9-16` | `is_safe_path` (local) |
| `reading_sessions.lua` | `has_active_session`, `get_sessions`, `get_sessions_range`, `cleanup_old_sessions` (**por isso `tracking.cleanup_after_days` não tem efeito**), `recalculate_totals`, `get_config`, `get_statistics` |
| `library/statistics.lua:9` | `get_statistics` (o stats dashboard recalcula à mão) |
| `user_highlights.lua:166` | `get_cached` ("for benchmark testing") |
| `tracking.lua:101` | `stop` |
| `data/directory_migration.lua:279` | `force_migrate` |
| `ui/render.lua:130-155` | `extract_plain_text` |
| `ui/library_view.lua:306-320` + `ui/init.lua:56` | `show_library_by_format` (usada só em comandos comentados) |
| `ui/init.lua` | reexportações `render_chapter`, `invalidate_glossary_cache`, `clear_book_cache`, `config` |
| `ui/cache.lua:48,95` | `show_cache_telescope`, `show_cache_floating` (só uso interno, deveriam ser `local`) |
| `ui/book_loader.lua` | `create_book_buffer`, `setup_book_context`, `setup_book_keymaps`, `setup_book_autocmds` (só uso interno) |
| `html/patterns.lua` | `get_attribute`, `extract_attributes`, constantes `STYLE_`, `NAME_`, `ALT_`, `WHITESPACE_`, `WORD_PATTERN` |
| `html/utils.lua:64-89` | `reverse_map_column` |
| `html/init.lua` | reexportações `entities`, `tokens`, `parser`, `formatter`, `utils` |
| `html/formatter.lua:15-21` | reexportações "backwards compat" |
| `parsed.justify_map` | gerado em `html/justification.lua:71` e gravado em `ctx.justify_map`, **nunca lido** |
| `markdown/inline.lua:92-98` | `process_emphasis` (duplica `process_inline`) |
| `markdown/toc.lua:140-197` | `extract_headings`, `build_toc` |
| `markdown/util.lua:122-127` | `generate_id` |
| `markdown/init.lua:86-94` | `is_markdown`, reexportações `parser`, `toc_builder`, `util` |
| `css_cache.lua:60-67` | `clear` (deveria ser usada, I32) |
| `dashboard/init.lua:21,27` | `show_library`, `show_stats` |
| `dashboard/utils/text.lua` | `visual_width`, `fit_string`, `word_wrap` |
| `glossary` | `get_by_type`, `get_types`, `get_related`, `add_alias`, `remove_alias`, `add_related`, `remove_related`, `add_custom_type`, reexportações `save/load/get_file_path`. O campo `entry.related` é **um segundo modelo de relacionamento**, paralelo a `relationships`, e está morto. |
| `bookmarks` | `find_by_id`, `find_at_line`, reexportações `save/load/get_file_path`, fallback `bm._line_idx` |
| `notes/init.lua:5-7` | reexportações `get_all_notes`, `get_book_notes`, `get_all_notes_async` |
| `collections` | `rename`, `update`, `move_book`, `count_books`, `get_collection_progress`, `filter_books`, `get_empty_collections`, `search`, `invalidate_stats`, `M.data`, `stats_cache` (≈70% da API) |
| `padnotes/data.lua` | `sanitize_chapter_title`, cálculo de `chapter_title` em `get_padnote_path` (parâmetro ignorado), regex legado de `list_padnotes` |
| `padnotes/actions.lua:319-351` | `toggle()` equivale a `open()` |
| `padnotes` config | `template = "default"` nunca lido |
| `export/util.lua:41-49` | `escape_markdown` (deveria ser usada, I55) |
| `export/init.lua:169-176` | reexportações "advanced" |
| `web/init.lua:47-113` | `old_validate_url` |
| `web/init.lua:413` + `fetcher.lua:350` | `clear_cache` |
| `web/changelog.lua:194` | `get_modified_articles` |
| `web/migrate_highlights.lua:379` | `supports_migration` |
| `web/generic_parser.lua:70,340` | `CONTENT_TAGS`, campo `full_html` |
| `web/planalto_parser.lua:429` | campo `has_modifications` |
| `cache/lru.lua:124-136` | `size`, `stats` (provavelmente) |

### 5.3 Código comentado, legado e restos de debug

- `init.lua:308-322`: comandos `InkListEpubs/Markdown/Web` comentados.
- `epub/init.lua:143,181,188-190,267-270` e `markdown/init.lua:21,63-66`: timing e notify comentados.
- `glossary/data.lua:3,8`: `migrate` comentado com TODO.
- `collections/management.lua:118`: TODO não implementado.
- `ui/context.lua:92-110`: proxy legado `M.ctx` (usado só pelo bug C2).
- `ui/render.lua:193-202`: migração de `parsed_chapters` de tabela para LRU (todo contexto já nasce com LRU).
- `ui/render.lua:267-276`: reinicialização "para contextos antigos" (contextos só existem em memória).
- `export/html_graph.lua`: `console.log` (~11×) e `alert` (2×) de debug no JS gerado.
- `dashboard/library_dashboard.lua:576-577`: `keymap.set("n","j","j")` (no-op).
- `dashboard/stats_dashboard.lua:614-619`: "Pages Read N/A" fixo.
- `export/html_graph.lua:1417-1418`: "Created"/"Modified" sempre `N/A`.

### 5.4 Requires e locais não usados

| Local | Tipo | Item |
|---|---|---|
| `health.lua:61` | require | `library_data` |
| `notes/query.lua:2` | require | `user_highlights` |
| `glossary/ui.lua:4` | require | `util` |
| `ui/library_view.lua:3` | require | `context` |
| `ui/search.lua:1-2` | require | `fs`, `html` |
| `ui/search_index.lua:4` | require | `context` |
| `ui/init.lua:212,248` | require | `glossary` |
| `html/parser.lua:2,7` | require | `tokens`, `pool` |
| `html/formatter.lua:4-5` | require | `tokens`, `entities` |
| `html/text.lua:5` | require | `entities` |
| `web/test_migration.lua:6-7` | require | `fs`, `data` |
| `reading_sessions.lua:5` | local | `cache` (nunca lido) |
| `reading_sessions.lua:90` | local | linha no-op |
| `export/ui.lua:103` | local | `title` |
| `ui/notes.lua:153` | local | `line` |
| `ui/search.lua:206` | local | `header_offset` |
| `ui/search.lua:27,39,53` | local | `chapter_path` |
| `ui/floating_toc.lua:15` | local | `floating_state.ctx` |
| `padnotes/ui.lua:16` | local | `floating_state.ctx` |
| `padnotes/actions.lua:249` | local | `cursor_line` |
| `ui/extmarks.lua:38-39` | parâmetro | `padding` |
| `web/init.lua:261,391` | local | `chlog`, `new_hash` |
| `web/versions.lua:392` | local | `err` |
| `web/migrate_highlights.lua:367` | local | atribuição morta |

Além disso, `glossary/ui.lua` redeclara dentro de funções os módulos `glossary`/`context`, que já vêm do topo.

---

## 6. Organização de módulos e proposta de estrutura

### 6.1 Problemas atuais

1. **`init.lua` é um god-file (898 linhas).** `M.setup` é **uma função de ~720 linhas** que contém:
   - o merge da config (179-184);
   - a migração de diretórios (187-190);
   - os highlight groups e o autocmd de ColorScheme (193-258);
   - **37 comandos de usuário com lógica de negócio inline** (261-849). Exemplos: `InkWebUpdateSafe` faz backup de highlights lendo JSON à mão; `InkRebuildTOC`, `InkAddLibrary`, `InkCleanupRelated`, `InkGlossaryAdd`;
   - os keymaps globais (852-882);
   - o setup de padnotes, tracking e which-key (885-895).
   
   Os `default_config` sozinhos ocupam 169 linhas.
2. **Features divididas de forma incoerente:**
   - **glossary** e **padnotes** seguem o padrão `<feature>/ui.lua`.
   - **bookmarks** tem dados em `bookmarks/` e UI em `ui/bookmarks.lua` (643 linhas).
   - **notes** está em 3 lugares: `notes/` (só listagem), `ui/notes.lua` (CRUD de **highlights** e notas) e `user_highlights.lua` (dados), e há **dois arquivos "notes ui"**.
   - **search**, **related** e **TOC** são features inteiras dentro de `ui/`.
   - **collections** não tem UI própria (vive dentro do dashboard).
   - **library** está em 3 lugares: `library/`, `ui/library_view.lua` e `dashboard/library_dashboard.lua`, que são **duas UIs completas para a mesma função**, com comportamento diferente (uma confirma a exclusão, a outra não).
3. **Caches espalhados:**
   - em `lua/ink/`: `chapter_cache.lua` (morto), `toc_cache.lua`, `css_cache.lua`;
   - em `lua/ink/cache/`: só `lru.lua`;
   - fora das duas: `glossary/cache.lua`, `ui/search_index.lua` e `ui/cache.lua`.
   
   `ui/cache.lua` é a UI que limpa **só** o cache de extração EPUB. Não limpa web, TOC, CSS, glossário nem busca.
4. **Migrações em 4 lugares:** `library/data.lua` (entities), `library/migration.lua` (campos, misturado com regra de negócio `calculate_status`), `data/migrate.lua` (layout de arquivos, executado em **toda** leitura) e `data/directory_migration.lua`.
5. **Sete arquivos `util`** com conteúdo sobreposto e nomes inconsistentes (ver 4.3).
6. **Dependências entre camadas vazando:**
   - `reading_sessions.lua` (camada de dados) faz `require("ink.ui.context")`.
   - `library/core.lua` (dados) carrega os parsers epub, markdown e web para abrir livros.
   - `library/core.remove_book` conhece collections e related. Seria melhor disparar um evento `User InkBookRemoved`.
   - Ciclo `data/related.lua` ↔ `library`.
   - `epub/opf.lua` depende de `html.entities`.
   - `web/init.lua` depende de `markdown.util`.
   - `web/changelog.lua` importa `planalto_parser` diretamente.
7. **`ui/` mistura UI com dados, I/O e algoritmos:**
   - `render.lua` carrega capítulos do disco, faz o pipeline completo de glossário com cache **persistente em disco**, atualiza o statusline e persiste o progresso na biblioteca.
   - `util.lua` tem algoritmos puros de texto e offset junto com abertura de URL por sistema operacional.
   - `navigation.lua` tem comandos de tipografia, que não têm nada a ver com navegação.
8. **`ui/init.lua`** mistura fachada (reexportações) com implementações próprias:
   - glossário (77-263);
   - focused mode (301-393);
   - `open_last_book`.
   
   Submódulos importam a fachada, o que gera os ciclos.
9. **`dashboard/utils/`** guarda helpers genéricos de texto e data usados ou duplicados em todo o projeto.
10. **`html/`** é na verdade um **motor de layout** (HTML para linhas, highlights e justificação), não um parser genérico.
    - `css_parser/highlighter.lua` mapeia CSS para grupos `Ink*`, que é responsabilidade do renderizador.
    - `css_cache.lua` fica na raiz.
11. **Código específico do Planalto (legislação brasileira) misturado ao código web genérico:**
    - `language = "pt-BR"` fixo para **qualquer** site;
    - encoding ISO-8859-1 fixo;
    - rótulos "Crua"/"Compilada" aplicados a qualquer página;
    - autor "Governo Federal do Brasil".
12. **`health.lua`** reimplementa uma janela flutuante própria em vez de usar `vim.health`.

### 6.2 Estrutura-alvo proposta

```
lua/ink/
  init.lua                 -- só: setup(opts) → config.setup, highlights.setup, commands.setup, keymaps.setup (~30 linhas)
  config.lua               -- defaults (único lugar), setup(), get()
  types.lua                -- só anotações LuaCATS (ink.Config, ink.Context, ink.Book, ...)
  notify.lua               -- wrapper de vim.notify com title + mensagens padrão
  health.lua               -- usando vim.health.*
  highlights.lua           -- definição dos highlight groups + autocmd ColorScheme

  commands/                -- registro declarativo { name, fn, opts, complete }
    init.lua
    library.lua  cache.lua  related.lua  glossary.lua  web.lua  export.lua  notes.lua  bookmarks.lua
  keymaps/
    global.lua             -- keymaps globais (ex-init.lua:852-882)
    reader.lua             -- tabela declarativa dos keymaps do leitor (ex-book_loader.lua:91-406)

  util/                    -- utilidades puras, sem vim.api quando possível
    date.lua  id.lua  tbl.lua
  text/                    -- ver 4.3: width, wrap, strings, html, xml, slug, anchor
  fs.lua                   -- + list_dir, sem efeito colateral no load

  data/                    -- persistência
    paths.lua              -- book_dir, cache_dir(slug, kind), library_file (validação de slug + memo)
    json.lua               -- read (decode seguro + backup), write (atômico)
    store.lua              -- store genérico por livro/global com cache e migração
    migrations/            -- TODAS as migrações, versionadas por schema_version
      init.lua  directory_layout.lua  book_files.lua  library_fields.lua  entities.lua
    state.lua              -- (ex-ink/state.lua)

  cache/
    lru.lua  toc.lua  css.lua  glossary.lua  search.lua
    registry.lua           -- lista/limpa todos os caches de um slug (usado por :InkClearCache)

  formats/                 -- loaders: open(path, opts) -> ink.Book | nil, err  (contrato único)
    init.lua               -- detect(path_or_url), open(path)
    book.lua               -- construtor/normalizador de ink.Book (format, spine, toc, ...)
    toc.lua                -- item de TOC comum + build_from_headings
    epub/    init.lua container.lua opf.lua nav.lua ncx.lua css.lua extract.lua(unzip/tar)
    markdown/ init.lua block.lua inline.lua chapters.lua
    web/
      init.lua             -- orquestra: validate → provider = registry.match(url) → fetch → parse
      fetch.lua            -- curl + vim.iconv
      security.lua         -- validate_url / SSRF
      registry.lua
      providers/generic.lua
      providers/planalto/{init,parser,diff}.lua
      tracking/{versions,changelog,remap}.lua

  layout/                  -- motor de layout (ex-html/ + css_parser/)
    html/  parser.lua formatter.lua blocks.lua text.lua table.lua justification.lua tokens.lua
    css/   parser.lua styles.lua

  library/
    init.lua  store.lua  queries.lua  scanning.lua  statistics.lua  model.lua(calculate_status, progress_percent)
  sessions/                -- ex reading_sessions.lua + tracking.lua
    store.lua  stats.lua  tracker.lua

  features/                -- (ou manter na raiz) — TODAS com o mesmo layout:
    highlights/  init store query actions ui           (ex user_highlights.lua + ui/notes.lua)
    notes/       init query actions browser            (ex notes/ + parte de ui/notes.lua)
    bookmarks/   init store query actions ui browser   (ex bookmarks/ + ui/bookmarks.lua)
    glossary/    init store query actions detection graph types ui browser editor graph_view
    padnotes/    init store actions template ui
    collections/ init store actions query               (maintenance removido)
    related/     init store ui                          (ex data/related.lua + ui/linked_resources.lua)
    search/      index ui                               (ex ui/search*.lua)
    export/      init registry data formats/{markdown,json,glossary_md} glossary_graph/{data,render}
                 resources/ (template.html, graph.css, graph.js)

  ui/                      -- núcleo do leitor + componentes compartilhados
    init.lua               -- fachada pura (só reexporta; submódulos nunca a importam)
    context.lua            -- registro de contextos (sem proxy legado; índice buf→ctx)
    book_loader.lua        -- só open_book
    autocmds.lua
    render.lua             -- orquestrador render_chapter
    chapter_source.lua     -- carregar/parsear/LRU
    layout.lua             -- padding, line spacing (função pura), adaptive width
    viewport.lua           -- captura/restaura posição, save_reading_position
    statusline.lua
    extmarks/  highlights.lua notes.lua margin_notes.lua bookmarks.lua glossary.lua
    modes/     focused.lua reading_paragraph.lua
    links.lua              -- jump/handle_enter
    typography.lua         -- width/justify/spacing commands
    toc.lua                -- ex floating_toc
    footnotes.lua
    float.lua  picker.lua  format.lua  modals.lua   -- componentes compartilhados

  dashboard/
    init.lua               -- registro: show(name, opts)
    framework.lua          -- buffer/aba, flush com centralização, autocmds, teclas comuns, ttl cache
    widgets.lua            -- Box, columns, kv_list, progress_bar, sparkline
    views/library.lua  views/stats.lua
    providers/library.lua  providers/stats.lua
    actions/library.lua
```

**Princípios desta estrutura:**
1. Cada feature tem `init` (fachada), `store` (persistência), `query` (leitura pura), `actions` (mutações), `ui` (interação no buffer do leitor) e `browser` (picker/listagem).
2. Cada feature exporta `M.commands` e `M.keymaps(buf, cfg)`. `commands/init.lua` e `keymaps/reader.lua` só iteram sobre eles.
3. Camadas: `util/text/fs` → `data/cache` → `formats/layout/library/sessions` → `features` → `ui/dashboard` → `commands/keymaps`. **Nunca** importar de uma camada superior. Para avisar outras partes, usar eventos `User Ink*`.
4. `ui/init.lua` e as fachadas `init.lua` não contêm lógica.

> **Nota:** não é preciso fazer tudo de uma vez. A seção 13 propõe uma ordem incremental. Mover arquivos de lugar é o passo de **maior risco e menor ganho imediato**, então deve vir depois da deduplicação.

---

## 7. Análise por área

Esta seção resume os pontos específicos de cada área que ainda não foram cobertos nas seções transversais.

### 7.1 Núcleo (`init.lua`, `state`, `fs`, `data/*`, `library/*`, `reading_sessions`, `tracking`, `user_highlights`, `health`)

- **`init.lua`:** ver 6.1-1. Proposta de divisão em `config.lua`, `highlights.lua`, `commands/*`, `keymaps/global.lua` e `formats.open`.
- **`state.lua`:** `save` faz `load` + migração + `tbl_deep_extend` + escrita síncrona **a cada mudança de posição** (CursorHold). Manter o estado em memória e gravar com debounce.
- **`data/migrate.lua`:** é executado em **todo** `state.load` e em todo acesso a highlights (2 `fs_stat` por chamada). Consolidar num passo versionado no `setup`, com `schema_version`.
- **`library/data.lua`:** reescreve o arquivo em toda leitura (I24). Precisa de cache em memória com invalidação por mtime.
- **`library/scanning.lua`:**
  - o comentário diz "async", mas o código é síncrono;
  - a recursão não tem limite e segue symlinks;
  - o relatório só fala de "EPUB", embora também encontre Markdown.
- **`reading_sessions.lua`:** bugs C1, C2, I27 e I28. Além disso:
  - `load_sessions` não tem cache, então o stats dashboard lê `sessions.json` 4N vezes;
  - a variável `cache` é declarada e nunca populada.
- **`user_highlights.lua`:**
  - `positions_cache` cresce sem limite;
  - `save` invalida o cache em vez de atualizá-lo;
  - a chave do cache é o texto inteiro.
- **`fs.lua`:** efeito colateral no carregamento (I30). `command_exists` duplica `health`.
- **`health.lua`:** ver I31.
- **`which_key_groups.lua`:** não registra `highlight_change_color_keymaps`, `notes_list_keymaps` nem `export_keymaps`.

### 7.2 UI: núcleo do leitor (`ui/render`, `book_loader`, `extmarks`, `navigation`, `context`, `init`, `util`, `cache`)

**Responsabilidades misturadas:**

| Arquivo | O que concentra hoje |
|---|---|
| `render.lua` (916) | I/O de capítulo, parse + LRU, line spacing com remapeamento de coordenadas, renomear buffer, padding, orquestração de extmarks, pipeline de glossário com cache em disco, cursor, statusline, persistência na biblioteca, toggles, viewport |
| `book_loader.lua` (821) | Largura adaptativa, buffer/contexto, ~315 linhas de keymaps, ~270 de autocmds, `open_book` |
| `extmarks.lua` (757) | Todos os tipos de extmark + todo o modo de leitura por parágrafo (estado, autocmds, toggle, persistência) |

**Outros pontos:**
- **Objetos de dados mutados com campos de UI:** `hl.dimmed_id`, `hl._start_line` e `bm._line_idx` são gravados em objetos que vêm de `user_highlights` e `bookmarks`. Usar um mapa paralelo no `ctx`.
- **Prioridades de extmark espalhadas** (50, 100, 200, 1000, 1500, 2000, 2900, 3000, 4000). Criar uma tabela `PRIORITY = { dim=50, pad=100, ... }`.
- **`render.lua:278-297`:** se a janela de conteúdo sumiu, o render executa `vim.cmd("vsplit")`, um efeito colateral inesperado.
- **`render.lua:409` e `floating_toc.lua:330`:** `nvim_buf_set_name` pode falhar com E95. Envolver em `pcall`.
- **`book_loader.lua:497-521`:** `BufWinEnter`/`BufWinLeave` usam `nvim_get_current_win()` dentro de `schedule`. Usar `vim.fn.bufwinid(args.buf)`.
- **`navigation.lua:39-40,83`:** `normal! zz` roda na janela atual, não necessariamente na de conteúdo. Usar `nvim_win_call`.
- **`context.lua:53-62`:** `M.get` percorre todos os contextos a cada chamada. Manter um índice reverso `buf → ctx`.
- **Estado de módulo nunca limpo:** `margin_warning_shown` e `orphan_warnings_shown` (este último cresce por `slug:capítulo`).
- **Proposta de divisão:** ver 6.2 (`chapter_source`, `layout`, `viewport`, `statusline`, `extmarks/*`, `modes/*`, `links`, `typography`, `autocmds`, `keymaps/reader`).

### 7.3 UI: features (`ui/bookmarks`, `notes`, `floating_toc`, `linked_resources`, `library_view`, `search`, `search_index`, `modals`, `footnotes`)

- **Maior duplicação:** `library_view.lua` × `linked_resources.lua` (ver 4.6). Extrair `ui/format.lua` + um picker de livros elimina ~250 linhas.
- **`ui/bookmarks.lua`:**
  - `remove` e `edit` repetem a busca de bookmarks no parágrafo;
  - `goto_next` e `goto_prev` são cópias;
  - o bloco de salto com `defer_fn` aparece 4 vezes.
- **`ui/search.lua`:**
  - `get_index_status` decodifica o JSON inteiro só para dizer "cached", e depois o índice é lido de novo;
  - não há proteção contra builds concorrentes nem cancelamento.
- **`ui/search.lua:77,300`:** `<C-f>` só é mapeado no modo insert.
- **`ui/floating_toc.lua:91-100`:** o preview chama `html.parse` sem `typography`/`justify`, então diverge do render real.
- **Exclusões sem confirmação** (I14).
- **`defer_fn` de 10/100 ms** usado como sincronização (race condition).

### 7.4 Parsers (`html/`, `css_parser/`, `epub/`, `markdown/`)

**Os loaders não compartilham uma interface:**

| Campo | `epub.open` | `markdown.open` | `web.open` |
|---|---|---|---|
| `format` | **ausente** | `"markdown"` | `"web"` |
| `spine[i]` | `{href, media_type}` | `{content, href="chapter-N", title, index}` | um único item |
| `toc[i]` | `{label, href, level}` | `+ chapter_index` | — |
| `class_styles` | sim | ausente | — |
| `language`/`author` | do OPF | fixos `"en"`/`"Unknown"` | fixo `"pt-BR"` |
| `opts` | usados | ignorados | usados |
| erro | `error()` | `nil, err` | `nil, err` |

Por causa disso, `ui/render.lua:171`, `ui/navigation.lua:45,157` e `ui/util.lua:33` tratam cada formato caso a caso. **Proposta:** criar o tipo `ink.Book` com um construtor `book.new{...}` que normalize os campos.

**Outros pontos:**
- **Markdown → HTML → `html.parse`:** o formato intermediário compartilhado é uma boa ideia, mas exige que o markdown escape tudo corretamente (C9).
- **TOC construído de 4 formas:** `nav`, `ncx`, conteúdo e `markdown/toc`. Unificar com `formats/toc.lua` e `build_from_headings(parsed.headings)`.
- **`epub/init.lua:109-140`** (`build_toc_from_content`): faz o parse completo de todos os capítulos de forma síncrona, com largura 80 fixa.
- **CSS:**
  - `css_parser` só entende seletores `.classe {`;
  - a ordem do CSS é indefinida (`pairs(manifest)`);
  - uma classe definida em dois arquivos é sobrescrita em vez de mesclada.
- **`html/blocks.lua:67,75`:** a linha do heading é registrada no fechamento (multilinha aponta para a última linha). Só H1-H3 entram.
- **`html/table.lua`:** a largura mínima de 10 por coluna pode passar de `max_width`.
- **`html/justification.lua`:** perde o recuo inicial da linha.
- **Typography parcial vinda do usuário quebra com `nil`** (`html/text.lua:18`). Fazer o merge com defaults uma única vez em `parser.parse`.
- **`markdown/util.lua`** mistura o lexer de markdown com utilidades genéricas, e vários `gsub` vazam um segundo valor de retorno.
- **`unzip` (`fs.lua:108-120`):** não é garantido no Windows. Fazer fallback para `tar -xf` (bsdtar, Windows 10+).

### 7.5 Web (`web/*`)

- **Bugs graves:** C5, C6, I45-I52.
- **Contrato de provider implícito:** `generic_parser` e `planalto_parser` já têm a mesma API. Formalizar um registro de providers (ver 6.2) com a interface `{ name, match, slug, encoding?, parse, build_spines, build_toc, metadata, diff?, version_labels? }`.
- **Tudo síncrono:** `vim.system():wait()` trava a UI por até 30 s. O DNS faz espera ativa com `uv.run("nowait")`, reentrando no loop.
- **Parse repetido:** numa atualização, o HTML do Planalto é parseado **4 vezes**. As preferências de versão são lidas de 3 a 4 vezes por `open`.
- **`check_updates`** baixa a página inteira só para comparar o hash. Usar `curl -I` com ETag/Last-Modified.
- **Laços O(n²)** que recomeçam do início e concatenam strings: `remove_strikethrough`, `normalize_strikethrough` e `clean_html`.
- **CSS injetado fora do `<head>`:** provavelmente não tem efeito, ou aparece como texto. **Vale verificar visualmente.**
- **Comandos `InkWeb*`:** ~130 linhas de lógica web dentro de `init.lua:512-646`. Mover para `web/commands.lua`.

### 7.6 Export (`export/*`)

- **`html_graph.lua` (1955 linhas):**
  - ~9% Lua, ~48% CSS, ~7% HTML e ~36% JS, tudo numa long string dentro de **uma função de ~1780 linhas**;
  - o CSS tem regras duplicadas;
  - o JS mistura `innerHTML` com `createElement` e handlers inline com `addEventListener`;
  - o D3 vem de CDN sem versão fixa nem SRI, então o arquivo não funciona offline.

  **Proposta:**
  - `export/glossary_graph/data.lua` para a lógica Lua;
  - `resources/glossary_graph/{template.html, graph.css, graph.js}`, lidos em runtime e inlinados no arquivo final;
  - dados passados num bloco `<script type="application/json">`, o que também reduz a superfície de injeção (C25).
- **Sem registro de formatos:** o formato está fixo em 4 lugares (`if/elseif` em `init.lua:135`, parser da UI, extensão e prompt). **Proposta:** `M.formats = { markdown = { ext="md", aliases={"md"}, format=fn }, ... }` + `register_format`.
- **`export/data.lua`** reimplementa a coleta de bookmarks (pior: sem desempate e quebra com `chapter` nil) e notas. Usar `bookmarks.query` e `notes.query`.
- **Medidas em bytes:** `word_wrap` e a regra `#text >= 80` contam bytes, então texto em português quebra antes do previsto.
- **PNG/SVG exportados perdem o estilo** (o CSS não é serializado junto).
- **Resize no grafo** não atualiza `width`/`height`.
- **Saída não determinística:** a iteração com `pairs` gera diffs ruidosos entre execuções.
- **Bugs:** I53-I59 e C24, C25.

### 7.7 Dashboard (`dashboard/*`)

- **Duas camadas em cada arquivo:** os dois dashboards misturam dados, render, input e ações num arquivo só, e duplicam ~40% do código entre si (ver 4.11).
- **Proposta:** `framework.lua` (abrir buffer/aba, `flush` com centralização H/V, autocmds, teclas comuns, ttl cache), `widgets.lua` (Box builder, `render_columns`, `render_kv_list`, `progress_bar`, `sparkline`), `views/`, `providers/` (agregação pura) e `actions/`.
- **O stats dashboard recalcula tudo à mão,** em vez de usar `library.get_statistics()` e `reading_sessions.get_statistics()` (que existem e estão mortos). Pior: chama `library.get_books()` 4 vezes e lê `sessions.json` 4N vezes. Criar um provider de passada única.
- **`collections.get_book_collections` por livro:** é O(N·C·M). Pré-computar `slug → coleções`.
- **Estado de módulo compartilhado:** filtros e ordenação persistem entre aberturas, e dois dashboards abertos em abas diferentes compartilham o mesmo estado.
- **`render()` usa a janela corrente** (`nvim_win_get_width(0)`), não a do dashboard.
- **A confirmar:** `WinResized` com `buffer = buf` pode não disparar (o pattern do evento é o ID da janela). Testar.
- **Bugs:** C22, C23, I60-I64.

### 7.8 Features (`glossary`, `notes`, `bookmarks`, `padnotes`, `collections`)

| Feature | init | data | query | ui | actions | cache | Onde fica a UI |
|---|---|---|---|---|---|---|---|
| glossary | fachada | ✔ | ✔ | ✔ (1055 l.) | ✔ | ✔ (disco) | `glossary/ui.lua` + wrappers em `ui/init.lua:80-260` |
| notes | fachada (requires inline) | ✘ (lê `highlights.json` direto) | ✔ | só listagem | ✘ | ✘ | `ui/notes.lua` + `notes/ui.lua` |
| bookmarks | fachada | ✔ (sem cache) | ✔ | ✘ | ✔ | ✘ | `ui/bookmarks.lua` |
| padnotes | fachada lazy **+ estado/config** | ✔ (+ formatação de data) | ✘ | ✔ | ✔ | ✘ | `padnotes/ui.lua` |
| collections | fachada + `M.data` | ✔ (com cache) | `queries` (plural) | ✘ | `management` + `associations` | dentro de `data`/`queries` | dashboard |
| highlights | — (arquivo único) | ✔ | ✔ | — | ✔ | ✔ | `ui/notes.lua` |

**Pontos principais:**
- **`glossary/ui.lua` (1055 linhas):** dividir em `ui.lua` (modais e preview), `browser.lua`, `editor.lua` (linhas 71-253) e `graph_view.lua` (928-1053).
- **Desempenho do glossário:**
  - `get_all` relê e reordena o JSON a cada chamada;
  - `detection.detect_in_text` recria e reordena a lista de termos **para cada linha** (O(L·T log T));
  - `graph.generate_full_graph` é O(N²).
  - Pré-computar tudo no `build_detection_index`.
- **collections:** ~70% da API está morta. Consolidar em `init` + `store` + `actions` + `query`.
- **padnotes:**
  - `toggle` equivale a `open`;
  - o timer de auto-save percorre `nvim_list_bufs()` a cada tick;
  - `get_padnote_path` faz um cálculo morto.
- **Todos os keymaps de feature** ficam em `ui/book_loader.lua`, e todos os comandos em `init.lua`. Cada feature deveria exportar os seus.

---

## 8. Desempenho

Ordenado por impacto percebido:

| # | Local | Problema | Proposta |
|---|---|---|---|
| P1 | `library/data.lua:70-72` + `queries` + scan | Reescreve `library.json` em toda leitura; dezenas de leituras e escritas por ação | Salvar só quando a migração muda algo; cache em memória com mtime |
| P2 | `stats_dashboard.lua` + `reading_sessions.lua` | `get_books()` 4×; `sessions.json` lido 4N× | Provider de passada única + cache em `load_sessions` |
| P3 | `ui/book_loader.lua:434-443` | Todo `WinResized` apaga o cache de glossário **em disco** e re-renderiza | Invalidar só quando a largura muda |
| P4 | `ui/util.lua:220-290` (`find_text_position`) | Concatena o capítulo inteiro e percorre caractere a caractere com `sub`/`match`, para **cada** highlight sem cache e para **cada** bookmark: O(H·N) | Mapa de offsets normalizados construído uma vez por render |
| P5 | `glossary/detection.lua:100-111,175` | Recria e ordena a lista de termos por linha | Pré-computar no índice |
| P6 | `ui/render.lua:516,576,720` | Lê o glossário do disco a cada render; grava o cache inteiro a cada miss; `state.load` (com migração) a cada re-render | Cache no `ctx` |
| P7 | `data/migrate.lua`, `data.get_book_dir`, `get_cache_path`, `get_padnotes_dir`, `get_index_cache_path` | `fs_stat` + `mkdir -p` a cada leitura | Memoizar diretórios e migrações por slug |
| P8 | `bookmarks/query`, `glossary/query`, `notes/query` | Releem o JSON do disco a cada chamada (o render chama `get_chapter_bookmarks` sempre) | `data/store.lua` com cache |
| P9 | `collections/associations.lua:108-119` | `get_book_collections`: O(C²+C·B) por livro, executado para cada livro do dashboard | Índice `slug → {ids}` |
| P10 | `extmarks.update_reading_paragraph_highlights` | Refaz `apply_dim_all` + `get_chapter_highlights` + resolve posições a cada troca de parágrafo | Calcular uma vez por render |
| P11 | `html/text.lua:129-130` | `strdisplaywidth` da linha inteira a cada palavra: O(n²) | Largura incremental |
| P12 | `html/justification.lua:73-92` | Varre todos os highlights para cada linha justificada | Indexar por linha |
| P13 | `html/blocks.lua:148` | `content:lower()` do capítulo inteiro a cada `<pre>` | `find` com padrão case-insensitive |
| P14 | `html/blocks.lua:210` | `require` dentro de um laço por classe CSS | Mover para o topo |
| P15 | `epub/init.lua:109-140` | Parse completo síncrono de todos os capítulos para montar o TOC | Regex só de `<h1-3>` |
| P16 | `web/*` | HTML parseado 4× por atualização; laços O(n²); download completo só para comparar hash | Ver 7.5 |
| P17 | `ui/util.lua:351-358`, `extmarks.lua:329`, `html/table.lua:163-186` | Concatenação de string ou `table.concat` dentro de laços | Buffer de tabela |
| P18 | `ui/library_view.lua:27-29` (`fit_string`) | Remove um caractere por vez: O(n²) | `text.truncate` unificado |
| P19 | `dashboard/*:382-387` | `table.insert(lines, 1, "")` em laço | Montar o prefixo antes |
| P20 | `ui/search_index.lua:266-280` | Decodifica o JSON inteiro só para devolver o status | `fs.exists` + metadados |
| P21 | `ui/context.lua:53-62` | `get` linear sobre os contextos a cada chamada | Índice `buf → ctx` |
| P22 | `export/html_graph.lua:1774-1799` (JS) | `Map linkPairs` reconstruído **a cada tick** da simulação | Calcular uma vez |
| P23 | `padnotes/actions.lua:50-55` | O timer percorre `nvim_list_bufs()` a cada tick | Checar só o buffer conhecido |

---

## 9. Números mágicos

Agrupados por tema. **Proposta geral:**
- constantes nomeadas no topo de cada módulo para valores internos;
- a tabela `config` para o que o usuário pode querer ajustar;
- uma tabela `PRIORITY` para extmarks.

| Tema | Valores e onde aparecem |
|---|---|
| Largura padrão | `120`: `render` 217, 306 e 862; `navigation` 222 e 249; `extmarks` 294; `context` 5; `init.lua` 409; dashboards (`math.min(w-4, 120)`) |
| Largura mínima | `40`: `book_loader` 48; `navigation` 250 e 278 |
| Tamanho do LRU | `15`: `context` 33; `render` 197; `book_loader` 434 |
| Limites de spacing | `5`, `1`: `navigation` 382, 416, 450 e 484 |
| Margem adaptativa | `0.8`, `0.1`, `1.0`: `book_loader` 31-42 |
| Contexto da âncora | `30`: `ui/notes` 112 e 255; `ui/bookmarks` 99 e 140; `render` 106. `200`/`100`: `render` 98; `ui/bookmarks` 73, 90, 102 e 141 |
| Prioridades de extmark | 50 / 100 / 200 / 1000 / 1500 / 2000 / 2900 / 3000 / 4000, espalhados por `extmarks` e `render` |
| Margem de notas | `35`, `4`/`20`/`40`, `MAX_NOTE_LINES 10`. O prefixo `4` não bate com o prefixo real `"[^N] "` |
| Delays | 10 / 100 ms em `ui/bookmarks` e `ui/search`; 150 / 20 / 10 ms em `scanning` |
| Floats | 0.5 / 0.6 / 0.7 / 0.8 / 0.70 / 0.30; `80`/`100`/`20`; `60`/`20` em `ui/cache` |
| Colunas de listagem | 28 / 20 / 15 / 10 / 4: `library_view`, `linked_resources`, `library_dashboard` |
| Wrap | `60`: `library_view`, `linked`, `footnotes`. `80`/`78`: `export/markdown`. `80`: `epub/init.lua:119`. `60`: `html/formatter.lua:92` (hr) |
| Truncamentos | 20/17, 60/57: `search_index`. 60/57/80/50: `notes/ui`. `title:sub(1,n)`: dashboard |
| Async | `20` livros (`notes/query`, `notes/ui`, `search_index`); `50` (`search`, `search_index`); `5` (lote) |
| Cache TTL | 30 s (`library_dashboard`) e 60 s (`stats_dashboard`) |
| Paginação | `items_per_page = 15`; offset de cabeçalho `+ 6` (`library_dashboard.lua:849`, frágil) |
| Stats | top `5` (definido duas vezes); `6` coleções; comprimentos de cabeçalho fixos (18, 15, 8, 14, 9, 11) |
| Tempo | `86400` (6×), `30*24*60*60`, `3600` (sessão órfã), `120` s (auto-save, 3 lugares) |
| Glossário | pesos de busca 10/8/3; apenas H1-H3; default `"📝"` / `"InkGlossary"` |
| Padnotes | linha `6` do cabeçalho (2 lugares, deveria ser `#lines`); mínimos de split 10/5; preview com `15` linhas |
| HTML | `0.90` (justificação); `10` (tabela); `- 2` (indent); `2` (indent de lista no markdown); `50` (pool) |
| Web | `2048` (3×), `30` (timeout), `200`, `2000`, `80`, `100`, `10000` (2×), pesos 10/50/25/20, `16` (hash) |
| Grafo | 300/320/150, −1000/−1100/−900/−200, raios 100/110, 600, 24, 38, 14; header `89px` (2×), footer `70` (2×) |
| Cores fixas | `#666666`/`#1d1d1d` (`init.lua:238-245`), fora da config |

---

## 10. Funções longas

Candidatas a quebrar, em ordem de tamanho:

| Função | Local | Linhas | Sugestão |
|---|---|---|---|
| `M.generate` | `export/html_graph.lua:170-1953` | ~1780 | Template em arquivos (7.6) |
| `M.setup` | `init.lua:178-896` | ~720 | `config` / `highlights` / `commands` / `keymaps` (6.2) |
| `render_chapter` | `ui/render.lua:259-637` | ~380 | `chapter_source`, `layout`, `extmarks`, `glossary_render`, `viewport` |
| `setup_book_keymaps` | `ui/book_loader.lua:91-406` | ~315 | Tabela declarativa `{group, key, mode, fn, desc}` + laço |
| `setup_book_autocmds` | `ui/book_loader.lua:409-679` | ~270 | `ui/autocmds.lua` + `save_reading_position` |
| `parse_articles` | `web/planalto_parser.lua:218-434` | ~217 | `find_article_markers`, `extract_header`, `article_bounds`, `article_title` |
| `show_glossary_telescope` | `glossary/ui.lua:596-804` | ~210 | `ui/picker.lua` |
| `open_search_picker` | `ui/search.lua:110-312` | ~200 | O `define_preview` sozinho tem ~120 |
| `render` | `dashboard/library_dashboard.lua:218-408` | ~190 | header, lista, help, flush |
| `M.open` | `padnotes/actions.lua:84-264` | ~180 | `compute_split_size`, `recover_content_win`, `open_split` |
| `show_book_preview` | `dashboard/library_dashboard.lua:1072-1242` | ~170 | dados / moldura / janela |
| JS `updateGraph` | `export/html_graph.lua:1655-1819` | ~165 | `renderLinks`, `renderNodes`, `bindEvents`, `onTick` |
| `show_library_telescope` | `ui/library_view.lua:37-198` | ~162 | picker de livros |
| `load_data` | `dashboard/stats_dashboard.lua:91-248` | ~158 | provider |
| `web.open` | `web/init.lua:228-376` | ~149 | `handle_update`, `build_page_data` |
| `epub.open` | `epub/init.lua:142-286` | ~145 | `ensure_extracted`, `load_opf`, `load_toc`, `load_css`, `resolve_toc` |
| `show_bookmarks_telescope` | `ui/bookmarks.lua:368-501` | ~134 | picker |
| `html.parse` | `html/parser.lua:11-143` | ~133 | — |
| `book_loader.open_book` | `ui/book_loader.lua:686-816` | ~130 | — |
| `show_related_telescope` | `ui/linked_resources.lua:97-225` | ~129 | picker de livros |
| `show_entry_preview` | `glossary/ui.lua:400-526` | ~125 | `build_entry_lines` |
| `util.open_image` | `ui/util.lua:7-138` | ~130 | `vim.ui.open` |
| `show_glossary_floating`, `show_notes_telescope` | `glossary/ui.lua:807-925`, `notes/ui.lua:82-199` | ~120 cada | — |
| `add_related_resource` | `ui/linked_resources.lua:246-360` | ~115 | — |
| `handle_enter` | `ui/navigation.lua:102-216` | ~115 | `open_external`, `find_anchor_in_book`, `goto_href` |
| `convert_to_graph_data` | `export/html_graph.lua:4-117` | ~113 | resolver / nodes / links / dedupe |
| `handle_opening_tag` | `html/blocks.lua:109-219` | ~111 | — |
| `fetch_url` | `web/fetcher.lua:102-207` | ~106 | — |
| `validate_url` | `web/init.lua:118-221` | ~104 | — |
| `apply_margin_notes` | `ui/extmarks.lua:472-572` | ~100 | — |
| `html/text.add_text` | `html/text.lua:60-159` | ~100 | — |
| `apply_bookmarks` | `ui/extmarks.lua:253-349` | ~97 | — |
| `apply_justification` | `html/justification.lua:8-101` | ~94 | 6 níveis de aninhamento |
| `handle_closing_tag` | `html/blocks.lua:17-107` | ~91 | — |

---

## 11. Segurança e portabilidade (Windows)

### Segurança

- **Injeção HTML/JS no grafo exportado** (C25).
- **SSRF incompleto** (`web/*`):
  - `curl -L` segue redirects para IPs privados sem nova validação;
  - há risco de DNS rebinding;
  - a lista de IPs bloqueados está incompleta (faltam `0.0.0.0/8`, `100.64/10`, `::`, `fec0::/10`);
  - não usa `--fail`, então respostas 404/500 são cacheadas;
  - não há `--max-filesize`.
  
  Sugestão: `--proto =http,https --proto-redir =http,https --max-redirs 5 --fail --resolve host:port:ip`.
- **Validação de caminhos:**
  - `epub/util.lua:12`: checa o prefixo sem separador;
  - os `href` do spine não são validados;
  - os caminhos de cache não validam o slug;
  - `export/init.lua:12-40` não protege nada no Windows;
  - `ui/util.lua:19` só bloqueia `^/` e `^~`.
- **Escape de shell está correto:** `vim.system` sempre recebe argv em lista. ✔

### Windows (o seu ambiente)

| Problema | Local | Correção |
|---|---|---|
| `unzip` não garantido no PATH | `fs.lua:108` | Fallback `tar -xf` |
| `curl`/`iconv` lançam erro se ausentes | `web/fetcher.lua` | `vim.iconv` nativo; checar `curl` no health |
| `du -sh`, `rm -rf` | `health.lua:177,181` | Usar Lua |
| Dicas de instalação só para apt/brew | `health.lua:28` | Incluir winget/scoop |
| Comparação de caminhos sensível a maiúsculas e `\` vs `/` | `export/init.lua`, `ui/util.lua:50,74` | `vim.fs.normalize` + comparação case-insensitive |
| Montagem de caminho com `"/"` | vários | `vim.fs.joinpath` |
| `io.open(..., "w")` converte `\n` em `\r\n` | todos os saves e exports | `"wb"` |
| Caminho com espaço truncado | `export/ui.lua:41,70-72` | Tratar o resto da linha como caminho |
| `fs_realpath` pode retornar nil | `ui/util.lua:74-75` | Checar |

---

## 12. Divergências entre README e código

| README | Código |
|---|---|
| "Neovim 0.7+" (`README.md:59`) | Usa `vim.system` (0.10+); `health` exige 0.8; `nvim_open_win` com `title` exige 0.9 |
| Requisitos não citam `curl` nem `iconv` | `web/` depende dos dois |
| "Smart caching ... automatic invalidation" | O cache web nunca expira por tempo |
| `:InkOpen https://example.com/article` como se fosse genérico | O suporte rico (artigos, changelog, versões) é **só do planalto.gov.br**; `language = "pt-BR"` fixo para qualquer site; URLs genéricas não reabrem pela biblioteca (I26) |
| `InkWebToggleVersion`: "Switch between versions" | Os rótulos "Crua/Compilada" não fazem sentido para páginas genéricas |
| Seção de armazenamento | Não lista `page.html`, `page_metadata.json`, `changelog.json`, `version_prefs.json`, `highlights.json.before-update.*`; não avisa que apagar `cache/` perde a base de comparação |
| `export_defaults.{format, include_*}` documentados | Ignorados (I59) |
| `tracking.cleanup_after_days` | Nunca aplicado (função morta) |
| `focused_mode = false`, `glossary_visible = false` | Não têm efeito (C18) |
| `padnotes.template` | Nunca lido |
| `ink-test.md` | Não cobre web; não existem testes automatizados |

---

## 13. Roteiro sugerido de refatoração

As fases estão em ordem e cada uma pode virar um ou mais PRs pequenos. A regra geral é: **primeiro corrigir e padronizar, depois deduplicar, e só no fim mover arquivos de lugar.**

### Fase 0: Rede de segurança (antes de tudo)
- [ ] Criar `tests/` com [mini.test](https://github.com/echasnovski/mini.nvim) ou plenary/busted, rodando headless.
- [ ] Testes de caracterização para funções puras: `html.parse` (com os casos de C3, C4, I38-I42), `markdown` (C8, C9), `slugify`, `find_text_position`, `json` (round-trip), `entities`.
- [ ] Mover `web/test_migration.lua` para `tests/` usando um diretório de dados temporário.
- [ ] Adicionar CI simples (GitHub Actions: `stylua --check` + testes).

### Fase 1: Bugs críticos
Corrigir **C1-C25** (seção 2.1), com cada correção acompanhada de um teste quando possível. São mudanças pequenas e localizadas.

### Fase 2: Padronização mecânica
- [ ] `.stylua.toml` + `.editorconfig`. Formatar tudo em **um commit isolado**.
- [ ] Remover o código morto da seção 5 (um commit por área).
- [ ] Remover requires e locais não usados.
- [ ] Trocar as APIs depreciadas (3.9) e declarar Neovim 0.10+.
- [ ] Escrever `CONTRIBUTING.md` com as convenções: idioma inglês, cabeçalho de uma linha, `---@param`, tratamento de erro (3.4), notify (3.5), requires (3.7).

### Fase 3: Infraestrutura compartilhada (o maior ganho)
- [ ] `notify.lua` + mensagens padrão. Trocar as 339 chamadas de forma incremental.
- [ ] `config.lua` (defaults únicos; corrigir C18 e I6).
- [ ] `data/json.lua` + `data/paths.lua` + `data/store.lua`. Migrar um módulo por PR: bookmarks → glossary → highlights → collections → state → library → sessions → caches.
- [ ] `text/*` (4.3) + `util/date.lua` + `util/id.lua`.
- [ ] `ui/float.lua` + `ui/picker.lua` + `ui/format.lua` + `modals.confirm`.
- [ ] `context.require_current()`.
- [ ] `types.lua` com as classes principais.

### Fase 4: Desmontar os god-files
- [ ] `init.lua` → `config` / `highlights` / `commands/*` / `keymaps/global`.
- [ ] `ui/book_loader.lua` → keymaps declarativos + `autocmds` + `save_reading_position`.
- [ ] `ui/navigation.lua` → `links` + `typography` (usando `rerender_preserving_viewport`).
- [ ] `ui/render.lua` → `chapter_source` / `layout` / `viewport` / `statusline`.
- [ ] `ui/extmarks.lua` → `extmarks/*` + `modes/reading_paragraph`.
- [ ] `export/html_graph.lua` → templates em `resources/` + `glossary_graph/data.lua`.
- [ ] Dashboards → `framework` + `widgets` + `views` + `providers` + `actions`.
- [ ] `glossary/ui.lua` → `ui` / `browser` / `editor` / `graph_view`.

### Fase 5: Contratos
- [ ] Tipo `ink.Book` + `formats.detect` + `formats.open` com contrato único (corrige C7 e I26).
- [ ] Registro de providers web (genérico + Planalto).
- [ ] Registro de formatos de export.
- [ ] Eventos `User InkBookOpened`, `InkChapterRendered`, `InkBookRemoved` no lugar de `defer_fn` e dependências cruzadas.
- [ ] Consolidar as migrações em `data/migrations/` com `schema_version`.

### Fase 6: Reorganização de pastas
Mover para o layout da seção 6.2, mantendo `ui/init.lua` e as fachadas com os mesmos nomes públicos, para não quebrar a configuração dos usuários. Com a infraestrutura das fases 3-5 pronta, os movimentos viram, na maior parte, renomeações.

### Fase 7: Desempenho
Aplicar a tabela da seção 8, começando por P1-P6.

---

## 14. Apêndice: convenções por arquivo

Legenda: **Ind.** = indentação (2 = 2 espaços, 4 = 4 espaços, T = tab); **Cab.** = cabeçalho (`path` = `-- lua/ink/...`, `PT` = "Responsabilidade:" em português, `desc` = só descrição, `—` = nenhum); **Anot.** = anotações; **Erro** = estratégia de erro.

| Arquivo | Ind. | Cab. | Anot. | Erro | Observações |
|---|---|---|---|---|---|
| `init.lua` | 4 | — | — | pcall + notify | `setup` de 720 linhas; mensagens PT/EN |
| `state.lua` | 2 | — | — | `false`/`nil` silencioso | `vim.json.encode` compacto |
| `utils.lua` | T | path | `--- @param` | — | Único com LuaCATS |
| `fs.lua` | 2 | — | — | notify + `false, err` | Efeito colateral no load |
| `library.lua` | — | path | — | — | Shim |
| `library/*` | T | path | `-- @param` | bool / `false, msg` | `M` antes dos requires |
| `data/init.lua` | 2 | — | `-- @param` | `error()` / `nil, err` | `json_encode` com bugs |
| `data/migrate.lua` | 2 | — | — | silencioso | Roda em toda leitura |
| `data/directory_migration.lua` | 2 | desc | — | `bool, msg` | `vim.json.encode` |
| `data/related.lua` | T | — | — | bool silencioso | Ciclo com `library` |
| `cache/lru.lua` | 2 | path | `-- @param` | — | Métodos com `:` |
| `chapter_cache.lua` | 2 | path | `-- @param` | — | **Morto** |
| `toc_cache.lua` | 2 | — | — | bool/nil | Caminho hardcoded |
| `css_cache.lua` | 2 | path | — | apaga o corrompido | `io.open` sem pcall |
| `tracking.lua` | 2 | path | — | `pcall(require)` | Timer vaza |
| `reading_sessions.lua` | T (+4 em 155-165) | — | — | notify; renomeia `.corrupt` | Requires inline |
| `user_highlights.lua` | 2 | — | — | silencioso | Cache em memória |
| `which_key_groups.lua` | 4 | — | — | `pcall(require)` | |
| `health.lua` | 2 | path | — | acumula | Não usa `vim.health` |
| `ui/render.lua` | T | — | — | pcall + notify; erro escrito no buffer | 7 lazy getters |
| `ui/book_loader.lua` | T | path+PT | `-- @param` | notify pontual | 40× `require("ink.ui")` |
| `ui/extmarks.lua` | T | — | — | `false` / contagem | |
| `ui/navigation.lua` | 2 | — | — | silencioso | |
| `ui/context.lua` | 4 | — | comentários inline | WARN no proxy | Config singleton |
| `ui/init.lua` | T | — | — | notify WARN | Fachada + lógica |
| `ui/util.lua` | 2 (trechos com 8) | — | — | notify ERROR | Comentário em PT |
| `ui/cache.lua` | 2 | path+PT | — | `(ok, msg)` | |
| `ui/bookmarks.lua` | 2 | — | — | notify, sem pcall | `defer_fn` |
| `ui/notes.lua` | 2 (linhas com `;`) | — | — | notify | Estilo compacto |
| `ui/floating_toc.lua` | 2 | path | — | checa validade | Função global |
| `ui/linked_resources.lua` | T | — | — | sem guarda para telescope | Sem newline final |
| `ui/library_view.lua` | 2 | — | `-- @param` (1×) | notify | |
| `ui/search.lua` | 2 | — | — | notify ERROR | |
| `ui/search_index.lua` | **T + 2** | path+PT | — | pcall no decode | |
| `ui/modals.lua` | 2 | path+PT | comentário livre | — | |
| `ui/footnotes.lua` | 4 | — | — | `false` | |
| `html/blocks.lua`, `formatter.lua`, `text.lua`, `justification.lua` | 2/4 | path+PT | — | — | |
| `html/patterns.lua` | 4 | path EN | — | — | MAIÚSCULAS (único) |
| `html/pool.lua`, `string_builder.lua` | 2 | EN | — | — | **Mortos** |
| `html/entities.lua`, `init.lua`, `parser.lua`, `table.lua`, `tokens.lua`, `utils.lua` | 2/4 | — | — | — | |
| `css_parser/*` | 4 (`parser`: 2) | — | — | — | |
| `epub/*` | 2 (`ncx`: 4) | — | — | `error()` | `get_attribute` 4×; `vim.loop` |
| `markdown/*` | 2 | — | "Returns:" | `nil, err` | `ParserState` OO (único) |
| `web/init.lua`, `fetcher`, `versions`, `changelog` | 2 | — | `-- @param` | `nil, err` / `nil, nil, err` / `error()` | Notify PT/EN |
| `web/generic_parser.lua` | 2 | — | — | — | MAIÚSCULAS |
| `web/planalto_parser.lua` | 4 | — | — | `error()` | `goto continue` |
| `web/migrate_highlights.lua`, `test_migration.lua`, `util.lua` | 2 | desc/path | `@param` informal | — | |
| `export/*` | 2 (`html_graph`: 4) | — | `-- @param` (2 arquivos) | notify + `false` | Espaços no fim de linha |
| `dashboard/*` | T (linhas com 2) | path | `-- @param x: tipo - desc` | pcall com retorno ignorado | API depreciada |
| `glossary/*` | 2 | — (`cache`: desc) | `@param` pontual | silencioso / notify EN | `ui.lua` com 1055 linhas |
| `notes/*` | 2 | desc | "Returns:" | silencioso | `vim.bo` |
| `bookmarks/*` | 2 | — | — | notify slug inválido | |
| `padnotes/*` | 2 + espaços no fim de linha | path+PT | — | notify EN | `config` no `init` |
| `collections/*` | T | path | `@param`/`@return` em tudo | notify ERROR/WARN | Único com docstrings completas |
