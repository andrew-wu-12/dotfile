return {
  {
    'nvim-treesitter/nvim-treesitter',
    opts = { ensure_installed = { 'astro', 'css' } },
  },

  {
    'neovim/nvim-lspconfig',
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      opts.servers.astro = {}
    end,
  },

  {
    'conform.nvim',
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.astro = { 'prettier', 'prettierd' }
    end,
  },
}