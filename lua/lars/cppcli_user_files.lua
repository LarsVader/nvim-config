-- Auto-generates `<csproj>.user` files so Roslyn LSP can resolve types
-- defined in C++/CLI assemblies referenced via `<ProjectReference>` to a
-- vcxproj. Roslyn's MSBuildWorkspace cannot evaluate vcxproj outputs at
-- design time (no VC++ toolchain in the .NET SDK MSBuild), so the assembly
-- never appears and every type from it lights up as CS0103.
--
-- Workaround: drop a `<csproj>.user` next to the csproj with a
-- design-time-only `<Reference>` whose `<HintPath>` points at the built
-- DLL. The condition `'$(DesignTimeBuild)' == 'true'` means the LSP
-- (which sets that property) sees it and real MSBuild builds don't, so no
-- MSB3243 conflict warnings on the actual build.
--
-- DLL location: we discover by walking the workspace tree once for *.dll,
-- indexed by basename. The expected assembly name for each vcxproj is its
-- filename without the `.vcxproj` suffix (covers the common case; custom
-- `<TargetName>` in vcxproj is not supported — those projects can ship a
-- hand-written .user). MSBuild is no longer invoked. This is robust to
-- projects with non-standard $(OutDir), unresolved property variables, and
-- to vcxprojs that don't evaluate cleanly outside their solution.

local M = {}

local NOISE_DIRS = {
    [".git"] = true, [".svn"] = true, [".hg"] = true, [".vs"] = true,
    bin = true, obj = true, node_modules = true,
    packages = true, [".idea"] = true, [".vscode"] = true,
}

-- workspace_root -> { csprojs, vcxprojs, dll_index }
-- dll_index is `lowercased_basename_no_ext -> string[] of full paths`.
local scan_cache = {}
-- workspace_root -> true once we've tried a pass in this session
-- (succeeded or partially failed). Prevents re-walks on every LspAttach.
-- Cleared only by M.invalidate.
local attempted = {}
-- (workspace_root .. "\0" .. asm_name:lower()) -> vcxproj_dir | false
local vcxproj_dir_cache = {}

local function mtime(p)
    local st = vim.uv.fs_stat(p)
    if not st then return nil end
    return st.mtime.sec
end

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function skip_noise(name)
    return not NOISE_DIRS[name:lower()]
end

