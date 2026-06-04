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
