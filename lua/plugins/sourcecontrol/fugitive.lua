return {
	{
		'tpope/vim-fugitive',
		dependencies = { 'tpope/vim-rhubarb', },
		keys = {
			{ '<leader>gs', function()
				local function float_opts()
					local width = math.floor(vim.o.columns * 0.9)
					local height = math.floor(vim.o.lines * 0.9)
					return {
						relative = 'editor',
						width = width,
						height = height,
						col = math.floor((vim.o.columns - width) / 2),
						row = math.floor((vim.o.lines - height) / 2),
						style = 'minimal',
						border = 'rounded',
					}
				end

				-- Close any existing fugitive floats
				for _, win in ipairs(vim.api.nvim_list_wins()) do
					if vim.api.nvim_win_is_valid(win) and vim.w[win].fugitive_float then
						vim.api.nvim_win_close(win, true)
					end
				end
				pcall(vim.api.nvim_del_augroup_by_name, 'FugitiveFloat')

				-- Create fugitive buffer, then move it to a float
				vim.cmd('G')
				local buf = vim.api.nvim_get_current_buf()
				vim.bo[buf].bufhidden = 'hide'
				vim.api.nvim_win_close(0, false)
				local float_win = vim.api.nvim_open_win(buf, true, float_opts())
				vim.w[float_win].fugitive_float = true

				local group = vim.api.nvim_create_augroup('FugitiveFloat', { clear = true })

				local function has_fugitive_float()
					for _, win in ipairs(vim.api.nvim_list_wins()) do
						if vim.api.nvim_win_is_valid(win) and vim.w[win].fugitive_float then
							return true
						end
					end
					return false
				end

				local function cleanup()
					pcall(vim.api.nvim_del_augroup_by_name, 'FugitiveFloat')
				end

				local function close_all_fugitive_floats()
					for _, win in ipairs(vim.api.nvim_list_wins()) do
						if vim.api.nvim_win_is_valid(win) and vim.w[win].fugitive_float then
							local b = vim.api.nvim_win_get_buf(win)
							vim.bo[b].bufhidden = 'hide'
							vim.api.nvim_win_close(win, false)
						end
					end
				end

				-- Remap split-opening keys to edit in the same float window
				vim.keymap.set('n', 'o', '<CR>', { buffer = buf, remap = true })
				vim.keymap.set('n', 'gO', '<CR>', { buffer = buf, remap = true })

				-- Fallback: intercept new windows spawned from a fugitive float
				vim.api.nvim_create_autocmd('WinNew', {
					group = group,
					callback = function()
						local prev = vim.fn.win_getid(vim.fn.winnr('#'))
						if not (prev ~= 0 and vim.api.nvim_win_is_valid(prev)
							and vim.w[prev].fugitive_float) then
							return
						end
						local new_win = vim.api.nvim_get_current_win()
						if not vim.api.nvim_win_is_valid(new_win) then return end
						local config = vim.api.nvim_win_get_config(new_win)
						if config.relative ~= '' then return end
						local new_buf = vim.api.nvim_win_get_buf(new_win)
						vim.api.nvim_win_close(new_win, false)
						if vim.api.nvim_win_is_valid(prev) then
							vim.api.nvim_set_current_win(prev)
							vim.cmd('buffer ' .. new_buf)
						end
					end,
				})

				-- Clean up when all fugitive floats are gone
				vim.api.nvim_create_autocmd('WinClosed', {
					group = group,
					callback = function()
						vim.schedule(function()
							if not has_fugitive_float() then
								cleanup()
								-- Wipe the fugitive buffer if it's still around
								if vim.api.nvim_buf_is_valid(buf) then
									vim.api.nvim_buf_delete(buf, { force = true })
								end
							end
						end)
					end,
				})

				-- Add +/-, <C-o> keymaps to all diff windows
				local function setup_diff_keymaps(restore_buf)
					for _, win in ipairs(vim.api.nvim_list_wins()) do
						if vim.api.nvim_win_is_valid(win) and vim.wo[win].diff then
							vim.wo[win].foldlevel = 0
							local b = vim.api.nvim_win_get_buf(win)
							local function set_context(delta)
								return function()
									local opt = vim.o.diffopt
									local cur = tonumber(opt:match('context:(%d+)')) or 6
									local new = math.max(0, cur + delta)
									vim.opt.diffopt:remove('context:' .. cur)
									vim.opt.diffopt:append('context:' .. new)
									for _, w in ipairs(vim.api.nvim_list_wins()) do
										if vim.api.nvim_win_is_valid(w) and vim.wo[w].diff then
											vim.wo[w].foldlevel = 0
										end
									end
								end
							end
							vim.keymap.set('n', '+', set_context(3), { buffer = b, desc = 'More diff context' })
							vim.keymap.set('n', '-', set_context(-3), { buffer = b, desc = 'Less diff context' })
							vim.keymap.set('n', '<C-o>', function()
								vim.cmd('diffoff!')
								vim.cmd('only')
								if restore_buf and vim.api.nvim_buf_is_valid(restore_buf) then
									vim.cmd('buffer ' .. restore_buf)
								end
							end, { buffer = b, desc = 'Close diff, return to previous buffer' })
						end
					end
				end

				-- Diff: 4-way merge during conflicts, 2-way diff otherwise
				vim.keymap.set('n', 'd', function()
					local cursor = vim.api.nvim_win_get_cursor(0)
					-- Extract filename from fugitive status line (e.g. "M file.txt", "UU file.txt")
					local cfile = vim.api.nvim_get_current_line():match('^%S+%s+(.-)%s*$')
					local git_dir = vim.fn.FugitiveGitDir()
					local worktree = vim.fn.FugitiveWorkTree()
					local is_merge = vim.fn.filereadable(git_dir .. '/MERGE_HEAD') == 1
						or vim.fn.filereadable(git_dir .. '/REBASE_HEAD') == 1
					cleanup()
					-- Remember the buffer behind the float to restore later
					local restore_buf = nil
					for _, win in ipairs(vim.api.nvim_list_wins()) do
						if vim.api.nvim_win_is_valid(win) and not vim.w[win].fugitive_float then
							local config = vim.api.nvim_win_get_config(win)
							if config.relative == '' then
								restore_buf = vim.api.nvim_win_get_buf(win)
								break
							end
						end
					end
					-- Close all float windows
					for _, win in ipairs(vim.api.nvim_list_wins()) do
						if vim.api.nvim_win_is_valid(win) and vim.w[win].fugitive_float then
							vim.api.nvim_win_close(win, true)
						end
					end
					if vim.api.nvim_buf_is_valid(buf) then
						vim.api.nvim_buf_delete(buf, { force = true })
					end

					if is_merge and cfile and cfile ~= '' then
						-- 4-way merge: LOCAL | BASE | REMOTE / MERGED
						vim.cmd('only')
						local escaped = vim.fn.fnameescape(cfile)
						vim.cmd('Gedit :2:' .. escaped)
						local local_buf = vim.api.nvim_get_current_buf()
						vim.cmd('diffthis')
						vim.cmd('rightbelow vsplit')
						vim.cmd('Gedit :1:' .. escaped)
						local base_buf = vim.api.nvim_get_current_buf()
						vim.cmd('diffthis')
						vim.cmd('rightbelow vsplit')
						vim.cmd('Gedit :3:' .. escaped)
						local remote_buf = vim.api.nvim_get_current_buf()
						vim.cmd('diffthis')
						vim.cmd('botright split ' .. vim.fn.fnameescape(worktree .. '/' .. cfile))
						local merged_buf = vim.api.nvim_get_current_buf()
						vim.cmd('diffthis')
						-- diffget keymaps on the MERGED buffer
						vim.keymap.set('n', 'gl', function() vim.cmd('diffget ' .. local_buf) end,
							{ buffer = merged_buf, desc = 'Get from LOCAL (left)' })
						vim.keymap.set('n', 'gb', function() vim.cmd('diffget ' .. base_buf) end,
							{ buffer = merged_buf, desc = 'Get from BASE (center)' })
						vim.keymap.set('n', 'gr', function() vim.cmd('diffget ' .. remote_buf) end,
							{ buffer = merged_buf, desc = 'Get from REMOTE (right)' })
						setup_diff_keymaps(restore_buf)
					else
						-- Regular 2-way diff
						vim.cmd('G')
						vim.cmd('only')
						pcall(vim.api.nvim_win_set_cursor, 0, cursor)
						vim.api.nvim_create_autocmd('WinNew', {
							once = true,
							callback = function()
								vim.schedule(function()
									for _, win in ipairs(vim.api.nvim_list_wins()) do
										if vim.api.nvim_win_is_valid(win) then
											local b = vim.api.nvim_win_get_buf(win)
											if vim.api.nvim_buf_is_valid(b) and vim.bo[b].filetype == 'fugitive' then
												vim.api.nvim_win_close(win, false)
												break
											end
										end
									end
									setup_diff_keymaps(restore_buf)
								end)
							end,
						})
						vim.schedule(function()
							vim.api.nvim_feedkeys('dv', 'm', false)
						end)
					end
				end, { buffer = buf })
			end, desc='Git status' },
			{ '<leader>gb', ':G blame<CR>', desc='Git blame' },
			{ '<leader>gd', ':G diff<CR>:only<CR>', desc='Git diff' },
			{ '<leader>gm', ':Gdiffsplit<CR>', desc='Git diffsplit' },
			-- other commands like log i use telescope instead
		}
	},
	{
		-- on the blame window from fugitive show the commit message of the current line
		'tommcdo/vim-fugitive-blame-ext',
		keys = '<leader>gb',
		dependencies = { 'tpope/vim-fugitive' },
	},
}
