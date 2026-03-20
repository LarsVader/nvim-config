return {
	{
		-- pin buffers and jump to them fast
		'ThePrimeagen/harpoon',
		branch = 'harpoon2',
		dependencies = { 'nvim-lua/plenary.nvim' },
		config = function()
			require('harpoon'):setup()
		end,
		keys = (function()
			local k = {
				{"<leader>ha", function() require('harpoon'):list():add() end, desc='harpoon add'},
				{"<leader>hh", function()
					local h = require('harpoon')
					h.ui:toggle_quick_menu(h:list())
				end, desc='harpoon menu'},
			}
			for i = 1, 9 do
				table.insert(k, {"<leader>"..i, function() require('harpoon'):list():select(i) end, desc='harpoon file '..i})
			end
			return k
		end)(),
	},
}
