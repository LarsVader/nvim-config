return {
	{
		'sindrets/diffview.nvim',
		cmd = { 'DiffviewOpen', 'DiffviewClose', 'DiffviewFileHistory', 'DiffviewToggleFiles', 'DiffviewFocusFiles', 'DiffviewRefresh' },
		keys = {
			{ '<leader>dv', '<cmd>DiffviewOpen<cr>', desc = 'Diffview open (working tree)' },
			{ '<leader>dh', '<cmd>DiffviewFileHistory %<cr>', desc = 'Diffview file history' },
			{ '<leader>dc', '<cmd>DiffviewClose<cr>', desc = 'Diffview close' },
			{ '<leader>dm', '<cmd>DiffviewOpen main<cr>', desc = 'Diff against main' },
			{ '<leader>do', function()
				local branch = vim.fn.system('git rev-parse --abbrev-ref HEAD'):gsub('%s+', '')
				vim.cmd('DiffviewOpen origin/' .. branch)
			end, desc = 'Diff against origin' },
		},
		config = function()
			require('diffview').setup({})
		end,
	},
}
