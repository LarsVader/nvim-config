return {
	{
		-- pin buffers and jump to them fast
		'ThePrimeagen/harpoon',
		dependencies = { 'nvim-lua/plenary.nvim' },
		keys = (function()
			local k = {
				{"<leader>ha", function() require('harpoon.mark').add_file() end, desc='harpoon add'},
				{"<leader>hh", function() require('harpoon.ui').toggle_quick_menu() end, desc='harpoon menu'},
			}
			for i = 0, 9 do
				table.insert(k, {"<leader>"..i, function() require('harpoon.ui').nav_file(i) end, desc='harpoon file '..i})
			end
			return k
		end)(),
	},
}
