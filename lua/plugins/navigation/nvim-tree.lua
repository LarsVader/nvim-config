return {
	{
		"nvim-tree/nvim-tree.lua",
		version = "*",
		lazy = true,
		dependencies = { "nvim-tree/nvim-web-devicons", },
		config = function()
			require("nvim-tree").setup ({
				view = {
					width = {},
					relativenumber = true,
				},
				renderer = {
					group_empty = true,

				},
				git = {
					enable = false, --[[  seems to not work and just throws errors ]]
				}

			})
			vim.keymap.set('n', '<leader>tc', '<cmd>NvimTreeCollapse <CR>', { desc='collapse all folder in file tree view' })
			vim.keymap.set('n', '<leader>tq', '<cmd>NvimTreeClose <CR>', { desc='Close NvimTree' })
		end,
		keys = {
			{ '<leader>te', '<cmd>NvimTreeOpen <CR>', desc='open NvimTree'},
			{ '<leader>ts', '<cmd>NvimTreeFindFile <CR>', desc='tree search current file'},
		}
	},
}
