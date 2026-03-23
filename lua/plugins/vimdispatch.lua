local function makefile_targets(arg_lead)
	local targets = {}
	local f = io.open("Makefile", "r")
	if not f then return targets end
	for line in f:lines() do
		local target = line:match("^([%w_%-]+)%s*:")
		if target and target:find(arg_lead, 1, true) == 1 then
			targets[#targets + 1] = target
		end
	end
	f:close()
	table.sort(targets)
	return targets
end

return {
	{
		'tpope/vim-dispatch',
		cmd = { 'Dispatch', 'Make', 'Start'},
		keys = {
			{ 'm<CR>', desc='call make dispatched' },
			{ 'm<Space>', desc='prepare a call to make dispatched' },
			{ '`<Space>', desc='prepare calling a shell command dispatched' },
		},
		config = function()
			vim.api.nvim_create_user_command("Make", function(opts)
				local result = vim.fn["dispatch#compile_command"](
					opts.bang and 1 or 0,
					"-- " .. opts.args,
					-1,
					""
				)
				vim.cmd(result)
			end, {
				bang = true,
				nargs = "*",
				complete = function(arg_lead)
					return makefile_targets(arg_lead)
				end,
			})
		end,
	},
}
