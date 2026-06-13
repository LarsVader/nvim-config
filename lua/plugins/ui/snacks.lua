return {
	{
		'folke/snacks.nvim',
		priority = 1000,
		lazy = false,
		opts = {
			image = { enabled = true },
			input = { enabled = true },
			notifier = { enabled = true },
			scroll = { enabled = true },
			picker = {
				actions = {
					sidekick_send = function(...)
						return require("sidekick.cli.picker.snacks").send(...)
					end,
					-- One-shot git_log actions. They act on the highlighted commit
					-- (item.commit) in the picker's cwd (item.cwd -- so they honour
					-- submodule-scoped logs). Unlike the submodule switcher these need
					-- no cross-reopen state or cwd re-scoping of the picker itself, so
					-- they live inline here rather than in a wrapper module.
					git_rebase = function(picker, item)
						if not (item and item.commit) then
							return Snacks.notify.warn("No commit under cursor", { title = "Git Rebase" })
						end
						local commit, cwd = item.commit, item.cwd or picker:cwd()
						picker:close()
						-- Rebase the current branch onto the selected commit. Non-interactive,
						-- so no editor is needed; util.cmd surfaces conflicts/errors in a popup
						-- (resolve via <leader>gs / :G rebase --continue).
						Snacks.picker.util.cmd({ "git", "rebase", commit }, function()
							Snacks.notify("Rebased onto " .. commit, { title = "Git Rebase" })
							vim.cmd.checktime()
						end, { cwd = cwd })
					end,
					-- Interactive rebase: optionally pre-mark commits first (the
						-- git_rebase_mark_* actions below), then launch. The module
						-- computes the base, opens Fugitive's rebase-todo in a fresh
						-- tcd-scoped tab (so submodule-scoped logs hit the right repo),
						-- and seeds the todo with any marks. See lua/lars/snacks-rebase.lua.
						git_rebase_interactive = function(picker, item)
							require("lars.snacks-rebase").launch(picker, item)
						end,
						-- Mark the selected/cursor commit(s) with a rebase action; the
						-- marks are applied to the todo when git_rebase_interactive runs.
						-- "pick" clears a mark; git_rebase_clear drops them all.
						git_rebase_mark_edit = function(picker) require("lars.snacks-rebase").tag(picker, "edit") end,
						git_rebase_mark_reword = function(picker) require("lars.snacks-rebase").tag(picker, "reword") end,
						git_rebase_mark_squash = function(picker) require("lars.snacks-rebase").tag(picker, "squash") end,
						git_rebase_mark_fixup = function(picker) require("lars.snacks-rebase").tag(picker, "fixup") end,
						git_rebase_mark_drop = function(picker) require("lars.snacks-rebase").tag(picker, "drop") end,
						-- "split" expands to pick + reset + break: the rebase stops with the
						-- commit's changes unstaged so you can re-commit it in pieces.
						git_rebase_mark_split = function(picker) require("lars.snacks-rebase").tag(picker, "split") end,
						git_rebase_mark_pick = function(picker) require("lars.snacks-rebase").tag(picker, "pick") end,
						git_rebase_clear = function(picker) require("lars.snacks-rebase").clear(picker) end,
						-- Reorder commits in the picker (empty filter only). Permutes the
						-- finder's items in place; the order is captured at launch and the
						-- todo is seeded in that sequence. See lua/lars/snacks-rebase.lua.
						git_rebase_move_up = function(picker) require("lars.snacks-rebase").move(picker, -1) end,
						git_rebase_move_down = function(picker) require("lars.snacks-rebase").move(picker, 1) end,
					-- Open the selected commit in Diffview (commit vs its parent).
					diffview_open = function(picker, item)
						if not (item and item.commit) then
							return Snacks.notify.warn("No commit under cursor", { title = "Diffview" })
						end
						local commit, cwd = item.commit, item.cwd or picker:cwd()
						picker:close()
						-- -C scopes Diffview to the picker's cwd so submodule-scoped logs
						-- open the right repo; <commit>^! is Diffview's single-commit diff.
						require("lazy").load({ plugins = { "diffview.nvim" } })
						require("diffview").open({ "-C" .. cwd, commit .. "^!" })
					end,
					-- Toggle the git_log preview between the full diff (git show, the
					-- default) and a bare changed-files list (git show --name-status).
					-- The flag lives on the picker instance so it resets every open;
					-- preview:refresh nils the cached item to force a re-render (a plain
					-- show_preview would no-op since the highlighted commit is unchanged).
					git_log_toggle_files = function(picker)
						picker._files_only = not picker._files_only
						picker.preview:refresh(picker)
					end,
				},
				sources = {
					-- Rebase keys live only in the commit-log picker. <c-r> is a prefix
					-- (the second key disambiguates), so it neither fires a bare-<c-r>
					-- timeout nor clashes with the global <c-r><c-w>/<c-r>% register
					-- inserts, and <c-r>i avoids the <c-i>==<Tab> terminal collision.
					git_log = {
						-- Prefix each row with a rebase-mark badge (edit/squash/...) once
						-- any commit is marked via <c-r>{e,w,s,f,d}; stock git_log rows
						-- otherwise. See lua/lars/snacks-rebase.lua.
						format = function(item, picker)
							return require("lars.snacks-rebase").format(item, picker)
						end,
						-- Dispatch the preview on the per-picker _files_only flag (set by
						-- the <M-l> git_log_toggle_files action). Default is snacks' own
						-- git_show (full diff); the toggle swaps in a bare changed-files
						-- list. preview.cmd runs in ctx.item.cwd, so both honour the
						-- submodule-scoped log selected via the <c-g> switcher.
						preview = function(ctx)
							if ctx.picker._files_only then
								return Snacks.picker.preview.cmd(
									{ "git", "--no-pager", "show", "--name-status", "--oneline", ctx.item.commit },
									ctx, { ft = "git" })
							end
							return Snacks.picker.preview.git_show(ctx)
						end,
						win = {
							input = {
								keys = {
									["<c-r>r"] = { "git_rebase", mode = { "n", "i" }, desc = "Rebase branch onto commit" },
									["<c-r>i"] = { "git_rebase_interactive", mode = { "n", "i" }, desc = "Interactive rebase (apply marks)" },
									-- <c-r>{e,w,s,f,d,p} mark the cursor/selected commit(s) for the
									-- next interactive rebase; <c-r>x clears all marks. Reordering
									-- happens in the seeded todo buffer that <c-r>i opens.
									["<c-r>e"] = { "git_rebase_mark_edit", mode = { "n", "i" }, desc = "Mark commit: edit" },
									["<c-r>w"] = { "git_rebase_mark_reword", mode = { "n", "i" }, desc = "Mark commit: reword" },
									["<c-r>s"] = { "git_rebase_mark_squash", mode = { "n", "i" }, desc = "Mark commit: squash" },
									["<c-r>f"] = { "git_rebase_mark_fixup", mode = { "n", "i" }, desc = "Mark commit: fixup" },
									["<c-r>d"] = { "git_rebase_mark_drop", mode = { "n", "i" }, desc = "Mark commit: drop" },
									["<c-r>m"] = { "git_rebase_mark_split", mode = { "n", "i" }, desc = "Mark commit: split (mixed reset)" },
									["<c-r>p"] = { "git_rebase_mark_pick", mode = { "n", "i" }, desc = "Mark commit: pick (clear one)" },
									["<c-r>x"] = { "git_rebase_clear", mode = { "n", "i" }, desc = "Clear all rebase marks" },
									-- Reorder the commit under the cursor (empty filter only). These
									-- override the global <c-j>/<c-k> list nav inside git_log only;
									-- use j/k or <Tab>/<S-Tab> to navigate here.
									["<c-k>"] = { "git_rebase_move_up", mode = { "n", "i" }, desc = "Reorder: move commit up" },
									["<c-j>"] = { "git_rebase_move_down", mode = { "n", "i" }, desc = "Reorder: move commit down" },
									-- <c-d> overrides list_scroll_down in the git_log picker only.
									["<c-d>"] = { "diffview_open", mode = { "n", "i" }, desc = "Open commit in Diffview" },
									-- <M-l> flips the preview between full diff and file list.
									["<M-l>"] = { "git_log_toggle_files", mode = { "n", "i" }, desc = "Toggle preview: diff / file list" },
								},
							},
						},
					},
					git_status = {
						win = {
							input = {
								keys = {
									-- snacks' git_status default binds <Tab> to git_stage,
									-- shadowing the global list_down nav. Conceptually,
									-- "selecting" a change in a status list IS staging it, so
									-- move staging onto the select keys (git_stage toggles
									-- stage/unstage and acts on the cursor item, or on all
									-- multi-selected items after <c-a>) and give <Tab> back
									-- to navigation.
									["<Tab>"] = { "list_down", mode = { "n", "i" } },
									["<c-n>"] = { { "git_stage", "list_down" }, mode = { "n", "i" }, desc = "Stage + next" },
									["<c-t>"] = { { "git_stage", "list_down" }, mode = { "n", "i" }, desc = "Stage + next" },
									["<c-p>"] = { { "git_stage", "list_up" }, mode = { "n", "i" }, desc = "Stage + prev" },
								},
							},
						},
					},
				},
				win = {
					input = {
						keys = {
							-- to close the picker on ESC instead of going to normal mode,
							-- add the following keymap to your config
							-- ["<Esc>"] = { "close", mode = { "n", "i" } },
							["/"] = "toggle_focus",
							["<C-Down>"] = { "history_forward", mode = { "i", "n" } },
							["<C-Up>"] = { "history_back", mode = { "i", "n" } },
							["<C-c>"] = { "cancel", mode = "i" },
							["<C-w>"] = { "<c-s-w>", mode = { "i" }, expr = true, desc = "delete word" },
							["<CR>"] = { "confirm", mode = { "n", "i" } },
							["<Tab>"] = { "list_down", mode = { "i", "n" } },
							["<Esc>"] = "cancel",
							["<S-CR>"] = { { "pick_win", "jump" }, mode = { "n", "i" } },
							["<C-p>"] = { "select_and_prev", mode = { "i", "n" } },
							["<C-n>"] = { "select_and_next", mode = { "i", "n" } },
							["<C-t>"] = { "select_and_next", mode = { "i", "n" } },
							["<S-Tab>"] = { "list_up", mode = { "i", "n" } },
							["<a-d>"] = { "inspect", mode = { "n", "i" } },
							["<a-f>"] = { "toggle_follow", mode = { "i", "n" } },
							["<a-h>"] = { "toggle_hidden", mode = { "i", "n" } },
							["<a-i>"] = { "toggle_ignored", mode = { "i", "n" } },
							["<a-r>"] = { "toggle_regex", mode = { "i", "n" } },
							["<a-m>"] = { "toggle_maximize", mode = { "i", "n" } },
							["<a-p>"] = { "toggle_preview", mode = { "i", "n" } },
							["<a-w>"] = { "cycle_win", mode = { "i", "n" } },
							["<c-a>"] = { "select_all", mode = { "n", "i" } },
							["<a-k>"] = { "preview_scroll_up", mode = { "i", "n" } },
							["<c-d>"] = { "list_scroll_down", mode = { "i", "n" } },
							["<a-j>"] = { "preview_scroll_down", mode = { "i", "n" } },
							["<c-g>"] = { "toggle_live", mode = { "i", "n" } },
							["<c-j>"] = { "list_down", mode = { "i", "n" } },
							["<c-k>"] = { "list_up", mode = { "i", "n" } },
							-- ["<c-n>"] = { "list_down", mode = { "i", "n" } },
							-- ["<c-p>"] = { "list_up", mode = { "i", "n" } },
							["<c-q>"] = { "qflist", mode = { "i", "n" } },
							["<c-s>"] = { "edit_split", mode = { "i", "n" } },
							-- ["<c-t>"] = { "tab", mode = { "n", "i" } },
							["<c-u>"] = { "list_scroll_up", mode = { "i", "n" } },
							["<c-v>"] = { "edit_vsplit", mode = { "i", "n" } },
							["<c-r>#"] = { "insert_alt", mode = "i" },
							["<c-r>%"] = { "insert_filename", mode = "i" },
							["<c-r><c-a>"] = { "insert_cWORD", mode = "i" },
							["<c-r><c-f>"] = { "insert_file", mode = "i" },
							["<c-r><c-l>"] = { "insert_line", mode = "i" },
							["<c-r><c-p>"] = { "insert_file_full", mode = "i" },
							["<c-r><c-w>"] = { "insert_cword", mode = "i" },
							["<c-w>H"] = "layout_left",
							["<c-w>J"] = "layout_bottom",
							["<c-w>K"] = "layout_top",
							["<c-w>L"] = "layout_right",
							["?"] = "toggle_help_input",
							["G"] = "list_bottom",
							["gg"] = "list_top",
							["j"] = "list_down",
							["k"] = "list_up",
							["q"] = "cancel",
							["<a-a>"] = { "sidekick_send", mode = { "n", "i" }, },
						},
					},
				},
			},
		},
		keys = {
			{
				'<M-i>',
				function()
					require('snacks.image.placement').clean()
					local buf = vim.api.nvim_get_current_buf()
					local name = vim.api.nvim_buf_get_name(buf):lower()
					local ft = vim.bo[buf].filetype
					if name:match('%.[pj][np]e?g$') or name:match('%.gif$')
						or name:match('%.webp$') or name:match('%.bmp$')
						or name:match('%.avif$') or name:match('%.tiff?$') then
						require('snacks.image.buf').attach(buf)
					elseif ft == 'markdown' or ft == 'norg' or ft == 'html'
						or ft == 'css' or ft == 'typst' then
						require('snacks.image.doc').attach(buf)
					end
				end,
				mode = { 'n', 'i', 't' },
				desc = 'Image: refresh placements (clear stuck + re-attach current buffer)',
			},
			{ "<leader>fl", function() require("lars.snacks-submodule").open("git_log") end,      desc = "Git Log (submodule-aware)" },
			{ "<leader>fi", function()
				-- Show the remaining steps of an in-progress rebase (action + commit
				-- + git show preview). <leader>fl still shows the full log.
				require("lars.snacks-rebase").open_todo()
			end, desc = "Rebase TODO (in-progress steps)" },
			{ "<leader>fb", function() require("lars.snacks-submodule").open("git_branches") end, desc = "Git Log (submodule-aware)" },
			{ "<leader>fS", function() require("lars.snacks-submodule").open("git_status") end, desc = "Git Status (submodule-aware)" },
			{ "<leader>fc", function() Snacks.picker.git_log_file() end,                          desc = "Git Log (submodule-aware)" },
			{ "<leader>fB", function() Snacks.gitbrowse() end,                                    desc = "Git Browse",               mode = { "n", "v" } },
			{ "<leader>fh", function() Snacks.picker.help() end,                                  desc = "Help Pages" },
			{ "<leader>fk", function() Snacks.picker.keymaps() end,                               desc = "Keymaps" },
			{ "<leader>fr", function() Snacks.picker.resume() end,                                desc = "Resume" },
			{ "<leader>fq", function() Snacks.picker.qflist() end,                                desc = "Quickfix List" },
			{ "<leader>fp", function() Snacks.picker.projects() end,                              desc = "Projects" },
			{ "<leader>fd", function() Snacks.picker.diagnostics() end,                           desc = "Diagnostics" },
			{ "<leader>fu", function() Snacks.picker.buffers() end,                               desc = "Diagnostics" },
		},
	},
}
