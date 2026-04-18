return {
	{
		'sindrets/diffview.nvim',
		keys = {
			{ '<leader>dv', '<cmd>DiffviewOpen<cr>', desc = 'Diffview open (working tree)' },
			{ '<leader>dh', '<cmd>DiffviewFileHistory %<cr>', desc = 'Diffview file history' },
			{ '<leader>dc', '<cmd>DiffviewClose<cr>', desc = 'Diffview close' },
			{ '<leader>dm', '<cmd>DiffviewOpen main<cr>', desc = 'Diff against main' },
		},
		config = function()
			require('diffview').setup({})
		end,
	},
}
