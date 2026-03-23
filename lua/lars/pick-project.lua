-- Telescope picker: recent git projects extracted from oldfiles.
-- Selecting a project changes cwd and opens the most recent file from that project.

local function get_git_root(path)
	local dir = vim.fn.fnamemodify(path, ':p:h')
	local git_dir = vim.fn.finddir('.git', dir .. ';')
	if git_dir ~= '' then
		return vim.fn.fnamemodify(git_dir, ':p:h:h')
	end
	return nil
end

local function pick_project()
	local actions      = require('telescope.actions')
	local action_state = require('telescope.actions.state')
	local pickers      = require('telescope.pickers')
	local finders      = require('telescope.finders')
	local sorters      = require('telescope.sorters')

	-- Collect unique git roots from oldfiles, preserving recency order
	local seen = {}
	local projects = {}
	for _, file in ipairs(vim.v.oldfiles) do
		local root = get_git_root(file)
		if root then
			local norm = vim.fn.resolve(root)
			if not seen[norm] then
				seen[norm] = file  -- remember most recent file for this project
				table.insert(projects, { root = norm, recent_file = file })
			end
		end
	end

	pickers.new({}, {
		prompt_title = 'Recent Projects',
		finder = finders.new_table({
			results = projects,
			entry_maker = function(entry)
				local short = vim.fn.fnamemodify(entry.root, ':~')
				return {
					value   = entry,
					display = short,
					ordinal = short,
				}
			end,
		}),
		sorter = sorters.get_generic_fuzzy_sorter(),
		attach_mappings = function(prompt_bufnr)
			actions.select_default:replace(function()
				local sel = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				if sel then
					local project = sel.value
					vim.cmd('cd ' .. vim.fn.fnameescape(project.root))
					vim.cmd('edit ' .. vim.fn.fnameescape(project.recent_file))
				end
			end)
			return true
		end,
	}):find()
end

return pick_project
