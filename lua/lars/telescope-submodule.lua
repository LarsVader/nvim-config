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

--- TTL cache implementation.
--- Each cache is a table keyed by cache key, with entries { value, timestamp }.
---@class TtlCache
---@field entries table<string, { value: any, ts: number }>
---@field ttl number seconds before entries expire
local TtlCache = {}
TtlCache.__index = TtlCache

--- Create a new TTL cache.
---@param ttl number seconds
---@return TtlCache
function TtlCache.new(ttl)
    return setmetatable({ entries = {}, ttl = ttl }, TtlCache)
end

--- Get a cached value, or nil if expired/missing.
---@param key string
---@return any|nil
function TtlCache:get(key)
    local entry = self.entries[key]
    if not entry then return nil end
    if (vim.uv.now() - entry.ts) / 1000 > self.ttl then
        self.entries[key] = nil
        return nil
    end
    return entry.value
end

--- Store a value in the cache.
---@param key string
---@param value any
function TtlCache:set(key, value)
    self.entries[key] = { value = value, ts = vim.uv.now() }
end

--- Clear all entries.
function TtlCache:clear()
    self.entries = {}
end

-- Expose TtlCache for testing
M._TtlCache = TtlCache

--- Caches with appropriate TTLs
local _toplevel_cache = TtlCache.new(86400)
local _submodule_cache = TtlCache.new(86400)
local _dirty_cache = TtlCache.new(10)

--- Get the git toplevel for a given path.
--- Returns the path in native OS format (backslashes on Windows) so that
--- telescope can correctly compute relative paths for display.
--- Results are cached with a 24-hour TTL.
---@param path string
---@return string|nil absolute path in native format
function M.git_toplevel(path)
    local cached = _toplevel_cache:get(path)
    if cached ~= nil then return cached end

    local result = vim.fn.systemlist({ "git", "-C", path, "rev-parse", "--show-toplevel" })
    if vim.v.shell_error == 0 and result[1] then
        local toplevel = vim.fn.fnamemodify(result[1], ":p"):gsub("[/\\]$", "")
        _toplevel_cache:set(path, toplevel)
        return toplevel
    end
    return nil
end

--- Get ordered list of submodule relative paths for a git root.
--- The root repo itself is always entry "." at index 1.
--- Results are cached with a 24-hour TTL.
---@param git_root string
---@return string[]
function M.get_submodules(git_root)
    local cached = _submodule_cache:get(git_root)
    if cached then return cached end

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

    _submodule_cache:set(git_root, submodules)
    return submodules
end

--- Clear all caches (toplevel, submodules, dirty status).
function M.clear_cache()
    _toplevel_cache:clear()
    _submodule_cache:clear()
    _dirty_cache:clear()
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
--- Results are cached with a 10-second TTL.
---@param git_root string
---@param sm string submodule relative path ("." for root)
---@return boolean
function M.is_dirty(git_root, sm)
    local cache_key = git_root .. "\0" .. sm
    local cached = _dirty_cache:get(cache_key)
    if cached ~= nil then return cached end

    local cwd = M.submodule_cwd(git_root, sm)
    local result = vim.fn.systemlist({ "git", "-C", cwd, "status", "--porcelain" })
    local dirty = vim.v.shell_error == 0 and #result > 0
    _dirty_cache:set(cache_key, dirty)
    return dirty
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

--- Get the current branch name for a submodule.
---@param git_root string
---@param sm string submodule relative path ("." for root)
---@return string branch name or "detached"
function M._get_branch(git_root, sm)
    local cwd = M.submodule_cwd(git_root, sm)
    local result = vim.fn.systemlist({ "git", "-C", cwd, "rev-parse", "--abbrev-ref", "HEAD" })
    if vim.v.shell_error == 0 and result[1] then
        return vim.trim(result[1])
    end
    return "detached"
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

