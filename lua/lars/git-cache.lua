-- Persistent TTL cache for git data with stale-while-revalidate semantics.
--
-- Cached data survives Neovim restarts via a JSON file at stdpath("data").
-- All public accessors return immediately from cache (even stale), while
-- kicking off async background refreshes when data goes stale.

local M = {}

---@class PersistentTtlCache
---@field entries table<string, { value: any, ts: number }>
---@field fresh_ttl number seconds before data is considered stale
---@field stale_ttl number seconds before data is evicted entirely
---@field persisted boolean whether this bucket is saved to disk
local PersistentTtlCache = {}
PersistentTtlCache.__index = PersistentTtlCache

---@param fresh_ttl number seconds before data becomes stale
---@param stale_ttl number|nil seconds before data is evicted (defaults to fresh_ttl)
---@param persisted boolean|nil whether to persist to disk (default true)
---@return PersistentTtlCache
function PersistentTtlCache.new(fresh_ttl, stale_ttl, persisted)
    return setmetatable({
        entries = {},
        fresh_ttl = fresh_ttl,
        stale_ttl = stale_ttl or fresh_ttl,
        persisted = persisted ~= false,
    }, PersistentTtlCache)
end

--- Returns value, is_stale. Returns nil, nil when missing or past stale TTL.
---@param key string
---@return any|nil value
---@return boolean|nil is_stale
function PersistentTtlCache:get(key)
    local entry = self.entries[key]
    if not entry then return nil, nil end
    local age = os.time() - entry.ts
    if age > self.stale_ttl then
        self.entries[key] = nil
        return nil, nil
    end
    return entry.value, age > self.fresh_ttl
end

---@param key string
---@param value any
function PersistentTtlCache:set(key, value)
    self.entries[key] = { value = value, ts = os.time() }
end

function PersistentTtlCache:clear()
    self.entries = {}
end

M._PersistentTtlCache = PersistentTtlCache

-- Cache buckets

local buckets = {
    toplevel   = PersistentTtlCache.new(86400,  604800,  true),   -- 24h fresh, 7d stale
    submodules = PersistentTtlCache.new(86400,  604800,  true),   -- 24h fresh, 7d stale
    branches   = PersistentTtlCache.new(3600,   86400,   true),   -- 1h fresh, 24h stale
    dirty      = PersistentTtlCache.new(10,     60,      false),  -- 10s fresh, 60s stale
}

-- JSON persistence

local CACHE_VERSION = 1
local cache_path = vim.fn.stdpath("data") .. "/telescope-git-cache.json"

local _persist_timer = nil

local function load_from_disk()
    local f = io.open(cache_path, "r")
    if not f then return end
    local raw = f:read("*a")
    f:close()
    local ok, data = pcall(vim.json.decode, raw)
    if not ok or type(data) ~= "table" or data.version ~= CACHE_VERSION then return end
    for name, bucket in pairs(buckets) do
        if bucket.persisted and type(data[name]) == "table" then
            for key, entry in pairs(data[name]) do
                if type(entry) == "table" and entry.value ~= nil and type(entry.ts) == "number" then
                    bucket.entries[key] = { value = entry.value, ts = entry.ts }
                end
            end
        end
    end
end

local function persist_to_disk()
    local data = { version = CACHE_VERSION }
    for name, bucket in pairs(buckets) do
        if bucket.persisted then
            data[name] = bucket.entries
        end
    end
    local ok, json = pcall(vim.json.encode, data)
    if not ok then return end
    local tmp = cache_path .. ".tmp"
    local f = io.open(tmp, "w")
    if not f then return end
    f:write(json)
    f:close()
    os.remove(cache_path)
    os.rename(tmp, cache_path)
end

local function schedule_persist()
    if _persist_timer then
        _persist_timer:stop()
    else
        _persist_timer = vim.uv.new_timer()
    end
    _persist_timer:start(200, 0, vim.schedule_wrap(function()
        persist_to_disk()
    end))
end

load_from_disk()

vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("GitCachePersist", {}),
    callback = function()
        if _persist_timer then
            _persist_timer:stop()
            _persist_timer:close()
            _persist_timer = nil
        end
        persist_to_disk()
    end,
})

-- Async git helper

local function async_git(cmd, callback)
    vim.system(cmd, { text = true }, function(result)
        vim.schedule(function()
            callback(result.code, result.stdout or "", result.stderr or "")
        end)
    end)
end

-- Submodule cwd helper

local function submodule_cwd(git_root, sm)
    if sm == "." then return git_root end
    local sep = vim.fn.has("win32") == 1 and "\\" or "/"
    return git_root .. sep .. sm:gsub("/", sep)
end

-- git_toplevel

function M.git_toplevel(path)
    local cached, is_stale = buckets.toplevel:get(path)
    if cached ~= nil then
        if is_stale then
            M.git_toplevel_async(path, function() end)
        end
        return cached
    end
    local result = vim.fn.systemlist({ "git", "-C", path, "rev-parse", "--show-toplevel" })
    if vim.v.shell_error == 0 and result[1] then
        local toplevel = vim.fn.fnamemodify(result[1], ":p"):gsub("[/\\]$", "")
        buckets.toplevel:set(path, toplevel)
        schedule_persist()
        return toplevel
    end
    return nil
