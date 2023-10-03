return {
	{
		'tpope/vim-dispatch',
		cmd = { 'Dispatch', 'Make', 'Start'},
		keys = {
			{ 'm<CR>', desc='call make dispatched' },
			{ 'm<Space>', desc='prepare a call to make dispatched' },
			{ '`<Space>', desc='prepare calling a shell command dispatched' },
		}
	},
}
