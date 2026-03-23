return {
	{
		"nvim-tree/nvim-tree.lua",
		version = "*",
		lazy = true,
		dependencies = { "nvim-tree/nvim-web-devicons", },
		config = function()
			require("nvim-tree").setup({
				sync_root_with_cwd = true,
				respect_buf_cwd = true,
				sort = {
					sorter = "case_sensitive",
				},
				view = {
					width = 60,
				},
				renderer = {
					group_empty = true,
				},
				filters = {
					dotfiles = true,
				},
			})
			vim.keymap.set('n', '<leader>tc', '<cmd>NvimTreeCollapse <CR>', { desc='collapse all folder in file tree view' })
		end,
		keys = {
			{ '<leader>te', '<cmd>NvimTreeToggle<CR><cmd>setlocal relativenumber<cr>', desc='toggle explorer'},
			{ '<leader>ts', '<cmd>NvimTreeFindFileToggle <CR><cmd>setlocal relativenumber<CR>', desc='tree search current file'},
		}
	},
}
