return {
	{
		-- pin buffers and jump to them fast
		'ThePrimeagen/harpoon',
		dependencies = { 'nvim-lua/plenary.nvim' },
		keys = {
			{"<leader>ha", function () require('harpoon.mark').add_file() end, desc='harpoon add'},
			{"<leader>hh", function () require('harpoon.ui').toggle_quick_menu() end, desc='harpoon toggle quick menu'},
			{"<leader>1", function () require('harpoon.ui').nav_file(1) end, desc='harpoon navigate to file 1'},
			{"<leader>2", function () require('harpoon.ui').nav_file(2) end, desc='harpoon navigate to file 2'},
			{"<leader>3", function () require('harpoon.ui').nav_file(3) end, desc='harpoon navigate to file 3'},
			{"<leader>4", function () require('harpoon.ui').nav_file(4) end, desc='harpoon navigate to file 4'},
			{"<leader>5", function () require('harpoon.ui').nav_file(5) end, desc='harpoon navigate to file 5'},
			{"<leader>6", function () require('harpoon.ui').nav_file(6) end, desc='harpoon navigate to file 6'},
			{"<leader>7", function () require('harpoon.ui').nav_file(7) end, desc='harpoon navigate to file 7'},
			{"<leader>8", function () require('harpoon.ui').nav_file(8) end, desc='harpoon navigate to file 8'},
			{"<leader>9", function () require('harpoon.ui').nav_file(9) end, desc='harpoon navigate to file 9'},
			{"<leader>0", function () require('harpoon.ui').nav_file(0) end, desc='harpoon navigate to file 0'},
		}
	},
}
