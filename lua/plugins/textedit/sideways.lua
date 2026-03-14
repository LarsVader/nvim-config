return {
	{
		-- move parameters left or right in a list
		'AndrewRadev/sideways.vim',
		keys = {
			{'<c-h>', ':SidewaysLeft<cr>', desc = "Move argument left"},
			{'<c-l>', ':SidewaysRight<cr>', desc = "Move argument right"},
		},
	},
}
