vim.g.mapleader = " "

vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })
vim.keymap.set('n', '<c-d>', '<c-d>zz', { desc = "Scroll down, keep cursor centered" })
vim.keymap.set('n', '<c-u>', '<c-u>zz', { desc = "Scroll up, keep cursor centered" })

vim.keymap.set('n', '<leader>n', ':cnext<CR>', { desc = "Next quickfix item" })
vim.keymap.set('n', '<leader>N', ':cprev<CR>', { desc = "Previous quickfix item" })

vim.keymap.set({'n', 'v'}, '<leader>y', '"*y', { desc = "Yank to system clipboard" })
vim.keymap.set({'n', 'v'}, '<leader>p', '"+p', { desc = "Paste from system clipboard" })
vim.keymap.set({'n', 'v'}, 'p', 'p==', { desc = "Paste and re-indent" })

vim.keymap.set({'i'}, '<C-c>', '<ESC>u', { desc = "Leave insert mode and undo" })

vim.keymap.set({'n', 'v'}, '<leader>ml', [[<cmd>compiler dotnet<cr><cmd>Make "\Lofwyr"<CR>]], { desc = "dotnet Make Lofwyr" })

-- Terminal mode: exit and window navigation
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })
vim.keymap.set('t', '<C-w>h', '<C-\\><C-n><C-w>h', { desc = 'Terminal: move left' })
vim.keymap.set('t', '<C-w>l', '<C-\\><C-n><C-w>l', { desc = 'Terminal: move right' })
vim.keymap.set('t', '<C-w>j', '<C-\\><C-n><C-w>j', { desc = 'Terminal: move down' })
vim.keymap.set('t', '<C-w>k', '<C-\\><C-n><C-w>k', { desc = 'Terminal: move up' })
vim.keymap.set('t', '<C-w>w', '<C-\\><C-n><C-w>w', { desc = 'Terminal: cycle windows' })
