-- LSP Plugins
local ts_hover_state = {}

local function ts_expanded_hover(client, bufnr)
  local pos = vim.api.nvim_win_get_cursor(0)
  local key = table.concat({ bufnr, pos[1], pos[2], vim.b[bufnr].changedtick }, ':')
  local level = 0
  if ts_hover_state.key == key then
    level = ts_hover_state.can_increase and ts_hover_state.level + 1 or ts_hover_state.level
  end

  local position_params = vim.lsp.util.make_position_params(0, client.offset_encoding)
  client:request('textDocument/hover', position_params, function()
    client:request('workspace/executeCommand', {
      command = 'typescript.tsserverRequest',
      arguments = {
        'quickinfo',
        {
          file = vim.api.nvim_buf_get_name(bufnr),
          line = pos[1],
          offset = pos[2] + 1,
          verbosityLevel = level,
        },
      },
    }, function(err, result)
      local body = result and result.body
      if err or not body then
        vim.notify('No type info', vim.log.levels.INFO)
        return
      end

      ts_hover_state = { key = key, level = level, can_increase = body.canIncreaseVerbosityLevel }

      local lines = { '```typescript' }
      vim.list_extend(lines, vim.split(body.displayString, '\n'))
      table.insert(lines, '```')

      local doc = body.documentation
      if type(doc) == 'table' then
        doc = table.concat(vim.tbl_map(function(part)
          return part.text
        end, doc))
      end
      if doc and doc ~= '' then
        table.insert(lines, '')
        vim.list_extend(lines, vim.split(doc, '\n'))
      end

      local title = (' level %d%s '):format(level, body.canIncreaseVerbosityLevel and ' · gK to expand' or '')
      vim.lsp.util.open_floating_preview(lines, 'markdown', {
        border = 'rounded',
        focus = false,
        title = title,
      })
    end, bufnr)
  end, bufnr)
end

return {
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      { 'williamboman/mason.nvim', opts = {} },
      'williamboman/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',
      'hrsh7th/cmp-nvim-lsp',
    },
    config = function()
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = desc })
          end

          map('<leader>ca', vim.lsp.buf.code_action, 'Code Action', { 'n', 'x' })
          map('gD', vim.lsp.buf.declaration, 'Goto Declaration')

          map('<leader>th', function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf }, { bufnr = event.buf })
          end, 'Toggle Inlay Hints')

          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client.name == 'vtsls' then
            map('gK', function()
              ts_expanded_hover(client, event.buf)
            end, 'Hover (expand type)')
          end

          if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
            local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })
            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })
          end
        end,
      })

      local capabilities = vim.lsp.protocol.make_client_capabilities()
      capabilities = vim.tbl_deep_extend('force', capabilities, require('cmp_nvim_lsp').default_capabilities())
      capabilities.textDocument.foldingRange = {
        dynamicRegistration = false,
        lineFoldingOnly = true,
      }

      vim.lsp.config('vtsls', {
        settings = {
          ['js/ts'] = {
            hover = { maximumLength = 100000 },
          },
        },
      })

      require('mason-tool-installer').setup {
        ensure_installed = {
          'astro-language-server',
          'vtsls',
        },
      }

      require('mason-lspconfig').setup {
        ensure_installed = {
          'astro',
          'vtsls',
        },
        automatic_installation = false,
        handlers = function(server_name)
          local server = {}
          server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
          require('lspconfig')[server_name].setup(server)
        end,
      }
    end,
  },
}