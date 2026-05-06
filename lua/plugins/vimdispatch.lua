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
			local notify = require("lars.dispatch-notify")

			vim.api.nvim_create_user_command("Make", function(opts)
				notify.show("Make " .. opts.args, {
					is_running = function()
						-- dispatch#completed(0) returns 1 when the
						-- most recent request has finished
						local ok, done = pcall(vim.fn["dispatch#completed"], 0)
						if ok and done == 1 then
							return false
						end
						return true
					end,
					poll_interval = 300,
				})
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
					local obj = vim.system({'make', '-qp'}, {text = true}):wait()
					if not obj.stdout or obj.stdout == "" then return {} end
					local seen = {}
					local result = {}
					for line in obj.stdout:gmatch("[^\r\n]+") do
						local before_colon = line:match("^([a-zA-Z0-9][^$#/\t=]*):")
						if before_colon and line:sub(#before_colon + 2, #before_colon + 2) ~= "=" then
							for word in before_colon:gmatch("%S+") do
								if not seen[word] and (arg_lead == "" or word:find(arg_lead, 1, true) == 1) then
									seen[word] = true
									result[#result + 1] = word
								end
							end
						end
					end
					table.sort(result)
					return result
				end,
			})
		end,
	},
}
