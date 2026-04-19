-- Submodule-aware telescope git pickers
--
-- When the current repo has submodules, git pickers show which submodule
-- they are operating on in the prompt title and offer shortcuts to switch:
--   <C-s>   cycle to next submodule
--   <C-a>   cycle to previous submodule
--   <C-g>   open a submodule picker to jump directly
--
-- The default submodule is determined by the current buffer's path.
-- When there are no submodules, pickers behave normally.

local M = {}

--- Cache: git_root -> { submodule_paths }
local _cache = {}

--- Get the git toplevel for a given path.
--- Returns the path in native OS format (backslashes on Windows) so that
--- telescope can correctly compute relative paths for display.
---@param path string
---@return string|nil absolute path in native format
function M.git_toplevel(path)
    local result = vim.fn.systemlist({ "git", "-C", path, "rev-parse", "--show-toplevel" })
    if vim.v.shell_error == 0 and result[1] then
        return vim.fn.fnamemodify(result[1], ":p"):gsub("[/\\]$", "")
    end
    return nil
end

--- Get ordered list of submodule relative paths for a git root.
--- The root repo itself is always entry "." at index 1.
---@param git_root string
---@return string[]
function M.get_submodules(git_root)
    if _cache[git_root] then return _cache[git_root] end

    local result = vim.fn.systemlist({
        "git", "-C", git_root,
        "submodule", "status", "--recursive",
    })

    local submodules = { "." }
    if vim.v.shell_error == 0 then
        for _, line in ipairs(result) do
            -- Each line looks like: " <hash> <path> (<ref>)" or "+<hash> <path> (<ref>)"
            local sm_path = line:match("^[%s%+%-U]+%x+%s+(%S+)")
            if sm_path and sm_path ~= "" then
                table.insert(submodules, sm_path)
            end
        end
    end

    _cache[git_root] = submodules
    return submodules
end

--- Clear the submodule cache (e.g. after adding/removing submodules).
function M.clear_cache()
    _cache = {}
end

