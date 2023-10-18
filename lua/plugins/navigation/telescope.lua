function SplitFilename(strFilename)
  -- Returns the Path, Filename, and Extension as 3 values
  return string.match(strFilename, "(.-)([^\\]-([^\\%.]+))$")
end

return {
	{
		-- make fuzzy finder fast
		'nvim-telescope/telescope-fzf-native.nvim',
		build = 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build',
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
				file_ignore_patterns = { "tags", "Jenkins*", "_customer", ".*bat", "DentalDB", ".vs", ".*pdb", ".*lib", ".*dll", "_intermediate", "WorkParamsDB", },
				path_display = function(opts, path)
						local spath,file,extension = SplitFilename(path)
						spath = string.gsub(spath, 'DentalProcessorControls', 'DPC')
						spath = string.gsub(spath, 'DentalProcessors', 'DP')
						spath = string.gsub(spath, 'DentalConstruction', 'DC')
						spath = string.gsub(spath, 'DentalCAD', 'DC')
						spath = string.gsub(spath, 'DentalBase', 'DB')
						return string.format("%s (%s)", file, spath)
					end,
				layout_config = { 
					height = 0.95,
					width = 0.95,
					preview_width = 0.5,
				},
			},
			pickers = {
				find_files = {
					find_command = { "rg", "--files", "--hidden", "--glob", "!**/.git/*", "--no-ignore", },
				},
				git_files = {
					recurse_submodules = true,
				},
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
			{
				'<leader>fb',
				function ()
					local selection = vim.fn.input("select submodule\n 1: dentalcaddevelopment\n 2: dentalconfig\n 3: dentalbase \n dentalcad otherwise\n")
					if selection == '1' then
						require('telescope.builtin').git_branches()
					elseif selection == '2' then
						require('telescope.builtin').git_branches({cwd = "./dentalcad/dentalconfig/"})
					elseif selection == '3' then
						require('telescope.builtin').git_branches({cwd = "./dentalbase/"})
					else
						require('telescope.builtin').git_branches({cwd = "./dentalcad"})
					end
				end , desc='telescope fuzzy find branch'
			},
			{
				'<leader>fz',
				function ()
					local selection = vim.fn.input("select submodule\n 1: dentalcaddevelopment\n 2: dentalconfig\n 3: dentalbase \n dentalcad otherwise\n")
					if selection == '1' then
						require('telescope.builtin').git_stash()
					elseif selection == '2' then
						require('telescope.builtin').git_stash({cwd = "./dentalcad/dentalconfig/"})
					elseif selection == '3' then
						require('telescope.builtin').git_stash({cwd = "./dentalbase/"})
					else
						require('telescope.builtin').git_stash({cwd = "./dentalcad"})
					end
				end , desc='telescope fuzzy find branch'
			},
		}
	}, -- fuzzy finder :)
}
