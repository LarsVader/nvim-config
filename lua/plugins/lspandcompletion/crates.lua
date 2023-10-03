return {
	{
		-- completions on the cargo.toml file
		-- is this still necessary?
		'saecki/crates.nvim',
		dependencies = { 'nvim-lua/plenary.nvim', },
		ft = {'rust', 'toml'},
		opts = {},
		config = function(_,opts)
			local crates = require('crates')
			crates.setup(opts)
			crates.show()
		end,
	}
}
