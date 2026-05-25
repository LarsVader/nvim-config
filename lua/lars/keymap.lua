vim.g.mapleader = " "

vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })
vim.keymap.set('n', '<c-d>', '<c-d>zz', { desc = "Scroll down, keep cursor centered" })
vim.keymap.set('n', '<c-u>', '<c-u>zz', { desc = "Scroll up, keep cursor centered" })

vim.keymap.set('n', '<leader>n', ':cnext<CR>', { desc = "Next quickfix item" })
vim.keymap.set('n', '<leader>N', ':cprev<CR>', { desc = "Previous quickfix item" })
vim.keymap.set('n', '<leader>cc', ':cclose<CR>', { desc = "Close quickfix window" })

vim.keymap.set({'n', 'v'}, '<leader>y', '"*y', { desc = "Yank to system clipboard" })
vim.keymap.set({'n', 'v'}, '<leader>p', '"+p', { desc = "Paste from system clipboard" })
vim.keymap.set({'n', 'v'}, 'p', 'p==', { desc = "Paste and re-indent" })

vim.keymap.set({'i'}, '<C-c>', '<ESC>u', { desc = "Leave insert mode and undo" })
vim.keymap.set({'i', 'c'}, '<S-BS>', '<C-w>', { desc = "Delete word backwards" })
vim.keymap.set('t', '<S-BS>', function()
    vim.api.nvim_chan_send(vim.b.terminal_job_id, '\23')
end, { desc = "Delete word backwards" })
vim.keymap.set('t', '<S-Tab>', function()
    vim.api.nvim_chan_send(vim.b.terminal_job_id, '\27[Z')
end, { desc = "Pass Shift+Tab to terminal (Claude mode switch, etc.)" })

vim.keymap.set({'n', 'v'}, '<leader>ml', [[<cmd>compiler dotnet<cr><cmd>Make "\Lofwyr"<CR>]], { desc = "dotnet Make Lofwyr" })

-- Alternate file navigation (test <-> source, view/page <-> viewmodel)
local alt = require('lars.alternate')
vim.keymap.set('n', '<leader>jt', alt.goto_test_or_source,      { desc = 'Alternate: test ↔ source' })
vim.keymap.set('n', '<leader>jv', alt.goto_view_or_viewmodel,  { desc = 'Alternate: view/page ↔ viewmodel' })
vim.keymap.set('n', '<leader>jh', alt.goto_header_or_source,   { desc = 'Alternate: header ↔ source' })
vim.keymap.set('n', '<leader>ji', alt.goto_interface,           { desc = 'Alternate: go to interface' })
vim.keymap.set('n', '<leader>jx', alt.goto_xaml_or_codebehind,  { desc = 'Alternate: xaml ↔ codebehind' })
vim.keymap.set('n', '<leader>jb', alt.goto_base_class,          { desc = 'Alternate: go to base class' })

-- Fold commands (descriptions make them discoverable via <leader>fk)
vim.keymap.set('n', 'za', 'za', { desc = "Toggle fold under cursor" })
vim.keymap.set('n', 'zc', 'zc', { desc = "Close fold under cursor" })
vim.keymap.set('n', 'zo', 'zo', { desc = "Open fold under cursor" })
vim.keymap.set('n', 'zM', 'zM', { desc = "Close all folds" })
vim.keymap.set('n', 'zR', 'zR', { desc = "Open all folds" })
vim.keymap.set('n', 'zm', 'zm', { desc = "Fold more (reduce foldlevel)" })
vim.keymap.set('n', 'zr', 'zr', { desc = "Fold less (increase foldlevel)" })

-- Spelling (descriptions all contain "Spelling" for easy filtering)
vim.keymap.set('n', 'z=', 'z=', { desc = "Spelling: suggest corrections" })
vim.keymap.set('n', 'zg', 'zg', { desc = "Spelling: add word to spellfile" })
vim.keymap.set('n', 'zw', 'zw', { desc = "Spelling: mark word as bad" })
vim.keymap.set('n', 'zug', 'zug', { desc = "Spelling: undo add to spellfile" })
vim.keymap.set('n', 'zuw', 'zuw', { desc = "Spelling: undo mark as bad" })
vim.keymap.set('n', ']s', ']s', { desc = "Spelling: next misspelled word" })
vim.keymap.set('n', '[s', '[s', { desc = "Spelling: previous misspelled word" })

