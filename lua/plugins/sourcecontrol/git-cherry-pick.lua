local function cherry_pick_in(cwd, git_root, submodules, sm_idx)
	local pickers = require('telescope.pickers')
	local finders = require('telescope.finders')
	local conf = require('telescope.config').values
	local actions = require('telescope.actions')
	local action_state = require('telescope.actions.state')
	local tsm = require('lars.telescope-submodule')

	local has_subs = submodules and #submodules > 1
	local sm_label = ""
	if has_subs then
		local sm = submodules[sm_idx]
		sm_label = sm == "." and "(root)" or sm
	end

	local function add_sub_mappings(prompt_bufnr)
		if not has_subs then return end
		local buf_set = function(mode, lhs, fn, desc)
			vim.keymap.set(mode, lhs, fn, { buffer = prompt_bufnr, desc = desc })
		end
		buf_set("i", "<C-s>", function()
			actions.close(prompt_bufnr)
			local next_idx = (sm_idx % #submodules) + 1
			vim.schedule(function()
				cherry_pick_in(
					tsm.submodule_cwd(git_root, submodules[next_idx]),
					git_root, submodules, next_idx
				)
			end)
		end, "Submodule: cycle to next")
		buf_set("i", "<C-a>", function()
			actions.close(prompt_bufnr)
			local prev_idx = ((sm_idx - 2) % #submodules) + 1
			vim.schedule(function()
				cherry_pick_in(
					tsm.submodule_cwd(git_root, submodules[prev_idx]),
					git_root, submodules, prev_idx
				)
			end)
		end, "Submodule: cycle to previous")
		buf_set("i", "<C-g>", function()
			actions.close(prompt_bufnr)
			vim.schedule(function()
				local sm_pickers = require('telescope.pickers')
				local sm_finders = require('telescope.finders')
				local sm_previewers = require('telescope.previewers')
				local entries = {}
				for i, sm in ipairs(submodules) do
					local label = sm == "." and "(root)" or sm
					if i == sm_idx then label = label .. " *" end
					table.insert(entries, { label = label, idx = i, submodule = sm })
				end
				sm_pickers.new({}, {
					prompt_title = "Select Submodule",
					preview_title = "Branches preview",
					finder = sm_finders.new_table({
						results = entries,
						entry_maker = function(entry)
							return { value = entry, display = entry.label, ordinal = entry.label }
						end,
					}),
					sorter = conf.generic_sorter({}),
					previewer = sm_previewers.new_buffer_previewer({
						title = "Branches preview",
						define_preview = function(self, entry)
							local sm_cwd = tsm.submodule_cwd(git_root, entry.value.submodule)
							local lines = vim.fn.systemlist({
								'git', '-C', sm_cwd,
								'branch', '--all', '--format=%(refname:short)',
							})
							if vim.v.shell_error ~= 0 then
								lines = { "(no output)" }
							end
							vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
						end,
					}),
					attach_mappings = function(sm_bufnr)
						actions.select_default:replace(function()
							local sel = action_state.get_selected_entry()
							actions.close(sm_bufnr)
							if sel then
								vim.schedule(function()
									cherry_pick_in(
										tsm.submodule_cwd(git_root, sel.value.submodule),
										git_root, submodules, sel.value.idx
									)
								end)
							end
						end)
						return true
					end,
				}):find()
			end)
		end, "Submodule: pick from list")
	end

	local branch_title = 'Cherry-pick: select branch'
	if has_subs then
		branch_title = string.format('Cherry-pick: select branch [%s]', sm_label)
	end

	-- Step 1: Pick a branch
	pickers.new({}, {
		prompt_title = branch_title,
		finder = finders.new_oneshot_job(
			{ 'git', 'branch', '--all', '--format=%(refname:short)' },
			{ cwd = cwd }
		),
		sorter = conf.generic_sorter({}),
		attach_mappings = function(prompt_bufnr)
			add_sub_mappings(prompt_bufnr)
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				if not selection then return end
				local branch = selection[1]

				local commit_title = 'Cherry-pick commit from: ' .. branch
				if has_subs then
					commit_title = string.format('Cherry-pick from: %s [%s]', branch, sm_label)
				end

				-- Step 2: Pick a commit from that branch
				pickers.new({}, {
					prompt_title = commit_title,
					finder = finders.new_oneshot_job(
						{
							'git', 'log', branch,
							'--pretty=format:%h %an: %s',
							'-n', '100',
						},
						{ cwd = cwd }
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
								{ 'git', '-C', cwd, 'cherry-pick', hash }
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
end

return {
	{
		'nvim-telescope/telescope.nvim',
		keys = {
			{
				'<leader>gp',
				function()
					local tsm = require('lars.telescope-submodule')
					local git_root = tsm.git_toplevel(vim.fn.getcwd())
					if not git_root then
						cherry_pick_in(vim.fn.getcwd(), nil, nil, nil)
						return
					end

					local submodules = tsm.get_submodules(git_root)
					if #submodules <= 1 then
						cherry_pick_in(git_root, nil, nil, nil)
						return
					end

					local current_sm = tsm.current_submodule(git_root)
					local sm_idx = 1
					for i, sm in ipairs(submodules) do
						if sm == current_sm then sm_idx = i; break end
					end
					cherry_pick_in(tsm.submodule_cwd(git_root, current_sm), git_root, submodules, sm_idx)
				end,
				desc = 'Git cherry-pick from branch',
			},
		},
	},
}
