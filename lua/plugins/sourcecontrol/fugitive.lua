return {
	{
		'tpope/vim-fugitive',
		dependencies = { 'tpope/vim-rhubarb', },
		keys = {
			{ '<leader>gs', ':G<CR>:only<CR>', desc='Git status' },
			{ '<leader>gb', ':G blame<CR>', desc='Git blame' },
			{ '<leader>gd', ':G diff<CR>:only<CR>', desc='Git diff' },
			{ '<leader>gm', ':Gdiffsplit<CR>', desc='Git diffsplit' },
			-- other commands like log i use telescope instead
		}
	},
	{
		-- on the blame window from fugitive show the commit message of the current line 
		'tommcdo/vim-fugitive-blame-ext',
		keys = '<leader>gb',
		dependencies = { 'tpope/vim-fugitive' },
	},
}
