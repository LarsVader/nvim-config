return {
	{
		-- make fuzzy finder fast
		'nvim-telescope/telescope-fzf-native.nvim',
		build = 'make',
		lazy = true
	},
	{
		'nvim-telescope/telescope.nvim',
		dependencies = { 'nvim-lua/plenary.nvim', 'nvim-telescope/telescope-fzf-native.nvim' },
		opts = function()
			local actions = require("telescope.actions")
			return {
			extensions = {
				fzf = {
					fuzzy = true,                    -- false will only do exact matching
					override_generic_sorter = true,  -- override the generic sorter
					override_file_sorter = true,     -- override the file sorter
					case_mode = "smart_case",        -- or "ignore_case" or "respect_case"
					-- the default case_mode is "smart_case"
				}
			},
			defaults = {
				file_ignore_patterns = { "tags", },
				mappings = {
					i = {
						["<Tab>"] = actions.move_selection_previous,
						["<S-Tab>"] = actions.move_selection_next,
					},
					n = {
						["<Tab>"] = actions.move_selection_previous,
						["<S-Tab>"] = actions.move_selection_next,
					},
				},
			},
			pickers = {
				find_files = {
					find_command = { "rg", "--files", "--hidden", "--glob", "!**/.git/*", "--no-ignore", },
					-- find_command = {
					-- 	"rg",
					-- 	"--files",
					-- 	"--glob",
					-- },
				},
				git_status = {
					mappings = {
						i = {
							["<Tab>"] = actions.move_selection_previous,
							["<S-Tab>"] = actions.move_selection_next,
						},
						n = {
							["<Tab>"] = actions.move_selection_previous,
							["<S-Tab>"] = actions.move_selection_next,
						},
					},
				},
			}
		}
		end,
		keys = {
			{ '<leader>ff', function () require('telescope.builtin').find_files() end, desc='telescope fuzzy find files' },
			{ '<c-p>', function () require('lars.telescope-submodule').wrap_git_picker('git_files', {
				git_command = { "git", "ls-files", "--exclude-standard", "--cached", "--recurse-submodules" },
			})() end, desc='telescope fuzzy find git files'},
			{ '<leader>fg', function () require('lars.telescope-submodule').wrap_git_picker('live_grep')() end, desc='telescope fuzzy find string'},
			{ '<leader>fs', function () require('lars.telescope-submodule').wrap_git_picker('grep_string')() end, desc='telescope find string under cursor'},
			{ '<leader>fu', function () require('telescope.builtin').buffers() end, desc='telescope fuzzy find buffer'},
			{ '<leader>fh', function () require('telescope.builtin').help_tags() end, desc='telescope fuzzy help search'},
			{ '<leader>fr', function () require('telescope.builtin').resume() end, desc='telescope repeat last search'},
			{ '<leader>fl', function () require('lars.telescope-submodule').wrap_git_picker('git_commits')() end, desc='telescope fuzzy find git commits'},
			{ '<leader>fc', function () require('lars.telescope-submodule').wrap_git_picker('git_bcommits')() end, desc='telescope fuzzy find branch commits'},
			{ '<leader>fb', function () require('lars.telescope-submodule').wrap_git_picker('git_branches')() end, desc='telescope fuzzy find branch'},
			{ '<leader>fS', function () require('lars.telescope-submodule').wrap_git_picker('git_status', {
				previewer = require('lars.git-status-previewer')(),
			})() end, desc='telescope git status'},
		{ '<leader>fk', function()
			local actions     = require('telescope.actions')
			local action_state = require('telescope.actions.state')
			local pickers     = require('telescope.pickers')
			local finders     = require('telescope.finders')
			local keymaps = {}
			-- Show submodule picker shortcuts only when a submodule-aware picker is active
			local tsm = require('lars.telescope-submodule')
			if tsm._picker_active then
				vim.list_extend(keymaps, {
					{ mode = 'i', lhs = '<C-s>', desc = '[picker] Submodule: cycle to next' },
					{ mode = 'i', lhs = '<C-a>', desc = '[picker] Submodule: cycle to previous' },
					{ mode = 'i', lhs = '<C-g>', desc = '[picker] Submodule: pick from list' },
				})
				if tsm._state.picker_name == 'git_status' then
					vim.list_extend(keymaps, {
						{ mode = 'i', lhs = '<C-t>', desc = '[picker] Git: toggle stage/unstage' },
					})
				end
				if tsm._state.picker_name == 'git_commits' then
					vim.list_extend(keymaps, {
						{ mode = 'i', lhs = '<C-r>', desc = '[picker] Git: interactive rebase from commit' },
					})
				end
			end
			for _, mode in ipairs({ 'n', 'v', 'i', 'x', 'o', 't' }) do
				-- Buffer-local keymaps first (marked with [buf])
				for _, km in ipairs(vim.api.nvim_buf_get_keymap(0, mode)) do
					local desc = km.desc or ''
					local rhs  = type(km.rhs) == 'string' and km.rhs or ''
					if desc ~= '' or rhs ~= '' then
						table.insert(keymaps, {
							mode    = mode,
							lhs     = km.lhs or '',
							desc    = '[buf] ' .. (desc ~= '' and desc or rhs),
						})
					end
				end
				-- Global keymaps
				for _, km in ipairs(vim.api.nvim_get_keymap(mode)) do
					local desc = km.desc or ''
					local rhs  = type(km.rhs) == 'string' and km.rhs or ''
					if desc ~= '' or rhs ~= '' then
						table.insert(keymaps, {
							mode    = mode,
							lhs     = km.lhs or '',
							desc    = desc ~= '' and desc or rhs,
						})
					end
				end
			end

			pickers.new({}, {
				prompt_title = "Keymaps",
				finder = finders.new_table({
					results = keymaps,
					entry_maker = function(km)
						return {
							value   = km,
							display = string.format("%-2s  %-22s  %s", km.mode, km.lhs, km.desc),
							ordinal = km.mode .. ' ' .. km.lhs .. ' ' .. km.desc,
						}
					end,
				}),
				sorter = require('telescope.sorters').Sorter:new({
					scoring_function = function(_, prompt, line)
						if not prompt or prompt == '' then return 1 end
						return string.find(string.lower(line), string.lower(prompt), 1, true) and 1 or -1
					end,
				}),
				attach_mappings = function(prompt_bufnr)
					actions.select_default:replace(function()
						local sel = action_state.get_selected_entry()
						actions.close(prompt_bufnr)
						if sel then
							vim.schedule(function()
								local keys = vim.api.nvim_replace_termcodes(sel.value.lhs, true, false, true)
								vim.api.nvim_feedkeys(keys, 'm', false)
							end)
						end
					end)
					return true
				end,
			}):find()
		end, desc = "Search keymaps" },
		}
	}, -- fuzzy finder :)
}
