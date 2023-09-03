vim.g.mapleader = " "

vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })
-- vim.keymap.set('n', '<leader>e', vim.cmd.Ex, {})
vim.keymap.set('n', '<leader>e', ':edit .<CR>', {})
vim.keymap.set('n', '<c-d>', '<c-d>zz', {})
vim.keymap.set('n', '<c-u>', '<c-u>zz', {})

vim.keymap.set('n', '<leader>g', ':G<CR>:only<CR>', {})
vim.keymap.set('n', '<leader>gb', ':G blame<CR>', {})
vim.keymap.set('n', '<leader>bg', '<c-w>l:only<CR>', {})
vim.keymap.set('n', '<leader>gd', ':G diff<CR>:only<CR>', {})
vim.keymap.set('n', '<leader>gl', ':G log<CR>:only<CR>', {})
vim.keymap.set('n', '<leader>gf', ':Gdiffsplit<CR>', {})
vim.keymap.set('n', '<leader>cr', ':wa<CR>:CargoRun<CR>', {})

vim.keymap.set('n', '<leader>s', ':e ~/.config/nvim/<CR>', {})
vim.keymap.set('n', '<leader>y', '"+y', {})
vim.keymap.set('n', '<leader>p', '"+p', {})
