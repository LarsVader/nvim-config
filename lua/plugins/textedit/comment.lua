return {
	{
		'numToStr/Comment.nvim',
		lazy = false,
		keys = { 'gc', 'gb', },
		config = function ()
			require('Comment').setup()
		end
	},
}
