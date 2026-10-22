local regex_highlight = { ruby = true }
local no_indent = { ruby = true }

return {
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    lazy = false,
    build = ':TSUpdate',
    opts_extend = { 'ensure_installed' },
    opts = {
      ensure_installed = {
        'astro',
        'bash',
        'blade',
        'c',
        'caddy',
        'css',
        'diff',
        'dockerfile',
        'editorconfig',
        'gitignore',
        'go',
        'gomod',
        'gosum',
        'html',
        'javascript',
        'json',
        'lua',
        'luadoc',
        'nginx',
        'php',
        'php_only',
        'python',
        'sql',
        'typescript',
        'vim',
        'vimdoc',
        'ninja',
        'rst',
      },
    },
    config = function(_, opts)
      vim.filetype.add {
        pattern = {
          ['config'] = 'dosini',
        },
      }

      local ts = require 'nvim-treesitter'
      ts.install(opts.ensure_installed)

      local available = {}
      for _, lang in ipairs(ts.get_available()) do
        available[lang] = true
      end

      local function attach(buf, lang)
        if not vim.api.nvim_buf_is_valid(buf) then
          return
        end
        if not pcall(vim.treesitter.start, buf, lang) then
          return
        end
        if regex_highlight[lang] then
          vim.bo[buf].syntax = 'on'
        end
        if not no_indent[lang] then
          vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end

      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('treesitter-start', { clear = true }),
        callback = function(args)
          local lang = vim.treesitter.language.get_lang(args.match)
          if not lang then
            return
          end
          if vim.treesitter.language.add(lang) then
            attach(args.buf, lang)
          elseif available[lang] then
            ts.install(lang):await(function(err)
              if not err then
                vim.schedule(function()
                  attach(args.buf, lang)
                end)
              end
            end)
          end
        end,
      })
    end,
  },
}