--- Smart git branch checkout: for remote branches (e.g. origin/foo), strip
--- the remote prefix so `git checkout foo` auto-creates a local tracking branch.
---@param prompt_bufnr number
---@param cwd string|nil optional cwd for git command
local function smart_git_checkout(prompt_bufnr, cwd)
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local utils = require("telescope.utils")

    local selection = action_state.get_selected_entry()
    if not selection then return end

    local branch = selection.value
    -- If it's a remote branch like "origin/foo", strip the remote prefix
    local local_name = branch:match("^[^/]+/(.+)$")
    -- Only strip if it looks like a remote ref (not a local branch with slashes)
    -- Check if the original name starts with a known remote
    local is_remote = false
    local git_cwd = cwd or action_state.get_current_picker(prompt_bufnr).cwd
    local remotes = utils.get_os_command_output({ "git", "remote" }, git_cwd)
    for _, remote in ipairs(remotes or {}) do
        if branch:find("^" .. vim.pesc(remote) .. "/") then
            is_remote = true
            break
        end
    end

    local checkout_name = (is_remote and local_name) and local_name or branch
    actions.close(prompt_bufnr)
    local _, ret, stderr = utils.get_os_command_output({ "git", "checkout", checkout_name }, git_cwd)
    if ret == 0 then
        utils.notify("actions.git_checkout", {
            msg = string.format("Checked out: %s", checkout_name),
            level = "INFO",
        })
        vim.cmd("checktime")
    else
        utils.notify("actions.git_checkout", {
            msg = string.format("Error when checking out: %s. Git returned: '%s'",
                checkout_name, table.concat(stderr, " ")),
            level = "ERROR",
        })
    end
