-- Telescope-based picker for CLR exception breakpoints.
--
-- Lists curated BCL exception types plus project-local
-- types discovered via async ripgrep (`class \w+Exception`).
-- Multi-select with <C-t>; <CR> commits all marked picks.
-- Two sentinels appear at the top:
--   '+ Add custom type...' — prompt for a name not in lists
--   '× Clear all stored'   — wipe the stored selection
--
-- Items currently in the stored selection are marked with
-- `[*]` in the display so the user can see what's already
-- active. Commit semantics are REPLACE: whatever is marked
-- becomes the new stored state. To extend, mark all desired
-- items including currently-stored ones.
--
-- Discovery is asynchronous (vim.system + ripgrep) and the
-- result is cached in-memory per cwd. <C-r> inside the picker
-- forces a re-scan and reopens the picker.
--
-- The picker only collects type names; persisting and
-- submitting to the live DAP session is the caller's job.

local M = {}

-- Discovery cache: { [cwd] = { types = { 'A.B', ... }, t = os.time() } }
local cache = {}

local function extract_from_file(file)
	local names = {}
	local fh = io.open(file, "r")
	if not fh then
		return names
	end
	local ns = nil
	for line in fh:lines() do
		local got_ns = line:match("^%s*namespace%s+([%w%.]+)")
		if got_ns then
			ns = got_ns
		end
		local got_class =
			line:match("class%s+(%w+Exception)%f[%W]")
		if got_class then
			table.insert(
				names,
				ns and (ns .. "." .. got_class) or got_class
			)
		end
	end
	fh:close()
	return names
end

local function discover(cwd, callback)
	if vim.fn.executable("rg") ~= 1 then
		vim.schedule(function()
			vim.notify(
				"ripgrep not on PATH — "
					.. "skipping project exception discovery",
				vim.log.levels.WARN
			)
			callback({})
		end)
		return
	end
	vim.system({
		"rg",
		"--type", "cs",
		"--files-with-matches",
		"class\\s+\\w+Exception\\b",
		cwd,
	}, { text = true }, function(obj)
		if obj.code ~= 0 and obj.code ~= 1 then
			vim.schedule(function()
				vim.notify(
					"rg failed: "
						.. (obj.stderr or "")
						.. " (exit "
						.. tostring(obj.code)
						.. ")",
					vim.log.levels.WARN
				)
				callback({})
			end)
			return
		end
		local seen, out = {}, {}
		for file in (obj.stdout or ""):gmatch("[^\r\n]+") do
			for _, t in ipairs(extract_from_file(file)) do
				if not seen[t] then
					seen[t] = true
					table.insert(out, t)
				end
			end
		end
		table.sort(out)
		cache[cwd] = { types = out, t = os.time() }
		vim.schedule(function() callback(out) end)
	end)
end

-- Build the merged items list: sentinels first, then project-
-- discovered names, then the curated BCL list. Items whose
-- value is in currently_set are marked with `[*]`.
local function build_items(curated, custom, currently_set)
	local set_lookup = {}
	for _, t in ipairs(currently_set or {}) do
		set_lookup[t] = true
	end
	local function mark(t)
		return set_lookup[t] and "[*] " or "[ ] "
	end

	local items = {
		{
			value = "__custom__",
			display = "    + Add custom type...",
		},
		{
			value = "__clear__",
			display = "    × Clear all stored",
		},
	}
	local seen = { __custom__ = true, __clear__ = true }

	for _, t in ipairs(custom) do
		if not seen[t] then
			seen[t] = true
			table.insert(items, {
				value = t,
				display = mark(t) .. t .. "  (project)",
			})
		end
	end
	for _, t in ipairs(curated) do
		if not seen[t] then
			seen[t] = true
			table.insert(items, {
				value = t,
				display = mark(t) .. t,
			})
		end
	end
	return items
end

-- Forward decl so refresh can call back into open().
local open

-- Open a telescope picker over the merged items. on_pick is
-- called with:
--   * a non-empty array of fully-qualified type strings
--     (REPLACE the stored state with these), or
--   * an empty array (CLEAR the stored state).
-- It is NOT called when the user cancels (esc, no marks).
local function open_picker(curated, custom, currently_set, on_pick)
	local ok_t, pickers = pcall(require, "telescope.pickers")
	if not ok_t then
		vim.notify(
			"telescope not available — "
				.. "falling back to single free-text input",
			vim.log.levels.WARN
		)
		local t = vim.fn.input(
			"CLR exception type: ", "System.")
		if t and t ~= "" then on_pick({ t }) end
		return
	end
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")

	local items = build_items(curated, custom, currently_set)

	pickers.new({}, {
		prompt_title =
			"CLR Exception breakpoints — [*] = currently "
				.. "stored. <C-t> mark, <CR> REPLACE with "
				.. "marks, <C-r> rescan",
		finder = finders.new_table({
			results = items,
			entry_maker = function(it)
				return {
					value = it.value,
					display = it.display,
					ordinal = it.display,
				}
			end,
		}),
		sorter = conf.generic_sorter({}),
		attach_mappings = function(prompt_bufnr, map)
			actions.select_default:replace(function()
				local picker =
					action_state.get_current_picker(prompt_bufnr)
				local sels = picker:get_multi_selection()
				local values = {}
				if #sels > 0 then
					for _, s in ipairs(sels) do
						table.insert(values, s.value)
					end
				else
					local entry =
						action_state.get_selected_entry()
					if entry then
						table.insert(values, entry.value)
					end
				end
				actions.close(prompt_bufnr)
				if #values == 0 then return end
				-- Clear sentinel wins if anywhere in picks.
				for _, v in ipairs(values) do
					if v == "__clear__" then
						on_pick({})
						return
					end
				end
				-- Resolve Add-custom sentinel.
				local final = {}
				for _, v in ipairs(values) do
					if v == "__custom__" then
						local t = vim.fn.input(
							"Custom CLR exception type: ",
							"System."
						)
						if t and t ~= "" then
							table.insert(final, t)
						end
					else
						table.insert(final, v)
					end
				end
				if #final > 0 then on_pick(final) end
			end)
			-- <C-r>: force re-scan and reopen.
			local refresh = function()
				actions.close(prompt_bufnr)
				local cwd = vim.fn.getcwd()
				vim.notify(
					"Rescanning project for "
						.. "exception types...",
					vim.log.levels.INFO
				)
				cache[cwd] = nil
				discover(cwd, function(_)
					open(currently_set, on_pick)
				end)
			end
			map("i", "<C-r>", refresh)
			map("n", "<C-r>", refresh)
			return true
		end,
	}):find()
end

-- Public entry point. currently_set is the array of type
-- names currently stored (used for `[*]` markings); on_pick
-- is the callback invoked on commit.
function M.open(currently_set, on_pick)
	local curated = require("lars.clr_exceptions")
	local cwd = vim.fn.getcwd()
	local entry = cache[cwd]
	if entry then
		open_picker(
			curated, entry.types, currently_set, on_pick)
		return
	end
	vim.notify(
		"Scanning project for exception types...",
		vim.log.levels.INFO
	)
	discover(cwd, function(types)
		open_picker(curated, types, currently_set, on_pick)
	end)
end

open = M.open

function M._reset_cache()
	cache = {}
end

M._extract_from_file = extract_from_file
M._build_items = build_items

return M
