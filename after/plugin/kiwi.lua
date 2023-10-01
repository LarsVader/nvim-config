
-- Setup Custom wiki path if required
require('kiwi').setup({
  {
    name = "work",
	-- to have this in another folder best change this folder to be a symbolic link (windows mklink command)
    path = vim.fn.stdpath('data') .. '/vimwiki'
  },
})

-- Use default path (i.e. ~/wiki/)
local kiwi = require('kiwi')

-- Necessary keybindings
vim.keymap.set('n', '<leader>ww', kiwi.open_wiki_index, {})
vim.keymap.set('n', '<leader>wd', kiwi.open_diary_index, {})
vim.keymap.set('n', '<leader>wn', kiwi.open_diary_new, {})
vim.keymap.set('n', '<leader-x>', kiwi.todo.toggle, {})
