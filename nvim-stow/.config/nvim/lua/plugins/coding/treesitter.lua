return {
  { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    main = 'nvim-treesitter.configs', -- Sets main module to use for opts
    -- [[ Configure Treesitter ]] See `:help nvim-treesitter`
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
      -- Autoinstall languages that are not installed
      auto_install = true,
      highlight = {
        enable = true,
        -- Some languages depend on vim's regex highlighting system (such as Ruby) for indent rules.
        --  If you are experiencing weird indenting issues, add the language to
        --  the list of additional_vim_regex_highlighting and disabled languages for indent.
        additional_vim_regex_highlighting = { 'ruby' },
      },
      indent = { enable = true, disable = { 'ruby' } },
    },
    -- There are additional nvim-treesitter modules that you can use to interact
    -- with nvim-treesitter. You should go explore a few and see what interests you:
    --
    --    - Incremental selection: Included, see `:help nvim-treesitter-incremental-selection-mod`
    --    - Show your current context: https://github.com/nvim-treesitter/nvim-treesitter-context
    --    - Treesitter + textobjects: https://github.com/nvim-treesitter/nvim-treesitter-textobjects
    config = function()
      vim.filetype.add {
        pattern = {
          ['config'] = 'dosini', -- better syntax highlighting for config files
        },
      }

      -- nvim-treesitter's `master` branch is archived (frozen 2025-05) and its
      -- query handlers read `match[id]` as a single TSNode. Neovim 0.11+ passes
      -- captures as a list (`TSNode[]`) and dropped the `all = false` opt, so the
      -- archived handlers call node methods on a table and crash with "attempt to
      -- call method 'range' (a nil value)" -- e.g. opening a markdown file fires
      -- `set-lang-from-info-string!` on a code fence. Re-register the affected
      -- handlers to accept the list form. Remove after migrating to `main`.
      require 'nvim-treesitter.query_predicates' -- load archived handlers first
      local q = vim.treesitter.query
      local get_text = vim.treesitter.get_node_text
      local force = { force = true }

      local function node_of(match, id)
        local n = match[id]
        if type(n) == 'table' then
          n = n[#n]
        end
        return n
      end

      q.add_predicate('nth?', function(match, _, _, pred)
        local node = node_of(match, pred[2])
        local n = tonumber(pred[3])
        if node and node:parent() and node:parent():named_child_count() > n then
          return node:parent():named_child(n) == node
        end
        return false
      end, force)

      q.add_predicate('is?', function(match, _, bufnr, pred)
        local locals = require 'nvim-treesitter.locals'
        local node = node_of(match, pred[2])
        local types = { unpack(pred, 3) }
        if not node then
          return true
        end
        local _, _, kind = locals.find_definition(node, bufnr)
        return vim.tbl_contains(types, kind)
      end, force)

      q.add_predicate('kind-eq?', function(match, _, _, pred)
        local node = node_of(match, pred[2])
        local types = { unpack(pred, 3) }
        if not node then
          return true
        end
        return vim.tbl_contains(types, node:type())
      end, force)

      local html_script_type_languages = {
        importmap = 'json',
        module = 'javascript',
        ['application/ecmascript'] = 'javascript',
        ['text/ecmascript'] = 'javascript',
      }
      local non_filetype_match_injection_language_aliases = {
        ex = 'elixir',
        pl = 'perl',
        sh = 'bash',
        uxn = 'uxntal',
        ts = 'typescript',
      }
      local function parser_from_info_string(alias)
        local m = vim.filetype.match { filename = 'a.' .. alias }
        return m
          or non_filetype_match_injection_language_aliases[alias]
          or alias
      end

      q.add_directive('set-lang-from-mimetype!', function(match, _, bufnr, pred, metadata)
        local node = node_of(match, pred[2])
        if not node then
          return
        end
        local type_attr_value = get_text(node, bufnr)
        local configured = html_script_type_languages[type_attr_value]
        if configured then
          metadata['injection.language'] = configured
        else
          local parts = vim.split(type_attr_value, '/', {})
          metadata['injection.language'] = parts[#parts]
        end
      end, force)

      q.add_directive('set-lang-from-info-string!', function(match, _, bufnr, pred, metadata)
        local node = node_of(match, pred[2])
        if not node then
          return
        end
        local alias = get_text(node, bufnr):lower()
        metadata['injection.language'] = parser_from_info_string(alias)
      end, force)

      q.add_directive('downcase!', function(match, _, bufnr, pred, metadata)
        local id = pred[2]
        local node = node_of(match, id)
        if not node then
          return
        end
        local text = get_text(node, bufnr, { metadata = metadata[id] }) or ''
        if not metadata[id] then
          metadata[id] = {}
        end
        metadata[id].text = string.lower(text)
      end, force)
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