--- Determine which submodule the current buffer belongs to.
---@param git_root string
---@return string submodule relative path, or "." for root
function M.current_submodule(git_root)
    local bufpath = vim.fn.expand("%:p")
    if bufpath == "" then return "." end

    bufpath = vim.fs.normalize(bufpath)
    local root_norm = vim.fs.normalize(git_root)

    local submodules = M.get_submodules(git_root)
    local best_match = "."
    local best_len = 0

    for _, sm in ipairs(submodules) do
        if sm ~= "." then
            local sm_full = root_norm .. "/" .. sm
            if bufpath:sub(1, #sm_full):lower() == sm_full:lower() and #sm > best_len then
                best_match = sm
                best_len = #sm
            end
        end
    end

    return best_match
end

--- Resolve the absolute cwd for a submodule.
---@param git_root string
---@param submodule string
---@return string path in native OS format
function M.submodule_cwd(git_root, submodule)
    if submodule == "." then
        return git_root
    end
    local sep = vim.fn.has("win32") == 1 and "\\" or "/"
    return git_root .. sep .. submodule:gsub("/", sep)
end

--- Readable label for a submodule path.
---@param sm string
---@return string
local function sm_label(sm)
    return sm == "." and "(root)" or sm
end

--- Check whether a submodule has uncommitted changes.
---@param git_root string
---@param sm string submodule relative path ("." for root)
---@return boolean
function M.is_dirty(git_root, sm)
    local cwd = M.submodule_cwd(git_root, sm)
    local result = vim.fn.systemlist({ "git", "-C", cwd, "status", "--porcelain" })
    return vim.v.shell_error == 0 and #result > 0
end

--- Readable label with dirty indicator.
---@param git_root string
---@param sm string
---@return string
local function sm_label_dirty(git_root, sm)
    local label = sm_label(sm)
    if M.is_dirty(git_root, sm) then
        label = label .. " *"
    end
    return label
end

--- Whether a submodule-aware picker is currently active.
M._picker_active = false

--- Persistent state for the currently open picker session.
M._state = {}

--- Floating window for commit message preview (tracked for cleanup).
local commit_msg_float_win = nil
local commit_msg_timer = nil

--- Close the commit message float and poll timer if open.
local function close_commit_msg_float()
	if commit_msg_timer then
		commit_msg_timer:stop()
		commit_msg_timer:close()
		commit_msg_timer = nil
	end
	if commit_msg_float_win and vim.api.nvim_win_is_valid(commit_msg_float_win) then
		local buf = vim.api.nvim_win_get_buf(commit_msg_float_win)
		vim.api.nvim_win_close(commit_msg_float_win, true)
		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
	end
	commit_msg_float_win = nil
end

--- Open a standalone float with commit message lines (after telescope is closed).
---@param lines string[]
local function open_standalone_commit_float(lines)
	local float_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(float_buf, 0, -1, false, lines)
	vim.bo[float_buf].modifiable = false
	vim.bo[float_buf].bufhidden = 'wipe'

	local max_w = math.min(80, vim.o.columns - 4)
	local width = 40
	for _, l in ipairs(lines) do
		width = math.max(width, #l)
	end
	width = math.min(width, max_w)
	local height = math.min(#lines, math.floor(vim.o.lines * 0.5))

	local win = vim.api.nvim_open_win(float_buf, true, {
		relative = 'editor',
		width = width, height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
		style = 'minimal',
		border = 'rounded',
		title = ' Commit Message (q to close) ',
		title_pos = 'center',
	})

	local function close_and_resume()
		vim.api.nvim_win_close(win, true)
		vim.schedule(function()
			require('telescope.builtin').resume()
		end)
	end
	vim.keymap.set('n', 'q', close_and_resume, { buffer = float_buf })
	vim.keymap.set('n', '<Esc>', close_and_resume, { buffer = float_buf })
end

--- Show the full commit message for the selected telescope entry in a float.
--- K once = preview, K again = close telescope and open standalone float for yanking.
---@param prompt_bufnr number
---@param cwd string|nil
local function show_commit_message(prompt_bufnr, cwd)
	-- If float is already open: close telescope, reopen as standalone for yanking
	if commit_msg_float_win and vim.api.nvim_win_is_valid(commit_msg_float_win) then
		local float_buf = vim.api.nvim_win_get_buf(commit_msg_float_win)
		local lines = vim.api.nvim_buf_get_lines(float_buf, 0, -1, false)
		close_commit_msg_float()
		require("telescope.actions").close(prompt_bufnr)
		vim.schedule(function()
			open_standalone_commit_float(lines)
		end)
		return
	end

	local action_state = require("telescope.actions.state")
	local entry = action_state.get_selected_entry()
	if not entry or not entry.value then return end

	local hash = tostring(entry.value)
	local cmd = cwd
		and { "git", "-C", cwd, "log", "--format=%B", "-n1", hash }
		or  { "git", "log", "--format=%B", "-n1", hash }
	local lines = vim.fn.systemlist(cmd)

	-- Trim trailing blank lines
	while #lines > 0 and lines[#lines] == "" do
		table.remove(lines)
	end
	if #lines == 0 then return end

	local float_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(float_buf, 0, -1, false, lines)
	vim.bo[float_buf].modifiable = false

	-- Size: fit content, capped
	local max_w = math.min(80, vim.o.columns - 4)
	local width = 40
	for _, l in ipairs(lines) do
		width = math.max(width, #l)
	end
	width = math.min(width, max_w)
	local height = math.min(#lines, math.floor(vim.o.lines * 0.3))

	commit_msg_float_win = vim.api.nvim_open_win(float_buf, false, {
		relative = 'editor',
		width = width, height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
		style = 'minimal',
		border = 'rounded',
		title = ' Commit Message (K to enter) ',
		title_pos = 'center',
	})

	-- Poll for selection changes to auto-close (CursorMoved doesn't fire
	-- for telescope selection changes since they happen via API)
	commit_msg_timer = vim.uv.new_timer()
	commit_msg_timer:start(100, 100, vim.schedule_wrap(function()
		if not commit_msg_float_win or not vim.api.nvim_win_is_valid(commit_msg_float_win) then
			close_commit_msg_float()
			return
		end
		-- Close if telescope is gone
		if not vim.api.nvim_buf_is_valid(prompt_bufnr) or vim.fn.bufwinid(prompt_bufnr) == -1 then
			close_commit_msg_float()
			return
		end
		local ok, cur = pcall(action_state.get_selected_entry)
		if not ok or not cur or tostring(cur.value) ~= hash then
			close_commit_msg_float()
		end
	end))
end

--- Default prompt titles for wrapped pickers.
local default_titles = {
    git_files    = "Git Files",
    git_commits  = "Git Commits",
    git_bcommits = "Git Buffer Commits",
    git_branches = "Git Branches",
    git_status   = "Git Status",
    git_stash    = "Git Stash",
    live_grep    = "Live Grep",
    grep_string  = "Grep String",
}

--- Create a custom entry_maker for git_status that shows relative paths.
--- Wraps telescope's default maker and overrides the display function to
--- normalize path separators on Windows.
---@param cwd string the picker's cwd
---@return function entry_maker
function M._make_git_status_entry_maker(cwd)
    local make_entry = require("telescope.make_entry")
    local entry_display = require("telescope.pickers.entry_display")

    local cwd_fwd = cwd:gsub("\\", "/"):gsub("/$", "")
    local default_maker = make_entry.gen_from_git_status({ cwd = cwd })

    local git_icons = {
        ["+"] = { hl = "TelescopeResultsDiffAdd" },
        ["~"] = { hl = "TelescopeResultsDiffChange" },
        [">"] = { hl = "TelescopeResultsDiffChange" },
        ["-"] = { hl = "TelescopeResultsDiffDelete" },
        ["?"] = { hl = "TelescopeResultsDiffUntracked" },
    }
    local git_abbrev = {
        A = { icon = "+", hl = "TelescopeResultsDiffAdd" },
        U = { icon = "‡", hl = "TelescopeResultsDiffAdd" },
        M = { icon = "~", hl = "TelescopeResultsDiffChange" },
        C = { icon = ">", hl = "TelescopeResultsDiffChange" },
        R = { icon = "➡", hl = "TelescopeResultsDiffChange" },
        D = { icon = "-", hl = "TelescopeResultsDiffDelete" },
        ["?"] = { icon = "?", hl = "TelescopeResultsDiffUntracked" },
    }

    local displayer = entry_display.create({
        separator = "",
        items = { { width = 2 }, { width = 2 }, { remaining = true } },
    })

    return function(line)
        local entry = default_maker(line)
        if not entry then return nil end

        entry.display = function(e)
            local x = string.sub(e.status, 1, 1)
            local y = string.sub(e.status, -1)
            local sx = git_abbrev[x] or {}
            local sy = git_abbrev[y] or {}

            local path_clean = (e.path or ""):gsub("\\", "/")
            if path_clean:lower():sub(1, #cwd_fwd) == cwd_fwd:lower() then
                path_clean = path_clean:sub(#cwd_fwd + 2)
            end

            return displayer({
                { sx.icon or " ", sx.hl },
                { sy.icon or " ", sy.hl },
                { path_clean },
            })
        end

        return entry
    end
end

--- Open a git picker scoped to a specific submodule with cycling mappings.
---@param picker_name string telescope.builtin picker name
---@param git_root string
---@param submodules string[]
---@param current_sm string
---@param base_opts table|nil
function M._open_picker(picker_name, git_root, submodules, current_sm, base_opts)
    local actions = require("telescope.actions")

    local current_idx = 1
    for i, sm in ipairs(submodules) do
        if sm == current_sm then
            current_idx = i
            break
        end
    end

    M._picker_active = true
    M._state = {
        picker_name = picker_name,
        git_root    = git_root,
        submodules  = submodules,
        current_idx = current_idx,
        base_opts   = base_opts,
    }

    local cwd = M.submodule_cwd(git_root, current_sm)
    local base_title = default_titles[picker_name] or picker_name
    local prompt_title = string.format("%s [%s]", base_title, sm_label_dirty(git_root, current_sm))

    local opts = vim.tbl_deep_extend("force", base_opts or {}, {
        cwd          = cwd,
        prompt_title = prompt_title,
        -- For git_status: provide a custom entry_maker that normalizes paths on Windows
        entry_maker  = picker_name == "git_status"
            and M._make_git_status_entry_maker(cwd) or nil,
        attach_mappings = function(prompt_bufnr)
            local buf_set = function(mode, lhs, fn, desc)
                vim.keymap.set(mode, lhs, fn, { buffer = prompt_bufnr, desc = desc })
            end

            -- Clear active flag and close commit msg float when picker closes
            vim.api.nvim_create_autocmd("BufDelete", {
                buffer = prompt_bufnr,
                once = true,
                callback = function()
                    M._picker_active = false
                    close_commit_msg_float()
                end,
            })

            -- Commit message preview for commit pickers
            if picker_name == "git_commits" or picker_name == "git_bcommits" then
                buf_set("n", "K", function()
                    show_commit_message(prompt_bufnr, cwd)
                end, "Show full commit message")
            end

            buf_set("i", "<C-s>", function()
                actions.close(prompt_bufnr)
                local s = M._state
                local next_idx = (s.current_idx % #s.submodules) + 1
                vim.schedule(function()
                    M._open_picker(s.picker_name, s.git_root, s.submodules, s.submodules[next_idx], s.base_opts)
                end)
            end, "Submodule: cycle to next")

            buf_set("i", "<C-a>", function()
                actions.close(prompt_bufnr)
                local s = M._state
                local prev_idx = ((s.current_idx - 2) % #s.submodules) + 1
                vim.schedule(function()
                    M._open_picker(s.picker_name, s.git_root, s.submodules, s.submodules[prev_idx], s.base_opts)
                end)
            end, "Submodule: cycle to previous")

            buf_set("i", "<C-g>", function()
                actions.close(prompt_bufnr)
                vim.schedule(function()
                    M._pick_submodule()
                end)
            end, "Submodule: pick from list")

            -- For git_status: remap staging from <Tab> to <C-t>
            -- Use vim.schedule to override AFTER telescope sets up its own mappings
            if picker_name == "git_status" then
                vim.schedule(function()
                    if not vim.api.nvim_buf_is_valid(prompt_bufnr) then return end
                    local action_state = require("telescope.actions.state")

                    -- Remove <Tab> staging — restore default next-selection behavior
                    vim.keymap.set({ "i", "n" }, "<Tab>", function()
                        actions.move_selection_next(prompt_bufnr)
                    end, { buffer = prompt_bufnr, desc = "Next entry" })

                    -- Stage/unstage with <C-t> instead
                    vim.keymap.set({ "i", "n" }, "<C-t>", function()
                        actions.git_staging_toggle(prompt_bufnr)
                        local picker = action_state.get_current_picker(prompt_bufnr)
                        local selection = picker:get_selection_row()
                        local callbacks = { unpack(picker._completion_callbacks) }
                        picker:register_completion_callback(function(self)
                            self:set_selection(selection)
                            self._completion_callbacks = callbacks
                        end)
                        local finder_opts = vim.tbl_deep_extend("force", base_opts or {}, {
                            cwd = cwd,
                            entry_maker = M._make_git_status_entry_maker(cwd),
                        })
                        finder_opts.entry_maker = finder_opts.entry_maker
                            or require("telescope.make_entry").gen_from_git_status(finder_opts)
                        finder_opts.split_char = "\0"
                        local git_cmd = { "git", "-C", cwd, "status", "-z", "-uall", "--", "." }
                        picker:refresh(
                            require("telescope.finders").new_oneshot_job(git_cmd, finder_opts),
                            { reset_prompt = false }
                        )
                    end, { buffer = prompt_bufnr, desc = "Git: toggle stage/unstage" })
                end)
            end

            return true
        end,
    })

    require("telescope.builtin")[picker_name](opts)
end

--- Git command that produces the preview lines for each picker type.
---@param picker_name string
---@param cwd string
---@param base_opts table|nil
---@return string[] command args for vim.fn.systemlist
local function preview_command(picker_name, cwd, base_opts)
    if picker_name == "git_files" then
        -- Honour any custom git_command from base_opts (e.g. --recurse-submodules)
        if base_opts and base_opts.git_command then
            local cmd = vim.deepcopy(base_opts.git_command)
            table.insert(cmd, 2, "-C")
            table.insert(cmd, 3, cwd)
            return cmd
        end
        return { "git", "-C", cwd, "ls-files", "--exclude-standard", "--cached" }
    elseif picker_name == "git_commits" then
        return { "git", "-C", cwd, "log", "--oneline", "--decorate", "-n", "50" }
    elseif picker_name == "git_bcommits" then
        return { "git", "-C", cwd, "log", "--oneline", "--decorate", "-n", "50" }
    elseif picker_name == "git_branches" then
        return { "git", "-C", cwd, "branch", "--all", "--format=%(refname:short)" }
    elseif picker_name == "git_status" then
        return { "git", "-C", cwd, "status", "--short" }
    elseif picker_name == "git_stash" then
        return { "git", "-C", cwd, "stash", "list" }
    elseif picker_name == "live_grep" or picker_name == "grep_string" then
        return { "git", "-C", cwd, "ls-files", "--exclude-standard", "--cached" }
    end
    return { "git", "-C", cwd, "ls-files", "--exclude-standard", "--cached" }
end

--- Open a mini-picker to select a submodule, then reopen the git picker.
--- Shows a live preview of what the parent picker would display for the
--- highlighted submodule.
function M._pick_submodule()
    local pickers      = require("telescope.pickers")
    local finders      = require("telescope.finders")
    local previewers   = require("telescope.previewers")
    local conf         = require("telescope.config").values
    local actions      = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    local s = M._state
    local entries = {}
    for i, sm in ipairs(s.submodules) do
        local dirty = M.is_dirty(s.git_root, sm)
        local label = sm_label(sm)
        if dirty then
            label = label .. " [modified]"
        end
        if i == s.current_idx then
            label = label .. " (current)"
        end
        table.insert(entries, { label = label, submodule = sm })
    end

    local preview_title = default_titles[s.picker_name] or s.picker_name

    pickers.new({}, {
        prompt_title = "Select Submodule",
        preview_title = preview_title .. " preview",
        finder = finders.new_table({
            results = entries,
            entry_maker = function(entry)
                return {
                    value   = entry,
                    display = entry.label,
                    ordinal = entry.label,
                }
            end,
        }),
        sorter = conf.generic_sorter({}),
        previewer = previewers.new_buffer_previewer({
            title = preview_title .. " preview",
            define_preview = function(self, entry)
                local sm = entry.value.submodule
                local cwd = M.submodule_cwd(s.git_root, sm)
                local cmd = preview_command(s.picker_name, cwd, s.base_opts)
                local lines = vim.fn.systemlist(cmd)
                if vim.v.shell_error ~= 0 then
                    lines = { "(no output)" }
                end
                vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
            end,
        }),
        attach_mappings = function(prompt_bufnr)
            actions.select_default:replace(function()
                local sel = action_state.get_selected_entry()
                actions.close(prompt_bufnr)
                if sel then
                    vim.schedule(function()
                        M._open_picker(s.picker_name, s.git_root, s.submodules, sel.value.submodule, s.base_opts)
                    end)
                end
            end)
            return true
        end,
    }):find()
end

--- Create a submodule-aware wrapper for a telescope git picker.
--- Falls back to the default picker when there are no submodules.
---@param picker_name string telescope.builtin picker name
---@param base_opts table|nil extra options to pass to the picker
---@return function
function M.wrap_git_picker(picker_name, base_opts)
    return function()
        local git_root = M.git_toplevel(vim.fn.getcwd())
        if not git_root then
            require("telescope.builtin")[picker_name](
                M._apply_picker_mappings(picker_name, base_opts)
            )
            return
        end

        local submodules = M.get_submodules(git_root)
        if #submodules <= 1 then
            -- No submodules — plain picker
            require("telescope.builtin")[picker_name](
                M._apply_picker_mappings(picker_name, base_opts)
            )
            return
        end

        local current_sm = M.current_submodule(git_root)
        M._open_picker(picker_name, git_root, submodules, current_sm, base_opts)
    end
end

--- Apply extra mappings for non-submodule pickers (git_status remaps, commit message preview).
---@param picker_name string
---@param opts table|nil
---@return table
function M._apply_picker_mappings(picker_name, opts)
    opts = opts or {}

    if picker_name == "git_commits" or picker_name == "git_bcommits" then
        return vim.tbl_deep_extend("force", opts, {
            attach_mappings = function(prompt_bufnr)
                vim.keymap.set("n", "K", function()
                    show_commit_message(prompt_bufnr)
                end, { buffer = prompt_bufnr, desc = "Show full commit message" })
                vim.api.nvim_create_autocmd("BufDelete", {
                    buffer = prompt_bufnr, once = true,
                    callback = function() close_commit_msg_float() end,
                })
                return true
            end,
        })
    end

    if picker_name == "git_status" then
        return vim.tbl_deep_extend("force", opts, {
            attach_mappings = function(prompt_bufnr)
                local actions = require("telescope.actions")
                vim.schedule(function()
                    if not vim.api.nvim_buf_is_valid(prompt_bufnr) then return end
                    vim.keymap.set({ "i", "n" }, "<Tab>", function()
                        actions.move_selection_next(prompt_bufnr)
                    end, { buffer = prompt_bufnr, desc = "Next entry" })
                    vim.keymap.set({ "i", "n" }, "<C-t>", function()
                        actions.git_staging_toggle(prompt_bufnr)
                    end, { buffer = prompt_bufnr, desc = "Git: toggle stage/unstage" })
                end)
                return true
            end,
        })
    end

    return opts
end

return M
