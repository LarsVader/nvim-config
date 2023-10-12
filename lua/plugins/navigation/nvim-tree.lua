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
				}
			})
			vim.keymap.set('n', '<leader>tc', '<cmd>NvimTreeCollapse <CR>', { desc='collapse all folder in file tree view' })
		end,
		keys = {
			{ '<leader>te', '<cmd>NvimTreeToggle <CR>', desc='toggle explorer'},
			{ '<leader>ts', '<cmd>NvimTreeFindFileToggle <CR>', desc='tree search current file'},
		}
	},
}
