-- VSCode-familiar keybindings.
-- Layered on top of the default Vim/Neovim bindings — nothing here removes a
-- Vim motion, so muscle memory from either editor keeps working.
--
-- Terminal caveats (macOS + WezTerm/tmux):
--  * Ctrl-B is the tmux prefix, so the VSCode "toggle sidebar" is left on <leader>e.
--  * Ctrl+Shift+<key> and Ctrl+` can't be distinguished by most terminals, so
--    those VSCode shortcuts are intentionally not mapped here.
--  * Alt is the macOS Option key — WezTerm must send it as Meta for <A-...> to fire.

local map = vim.keymap.set

-- Save: Ctrl+S (works in normal, insert and visual; returns to normal after)
map({ 'n', 'i', 'v' }, '<C-s>', '<cmd>write<cr><esc>', { desc = 'Save file' })

-- Toggle comment: Ctrl+/  (terminals send it as either <C-/> or <C-_>)
-- Uses Neovim's built-in `gc` operator, so `remap = true` is required.
map('n', '<C-/>', 'gcc', { remap = true, desc = 'Toggle comment' })
map('n', '<C-_>', 'gcc', { remap = true, desc = 'Toggle comment' })
map('x', '<C-/>', 'gc', { remap = true, desc = 'Toggle comment' })
map('x', '<C-_>', 'gc', { remap = true, desc = 'Toggle comment' })
map('i', '<C-/>', '<esc>gccA', { remap = true, desc = 'Toggle comment' })
map('i', '<C-_>', '<esc>gccA', { remap = true, desc = 'Toggle comment' })

-- Quick Open: Ctrl+P (fuzzy file finder). Requiring the module lets lazy.nvim
-- load Telescope on first use.
map('n', '<C-p>', function()
  require('telescope.builtin').find_files()
end, { desc = 'Quick Open (find files)' })

-- Find in Files: Ctrl+Shift+F often can't be sent by terminals, so use Ctrl+F.
-- (Vim's default <C-f> = page-forward is still available as <PageDown>.)
map('n', '<C-f>', function()
  require('telescope.builtin').live_grep()
end, { desc = 'Find in files (grep)' })

-- Rename symbol: F2
map('n', '<F2>', vim.lsp.buf.rename, { desc = 'Rename symbol' })

-- Go to definition: F12
map('n', '<F12>', vim.lsp.buf.definition, { desc = 'Go to definition' })

-- Move line up/down: Alt+Up / Alt+Down (and Alt+k / Alt+j)
map('n', '<A-Down>', '<cmd>m .+1<cr>==', { desc = 'Move line down' })
map('n', '<A-Up>', '<cmd>m .-2<cr>==', { desc = 'Move line up' })
map('n', '<A-j>', '<cmd>m .+1<cr>==', { desc = 'Move line down' })
map('n', '<A-k>', '<cmd>m .-2<cr>==', { desc = 'Move line up' })
map('i', '<A-Down>', '<esc><cmd>m .+1<cr>==gi', { desc = 'Move line down' })
map('i', '<A-Up>', '<esc><cmd>m .-2<cr>==gi', { desc = 'Move line up' })
map('i', '<A-j>', '<esc><cmd>m .+1<cr>==gi', { desc = 'Move line down' })
map('i', '<A-k>', '<esc><cmd>m .-2<cr>==gi', { desc = 'Move line up' })
map('v', '<A-Down>', ":m '>+1<cr>gv=gv", { desc = 'Move selection down' })
map('v', '<A-Up>', ":m '<-2<cr>gv=gv", { desc = 'Move selection up' })
map('v', '<A-j>', ":m '>+1<cr>gv=gv", { desc = 'Move selection down' })
map('v', '<A-k>', ":m '<-2<cr>gv=gv", { desc = 'Move selection up' })

-- Duplicate line: Shift+Alt+Down (below) / Shift+Alt+Up (above)
map('n', '<A-S-Down>', '<cmd>copy .<cr>', { desc = 'Duplicate line down' })
map('n', '<A-S-Up>', '<cmd>copy .-1<cr>', { desc = 'Duplicate line up' })
