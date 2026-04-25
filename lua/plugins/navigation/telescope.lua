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
						["<C-t>"] = actions.toggle_selection + actions.move_selection_worse,
					},
					n = {
						["<Tab>"] = actions.move_selection_previous,
						["<S-Tab>"] = actions.move_selection_next,
						["<C-t>"] = actions.toggle_selection + actions.move_selection_worse,
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
			-- Human-readable descriptions for Neovim built-in keymaps
			local desc_overrides = {
				-- Insert mode
				['i <C-S>']  = 'LSP signature help',
				['i <C-U>']  = 'Delete to start of line',
				['i <C-W>']  = 'Delete word before cursor',
				-- Normal mode: LSP
				['n gO']     = 'LSP document symbols',
				['n gra']    = 'LSP code action',
				['n gri']    = 'LSP go to implementation',
				['n grn']    = 'LSP rename symbol',
				['n grr']    = 'LSP find references',
				['n grt']    = 'LSP go to type definition',
				['n grx']    = 'LSP run code lens',
				-- Normal mode: misc defaults
				['n &']      = 'Repeat last :s substitute',
				['n Y']      = 'Yank to end of line',
				-- Normal mode: unimpaired-style bracket navigation
				['n [<C-L>'] = 'Previous location file',
				['n ]<C-L>'] = 'Next location file',
				['n [<C-Q>'] = 'Previous quickfix file',
				['n ]<C-Q>'] = 'Next quickfix file',
				['n [<C-T>'] = 'Previous tag (preview)',
				['n ]<C-T>'] = 'Next tag (preview)',
				['n [A']     = 'First argument',
				['n ]A']     = 'Last argument',
				['n [B']     = 'First buffer',
				['n ]B']     = 'Last buffer',
				['n [L']     = 'First location list item',
				['n ]L']     = 'Last location list item',
				['n [Q']     = 'First quickfix item',
				['n ]Q']     = 'Last quickfix item',
				['n [T']     = 'First tag',
				['n ]T']     = 'Last tag',
				['n [l']     = 'Previous location list item',
				['n ]l']     = 'Next location list item',
				['n [q']     = 'Previous quickfix item',
				['n ]q']     = 'Next quickfix item',
				['n [t']     = 'Previous tag',
				['n ]t']     = 'Next tag',
				-- Visual/select mode
				['v <C-S>']  = 'LSP signature help',
				['v gra']    = 'LSP code action',
				['v #']      = 'Search backward for selection',
				['v *']      = 'Search forward for selection',
				['v @']      = 'Execute macro on selected lines',
				['v Q']      = 'Format selected lines',
				-- Visual mode
				['x gra']    = 'LSP code action',
				['x #']      = 'Search backward for selection',
				['x *']      = 'Search forward for selection',
				['x @']      = 'Execute macro on selected lines',
				['x Q']      = 'Format selected lines',
			}
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
						{ mode = 'i', lhs = '<C-r>i', desc = '[picker] Git: interactive rebase from commit' },
					})
				end
			end
			for _, mode in ipairs({ 'n', 'v', 'i', 'x', 'o', 't' }) do
				-- Buffer-local keymaps first (marked with [buf])
				for _, km in ipairs(vim.api.nvim_buf_get_keymap(0, mode)) do
					local lhs  = km.lhs or ''
					if lhs:find('<Plug>') then goto buf_continue end
					local desc = km.desc or ''
					local rhs  = type(km.rhs) == 'string' and km.rhs or ''
					if desc ~= '' or rhs ~= '' then
						table.insert(keymaps, {
							mode    = mode,
							lhs     = lhs,
							desc    = '[buf] ' .. (desc ~= '' and desc or rhs),
						})
					end
					::buf_continue::
				end
				-- Global keymaps
				for _, km in ipairs(vim.api.nvim_get_keymap(mode)) do
					local lhs  = km.lhs or ''
					if lhs:find('<Plug>') then goto global_continue end
					local desc = km.desc or ''
					local rhs  = type(km.rhs) == 'string' and km.rhs or ''
					if (rhs ~= '' and rhs:find('<Plug>')) then goto global_continue end
					if desc ~= '' or rhs ~= '' then
						local key = mode .. ' ' .. lhs
						table.insert(keymaps, {
							mode    = mode,
							lhs     = lhs,
							desc    = desc_overrides[key] or (desc ~= '' and desc or rhs),
						})
					end
					::global_continue::
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
