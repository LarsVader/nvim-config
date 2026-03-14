return {
	{
		'numToStr/Comment.nvim',
		lazy = false,
		keys = {
			{ 'gc', desc = "Comment (line)" },
			{ 'gb', desc = "Comment (block)" },
		},
		config = function ()
			require('Comment').setup()
		end
	},
}
