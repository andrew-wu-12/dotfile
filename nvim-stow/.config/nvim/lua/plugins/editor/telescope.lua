local kind_filter = {
  default = {
    'Class',
    'Constructor',
    'Enum',
    'Field',
    'Function',
    'Interface',
    'Method',
    'Module',
    'Namespace',
    'Package',
    'Property',
    'Struct',
    'Trait',
  },
  markdown = false,
  help = false,
  lua = {
    'Class',
    'Constructor',
    'Enum',
    'Field',
    'Function',
    'Interface',
    'Method',
    'Module',
    'Namespace',
    -- "Package", -- remove package since luals uses it for control flow structures
    'Property',
    'Struct',
    'Trait',
  },
}

local get_kind_filter = function(buf)
  buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
  local ft = vim.bo[buf].filetype

  if kind_filter[ft] == false then
    return
  end

  if type(kind_filter[ft]) == 'table' then
    return kind_filter[ft]
  end

  ---@diagnostic disable-next-line: return-type-mismatch
  return type(kind_filter) == 'table'
      and type(kind_filter.default) == 'table'
    and kind_filter.default
    or nil
end

local telescope_pickers = require 'telescope.pickers'
local telescope_finders = require 'telescope.finders'
local telescope_actions = require 'telescope.actions'
local telescope_action_state = require 'telescope.actions.state'
local telescope_conf = require('telescope.config').values

local open_deduped_references = function()
  local params = vim.lsp.util.make_position_params()
  params.context = { includeDeclaration = false }

  vim.lsp.buf_request_all(0, 'textDocument/references', params, function(responses)
    local locations = {}
    local seen = {}

    for _, response in pairs(responses) do
      local result = response.result
      if result then
        for _, location in ipairs(result) do
          local uri = location.uri or location.targetUri
          local range = location.range or location.targetSelectionRange or location.targetRange
          if uri and range then
            local key = string.format(
              '%s:%d:%d:%d:%d',
              uri,
              range.start.line,
              range.start.character,
              range['end'].line,
              range['end'].character
            )
            if not seen[key] then
              seen[key] = true
              table.insert(locations, location)
            end
          end
        end
      end
    end

    if vim.tbl_isempty(locations) then
      vim.notify('No references found', vim.log.levels.INFO)
      return
    end

    local entries = vim.lsp.util.locations_to_items(locations)

    telescope_pickers.new({}, {
      prompt_title = 'References (deduped)',
      finder = telescope_finders.new_table {
        results = entries,
        entry_maker = function(item)
          local filename = vim.fn.fnamemodify(item.filename, ':.')
          local display = string.format('%s:%d:%d', filename, item.lnum, item.col)
          local text = item.text and (' ' .. item.text) or ''

          return {
            value = item,
            display = display .. text,
            ordinal = display .. text,
            filename = item.filename,
            lnum = item.lnum,
            col = item.col,
          }
        end,
      },
      sorter = telescope_conf.generic_sorter({}),
      previewer = telescope_conf.grep_previewer({}),
      attach_mappings = function(prompt_bufnr)
        telescope_actions.select_default:replace(function()
          local selection = telescope_action_state.get_selected_entry()
          telescope_actions.close(prompt_bufnr)

          if not selection or not selection.value then
            return
          end

          local item = selection.value

          vim.cmd.edit(vim.fn.fnameescape(item.filename))
          vim.api.nvim_win_set_cursor(0, { item.lnum, item.col - 1 })
        end)

        return true
      end,
    }):find()
  end)
end

