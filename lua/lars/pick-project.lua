-- Telescope picker: recent git projects extracted from oldfiles.
-- Selecting a project changes cwd and opens the most recent file from that project.

local M = {}

local function get_git_root(path)
	local dir = vim.fn.fnamemodify(path, ':p:h')
	local git_dir = vim.fn.finddir('.git', dir .. ';')
	if git_dir ~= '' then
		return vim.fn.fnamemodify(git_dir, ':p:h:h')
	end
	return nil
end

-- v:oldfiles can contain non-file buffer names — terminal URIs like
-- `term://...` (e.g. claude-code.nvim's terminal), fugitive:// objects,
-- or stale paths to files that have since been deleted. `:edit`-ing those
-- either errors out or reopens something unexpected (like a Claude
-- terminal), so we keep only regular, readable files on disk.
local function is_real_file(path)
	if type(path) ~= 'string' or path == '' then
		return false
	end
	-- Reject any URI-style scheme (term://, fugitive://, oil://, etc.)
	if path:find('://', 1, true) then
		return false
	end
	return vim.fn.filereadable(path) == 1
end

-- Collect unique git-root projects from an oldfiles list, preserving the
-- recency order of the input. Exposed for unit tests.
function M.collect_projects(oldfiles)
	local seen = {}
	local projects = {}
	for _, file in ipairs(oldfiles or {}) do
		if is_real_file(file) then
			local root = get_git_root(file)
			if root then
				local norm = vim.fn.resolve(root)
				if not seen[norm] then
					seen[norm] = file -- remember most recent file for this project
					table.insert(projects, { root = norm, recent_file = file })
				end
			end
		end
	end
	return projects
end

function M.pick()
	local actions      = require('telescope.actions')
	local action_state = require('telescope.actions.state')
	local pickers      = require('telescope.pickers')
	local finders      = require('telescope.finders')
	local sorters      = require('telescope.sorters')

	local projects = M.collect_projects(vim.v.oldfiles)

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

-- Allow `require('lars.pick-project')()` to keep working as a shortcut.
return setmetatable(M, { __call = function(_, ...) return M.pick(...) end })
