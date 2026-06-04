return {
	'dmtrKovalenko/fff.nvim',
	build = function()
		-- downloads a prebuilt binary or falls back to cargo build
		require("fff.download").download_or_build_binary()
	end,
	-- for nixos:
	-- build = "nix run .#release",
	opts = {
		debug = {
			enabled = true,
			show_scores = true,
		},
		keymaps = {
			close = '<Esc>',
			select = '<CR>',
			select_split = '<C-s>',
			select_vsplit = '<C-v>',
			select_tab = '<C-CR>',
			move_up = { '<Up>', '<Tab>' },
			move_down = { '<Down>', '<S-Tab>' },
			preview_scroll_up = '<C-u>',
			preview_scroll_down = '<C-d>',
			toggle_debug = '<F2>',
			cycle_grep_modes = '<C-m>',
			cycle_previous_query = '<C-Up>',
			toggle_select = '<C-t>',
			send_to_quickfix = '<C-q>',
			focus_list = '<C-l>',
			focus_preview = '<C-p>',
		},
	},
	lazy = false, -- the plugin lazy-initialises itself
	keys = {
		{ "<C-p>", function() require('fff').find_files() end, desc = 'FFFind files' },
		{ "fg",    function() require('fff').live_grep() end,  desc = 'LiFFFe grep' },
		{
			"fz",
			function() require('fff').live_grep({ grep = { modes = { 'fuzzy', 'plain' } } }) end,
			desc = 'Live fffuzy grep',
		},
		{
			"fs",
			function() require('fff').live_grep({ query = vim.fn.expand("<cword>") }) end,
			desc = 'Search current word',
		},
	},
}
