return {
	{
		-- make fuzzy finder fast
		'nvim-telescope/telescope-fzf-native.nvim',
		build = 'make',
		lazy = true
	},
	{
		'nvim-telescope/telescope.nvim',
		tag = '0.1.2',
		dependencies = { 'nvim-lua/plenary.nvim', 'nvim-telescope/telescope-fzf-native.nvim' },
		opts = {
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
			},
			pickers = {
				find_files = {
					find_command = { "rg", "--files", "--hidden", "--glob", "!**/.git/*", "--no-ignore", },
					-- find_command = {
					-- 	"rg",
					-- 	"--files",
					-- 	"--glob",
					-- },
				}
			}
		},
		keys = {
			{ '<leader>ff', function () require('telescope.builtin').find_files() end, desc='telescope fuzzy find files' },
			{ '<c-p>', function () require('telescope.builtin').git_files() end, desc='telescope fuzzy find git files'},
			{ '<leader>fg', function () require('telescope.builtin').live_grep() end, desc='telescope fuzzy find string'},
			{ '<leader>fs', function () require('telescope.builtin').grep_string() end, desc='telescope find string under cursor'},
			{ '<leader>fu', function () require('telescope.builtin').buffers() end, desc='telescope fuzzy find buffer'},
			{ '<leader>fh', function () require('telescope.builtin').help_tags() end, desc='telescope fuzzy help search'},
			{ '<leader>fr', function () require('telescope.builtin').resume() end, desc='telescope repeat last search'},
			{ '<leader>fl', function () require('telescope.builtin').git_commits() end, desc='teslescope fuzzy find git commits'},
			{ '<leader>fc', function () require('telescope.builtin').git_bcommits() end, desc='telescope fuzzy find branch commits'},
			{ '<leader>fb', function () require('telescope.builtin').git_branches() end, desc='telescope fuzzy find branch'},
		}
	}, -- fuzzy finder :)
}
