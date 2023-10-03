return {
	{
		"nvim-treesitter/nvim-treesitter", build = ":TSUpdate",
		config = function()
			require('nvim-treesitter.configs').setup {
				ensure_installed = { 'cpp', 'lua', 'rust', 'javascript', 'vimdoc', 'vim' },
				sync_install = false,
				auto_install = false, -- this causes error in windows because of no c compiler installed
				ignore_install = {},
				highlight = { enable = true },
				indent = { enable = true },
				incremental_selection = {
					enable = true,
					keymaps = {
						init_selection = '<c-space>',
						node_incremental = '<c-space>',
						scope_incremental = '<c-s>',
						node_decremental = '<M-space>',
					},
				},
			}
		end,
	},
	{
		'nvim-treesitter/nvim-treesitter-context',
		dependencies = { 'nvim-treesitter/nvim-treesitter' },
	},
}