end

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

    -- git ls-files: --recurse-submodules and --others are incompatible, so we
    -- combine two commands via bash to get tracked (incl. submodule) + untracked files.
    local sm_opts = vim.deepcopy(base_opts or {})
    if picker_name == "git_files" then
        sm_opts.git_command = M._git_files_command()
    end

    local opts = vim.tbl_deep_extend("force", sm_opts, {
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

            -- Interactive rebase for git_commits only
            if picker_name == "git_commits" then
                local function rebase_selected()
                    local action_state = require("telescope.actions.state")
                    local entry = action_state.get_selected_entry()
                    if not entry or not entry.value then return end
                    local sha = tostring(entry.value)
                    actions.close(prompt_bufnr)
                    vim.schedule(function()
                        local prev_cwd = vim.fn.getcwd()
                        vim.cmd("lcd " .. vim.fn.fnameescape(cwd))
                        vim.cmd("G rebase -i " .. sha)
                        -- Poll for rebase completion: check if .git/rebase-merge
                        -- or .git/rebase-apply still exists in the submodule
                        local timer = vim.uv.new_timer()
                        timer:start(1000, 2000, vim.schedule_wrap(function()
                            local git_dir = vim.fn.systemlist({ "git", "-C", cwd, "rev-parse", "--git-dir" })
                            local gd = git_dir[1] or ""
                            if gd == "" then
                                timer:stop()
                                timer:close()
                                vim.cmd("lcd " .. vim.fn.fnameescape(prev_cwd))
                                return
                            end
                            -- Resolve relative git-dir against cwd
                            if not vim.fn.isabsolutepath(gd) then
                                gd = cwd .. "/" .. gd
                            end
                            local in_rebase = vim.fn.isdirectory(gd .. "/rebase-merge") == 1
                                or vim.fn.isdirectory(gd .. "/rebase-apply") == 1
                            if not in_rebase then
                                timer:stop()
                                timer:close()
                                vim.cmd("lcd " .. vim.fn.fnameescape(prev_cwd))
                            end
                        end))
                    end)
                end
                buf_set("i", "<C-r>i", rebase_selected, "Interactive rebase from commit")
                buf_set("n", "<C-r>i", rebase_selected, "Interactive rebase from commit")
            end

            -- Smart checkout for git_branches: strip remote prefix
            if picker_name == "git_branches" then
                actions.select_default:replace(function()
                    smart_git_checkout(prompt_bufnr, cwd)
                end)
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

            -- For git_status: remap staging to <C-t>
            -- Use vim.schedule to override AFTER telescope sets up its own mappings
            if picker_name == "git_status" then
                vim.schedule(function()
                    if not vim.api.nvim_buf_is_valid(prompt_bufnr) then return end
                    local action_state = require("telescope.actions.state")

                    -- Stage/unstage with <C-t>
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

--- Build a git_command that lists tracked files (incl. submodules) + untracked files.
--- git ls-files --recurse-submodules and --others are incompatible, so we use bash
--- to run both and deduplicate.
---@return string[]
function M._git_files_command()
    return {
        "bash", "-c",
        "{ git ls-files --exclude-standard --cached --recurse-submodules; git ls-files --exclude-standard --others; } | sort -u",
    }
end

--- Same as _git_files_command but for a specific cwd (used in preview_command).
---@param cwd string
---@return string[]
function M._git_files_command_with_cwd(cwd)
    return {
        "bash", "-c",
        string.format(
            "cd %q && { git ls-files --exclude-standard --cached --recurse-submodules; git ls-files --exclude-standard --others; } | sort -u",
            cwd:gsub("\\", "/")
        ),
    }
end

--- Git command that produces the preview lines for each picker type.
---@param picker_name string
---@param cwd string
---@param base_opts table|nil
---@return string[] command args for vim.fn.systemlist
local function preview_command(picker_name, cwd, base_opts)
    if picker_name == "git_files" then
        return M._git_files_command_with_cwd(cwd)
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
        return { "git", "-C", cwd, "ls-files", "--exclude-standard", "--cached", "--others" }
    end
    return { "git", "-C", cwd, "ls-files", "--exclude-standard", "--cached", "--others" }
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
        local branch = M._get_branch(s.git_root, sm)
        local label = sm_label(sm)
        if dirty then
            label = label .. " [modified]"
        end
        if i == s.current_idx then
            label = label .. " (current)"
        end
        table.insert(entries, { label = label, submodule = sm, branch = branch })
    end

    local preview_title = default_titles[s.picker_name] or s.picker_name

    pickers.new({}, {
        prompt_title = "Select Submodule",
        preview_title = preview_title .. " preview",
        finder = finders.new_table({
            results = entries,
            entry_maker = function(entry)
                local branch_part = "  " .. entry.branch
                local full = entry.label .. branch_part
                return {
                    value   = entry,
                    display = function()
                        return full, { { { #entry.label, #full }, "TelescopeResultsComment" } }
                    end,
                    ordinal = entry.label,
                }
            end,
        }),
        sorter = conf.generic_sorter({}),
        previewer = previewers.new_buffer_previewer({
            title = preview_title .. " preview",
            define_preview = function(self, entry)
                -- Cancel any in-flight preview job
                if self._preview_job then
                    self._preview_job:kill()
                    self._preview_job = nil
                end

                local sm = entry.value.submodule
                local cwd = M.submodule_cwd(s.git_root, sm)
                local cmd = preview_command(s.picker_name, cwd, s.base_opts)
                local bufnr = self.state.bufnr

                -- Show loading indicator immediately
                if vim.api.nvim_buf_is_valid(bufnr) then
                    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Loading..." })
                end

                self._preview_job = vim.system(cmd, { text = true }, function(result)
                    vim.schedule(function()
                        if not vim.api.nvim_buf_is_valid(bufnr) then
                            return
                        end
                        local lines
                        if result.code ~= 0 or not result.stdout or result.stdout == "" then
                            lines = { "(no output)" }
                        else
                            lines = vim.split(result.stdout, "\n", { trimempty = true })
                        end
                        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
                    end)
                end)
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
            -- No submodules — plain picker with untracked files included
            local plain_opts = base_opts
            if picker_name == "git_files" then
                plain_opts = vim.tbl_deep_extend("force", base_opts or {}, {
                    git_command = M._git_files_command(),
                })
            end
            require("telescope.builtin")[picker_name](
                M._apply_picker_mappings(picker_name, plain_opts)
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
                if picker_name == "git_commits" then
                    local actions = require("telescope.actions")
                    local function rebase_selected()
                        local action_state = require("telescope.actions.state")
                        local entry = action_state.get_selected_entry()
                        if not entry or not entry.value then return end
                        local sha = tostring(entry.value)
                        actions.close(prompt_bufnr)
                        vim.schedule(function()
                            vim.cmd("G rebase -i " .. sha)
                        end)
                    end
                    vim.keymap.set("i", "<C-r>i", rebase_selected, { buffer = prompt_bufnr, desc = "Interactive rebase from commit" })
                    vim.keymap.set("n", "<C-r>i", rebase_selected, { buffer = prompt_bufnr, desc = "Interactive rebase from commit" })
                end
                return true
            end,
        })
    end

    if picker_name == "git_branches" then
        return vim.tbl_deep_extend("force", opts, {
            attach_mappings = function(prompt_bufnr)
                local actions = require("telescope.actions")
                actions.select_default:replace(function()
                    smart_git_checkout(prompt_bufnr)
                end)
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
