-- Snacks-based cherry-pick picker (was telescope).
--   <leader>gp  pick a branch, then a commit on it, then cherry-pick it
--
-- In a repo with submodules the picker opens scoped to the submodule of
-- the current buffer and can be re-scoped without leaving the flow:
--   <C-s>  cycle to next submodule
--   <C-a>  cycle to previous submodule
--   <C-g>  pick a submodule from a list
-- All git work runs in the active scope's cwd.

-- Forward decl: the submodule switcher reopens the branch picker.
local cherry_pick_in

--- Run a git command in `cwd` and return its stdout lines (empty on error).
---@param cwd string
---@param args string[]
---@return string[]
local function git_lines(cwd, args)
	local cmd = { "git", "-C", cwd }
	vim.list_extend(cmd, args)
	local out = vim.fn.systemlist(cmd)
	if vim.v.shell_error ~= 0 then
		return {}
	end
	return out
end

--- Cherry-pick `hash` in `cwd`, reporting success/failure.
---@param cwd string
---@param hash string
local function cherry_pick_commit(cwd, hash)
	local result = vim.fn.system({ "git", "-C", cwd, "cherry-pick", hash })
	if vim.v.shell_error == 0 then
		vim.notify(
			"Cherry-picked " .. hash .. " successfully",
			vim.log.levels.INFO)
	else
		vim.notify(
			"Cherry-pick failed:\n" .. result,
			vim.log.levels.ERROR)
	end
end

--- Step 2: pick a commit from `branch` (in `cwd`) and cherry-pick it.
---@param cwd string
---@param branch string
---@param title string
local function open_commit_picker(cwd, branch, title)
	local log = git_lines(cwd, {
		"log", branch, "--pretty=format:%h %an: %s", "-n", "100",
	})
	local items = {}
	for i, line in ipairs(log) do
		table.insert(items, {
			idx = i,
			text = line,
			line = line,
			hash = line:match("^(%S+)"),
		})
	end

	Snacks.picker.pick({
		title = title,
		items = items,
		format = function(item)
			return { { item.line } }
		end,
		confirm = function(picker, item)
			picker:close()
			if not (item and item.hash) then
				vim.notify("Could not parse commit hash", vim.log.levels.ERROR)
				return
			end
			cherry_pick_commit(cwd, item.hash)
		end,
	})
end

-- Step 1: pick a branch in `cwd`. `submodules`/`sm_idx` enable the
-- submodule switcher; pass nil/nil when not in a submodule-bearing repo.
cherry_pick_in = function(cwd, git_root, submodules, sm_idx)
	local sub = require("lars.snacks-submodule")
	local has_subs = submodules and #submodules > 1

	local sm_label = ""
	if has_subs then
		local sm = submodules[sm_idx]
		sm_label = sm == "." and "(root)" or sm
	end

	local branches = git_lines(cwd, {
		"branch", "--all", "--format=%(refname:short)",
	})
	local items = {}
	for i, b in ipairs(branches) do
		table.insert(items, { idx = i, text = b, branch = b })
	end

	local title = "Cherry-pick: select branch"
	if has_subs then
		title = string.format("Cherry-pick: select branch [%s]", sm_label)
	end

	-- Reopen the branch picker scoped to submodule index `idx`.
	local function reopen(idx)
		cherry_pick_in(
			sub.submodule_cwd(git_root, submodules[idx]),
			git_root, submodules, idx)
	end

	local opts = {
		title = title,
		items = items,
		format = function(item)
			return { { item.branch } }
		end,
		confirm = function(picker, item)
			picker:close()
			if not item then return end
			local commit_title = "Cherry-pick from: " .. item.branch
			if has_subs then
				commit_title = string.format(
					"Cherry-pick from: %s [%s]", item.branch, sm_label)
			end
			open_commit_picker(cwd, item.branch, commit_title)
		end,
	}

	if has_subs then
		local n = #submodules
		opts.actions = {
			cherry_sub_next = function(picker)
				picker:close()
				vim.schedule(function() reopen((sm_idx % n) + 1) end)
			end,
			cherry_sub_prev = function(picker)
				picker:close()
				vim.schedule(function() reopen(((sm_idx - 2) % n) + 1) end)
			end,
			cherry_sub_pick = function(picker)
				picker:close()
				vim.schedule(function()
					local entries = {}
					for i, sm in ipairs(submodules) do
						local label = sm == "." and "(root)" or sm
						if i == sm_idx then label = label .. " (current)" end
						table.insert(entries, { sm = sm, idx = i, label = label })
					end
					vim.ui.select(entries, {
						prompt = "Select submodule",
						format_item = function(e) return e.label end,
					}, function(choice)
						if choice then reopen(choice.idx) end
					end)
				end)
			end,
		}
		opts.win = {
			input = {
				keys = {
					["<c-s>"] = { "cherry_sub_next", mode = { "n", "i" }, desc = "Submodule: next" },
					["<c-a>"] = { "cherry_sub_prev", mode = { "n", "i" }, desc = "Submodule: previous" },
					["<c-g>"] = { "cherry_sub_pick", mode = { "n", "i" }, desc = "Submodule: pick" },
				},
			},
		}
	end

	Snacks.picker.pick(opts)
end

return {
	{
		-- Keys live on the always-loaded snacks spec (telescope is gone);
		-- the picker itself is built with Snacks.picker.
		"folke/snacks.nvim",
		keys = {
			{
				"<leader>gp",
				function()
					if not (Snacks and Snacks.picker) then
						vim.notify("snacks picker not available", vim.log.levels.ERROR)
						return
					end
					local gc = require("lars.git-cache")
					local sub = require("lars.snacks-submodule")
					local cwd = vim.fn.getcwd()

					local git_root = gc.git_toplevel(cwd)
					if not git_root then
						cherry_pick_in(cwd, nil, nil, nil)
						return
					end

					local submodules = gc.get_submodules(git_root)
					if #submodules <= 1 then
						cherry_pick_in(git_root, nil, nil, nil)
						return
					end

					local current_sm = sub.current_submodule(git_root, submodules)
					local sm_idx = 1
					for i, sm in ipairs(submodules) do
						if sm == current_sm then sm_idx = i; break end
					end
					cherry_pick_in(
						sub.submodule_cwd(git_root, current_sm),
						git_root, submodules, sm_idx)
				end,
				desc = "Git cherry-pick from branch",
			},
		},
	},
}
