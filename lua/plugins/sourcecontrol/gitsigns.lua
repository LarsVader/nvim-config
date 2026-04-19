return {
	{
		'lewis6991/gitsigns.nvim',
		event = { 'BufReadPre', 'BufNewFile' },
		opts = {
			signs = {
				add          = { text = '│' },
				change       = { text = '│' },
				delete       = { text = '_' },
				topdelete    = { text = '‾' },
				changedelete = { text = '~' },
			},
			on_attach = function(bufnr)
				local gs = require('gitsigns')

				local function map(mode, l, r, desc)
					vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
				end

				-- Navigation (wrap around)
				map('n', ']h', function() gs.nav_hunk('next', { wrap = true }) end, 'Next hunk')
				map('n', '[h', function() gs.nav_hunk('prev', { wrap = true }) end, 'Prev hunk')

				-- Actions
				map({ 'n', 'v' }, '<leader>hs', ':Gitsigns stage_hunk<CR>', 'Stage hunk')
				map({ 'n', 'v' }, '<leader>hr', ':Gitsigns reset_hunk<CR>', 'Reset hunk')
				map('n', '<leader>hu', gs.undo_stage_hunk, 'Undo stage hunk')
				map('n', '<leader>hS', gs.stage_buffer, 'Stage buffer')
				map('n', '<leader>hR', gs.reset_buffer, 'Reset buffer')
				map('n', '<leader>hp', gs.preview_hunk_inline, 'Preview hunk inline')
				map('n', '<leader>hd', gs.diffthis, 'Diff this')
				map('n', '<leader>htd', gs.toggle_deleted, 'Toggle deleted')
				map('n', '<leader>htb', gs.toggle_current_line_blame, 'Toggle line blame')
			end,
		},
	},
}
