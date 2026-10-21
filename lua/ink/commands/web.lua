--- Returns the current context if it holds web content, otherwise notifies and returns nil.
local function current_web_ctx()
  local context = require("ink.ui.context")
  local ctx = context.current()

  if not ctx or not ctx.data or ctx.data.format ~= "web" then
    vim.notify("This command only works with web content", vim.log.levels.ERROR)
    return nil
  end

  return ctx
end

return {
  {
    name = "InkWebToggleVersion",
    fn = function()
      local ctx = current_web_ctx()
      if not ctx then
        return
      end

      local web = require("ink.web")
      local new_version_name = web.toggle_version(ctx.data.slug)

      -- Reload the book with the new version
      local ok, data = pcall(web.open, ctx.data.url)
      if ok then
        require("ink.ui").open_book(data)
        vim.notify("Versão alterada para: " .. new_version_name, vim.log.levels.INFO)
      else
        vim.notify("Failed to reload page: " .. tostring(data), vim.log.levels.ERROR)
      end
    end,
  },

  {
    name = "InkWebChangelog",
    fn = function()
      local ctx = current_web_ctx()
      if not ctx then
        return
      end

      local changelog_text = require("ink.web").get_changelog(ctx.data.slug)

      -- Show in a new scratch buffer
      vim.cmd("new")
      local buf = vim.api.nvim_get_current_buf()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(changelog_text, "\n"))
      vim.bo[buf].filetype = "markdown"
      vim.bo[buf].buftype = "nofile"
      vim.bo[buf].bufhidden = "wipe"
      vim.api.nvim_buf_set_name(buf, "Web Changelog")
    end,
  },

  {
    name = "InkWebCheckUpdates",
    fn = function()
      local ctx = current_web_ctx()
      if not ctx then
        return
      end

      vim.notify("Verificando atualizações...", vim.log.levels.INFO)

      local has_update, message = require("ink.web").check_updates(ctx.data.slug, ctx.data.url)

      if has_update == nil then
        vim.notify("Erro ao verificar atualizações: " .. message, vim.log.levels.ERROR)
      elseif has_update then
        vim.notify(message .. ". Use :InkOpen " .. ctx.data.url .. " para recarregar.", vim.log.levels.WARN)
      else
        vim.notify(message, vim.log.levels.INFO)
      end
    end,
  },

  {
    name = "InkWebUpdateSafe",
    fn = function()
      local ctx = current_web_ctx()
      if not ctx then
        return
      end

      local fs = require("ink.fs")
      local data_module = require("ink.data")
      local web = require("ink.web")

      -- Check if highlights exist and back them up before updating
      local highlights_path = data_module.get_book_dir(ctx.data.slug) .. "/highlights.json"
      local has_highlights = false

      if fs.exists(highlights_path) then
        local content = fs.read_file(highlights_path)
        if content then
          local ok, hl_data = pcall(vim.json.decode, content)
          if ok and hl_data and hl_data.highlights and #hl_data.highlights > 0 then
            has_highlights = true

            local backup_path = highlights_path .. ".before-update." .. os.time()
            local backup_ok, backup_err = fs.copy_file(highlights_path, backup_path)

            if backup_ok then
              vim.notify(
                string.format(
                  "Backup de %d highlight(s) criado: %s",
                  #hl_data.highlights,
                  vim.fn.fnamemodify(backup_path, ":t")
                ),
                vim.log.levels.INFO
              )
            else
              vim.notify("Erro ao criar backup: " .. tostring(backup_err), vim.log.levels.ERROR)
              return
            end
          end
        end
      end

      -- Now proceed with the update
      vim.notify("Atualizando página...", vim.log.levels.INFO)
      local ok, data_or_err = pcall(web.open, ctx.data.url, { force_download = true })

      if ok then
        require("ink.ui").open_book(data_or_err)
        if has_highlights then
          vim.notify(
            "Página atualizada. Verifique se seus highlights estão alinhados corretamente.",
            vim.log.levels.WARN
          )
        else
          vim.notify("Página atualizada com sucesso.", vim.log.levels.INFO)
        end
      else
        vim.notify("Erro ao atualizar página: " .. tostring(data_or_err), vim.log.levels.ERROR)
      end
    end,
  },
}