-- g-commands
vim.keymap.set('n', 'g<', 'g<', { desc = "Reopen last pager (ui2)" })
vim.keymap.set('n', 'gv', 'gv', { desc = "Reselect last visual selection" })
vim.keymap.set('n', 'gi', 'gi', { desc = "Insert at last insert position" })
vim.keymap.set('n', 'gq', 'gq', { desc = "Format text (motion)" })
vim.keymap.set('n', 'g~', 'g~', { desc = "Toggle case (motion)" })
vim.keymap.set('n', 'gu', 'gu', { desc = "Lowercase (motion)" })
vim.keymap.set('n', 'gU', 'gU', { desc = "Uppercase (motion)" })

-- Macros
vim.keymap.set('n', 'qa', 'qa', { desc = "Macro: record into register a" })
vim.keymap.set('n', 'qq', 'qq', { desc = "Macro: record into register q" })
vim.keymap.set('n', 'q', 'q', { desc = "Macro: stop recording" })
vim.keymap.set('n', '@a', '@a', { desc = "Macro: play register a" })
vim.keymap.set('n', '@@', '@@', { desc = "Macro: replay last macro" })
vim.keymap.set('n', 'Q', 'Q', { desc = "Macro: replay last recorded macro" })

-- Spelling (descriptions make them discoverable via <leader>fk)
vim.keymap.set('n', ']s', ']s', { desc = "Spelling: next misspelled word" })
vim.keymap.set('n', '[s', '[s', { desc = "Spelling: previous misspelled word" })

-- Move selection vertically
vim.keymap.set('v', '<C-j>', ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
vim.keymap.set('v', '<C-k>', ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Scrolling (descriptions make them discoverable via <leader>fk)
vim.keymap.set('n', '<C-e>', '<C-e>', { desc = "Scroll down one line" })
vim.keymap.set('n', '<C-y>', '<C-y>', { desc = "Scroll up one line" })
vim.keymap.set('n', '<C-d>', '<C-d>', { desc = "Scroll down half page" })
vim.keymap.set('n', '<C-u>', '<C-u>', { desc = "Scroll up half page" })
vim.keymap.set('n', '<C-f>', '<C-f>', { desc = "Scroll down full page" })
vim.keymap.set('n', '<C-b>', '<C-b>', { desc = "Scroll up full page" })

-- Misc native commands
vim.keymap.set('n', '<C-a>', '<C-a>', { desc = "Increment number under cursor" })
vim.keymap.set('n', '<C-x>', '<C-x>', { desc = "Decrement number under cursor" })
vim.keymap.set('n', '@:', '@:', { desc = "Repeat last command-line command" })
vim.keymap.set('n', 'q:', 'q:', { desc = "Open command-line history window" })
vim.keymap.set('n', 'q/', 'q/', { desc = "Open search history window" })
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>', { desc = "Clear search highlight" })

-- Terminal mode: exit and window navigation
vim.keymap.set('t', '<C-\\><C-n>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })
vim.keymap.set('t', '<C-w>h', '<C-\\><C-n><C-w>h', { desc = 'Terminal: move left' })
vim.keymap.set('t', '<C-w>l', '<C-\\><C-n><C-w>l', { desc = 'Terminal: move right' })
vim.keymap.set('t', '<C-w>j', '<C-\\><C-n><C-w>j', { desc = 'Terminal: move down' })
vim.keymap.set('t', '<C-w>k', '<C-\\><C-n><C-w>k', { desc = 'Terminal: move up' })
vim.keymap.set('t', '<C-w>w', '<C-\\><C-n><C-w>w', { desc = 'Terminal: cycle windows' })
