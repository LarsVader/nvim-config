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
					git_rebase_interactive = function(picker, item)
						if not (item and item.commit) then
							return Snacks.notify.warn("No commit under cursor", { title = "Git Rebase" })
						end
						local commit, cwd = item.commit, item.cwd or picker:cwd()
						picker:close()
						-- Interactive rebase needs an editor for the todo list, so delegate
						-- to Fugitive (loaded on :G), which wires GIT_SEQUENCE_EDITOR back
						-- into nvim. Fugitive resolves the repo from the *current buffer*,
						-- not the window cwd -- so an lcd is ignored when the log was scoped
						-- to a submodule via the <c-g> switcher. Open the rebase in a fresh
						-- tab whose [No Name] buffer pins no repo, with tcd set to the
						-- picker's cwd, so Fugitive resolves the repo from that cwd.
						-- <commit>^ makes the selected commit itself editable; the root
						-- commit has no parent, so fall back to --root (rebase from the start).
						vim.schedule(function()
							local has_parent = vim.system(
								{ "git", "-C", cwd, "rev-parse", "--verify", "--quiet", commit .. "^" }
							):wait().code == 0
							local range = has_parent and ("-i " .. commit .. "^") or "-i --root"
							vim.cmd("tabnew")
							vim.cmd("tcd " .. vim.fn.fnameescape(cwd))
							local ok, err = pcall(vim.cmd, "G rebase " .. range)
							if not ok then
								vim.cmd("silent! tabclose")
								Snacks.notify.error("Interactive rebase failed: " .. tostring(err),
									{ title = "Git Rebase" })
							end
						end)
					end,
				},
				sources = {
					-- Rebase keys live only in the commit-log picker. <c-r> is a prefix
					-- (the second key disambiguates), so it neither fires a bare-<c-r>
					-- timeout nor clashes with the global <c-r><c-w>/<c-r>% register
					-- inserts, and <c-r>i avoids the <c-i>==<Tab> terminal collision.
					git_log = {
						win = {
							input = {
								keys = {
									["<c-r>r"] = { "git_rebase", mode = { "n", "i" }, desc = "Rebase branch onto commit" },
									["<c-r>i"] = { "git_rebase_interactive", mode = { "n", "i" }, desc = "Interactive rebase from commit" },
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
			{ "<leader>fb", function() require("lars.snacks-submodule").open("git_branches") end, desc = "Git Log (submodule-aware)" },
			{ "<leader>fs", function() require("lars.snacks-submodule").open("git_status") end, desc = "Git Status (submodule-aware)" },
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
