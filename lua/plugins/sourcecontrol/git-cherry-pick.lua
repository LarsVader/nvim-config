return {
	{
		'nvim-telescope/telescope.nvim',
		keys = {
			{
				'<leader>gp',
				function()
					local pickers = require('telescope.pickers')
					local finders = require('telescope.finders')
					local conf = require('telescope.config').values
					local actions = require('telescope.actions')
					local action_state = require('telescope.actions.state')

					-- Step 1: Pick a branch
					pickers.new({}, {
						prompt_title = 'Cherry-pick: select branch',
						finder = finders.new_oneshot_job(
							{ 'git', 'branch', '--all', '--format=%(refname:short)' },
							{}
						),
						sorter = conf.generic_sorter({}),
						attach_mappings = function(prompt_bufnr, _)
							actions.select_default:replace(function()
								local selection = action_state.get_selected_entry()
								actions.close(prompt_bufnr)
								if not selection then return end
								local branch = selection[1]

								-- Step 2: Pick a commit from that branch
								pickers.new({}, {
									prompt_title = 'Cherry-pick commit from: ' .. branch,
									finder = finders.new_oneshot_job(
										{
											'git', 'log', branch,
											'--pretty=format:%h %an: %s',
											'-n', '100',
										},
										{}
									),
									sorter = conf.generic_sorter({}),
									attach_mappings = function(commit_bufnr, _)
										actions.select_default:replace(function()
											local commit_entry = action_state.get_selected_entry()
											actions.close(commit_bufnr)
											if not commit_entry then return end
											local hash = commit_entry[1]:match('^(%S+)')
											if not hash then
												vim.notify(
													'Could not parse commit hash',
													vim.log.levels.ERROR
												)
												return
											end

											-- Step 3: Cherry-pick
											local result = vim.fn.system(
												{ 'git', 'cherry-pick', hash }
											)
											if vim.v.shell_error == 0 then
												vim.notify(
													'Cherry-picked ' .. hash .. ' successfully',
													vim.log.levels.INFO
												)
											else
												vim.notify(
													'Cherry-pick failed:\n' .. result,
													vim.log.levels.ERROR
												)
											end
										end)
										return true
									end,
								}):find()
							end)
							return true
						end,
					}):find()
				end,
				desc = 'Git cherry-pick from branch',
			},
		},
	},
}