return {
  {
    'nvim-telescope/telescope.nvim',
    tag = '0.1.5',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'echasnovski/mini.icons',
      {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'make',
      },
    },
    config = function()
      local telescope = require 'telescope'
      local actions = require 'telescope.actions'

      telescope.setup {
        defaults = {
          mappings = {
            i = {
              ['<C-j>'] = actions.move_selection_next,
              ['<C-k>'] = actions.move_selection_previous,
            },
          },
          file_ignore_patterns = { 'node_modules', '.git/' },
          vimgrep_arguments = {
            'rg',
            '--color=never',
            '--no-heading',
            '--with-filename',
            '--line-number',
            '--column',
            '--smart-case',
            '--hidden',
          },
        },
        pickers = {
          find_files = {
            hidden = true,
            follow = true,
          },
          buffers = {
            sort_mru = true,
            sort_lastused = true,
          },
        },
      }

      -- Load fzf native extension for better performance
      telescope.load_extension 'fzf'
    end,
    keys = {
      -- Buffer switching
      {
        '<leader>,',
        '<cmd>Telescope buffers sort_mru=true sort_lastused=true<cr>',
        desc = 'Switch Buffer',
      },

      -- Find
      {
        '<leader>fb',
        '<cmd>Telescope buffers sort_mru=true sort_lastused=true<cr>',
        desc = 'Buffers',
      },
      { '<leader>ff', '<cmd>Telescope find_files<cr>', desc = 'Files' },
      {
        '<leader><space>',
        '<cmd>Telescope find_files<cr>',
        desc = 'Find Files',
      },
      { '<leader>fg', '<cmd>Telescope git_files<cr>', desc = 'Git-files' },

      -- Search
      { '<leader>s"', '<cmd>Telescope registers<cr>', desc = 'Registers' },
      {
        '<leader>sa',
        '<cmd>Telescope autocommands<cr>',
        desc = 'Auto Commands',
      },
      {
        '<leader>sb',
        '<cmd>Telescope current_buffer_fuzzy_find<cr>',
        desc = 'Buffer',
      },
      {
        '<leader>sc',
        '<cmd>Telescope command_history<cr>',
        desc = 'Command History',
      },
      { '<leader>sC', '<cmd>Telescope commands<cr>', desc = 'Commands' },
      {
        '<leader>sd',
        '<cmd>Telescope diagnostics bufnr=0<cr>',
        desc = 'Document Diagnostics',
      },
      {
        '<leader>sD',
        '<cmd>Telescope diagnostics<cr>',
        desc = 'Workspace Diagnostics',
      },
      { '<leader>sg', '<cmd>Telescope live_grep<cr>', desc = 'Grep' },
      { '<leader>sh', '<cmd>Telescope help_tags<cr>', desc = 'Help Pages' },
      {
        '<leader>sH',
        '<cmd>Telescope highlights<cr>',
        desc = 'Highlight Groups',
      },
      { '<leader>sj', '<cmd>Telescope jumplist<cr>', desc = 'Jumplist' },
      { '<leader>sk', '<cmd>Telescope keymaps<cr>', desc = 'Key Maps' },
      { '<leader>sl', '<cmd>Telescope loclist<cr>', desc = 'Location List' },
      { '<leader>sM', '<cmd>Telescope man_pages<cr>', desc = 'Man Pages' },
      { '<leader>sm', '<cmd>Telescope marks<cr>', desc = 'Jump to Mark' },
      { '<leader>sR', '<cmd>Telescope resume<cr>', desc = 'Resume' },
      { '<leader>sq', '<cmd>Telescope quickfix<cr>', desc = 'Quickfix List' },
      {
        '<leader>ss',
        function()
          local filters = get_kind_filter()
          if filters then
            require('telescope.builtin').lsp_document_symbols {
              symbols = filters,
            }
          else
            require('telescope.builtin').lsp_document_symbols()
          end
        end,
        desc = 'Symbol (Document)',
      },
      {
        '<leader>sS',
        function()
          local filters = get_kind_filter()
          if filters then
            require('telescope.builtin').lsp_workspace_symbols {
              symbols = filters,
            }
          else
            require('telescope.builtin').lsp_workspace_symbols()
          end
        end,
        desc = 'Symbol (Workspace)',
      },
    },
  },
  {
    'neovim/nvim-lspconfig',
    opts = function()
      vim.keymap.set('n', 'gd', function()
        require('telescope.builtin').lsp_definitions {
          reuse_win = true,
        }
      end, { desc = 'Goto Definition' })

      vim.keymap.set('n', 'gr', open_deduped_references, { desc = 'References', nowait = true })

      vim.keymap.set('n', 'gI', function()
        require('telescope.builtin').lsp_implementations {
          reuse_win = true,
        }
      end, { desc = 'Goto Implementation' })

      vim.keymap.set('n', 'gy', function()
        require('telescope.builtin').lsp_type_definitions {
          reuse_win = true,
        }
      end, { desc = 'Goto Type Definitions' })
    end,
  },
}
