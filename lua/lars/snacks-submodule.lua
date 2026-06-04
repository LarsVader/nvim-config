-- Submodule-aware snacks pickers.
--
-- Adds a submodule switcher to any snacks picker that respects `cwd` (git_log,
-- git_status, git_diff, git_branches, git_stash, git_files, files, grep, ...),
-- mirroring the telescope version. The picker opens instantly with NO extra git
-- work -- the switcher keys lazily (and asynchronously) discover submodules only
-- when you actually press one:
--   <C-s>   cycle to next submodule
--   <C-a>   cycle to previous submodule
--   <C-g>   pick a submodule from a list
--
-- Once switched, the picker reopens scoped to the submodule's cwd and the title
-- shows which submodule is active. When the repo has no submodules, pressing a
-- switch key just reports that and the picker is otherwise untouched.
--
-- Usage -- wrap any snacks picker source by name:
--   { "<leader>gl", function() require("lars.snacks-submodule").open("git_log") end },
--   { "<leader>gs", function() require("lars.snacks-submodule").open("git_status") end },
-- or build a reusable callback with M.wrap("git_status").
--
-- NOTE: submodule discovery uses async git calls (vim.system) -- no caching and,
-- crucially, no blocking on the open path. A caching layer could be slotted back
-- in later by routing the discovery through lars.git-cache.

local M = {}

--- Resolve the absolute cwd for a submodule.
---@param git_root string
---@param submodule string submodule relative path ("." for root)
---@return string path in native OS format
function M.submodule_cwd(git_root, submodule)
    if submodule == "." then
        return git_root
    end
    local sep = vim.fn.has("win32") == 1 and "\\" or "/"
    return git_root .. sep .. submodule:gsub("/", sep)
end

--- Parse `git submodule status --recursive` output into relative paths.
--- Always returns "." (the root repo) as the first entry.
---@param lines string[]
---@return string[]
function M.parse_submodules(lines)
    local submodules = { "." }
    for _, line in ipairs(lines) do
        local sm_path = line:match("^[%s%+%-U]+%x+%s+(%S+)")
        if sm_path and sm_path ~= "" then
            table.insert(submodules, sm_path)
        end
    end
    return submodules
end

--- Determine which submodule a buffer path belongs to, given the submodule list.
---@param git_root string
---@param submodules string[]
---@param bufpath string|nil absolute buffer path (defaults to current buffer)
---@return string submodule relative path, or "." for root
function M.current_submodule(git_root, submodules, bufpath)
    bufpath = bufpath or vim.fn.expand("%:p")
    if bufpath == "" then return "." end

    bufpath = vim.fs.normalize(bufpath)
    local root_norm = vim.fs.normalize(git_root)

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

--- Readable label for a submodule path.
---@param sm string
---@return string
local function sm_label(sm)
    return sm == "." and "(root)" or sm
end

--- Per-session state. `resolved` is false until the first switch key triggers
--- async submodule discovery.
M._state = { resolved = false, current_idx = 1 }

--- Discover the git root + submodule list asynchronously, then call cb(ok).
--- Caches the result in M._state for the rest of the session. Never blocks.
---@param cb fun(ok: boolean)
function M._resolve(cb)
    if M._state.resolved then
        cb(true)
        return
    end

    local cwd = vim.fn.getcwd()
    vim.system(
        { "git", "-C", cwd, "rev-parse", "--show-toplevel" },
        { text = true },
        function(res)
            if res.code ~= 0 or not res.stdout or vim.trim(res.stdout) == "" then
                vim.schedule(function() cb(false) end)
                return
            end
            local git_root = vim.trim(res.stdout):gsub("[/\\]$", "")
            vim.system(
                { "git", "-C", git_root, "submodule", "status", "--recursive" },
                { text = true },
                function(res2)
                    local lines = (res2.code == 0 and res2.stdout)
                        and vim.split(res2.stdout, "\n", { trimempty = true }) or {}
                    local submodules = M.parse_submodules(lines)
                    vim.schedule(function()
                        M._state = {
                            resolved    = true,
                            source      = M._state.source,
                            git_root    = git_root,
                            submodules  = submodules,
                            current_idx = 1,
                        }
                        -- Default to the submodule of the current buffer.
                        local cur = M.current_submodule(git_root, submodules)
                        for i, sm in ipairs(submodules) do
                            if sm == cur then M._state.current_idx = i break end
                        end
                        cb(true)
                    end)
                end
            )
        end
    )
