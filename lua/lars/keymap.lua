vim.g.mapleader = " "

vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })
vim.keymap.set('n', '<c-d>', '<c-d>zz', {})
vim.keymap.set('n', '<c-u>', '<c-u>zz', {})

vim.keymap.set('n', '<leader>n', ':cnext<CR>', {})
vim.keymap.set('n', '<leader>N', ':cprev<CR>', {})

vim.keymap.set({'n', 'v'}, '<leader>y', '"*y', {})
vim.keymap.set({'n', 'v'}, '<leader>p', '"+p', {})
vim.keymap.set({'n', 'v'}, 'p', 'p==', {})

vim.keymap.set({'i'}, '<C-c>', '<ESC>u', { desc="leave insert mode and undo"})

-- vim.keymap.set('n', '<leader>rr', [[:! for /F "TOKENS=1,2,*" \%a in ('tasklist /FI "IMAGENAME eq WpfApp2.exe"') do set MyPID=\%b<cr>]], {})

-- vim.keymap.set({'n', 'v'}, '<leader>mr', [[<cmd>compiler msbuild<cr><cmd>Make /p:target=x64 && "WpfApp2/bin/Debug/net6.0-windows/WpfApp2"<CR>]], {})
vim.keymap.set({'n', 'v'}, '<leader>ml', [[<cmd>compiler dotnet<cr><cmd>Make "\Lofwyr"<CR>]], {})
