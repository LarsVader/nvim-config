return {
	{
		'numToStr/Comment.nvim',
		keys = {
			{ 'gc', mode = { 'n', 'x' }, desc = "Comment (line)" },
			{ 'gb', mode = { 'n', 'x' }, desc = "Comment (block)" },
		},
		config = function ()
			require('Comment').setup()
		end
	},
}