end

--- Shared picker options: switcher actions + keymaps. The keys are inert (they
--- just trigger lazy discovery) until a submodule is actually selected.
---@param extra table|nil cwd/title overrides for a scoped reopen
---@return table
local function picker_opts(extra)
    return vim.tbl_deep_extend("force", {
        actions = {
            submodule_next = function(picker) M._cycle(picker, 1) end,
            submodule_prev = function(picker) M._cycle(picker, -1) end,
            submodule_pick = function(picker) M._pick(picker) end,
        },
        win = {
            input = {
                keys = {
                    ["<c-s>"] = { "submodule_next", mode = { "n", "i" }, desc = "Submodule: next" },
                    ["<c-a>"] = { "submodule_prev", mode = { "n", "i" }, desc = "Submodule: previous" },
                    ["<c-g>"] = { "submodule_pick", mode = { "n", "i" }, desc = "Submodule: pick" },
                },
            },
        },
    }, extra or {})
end

--- Default title for a snacks picker source (falls back to the source name).
---@param source string
---@return string
local function source_title(source)
    local ok, t = pcall(function() return Snacks.picker.util.title(source) end)
    if ok and type(t) == "string" and t ~= "" then return t end
    return source
end

--- Reopen the picker scoped to the currently selected submodule in M._state.
local function open_scoped()
    local s = M._state
    local sm = s.submodules[s.current_idx]
    Snacks.picker[s.source](picker_opts({
        cwd = M.submodule_cwd(s.git_root, sm),
        title = string.format("%s [%s]", source_title(s.source), sm_label(sm)),
    }))
end

--- Close the current picker and reopen scoped to the next/previous submodule.
---@param picker table snacks picker instance
---@param dir number 1 for next, -1 for previous
function M._cycle(picker, dir)
    M._resolve(function(ok)
        local s = M._state
        if not ok or #s.submodules <= 1 then
            vim.notify("No submodules in this repository", vim.log.levels.INFO)
            return
        end
        s.current_idx = ((s.current_idx - 1 + dir) % #s.submodules) + 1
        picker:close()
        vim.schedule(open_scoped)
    end)
end

--- Close the current picker, prompt for a submodule, and reopen scoped to it.
---@param picker table snacks picker instance
function M._pick(picker)
    M._resolve(function(ok)
        local s = M._state
        if not ok or #s.submodules <= 1 then
            vim.notify("No submodules in this repository", vim.log.levels.INFO)
            return
        end

        local items = {}
        for i, sm in ipairs(s.submodules) do
            local label = sm_label(sm)
            if i == s.current_idx then label = label .. " (current)" end
            table.insert(items, { sm = sm, idx = i, label = label })
        end

        picker:close()
        vim.schedule(function()
            vim.ui.select(items, {
                prompt = "Select submodule",
                format_item = function(item) return item.label end,
            }, function(choice)
                M._state.current_idx = choice and choice.idx or s.current_idx
                open_scoped()
            end)
        end)
    end)
end

--- Open a submodule-aware snacks picker. Opens instantly (no git work);
--- submodule discovery is deferred to the switcher keys.
---@param source string snacks picker source name (e.g. "git_log", "git_status")
---@param opts table|nil extra options forwarded to the picker
function M.open(source, opts)
    M._state = { resolved = false, current_idx = 1, source = source }
    Snacks.picker[source](picker_opts(opts))
end

--- Build a reusable callback that opens a submodule-aware picker for `source`.
---@param source string snacks picker source name
---@param opts table|nil extra options forwarded to the picker
---@return fun()
function M.wrap(source, opts)
    return function() M.open(source, opts) end
end

--- Backward-compatible entry point for the git_log picker.
function M.git_log()
    M.open("git_log")
end

return M