end

function M.git_toplevel_async(path, callback)
    local cached, is_stale = buckets.toplevel:get(path)
    if cached ~= nil then
        callback(cached)
        if not is_stale then return end
    end
    async_git({ "git", "-C", path, "rev-parse", "--show-toplevel" }, function(code, stdout)
        if code == 0 and stdout ~= "" then
            local toplevel = vim.fn.fnamemodify(vim.trim(stdout), ":p"):gsub("[/\\]$", "")
            buckets.toplevel:set(path, toplevel)
            schedule_persist()
            if not cached then callback(toplevel) end
        end
    end)
end

-- get_submodules

function M.get_submodules(git_root)
    local cached, is_stale = buckets.submodules:get(git_root)
    if cached then
        if is_stale then
            M.get_submodules_async(git_root, function() end)
        end
        return cached
    end
    local result = vim.fn.systemlist({
        "git", "-C", git_root,
        "submodule", "status", "--recursive",
    })
    local submodules = { "." }
    if vim.v.shell_error == 0 then
        for _, line in ipairs(result) do
            local sm_path = line:match("^[%s%+%-U]+%x+%s+(%S+)")
            if sm_path and sm_path ~= "" then
                table.insert(submodules, sm_path)
            end
        end
    end
    buckets.submodules:set(git_root, submodules)
    schedule_persist()
    return submodules
end

function M.get_submodules_async(git_root, callback)
    local cached, is_stale = buckets.submodules:get(git_root)
    if cached then
        callback(cached)
        if not is_stale then return end
    end
    async_git({
        "git", "-C", git_root,
        "submodule", "status", "--recursive",
    }, function(code, stdout)
        local submodules = { "." }
        if code == 0 and stdout ~= "" then
            for _, line in ipairs(vim.split(stdout, "\n", { trimempty = true })) do
                local sm_path = line:match("^[%s%+%-U]+%x+%s+(%S+)")
                if sm_path and sm_path ~= "" then
                    table.insert(submodules, sm_path)
                end
            end
        end
        buckets.submodules:set(git_root, submodules)
        schedule_persist()
        if not cached then callback(submodules) end
    end)
end

-- is_dirty

function M.is_dirty(git_root, sm)
    local cache_key = git_root .. "\0" .. sm
    local cached, is_stale = buckets.dirty:get(cache_key)
    if cached ~= nil then
        if is_stale then
            M.is_dirty_async(git_root, sm, function() end)
        end
        return cached
    end
    local cwd = submodule_cwd(git_root, sm)
    local result = vim.fn.systemlist({ "git", "-C", cwd, "status", "--porcelain" })
    local dirty = vim.v.shell_error == 0 and #result > 0
    buckets.dirty:set(cache_key, dirty)
    return dirty
end

function M.is_dirty_async(git_root, sm, callback)
    local cache_key = git_root .. "\0" .. sm
    local cwd = submodule_cwd(git_root, sm)
    async_git({ "git", "-C", cwd, "status", "--porcelain" }, function(code, stdout)
        local dirty = code == 0 and stdout ~= ""
        buckets.dirty:set(cache_key, dirty)
        callback(dirty)
    end)
end

-- get_branch

function M.get_branch(git_root, sm)
    local cache_key = git_root .. "\0" .. sm
    local cached, is_stale = buckets.branches:get(cache_key)
    if cached then
        if is_stale then
            M.get_branch_async(git_root, sm, function() end)
        end
        return cached
    end
    local cwd = submodule_cwd(git_root, sm)
    local result = vim.fn.systemlist({ "git", "-C", cwd, "rev-parse", "--abbrev-ref", "HEAD" })
    local branch = "detached"
    if vim.v.shell_error == 0 and result[1] then
        branch = vim.trim(result[1])
    end
    buckets.branches:set(cache_key, branch)
    schedule_persist()
    return branch
end

function M.get_branch_async(git_root, sm, callback)
    local cache_key = git_root .. "\0" .. sm
    local cwd = submodule_cwd(git_root, sm)
    async_git({ "git", "-C", cwd, "rev-parse", "--abbrev-ref", "HEAD" }, function(code, stdout)
        local branch = "detached"
        if code == 0 and stdout ~= "" then
            branch = vim.trim(stdout)
        end
        buckets.branches:set(cache_key, branch)
        schedule_persist()
        callback(branch)
    end)
end

-- Invalidation

function M.clear_dirty(git_root, sm)
    buckets.dirty.entries[git_root .. "\0" .. sm] = nil
end

function M.clear_cache()
    for _, bucket in pairs(buckets) do
        bucket:clear()
    end
    os.remove(cache_path)
end

-- Prewarm

function M.prewarm()
    local cwd = vim.fn.getcwd()
    M.git_toplevel_async(cwd, function(toplevel)
        if not toplevel then return end
        M.get_submodules_async(toplevel, function(submodules)
            for _, sm in ipairs(submodules) do
                M.get_branch_async(toplevel, sm, function() end)
            end
        end)
    end)
end

-- Expose for testing

M._buckets = buckets
M._cache_path = cache_path
M._persist_to_disk = persist_to_disk
M._load_from_disk = load_from_disk

return M
