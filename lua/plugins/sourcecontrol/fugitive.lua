return {
	{
		'tpope/vim-fugitive',
		dependencies = { 'tpope/vim-rhubarb', },
		keys = {
			{ '<leader>gs', function()
				vim.cmd('G')
				local buf = vim.api.nvim_get_current_buf()
				vim.bo[buf].bufhidden = 'hide'
				vim.api.nvim_win_close(0, false)
				local width = math.floor(vim.o.columns * 0.9)
				local height = math.floor(vim.o.lines * 0.9)
				local col = math.floor((vim.o.columns - width) / 2)
				local row = math.floor((vim.o.lines - height) / 2)
				vim.api.nvim_open_win(buf, true, {
					relative = 'editor',
					width = width,
					height = height,
					col = col,
					row = row,
					style = 'minimal',
					border = 'rounded',
				})
				vim.bo[buf].bufhidden = 'wipe'
			end, desc='Git status' },
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
