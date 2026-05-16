return {
	{
		'tpope/vim-fugitive',
		dependencies = { 'tpope/vim-rhubarb', },
		cmd = 'G',
		config = function()
			-- When a commit editor opens, show it in a 3-panel float layout:
			-- top-left = commit message, bottom-left = recent commits, right = staged diff
			-- (bufhidden is reset after placing in float so fugitive's :wq commit flow works)
			vim.api.nvim_create_autocmd('FileType', {
				pattern = 'gitcommit',
				group = vim.api.nvim_create_augroup('FugitiveCommitLayout', { clear = true }),
				callback = function(args)
					local commit_buf = args.buf
					vim.schedule(function()
						if not vim.api.nvim_buf_is_valid(commit_buf) then return end

						-- Skip non-fugitive commit buffers (e.g. submodule commit float)
						local bufname = vim.api.nvim_buf_get_name(commit_buf)
						if not bufname:match("COMMIT_EDITMSG$") then return end

						-- Save fugitive's bufhidden (usually 'delete') then protect
						-- the buffer so it survives window transitions
						local orig_bufhidden = vim.bo[commit_buf].bufhidden
						vim.bo[commit_buf].bufhidden = 'hide'

						-- Tear down any existing fugitive float infrastructure
						pcall(vim.api.nvim_del_augroup_by_name, 'FugitiveFloat')
						for _, win in ipairs(vim.api.nvim_list_wins()) do
							if vim.api.nvim_win_is_valid(win) and vim.w[win].fugitive_float then
								local b = vim.api.nvim_win_get_buf(win)
								if b ~= commit_buf then
									vim.bo[b].bufhidden = 'hide'
								end
								vim.api.nvim_win_close(win, false)
							end
						end

						-- Close the regular window the commit buf is in (if any)
						local cw = vim.fn.bufwinid(commit_buf)
						if cw ~= -1 then
							vim.api.nvim_win_close(cw, false)
						end

						-- Build a diff buffer showing the commit's full diff.
						-- For amends we need parent..staged so the pane reflects the entire
						-- amended commit, not just the new tweak being staged on top.
						local worktree = vim.fn.FugitiveWorkTree()
						local git_amend = require('lars.git_amend')
						local commit_lines = vim.api.nvim_buf_get_lines(commit_buf, 0, -1, false)
						local head_message = vim.fn.systemlist({ 'git', '-C', worktree, 'log', '-1', '--format=%B' })
						local is_amend = git_amend.is_amending(commit_lines, head_message)
						local diff_lines = git_amend.get_diff_lines(worktree, is_amend)
						local diff_buf = vim.api.nvim_create_buf(false, true)
						vim.api.nvim_buf_set_lines(diff_buf, 0, -1, false, diff_lines)
						vim.bo[diff_buf].modifiable = false
						vim.bo[diff_buf].bufhidden = 'wipe'
						vim.bo[diff_buf].filetype = 'diff'

						-- Build recent commits buffer (bottom-left, async)
						local log_buf = vim.api.nvim_create_buf(false, true)
						vim.api.nvim_buf_set_lines(log_buf, 0, -1, false, { 'Loading...' })
						vim.bo[log_buf].modifiable = false
						vim.bo[log_buf].bufhidden = 'wipe'
						vim.bo[log_buf].filetype = 'git'

						-- Async: get staged submodule names, then build log
						vim.system(
							{ 'git', '-C', worktree, 'diff', '--cached', '--name-only', '--diff-filter=M' },
							{ text = true },
							function(result)
								-- Also get submodule list to filter
								vim.system(
									{ 'git', '-C', worktree, 'submodule', '--quiet', 'foreach', 'echo $sm_path' },
									{ text = true },
									function(sm_result)
										vim.schedule(function()
											if not vim.api.nvim_buf_is_valid(log_buf) then return end
											local sm_set = {}
											if sm_result.code == 0 and sm_result.stdout then
												for _, p in ipairs(vim.split(sm_result.stdout, '\n', { trimempty = true })) do
													sm_set[p] = true
												end
											end
											-- Find staged files that are submodules
											local staged_subs = {}
											if result.code == 0 and result.stdout then
												for _, f in ipairs(vim.split(result.stdout, '\n', { trimempty = true })) do
													if sm_set[f] then
														table.insert(staged_subs, f)
													end
												end
											end

											-- Build log: always show main repo, plus staged submodules
											local pending = 1 + #staged_subs
											local log_results = {} -- ordered: [1]=repo, [2..]=submodules
											local log_names = { worktree }
											local log_titles = { vim.fn.fnamemodify(worktree, ':t') }
											for _, sm in ipairs(staged_subs) do
												table.insert(log_names, worktree .. '/' .. sm)
												table.insert(log_titles, sm)
											end

											for idx, path in ipairs(log_names) do
												log_results[idx] = { 'Loading...' }
												vim.system(
													{ 'git', '-C', path, 'log', '--oneline', '-n', '15' },
													{ text = true },
													function(log_res)
														vim.schedule(function()
															if not vim.api.nvim_buf_is_valid(log_buf) then return end
															if log_res.code == 0 and log_res.stdout and log_res.stdout ~= '' then
																log_results[idx] = vim.split(log_res.stdout, '\n', { trimempty = true })
															else
																log_results[idx] = { '(no commits)' }
															end
															pending = pending - 1
															if pending == 0 then
																local lines = {}
																for i, title in ipairs(log_titles) do
																	if i > 1 then table.insert(lines, '') end
																	table.insert(lines, '── ' .. title .. ' ──')
																	vim.list_extend(lines, log_results[i])
																end
																vim.bo[log_buf].modifiable = true
																vim.api.nvim_buf_set_lines(log_buf, 0, -1, false, lines)
																vim.bo[log_buf].modifiable = false
															end
														end)
													end
												)
											end
										end)
									end
								)
							end
						)

						-- Layout: left column split top/bottom, right column full height
						local total_w = math.floor(vim.o.columns * 0.9)
						local h = math.floor(vim.o.lines * 0.9)
						local left_w = math.floor(total_w * 0.5)
						local right_w = total_w - left_w - 2
						local row = math.floor((vim.o.lines - h) / 2)
						local col = math.floor((vim.o.columns - total_w) / 2)
						local commit_h = math.floor(h * 0.4)
						local log_h = h - commit_h - 2

						-- Top-left: commit editor
						local commit_float = vim.api.nvim_open_win(commit_buf, true, {
							relative = 'editor',
							width = left_w, height = commit_h,
							col = col, row = row,
							style = 'minimal', border = 'rounded',
							title = ' Commit Message ', title_pos = 'center',
						})

						-- Bottom-left: recent commits
						local log_float = vim.api.nvim_open_win(log_buf, false, {
							relative = 'editor',
							width = left_w, height = log_h,
							col = col, row = row + commit_h + 2,
							style = 'minimal', border = 'rounded',
							title = ' Recent Commits ', title_pos = 'center',
						})

						-- Right: diff (full height)
						local status_float = vim.api.nvim_open_win(diff_buf, false, {
							relative = 'editor',
							width = right_w, height = h,
							col = col + left_w + 2, row = row,
							style = 'minimal', border = 'rounded',
							title = is_amend and ' Amend Diff ' or ' Staged Changes ', title_pos = 'center',
						})
						local status_buf = diff_buf

						-- Restore fugitive's original bufhidden so :wq triggers commit
						vim.bo[commit_buf].bufhidden = orig_bufhidden

						-- Focus the commit editor
						vim.api.nvim_set_current_win(commit_float)

						-- Navigation between the three floats
						local all_floats = { commit_float, log_float, status_float }
						local all_bufs = { commit_buf, log_buf, status_buf }
						for idx, float in ipairs(all_floats) do
							local buf = all_bufs[idx]
							for _, map in ipairs({ '<C-w>w', '<C-w><C-w>' }) do
								vim.keymap.set('n', map, function()
									local next = all_floats[(idx % #all_floats) + 1]
									if vim.api.nvim_win_is_valid(next) then
										vim.api.nvim_set_current_win(next)
									end
								end, { buffer = buf })
							end
						end
						vim.keymap.set('n', '<C-j>', function()
							if vim.api.nvim_win_is_valid(log_float) then vim.api.nvim_set_current_win(log_float) end
						end, { buffer = commit_buf })
						vim.keymap.set('n', '<C-l>', function()
							if vim.api.nvim_win_is_valid(status_float) then vim.api.nvim_set_current_win(status_float) end
						end, { buffer = commit_buf })
						vim.keymap.set('n', '<C-k>', function()
							if vim.api.nvim_win_is_valid(commit_float) then vim.api.nvim_set_current_win(commit_float) end
						end, { buffer = log_buf })
						vim.keymap.set('n', '<C-l>', function()
							if vim.api.nvim_win_is_valid(status_float) then vim.api.nvim_set_current_win(status_float) end
						end, { buffer = log_buf })
						vim.keymap.set('n', '<C-h>', function()
							if vim.api.nvim_win_is_valid(commit_float) then vim.api.nvim_set_current_win(commit_float) end
						end, { buffer = status_buf })

						-- Clean up all floats when any one closes
						local cg = vim.api.nvim_create_augroup('FugitiveCommitCleanup', { clear = true })
						vim.api.nvim_create_autocmd('WinClosed', {
							group = cg,
							callback = function()
								vim.schedule(function()
									if not vim.api.nvim_win_is_valid(commit_float)
										or not vim.api.nvim_win_is_valid(log_float)
										or not vim.api.nvim_win_is_valid(status_float) then
										pcall(vim.api.nvim_del_augroup_by_name, 'FugitiveCommitCleanup')
										for _, float in ipairs({ status_float, log_float }) do
											if vim.api.nvim_win_is_valid(float) then
												vim.api.nvim_win_close(float, true)
											end
										end
										for _, buf in ipairs({ status_buf, log_buf }) do
											if vim.api.nvim_buf_is_valid(buf) then
												vim.api.nvim_buf_delete(buf, { force = true })
											end
										end
									end
								end)
							end,
						})
					end)
				end,
			})
			-- Move git-filetype buffers (:G log, :G show, etc.) into a float
			vim.api.nvim_create_autocmd('FileType', {
				pattern = 'git',
				group = vim.api.nvim_create_augroup('FugitiveGitFloat', { clear = true }),
				callback = function(args)
					local buf = args.buf
					vim.schedule(function()
						if not vim.api.nvim_buf_is_valid(buf) then return end
						local win = vim.fn.bufwinid(buf)
						if win == -1 then return end
						-- Skip if already in a float
						local wc = vim.api.nvim_win_get_config(win)
						if wc.relative ~= '' then return end
						-- Skip if it's the only window (e.g. :G diff | only)
						local regular = 0
						for _, w in ipairs(vim.api.nvim_list_wins()) do
							if vim.api.nvim_win_is_valid(w) then
								local c = vim.api.nvim_win_get_config(w)
								if c.relative == '' then regular = regular + 1 end
							end
						end
						if regular <= 1 then return end
						-- Move to float
						vim.bo[buf].bufhidden = 'hide'
						vim.api.nvim_win_close(win, false)
						local width = math.floor(vim.o.columns * 0.9)
						local height = math.floor(vim.o.lines * 0.9)
						local float_win = vim.api.nvim_open_win(buf, true, {
							relative = 'editor',
							width = width, height = height,
							col = math.floor((vim.o.columns - width) / 2),
							row = math.floor((vim.o.lines - height) / 2),
							style = 'minimal', border = 'rounded',
						})
					end)
				end,
			})
		end,
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
						local local_win = vim.api.nvim_get_current_win()
						vim.cmd('diffthis')
						vim.cmd('rightbelow vsplit')
						vim.cmd('Gedit :1:' .. escaped)
						local base_win = vim.api.nvim_get_current_win()
						vim.cmd('diffthis')
						vim.cmd('rightbelow vsplit')
						vim.cmd('Gedit :3:' .. escaped)
						local remote_win = vim.api.nvim_get_current_win()
						vim.cmd('diffthis')
						vim.cmd('botright split ' .. vim.fn.fnameescape(worktree .. '/' .. cfile))
						local merged_buf = vim.api.nvim_get_current_buf()
						local merged_win = vim.api.nvim_get_current_win()
						vim.cmd('diffthis')
						-- Winbar labels (window-local) so you can't mix up which side is which
						vim.wo[local_win].winbar  = '%#DiffAdd# LOCAL  (ours :2) %*  <leader>cl = take this side'
						vim.wo[base_win].winbar   = '%#DiffChange# BASE   (ancestor :1) %*  <leader>cb = take this side'
						vim.wo[remote_win].winbar = '%#DiffDelete# REMOTE (theirs :3) %*  <leader>cr = take this side'
						vim.wo[merged_win].winbar = '%#StatusLine# MERGED (worktree) %*  ]x [x = jump conflicts'

						-- Find the conflict region containing `lnum` in the merged buffer.
						-- Returns {start, mid_base, sep, end_} as 1-indexed line numbers,
						-- or nil if the cursor isn't inside a conflict region.
						local function find_conflict_at(lnum)
							local lines = vim.api.nvim_buf_get_lines(merged_buf, 0, -1, false)
							local start
							for i = lnum, 1, -1 do
								local l = lines[i]
								if l and l:match('^<<<<<<<') then start = i; break
								-- A >>>>>>> on the cursor line itself closes the conflict
								-- the cursor sits inside, so don't bail until we're above it.
								elseif l and l:match('^>>>>>>>') and i < lnum then return nil end
							end
							if not start then return nil end
							local mid_base, sep, end_
							for i = start + 1, #lines do
								local l = lines[i]
								if l:match('^|||||||') then mid_base = i
								elseif l:match('^=======') and not sep then sep = i
								elseif l:match('^>>>>>>>') then end_ = i; break
								elseif l:match('^<<<<<<<') then return nil end
							end
							if not (sep and end_) or lnum > end_ then return nil end
							return { start = start, mid_base = mid_base, sep = sep, end_ = end_ }
						end

						-- Replace a single conflict region with the chosen side.
						-- Returns true on success, false if the side isn't available.
						local function apply_side(region, side)
							local lines = vim.api.nvim_buf_get_lines(merged_buf, 0, -1, false)
							local replacement
							if side == 'local' then
								local stop = (region.mid_base or region.sep) - 1
								replacement = vim.list_slice(lines, region.start + 1, stop)
							elseif side == 'remote' then
								replacement = vim.list_slice(lines, region.sep + 1, region.end_ - 1)
							elseif side == 'base' then
								if not region.mid_base then return false end
								replacement = vim.list_slice(lines, region.mid_base + 1, region.sep - 1)
							elseif side == 'all' then
								local ours_stop = (region.mid_base or region.sep) - 1
								local ours = vim.list_slice(lines, region.start + 1, ours_stop)
								local theirs = vim.list_slice(lines, region.sep + 1, region.end_ - 1)
								replacement = ours
								vim.list_extend(replacement, theirs)
							end
							vim.api.nvim_buf_set_lines(merged_buf, region.start - 1, region.end_, false, replacement)
							return true
						end

						local SIDE_LABEL = { ['local'] = 'LOCAL', remote = 'REMOTE', base = 'BASE', all = 'ALL' }

						local function resolve_at_cursor(side)
							local lnum = vim.api.nvim_win_get_cursor(0)[1]
							local region = find_conflict_at(lnum)
							if not region then
								vim.notify('No conflict under cursor (use ]x / [x to jump)', vim.log.levels.WARN)
								return
							end
							if not apply_side(region, side) then
								vim.notify('BASE not in conflict markers (need merge.conflictStyle = diff3)', vim.log.levels.WARN)
							end
						end

						local function resolve_all(side)
							-- Walk from last to first conflict so edits below don't shift the
							-- cached `starts` line numbers above them (an edit at line N never
							-- moves lines < N, so earlier indices stay valid).
							local lines = vim.api.nvim_buf_get_lines(merged_buf, 0, -1, false)
							local starts = {}
							for i, l in ipairs(lines) do
								if l:match('^<<<<<<<') then table.insert(starts, i) end
							end
							if #starts == 0 then
								vim.notify('No conflicts in file', vim.log.levels.INFO)
								return
							end
							local count, skipped = 0, 0
							for i = #starts, 1, -1 do
								local region = find_conflict_at(starts[i])
								if region and apply_side(region, side) then
									count = count + 1
								else
									skipped = skipped + 1
								end
							end
							local msg = string.format('Resolved %d conflict(s) as %s', count, SIDE_LABEL[side])
							if skipped > 0 then
								msg = msg .. string.format(' (skipped %d, BASE markers missing)', skipped)
							end
							vim.notify(msg, vim.log.levels.INFO)
						end

						-- Per-conflict (current cursor region only).
						-- Avoid bare g<letter> here: gr/gb/ga clash with LSP/Comment.nvim prefixes
						-- and would wait timeoutlen before firing.
						vim.keymap.set('n', '<leader>cl', function() resolve_at_cursor('local') end,
							{ buffer = merged_buf, desc = 'Conflict: take LOCAL (this region)' })
						vim.keymap.set('n', '<leader>cb', function() resolve_at_cursor('base') end,
							{ buffer = merged_buf, desc = 'Conflict: take BASE (this region)' })
						vim.keymap.set('n', '<leader>cr', function() resolve_at_cursor('remote') end,
							{ buffer = merged_buf, desc = 'Conflict: take REMOTE (this region)' })
						vim.keymap.set('n', '<leader>ca', function() resolve_at_cursor('all') end,
							{ buffer = merged_buf, desc = 'Conflict: keep ALL (this region)' })

						-- Whole-file (every conflict in the buffer)
						vim.keymap.set('n', '<leader>cL', function() resolve_all('local') end,
							{ buffer = merged_buf, desc = 'Conflict: take LOCAL (whole file)' })
						vim.keymap.set('n', '<leader>cB', function() resolve_all('base') end,
							{ buffer = merged_buf, desc = 'Conflict: take BASE (whole file)' })
						vim.keymap.set('n', '<leader>cR', function() resolve_all('remote') end,
							{ buffer = merged_buf, desc = 'Conflict: take REMOTE (whole file)' })
						vim.keymap.set('n', '<leader>cA', function() resolve_all('all') end,
							{ buffer = merged_buf, desc = 'Conflict: keep ALL (whole file)' })

						-- Conflict navigation
						vim.keymap.set('n', ']x', function()
							if vim.fn.search('^<<<<<<<', 'W') == 0 then
								vim.notify('No more conflicts', vim.log.levels.INFO)
							end
						end, { buffer = merged_buf, desc = 'Conflict: jump to next' })
						vim.keymap.set('n', '[x', function()
							if vim.fn.search('^<<<<<<<', 'bW') == 0 then
								vim.notify('No previous conflict', vim.log.levels.INFO)
							end
						end, { buffer = merged_buf, desc = 'Conflict: jump to previous' })

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
			{ '<leader>gc', ':G commit<CR>', desc='Git commit' },
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
