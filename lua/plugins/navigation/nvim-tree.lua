return {
	{
		"nvim-tree/nvim-tree.lua",
		version = "*",
		lazy = true,
		dependencies = { "nvim-tree/nvim-web-devicons", },
		config = function()
			require("nvim-tree").setup {}
			vim.keymap.set('n', '<leader>tc', ':NvimTreeCollapse <CR>', { desc='collapse all folder in file tree view' })
		end,
		keys = {
			{ '<leader>te', ':NvimTreeToggle <CR>:setlocal relativenumber<CR>', desc='toggle explorer'},
			{ '<leader>ts', ':NvimTreeFindFileToggle <CR>:setlocal relativenumber<CR>', desc='tree search current file'},
		}
	},
}
