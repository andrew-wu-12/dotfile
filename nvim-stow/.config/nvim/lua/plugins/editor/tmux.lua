return {
  {
    'aserowy/tmux.nvim',
    config = function()
      return require('tmux').setup {
        resize = {
          enable_default_keybindings = true,
        },
      }
    end,
  },
}