local function read_file_safe(p)
    local f = io.open(p, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

local function write_file(p, content)
    local f = io.open(p, "w")
    if not f then return false end
    f:write(content)
    f:close()
    return true
end

--- Parse a csproj's text. Pulls out `<ProjectReference Include="...vcxproj">`
--- and `<ProjectReference Include="...csproj">` entries, plus the set of
--- all existing `<Reference Include="X">` assembly names (so we can skip
--- vcxprojs the csproj already handles by hand).
---@param contents string
---@return { vcxproj_refs: string[], csproj_refs: string[], existing_refs: table<string, true> }
function M._parse_csproj(contents)
    -- Strip XML comments first so `<!-- <Reference Include="X" /> -->`
    -- doesn't get matched.
    contents = contents:gsub("<!%-%-.-%-%->", "")

    local vcxproj_refs = {}
    local csproj_refs = {}
    local existing_refs = {}

    for inc in contents:gmatch('<ProjectReference[^>]-Include%s*=%s*"([^"]+)"') do
        local l = inc:lower()
        if l:match("%.vcxproj$") then
            table.insert(vcxproj_refs, (inc:gsub("/", "\\")))
        elseif l:match("%.csproj$") then
            table.insert(csproj_refs, (inc:gsub("/", "\\")))
        end
    end

    for inc in contents:gmatch('<Reference[^>]-Include%s*=%s*"([^"]+)"') do
        local name = trim((inc:match("^([^,]+)") or inc))
        if name ~= "" then existing_refs[name] = true end
    end

    return {
        vcxproj_refs = vcxproj_refs,
        csproj_refs = csproj_refs,
        existing_refs = existing_refs,
    }
end

--- Compute a relative path from `from_dir` to `to_file` using backslash
--- separators (Windows-only consumer). Case-insensitive prefix match.
---@param from_dir string
---@param to_file string
---@return string
function M._compute_relative_path(from_dir, to_file)
    local function norm(p) return (p:gsub("/", "\\")) end
    from_dir = norm(from_dir):gsub("\\+$", "")
    to_file = norm(to_file)

    local segments = {}
    for seg in from_dir:gmatch("[^\\]+") do table.insert(segments, seg) end

    local depth = 0
    while #segments > 0 do
        local prefix = table.concat(segments, "\\")
        if to_file:sub(1, #prefix):lower() == prefix:lower()
            and (to_file:sub(#prefix + 1, #prefix + 1) == "\\"
                or #to_file == #prefix) then
            local rel = to_file:sub(#prefix + 1):gsub("^\\+", "")
            if depth == 0 then return rel end
            return string.rep("..\\", depth) .. rel
        end
        table.remove(segments) -- removes last (Lua 5.1 default)
        depth = depth + 1
    end
    return to_file
end

---@param entries { name: string, hint: string }[]
---@return string
function M._build_user_xml(entries)
    local out = {
        "<Project>",
        "  <!-- Auto-generated by lars.cppcli_user_files. Do not commit. -->",
        "  <ItemGroup Condition=\"'$(DesignTimeBuild)' == 'true'\">",
    }
    for _, e in ipairs(entries) do
        table.insert(out, '    <Reference Include="' .. e.name .. '">')
        table.insert(out, "      <HintPath>" .. e.hint .. "</HintPath>")
        table.insert(out, "      <Private>false</Private>")
        table.insert(out, "    </Reference>")
    end
    table.insert(out, "  </ItemGroup>")
    table.insert(out, "</Project>")
    return table.concat(out, "\n") .. "\n"
end

--- Walk the workspace tree once. Collects csprojs, vcxprojs, and indexes
--- every .dll under the workspace (sans noise dirs) by its basename
--- (lowercased, without .dll). The dll_index lets us resolve an assembly
--- name to a built DLL path without invoking MSBuild.
---@param workspace_root string
---@return string[] csprojs, string[] vcxprojs, table<string, string[]> dll_index
function M._scan(workspace_root)
    local csprojs = {}
    local vcxprojs = {}
    local dll_index = {}
    for entry, t in vim.fs.dir(workspace_root, { depth = 64, skip = skip_noise }) do
        if t == "file" then
            local l = entry:lower()
            if l:match("%.csproj$") then
                table.insert(csprojs, vim.fs.joinpath(workspace_root, entry))
            elseif l:match("%.vcxproj$") then
                table.insert(vcxprojs, vim.fs.joinpath(workspace_root, entry))
            elseif l:match("%.dll$") then
                local base = l:gsub("[/\\]", "/"):match("([^/]+)%.dll$")
                if base then
                    dll_index[base] = dll_index[base] or {}
                    table.insert(dll_index[base],
                        vim.fs.joinpath(workspace_root, entry))
                end
            end
        end
    end
    return csprojs, vcxprojs, dll_index
end

local function scan_cached(workspace_root)
    local c = scan_cache[workspace_root]
    if c then return c.csprojs, c.vcxprojs, c.dll_index end
    local csprojs, vcxprojs, dll_index = M._scan(workspace_root)
    scan_cache[workspace_root] = {
        csprojs = csprojs, vcxprojs = vcxprojs, dll_index = dll_index,
    }
    return csprojs, vcxprojs, dll_index
end

--- Pick the best DLL for `asm_name` from a workspace dll_index. Two
--- preference tiers:
---   1. DLLs whose path is under `hint_dir` (e.g. the vcxproj's parent
---      directory) — catches `bin/x64/Debug/Foo.dll` next to `Foo.vcxproj`.
---   2. Any other matching DLL anywhere in the workspace.
--- Within each tier the newest mtime wins. So a freshly-built Release
--- DLL beats a stale Debug DLL even when both sit under `hint_dir`.
---@param dll_index table<string, string[]>
---@param asm_name string
---@param hint_dir? string
---@return string?
function M._find_dll_for_assembly(dll_index, asm_name, hint_dir)
    if not asm_name or asm_name == "" then return nil end
    local key = asm_name:lower()
    local candidates = dll_index[key]
    if not candidates or #candidates == 0 then return nil end

    local hint_norm = nil
    if hint_dir and hint_dir ~= "" then
        hint_norm = vim.fs.normalize(hint_dir):lower():gsub("/+$", "") .. "/"
    end

    local under_hint, others = {}, {}
    for _, p in ipairs(candidates) do
        if hint_norm
            and vim.fs.normalize(p):lower():sub(1, #hint_norm) == hint_norm then
            table.insert(under_hint, p)
        else
            table.insert(others, p)
        end
    end

    local function newest(list)
        if #list == 0 then return nil end
        table.sort(list, function(a, b)
            return (mtime(a) or 0) > (mtime(b) or 0)
        end)
        return list[1]
    end

    return newest(under_hint) or newest(others)
end

--- Returns the vcxproj full paths under `workspace_root`.
---@param workspace_root string
---@return string[]
function M._scan_vcxprojs(workspace_root)
    local _, vcxprojs = scan_cached(workspace_root)
    return vcxprojs or {}
end

--- Walk a csproj's `<ProjectReference>` chain (csproj -> csproj -> ...)
--- and collect every reachable vcxproj's full path. Cycle-safe via
--- `visited`. The order is "direct refs first, then breadth into csproj
--- chain" which lets the caller dedupe by first-seen.
---@param csproj_path string  absolute path
---@param visited? table<string, true>  shared dedup set across recursion
---@return string[]  full paths of vcxprojs (deduplicated, lowercased keys)
function M._gather_transitive_vcxprojs(csproj_path, visited)
    visited = visited or {}
    local cs_norm = vim.fs.normalize(csproj_path):lower()
    if visited[cs_norm] then return {} end
    visited[cs_norm] = true

    local content = read_file_safe(csproj_path)
    if not content then return {} end

    local parsed = M._parse_csproj(content)
    local cs_dir = vim.fs.dirname(csproj_path)
    local results = {}
    local seen = {}

    local function add(vcx_full)
        local key = vcx_full:lower()
        if not seen[key] then
            seen[key] = true
            table.insert(results, vcx_full)
        end
    end

    for _, vcx_rel in ipairs(parsed.vcxproj_refs) do
        local full = vim.fs.normalize(vim.fs.joinpath(cs_dir, vcx_rel))
        add((full:gsub("/", "\\")))
    end

    for _, sub_rel in ipairs(parsed.csproj_refs) do
        local sub_full = vim.fs.normalize(vim.fs.joinpath(cs_dir, sub_rel))
        for _, v in ipairs(M._gather_transitive_vcxprojs(sub_full, visited)) do
            add(v)
        end
    end

    return results
end

--- Find the vcxproj directory whose filename (sans `.vcxproj`) matches
--- `asm_name` (case-insensitive). Returns nil when no such vcxproj exists.
---@param workspace_root string
---@param asm_name string
---@param _opts? table  reserved (was MSBuild config); ignored now.
---@return string?
function M.find_vcxproj_dir_for_assembly(workspace_root, asm_name, _opts)
    if not workspace_root or workspace_root == "" then return nil end
    if not asm_name or asm_name == "" then return nil end
    local key = workspace_root .. "\0" .. asm_name:lower()
    local cached = vcxproj_dir_cache[key]
    if cached ~= nil then
        if cached == false then return nil end
        return cached
    end

    local vcxprojs = M._scan_vcxprojs(workspace_root)
    local target = asm_name:lower()
    for _, vcx in ipairs(vcxprojs) do
        local base = vim.fs.basename(vcx):gsub("%.[Vv][Cc][Xx][Pp][Rr][Oo][Jj]$", "")
        if base:lower() == target then
            local dir = vim.fs.dirname(vcx)
            vcxproj_dir_cache[key] = dir
            return dir
        end
    end
    vcxproj_dir_cache[key] = false
    return nil
end

--- Ensure `.user` files are present and current for every csproj in the
--- workspace that pulls in a C++/CLI vcxproj. Synchronous; intended to be
--- called from a `vim.schedule` wrapper so it doesn't block LSP startup.
---
--- Caller-controlled dedup: `M.ensure_for_buffer` short-circuits via the
--- in-session `attempted` flag so this only runs once per workspace per
--- nvim session.
--- `changed` counts every csproj whose `.user` we wrote or removed.
--- `skipped` counts csprojs we left alone (already current, no work to do,
--- or hand-written marker missing).
---@param workspace_root string
---@param _opts? table  reserved for future options.
---@return integer changed, integer skipped
function M.ensure(workspace_root, _opts)
    if not workspace_root or workspace_root == "" then return 0, 0 end

    local csprojs, _, dll_index = scan_cached(workspace_root)
    local changed, skipped = 0, 0

    for _, csproj in ipairs(csprojs) do
        local user_path = csproj .. ".user"
        local csproj_dir = vim.fs.dirname(csproj)

        local content = read_file_safe(csproj)
        if not content then
            skipped = skipped + 1
        else
            local parsed = M._parse_csproj(content)
            -- Collect the full transitive vcxproj closure so a csproj
            -- gets references to indirect vcxprojs it reaches through
            -- intermediate csproj refs.
            local all_vcxprojs = M._gather_transitive_vcxprojs(csproj)

            local entries = {}
            local seen_asm = {}
            for _, vcx_full in ipairs(all_vcxprojs) do
                local asm = vim.fs.basename(vcx_full)
                    :gsub("%.[Vv][Cc][Xx][Pp][Rr][Oo][Jj]$", "")
                local key = asm:lower()
                if not seen_asm[key] and not parsed.existing_refs[asm] then
                    seen_asm[key] = true
                    local dll = M._find_dll_for_assembly(
                        dll_index, asm, vim.fs.dirname(vcx_full))
                    if dll then
                        table.insert(entries, {
                            name = asm,
                            hint = M._compute_relative_path(csproj_dir, dll),
                        })
                    end
                end
            end

            local desired = (#entries > 0)
                and M._build_user_xml(entries) or nil
            local existing = read_file_safe(user_path)
            -- Never touch a `.user` that wasn't produced by us — preserves
            -- hand-edited files. The marker is in the auto-generated XML.
            local is_auto = existing
                and existing:find(
                    "Auto-generated by lars.cppcli_user_files", 1, true)

            if existing and not is_auto then
                skipped = skipped + 1
            elseif desired == existing then
                -- Both equal or both nil. .user is current — including
                -- the case where the current "best DLL" pick still
                -- matches what's already on disk.
                skipped = skipped + 1
            elseif desired then
                -- Content differs (new vcxproj, stale HintPath, freshly
                -- built DLL took the lead, etc.) — rewrite.
                if write_file(user_path, desired) then
                    changed = changed + 1
                end
            elseif existing then
                -- We have no entries to write but a .user exists — its
                -- vcxprojs were removed or none of their DLLs are
                -- currently on disk. Remove the stale file.
                if os.remove(user_path) then
                    changed = changed + 1
                end
            end
        end
    end

    return changed, skipped
end

--- Resolve the workspace root for a buffer (walk up for .sln/.slnx, then
--- .csproj) and dispatch to `ensure` asynchronously. Short-circuits once
--- per workspace per session via the `attempted` flag — even if the
--- previous pass found no DLLs. To re-attempt (e.g. after a build), use
--- `:CppCliUserFilesRefresh` which calls `M.invalidate`.
---@param bufnr? integer  defaults to current buffer
---@param _opts? table
function M.ensure_for_buffer(bufnr, _opts)
    local fname = vim.api.nvim_buf_get_name(bufnr or 0)
    if fname == "" then return end
    fname = vim.fs.normalize(fname)
    local root = vim.fs.root(fname, function(name)
        return name:match("%.sln$") ~= nil or name:match("%.slnx$") ~= nil
    end) or vim.fs.root(fname, function(name)
        return name:match("%.csproj$") ~= nil
    end)
    if not root then return end
    if attempted[root] then return end
    attempted[root] = true
    vim.schedule(function()
        local t0 = vim.uv.hrtime()
        local ok, c_or_err, s = pcall(M.ensure, root)
        local ms = (vim.uv.hrtime() - t0) / 1e6
        if not ok then
            vim.notify(string.format(
                "cppcli_user_files: refresh failed after %.0fms: %s",
                ms, tostring(c_or_err)), vim.log.levels.ERROR)
        else
            vim.notify(string.format(
                "cppcli_user_files: refreshed %s (c=%d s=%d, %.0fms)",
                root, c_or_err or 0, s or 0, ms),
                vim.log.levels.INFO)
        end
    end)
end

--- Drop the scan + attempted caches. Pass a workspace root to invalidate
--- just that workspace; no argument clears all.
---@param workspace_root? string
function M.invalidate(workspace_root)
    if workspace_root then
        scan_cache[workspace_root] = nil
        attempted[workspace_root] = nil
        local prefix = workspace_root .. "\0"
        for k in pairs(vcxproj_dir_cache) do
            if k:sub(1, #prefix) == prefix then
                vcxproj_dir_cache[k] = nil
            end
        end
    else
        scan_cache = {}
        attempted = {}
        vcxproj_dir_cache = {}
    end
end

--- Test-only: clear in-memory caches.
function M._reset_for_test()
    scan_cache = {}
    attempted = {}
    vcxproj_dir_cache = {}
end

return M
