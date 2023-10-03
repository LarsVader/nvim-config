return {
	{ 'serenevoid/kiwi.nvim',
		dependencies = { 'nvim-lua/plenary.nvim' },
		opts = {
			{
				name = "work",
				-- to have this in another folder best change this folder to be a symbolic link (windows mklink command)
				path = vim.fn.stdpath('data') .. '/vimwiki'
			}
		},
		keys = {
			{'<leader>vw', function () require('kiwi').open_wiki_index() end , {}},
			{'<leader>vd', function () require('kiwi').open_diary_index() end, {}},
			{'<leader>vn', function () require('kiwi').open_diary_new() end, {}},
			{'<leader-x>', function () require('kiwi').todo.toggle() end, {}},
		}
	},
}
