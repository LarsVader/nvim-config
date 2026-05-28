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
-- DLL paths are discovered by asking MSBuild itself via
-- `MSBuild <vcxproj> -getTargetResult:GetTargetPath -p:Configuration=...
-- -p:Platform=...`, which returns JSON containing the resolved path
-- without actually building anything.

local M = {}

local CONFIGURATION_DEFAULT = "Debug"
local PLATFORM_DEFAULT = "x64"

local msbuild_cache = nil
-- workspace_root -> { csprojs, has_vcx, sln_dirs }
-- Cached because the depth=64 tree walk is the only meaningfully expensive
-- step per call.
local scan_cache = {}
-- workspace_root -> true once a full pass found nothing to regenerate.
-- Lets repeated FileType=cs autocmd fires (or :bufdo over many .cs buffers)
-- short-circuit without restating every HintPath on disk. Cleared on
-- generation (see `ensure`) or via `M.invalidate`.
local workspace_clean = {}

local function file_exists(p)
    if not p or p == "" then return false end
    return vim.uv.fs_stat(p) ~= nil
end

local function mtime(p)
    local st = vim.uv.fs_stat(p)
    if not st then return nil end
    return st.mtime.sec
end

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

---@return string?
local function probe_msbuild_via_vswhere()
    local pf86 = os.getenv("ProgramFiles(x86)")
    if not pf86 then return nil end
    local vswhere = pf86 .. "\\Microsoft Visual Studio\\Installer\\vswhere.exe"
    if not file_exists(vswhere) then return nil end
    local res = vim.system({
        vswhere, "-latest", "-prerelease", "-requires",
        "Microsoft.Component.MSBuild", "-find", "MSBuild\\**\\Bin\\MSBuild.exe",
    }, { text = true }):wait()
    if res.code ~= 0 then return nil end
    for line in (res.stdout or ""):gmatch("[^\r\n]+") do
        local p = trim(line)
        if file_exists(p) then return p end
    end
    return nil
end

---@return string?
local function probe_msbuild_via_filesystem()
    local editions = { "BuildTools", "Community", "Professional", "Enterprise", "Preview" }
    local roots = {}
    for _, env in ipairs({ "ProgramFiles(x86)", "ProgramFiles" }) do
        local v = os.getenv(env)
        if v then table.insert(roots, v .. "\\Microsoft Visual Studio") end
    end
    for _, root in ipairs(roots) do
        if file_exists(root) then
            local versions = {}
            for name, t in vim.fs.dir(root) do
                if t == "directory" and tonumber(name) then
                    table.insert(versions, tonumber(name))
                end
            end
            table.sort(versions, function(a, b) return a > b end)
            for _, ver in ipairs(versions) do
                for _, ed in ipairs(editions) do
                    local candidate = root
                        .. "\\" .. ver .. "\\" .. ed
                        .. "\\MSBuild\\Current\\Bin\\MSBuild.exe"
                    if file_exists(candidate) then return candidate end
                end
            end
        end
    end
    return nil
end

---@param override? string
---@return string?
function M._find_msbuild(override)
    if override and file_exists(override) then return override end
    if msbuild_cache then return msbuild_cache end
    local exe = vim.fn.exepath("MSBuild.exe")
    msbuild_cache = probe_msbuild_via_vswhere()
        or probe_msbuild_via_filesystem()
        or (exe ~= "" and exe or nil)
    return msbuild_cache
end

--- Parse a csproj's text. Pulls out `<ProjectReference Include="...vcxproj">`
--- entries and the set of all existing `<Reference Include="X">` assembly
--- names (so we can skip vcxprojs the csproj already handles by hand).
---@param contents string
---@return { vcxproj_refs: string[], existing_refs: table<string, true> }
function M._parse_csproj(contents)
    -- Strip XML comments first so `<!-- <Reference Include="X" /> -->`
    -- doesn't get matched. XML doesn't allow nested comments so a single
    -- non-greedy pass is correct.
    contents = contents:gsub("<!%-%-.-%-%->", "")

    local vcxproj_refs = {}
    local existing_refs = {}

    for inc in contents:gmatch('<ProjectReference[^>]-Include%s*=%s*"([^"]+)"') do
        if inc:lower():match("%.vcxproj$") then
            table.insert(vcxproj_refs, (inc:gsub("/", "\\")))
        end
    end

    for inc in contents:gmatch('<Reference[^>]-Include%s*=%s*"([^"]+)"') do
        local name = trim((inc:match("^([^,]+)") or inc))
        if name ~= "" then existing_refs[name] = true end
    end

    return { vcxproj_refs = vcxproj_refs, existing_refs = existing_refs }
end

--- Compute a relative path from one directory to a file using backslash
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
        -- Remove the LAST segment (Lua 5.1 table.remove without index
        -- defaults to #t). Walking from the file's deepest dir up.
        table.remove(segments)
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

--- Return true if every `<HintPath>` in the given .user file points at a
--- file that currently exists. Relative paths resolve against `csproj_dir`.
--- An empty .user (no HintPaths) is treated as valid — nothing to break.
---
--- The regex accepts attributes on the opening tag (e.g.
--- `<HintPath Condition="...">x.dll</HintPath>`) — a real MSBuild idiom —
--- and trims surrounding whitespace from the captured path the way
--- MSBuild itself does.
---@param user_path string
---@param csproj_dir string
---@return boolean
function M._all_hint_paths_exist(user_path, csproj_dir)
    local content = read_file_safe(user_path)
    if not content then return false end
    for hp in content:gmatch("<HintPath[^>]*>([^<]+)</HintPath>") do
        local p = trim(hp)
        if p == "" then return false end
        if not p:match("^%a:[\\/]") and not p:match("^\\\\") then
            p = vim.fs.joinpath(csproj_dir, p)
        end
        p = vim.fs.normalize(p):gsub("/", "\\")
        if not file_exists(p) then return false end
    end
    return true
end

---@param csproj_path string
---@param user_path string
---@param csproj_dir? string  if provided, also regen when any HintPath in
---  the existing .user points at a file that no longer exists.
---@return boolean
function M._needs_regen(csproj_path, user_path, csproj_dir)
    local user_mt = mtime(user_path)
    if not user_mt then return true end
    local cs_mt = mtime(csproj_path)
    if cs_mt and cs_mt > user_mt then return true end
    if csproj_dir and not M._all_hint_paths_exist(user_path, csproj_dir) then
        return true
    end
    return false
end

---@param msbuild string
---@param vcxproj string
---@param config string
---@param platform string
---@param solution_dir string? if set, passed as -p:SolutionDir=... so the
---   vcxproj resolves its OutDir relative to the .sln (which is where the
---   DLL actually lands when built via the solution). Without it, MSBuild
---   reports the project's intrinsic standalone OutDir, which is usually
---   wrong because vcxprojs in a solution emit to $(SolutionDir)\... .
---@return string?
function M._query_vcxproj_output(msbuild, vcxproj, config, platform, solution_dir)
    local cmd = {
        msbuild, vcxproj, "-getTargetResult:GetTargetPath",
        "-p:Configuration=" .. config,
        "-p:Platform=" .. platform,
        "-nologo", "-noAutoResponse",
    }
    if solution_dir and solution_dir ~= "" then
        -- MSBuild requires SolutionDir to end in a backslash.
        local sd = solution_dir:gsub("/", "\\"):gsub("\\+$", "") .. "\\"
        table.insert(cmd, "-p:SolutionDir=" .. sd)
    end
    local res = vim.system(cmd, { text = true }):wait()
    if res.code ~= 0 then return nil end
    local ok, parsed = pcall(vim.json.decode, res.stdout or "")
    if not ok or type(parsed) ~= "table" then return nil end
    local items = parsed.TargetResults
        and parsed.TargetResults.GetTargetPath
        and parsed.TargetResults.GetTargetPath.Items
    if not items or #items == 0 then return nil end
    return items[1].FullPath or items[1].Identity
end

local NOISE_DIRS = {
    [".git"] = true, [".svn"] = true, [".hg"] = true, [".vs"] = true,
    bin = true, obj = true, node_modules = true,
    packages = true, [".idea"] = true, [".vscode"] = true,
}

local function skip_noise(name)
    return not NOISE_DIRS[name:lower()]
end

--- Count path separators in a relative entry, used to pick the shallowest
--- .sln when multiple exist.
local function depth_of(entry)
    local d = 0
    for _ in entry:gmatch("[/\\]") do d = d + 1 end
    return d
end

--- Walk the workspace tree. Collects csprojs, detects any vcxproj, and
--- returns every directory that contains a .sln/.slnx so each csproj can
--- later resolve its own nearest-ancestor solution.
---
--- sln_dirs is sorted (shallowest first, then alphabetically) so the
--- nearest-ancestor lookup is deterministic when two solutions sit at the
--- same depth.
---@param workspace_root string
---@return string[] csprojs, boolean has_vcxproj, string[] sln_dirs
function M._scan(workspace_root)
    local csprojs = {}
    local has_vcx = false
    local sln_dirs = {}
    for entry, t in vim.fs.dir(workspace_root, { depth = 64, skip = skip_noise }) do
        if t == "file" then
            local l = entry:lower()
            if l:match("%.csproj$") then
                table.insert(csprojs, vim.fs.joinpath(workspace_root, entry))
            elseif l:match("%.vcxproj$") then
                has_vcx = true
            elseif l:match("%.sln$") or l:match("%.slnx$") then
                local abs = vim.fs.joinpath(workspace_root, entry)
                table.insert(sln_dirs, vim.fs.dirname(abs))
            end
        end
    end
    table.sort(sln_dirs, function(a, b)
        local da, db = depth_of(a), depth_of(b)
        if da ~= db then return da < db end
        return a < b
    end)
    return csprojs, has_vcx, sln_dirs
end

local function scan_cached(workspace_root)
    local c = scan_cache[workspace_root]
    if c then return c.csprojs, c.has_vcx, c.sln_dirs end
    local csprojs, has_vcx, sln_dirs = M._scan(workspace_root)
    scan_cache[workspace_root] = {
        csprojs = csprojs, has_vcx = has_vcx, sln_dirs = sln_dirs,
    }
    return csprojs, has_vcx, sln_dirs
end

--- Pick the deepest .sln directory that is an ancestor of `csproj_path`.
--- Returns nil when no candidate is an ancestor — in that case the
--- vcxproj's standalone OutDir (no SolutionDir property) is the right
--- answer.
---@param csproj_path string
---@param sln_dirs string[]
---@return string?
function M._nearest_sln_dir(csproj_path, sln_dirs)
    if not sln_dirs or #sln_dirs == 0 then return nil end
    local cs = vim.fs.normalize(csproj_path):lower()
    local best, best_len = nil, -1
    for _, sd in ipairs(sln_dirs) do
        local n = vim.fs.normalize(sd):gsub("/+$", "")
        local probe = n:lower() .. "/"
        if cs:sub(1, #probe) == probe and #n > best_len then
            best, best_len = sd, #n
        end
    end
    return best
end

--- Ensure `.user` files are present and current for every csproj in the
--- workspace that pulls in a C++/CLI vcxproj.
---
--- Safe to call repeatedly. Most calls short-circuit through
--- `workspace_clean[workspace_root]` once a full pass found nothing to
--- regenerate. The cache is cleared whenever this function writes a .user
--- (so the next call re-verifies) and by `M.invalidate`.
---@param workspace_root string
---@param opts? { configuration?: string, platform?: string, msbuild?: string, solution_dir?: string }
---@return integer generated, integer skipped
function M.ensure(workspace_root, opts)
    opts = opts or {}
    if not workspace_root or workspace_root == "" then return 0, 0 end
    if workspace_clean[workspace_root] then return 0, 0 end

    local csprojs, has_vcx, sln_dirs = scan_cached(workspace_root)
    if not has_vcx then
        workspace_clean[workspace_root] = true
        return 0, 0
    end

    local msbuild = M._find_msbuild(opts.msbuild)
    if not msbuild then
        vim.notify(
            "cppcli_user_files: MSBuild.exe not found, skipping .user generation",
            vim.log.levels.WARN
        )
        return 0, 0 -- don't mark clean; user can install MSBuild + refresh
    end

    local config = opts.configuration or CONFIGURATION_DEFAULT
    local platform = opts.platform or PLATFORM_DEFAULT
    local generated, skipped = 0, 0
    -- Collect vcxprojs whose `GetTargetPath` query came back empty so we
    -- can both surface them and avoid poisoning workspace_clean with the
    -- failure. Without this, a single broken vcxproj would mark the
    -- workspace clean and Roslyn errors would persist with no in-editor
    -- signal until `:CppCliUserFilesRefresh`.
    local failed_vcx = {}

    for _, csproj in ipairs(csprojs) do
        local user_path = csproj .. ".user"
        local csproj_dir = vim.fs.dirname(csproj)
        if not M._needs_regen(csproj, user_path, csproj_dir) then
            skipped = skipped + 1
        else
            local content = read_file_safe(csproj)
            if content then
                local parsed = M._parse_csproj(content)
                if #parsed.vcxproj_refs > 0 then
                    -- Pick the deepest .sln/.slnx that is an ancestor of
                    -- THIS csproj. Different csprojs in a multi-solution
                    -- workspace can belong to different solutions.
                    local solution_dir = opts.solution_dir
                        or M._nearest_sln_dir(csproj, sln_dirs)
                    local entries = {}
                    for _, vcx_rel in ipairs(parsed.vcxproj_refs) do
                        local vcx_full = vim.fs.normalize(
                            vim.fs.joinpath(csproj_dir, vcx_rel))
                        vcx_full = vcx_full:gsub("/", "\\")
                        local dll = M._query_vcxproj_output(
                            msbuild, vcx_full, config, platform, solution_dir)
                        if dll then
                            local base = vim.fs.basename(dll)
                            local name = base:gsub("%.[Dd][Ll][Ll]$", "")
                            if not parsed.existing_refs[name] then
                                table.insert(entries, {
                                    name = name,
                                    hint = M._compute_relative_path(
                                        csproj_dir, dll),
                                })
                            end
                        else
                            table.insert(failed_vcx, vcx_full)
                        end
                    end
                    if #entries > 0 then
                        if write_file(user_path, M._build_user_xml(entries)) then
                            generated = generated + 1
                        end
                    end
                end
            end
        end
    end

    if #failed_vcx > 0 then
        vim.notify(
            "cppcli_user_files: GetTargetPath failed for "
                .. #failed_vcx .. " vcxproj(s): "
                .. table.concat(failed_vcx, ", ")
                .. ". Run :CppCliUserFilesRefresh after fixing to retry.",
            vim.log.levels.WARN
        )
    end

    -- A pass that wrote nothing AND had no failed queries means everything
    -- is up to date. Subsequent calls in this session can short-circuit.
    -- If anything was written OR any query failed, leave the flag unset so
    -- the next call re-verifies (and gives the user a chance to recover
    -- after fixing the broken vcxproj).
    if generated == 0 and #failed_vcx == 0 then
        workspace_clean[workspace_root] = true
    end
    return generated, skipped
end

--- Resolve the workspace root for a buffer (walking up from the buffer's
--- file looking for .sln/.slnx, then .csproj) and dispatch to `ensure`.
--- Used by both the FileType autocmd and the :CppCliUserFilesRefresh
--- user command.
---@param bufnr? integer  defaults to current buffer
---@param opts? table
---@return integer? generated, integer? skipped
function M.ensure_for_buffer(bufnr, opts)
    local fname = vim.api.nvim_buf_get_name(bufnr or 0)
    if fname == "" then return end
    fname = vim.fs.normalize(fname)
    local root = vim.fs.root(fname, function(name)
        return name:match("%.sln$") ~= nil or name:match("%.slnx$") ~= nil
    end) or vim.fs.root(fname, function(name)
        return name:match("%.csproj$") ~= nil
    end)
    if not root then return end
    return M.ensure(root, opts)
end

--- Drop the scan + clean caches. Pass a workspace root to invalidate just
--- that workspace; no argument clears all. Use the :CppCliUserFilesRefresh
--- command after adding/removing csprojs or vcxprojs mid-session.
---@param workspace_root? string
function M.invalidate(workspace_root)
    if workspace_root then
        scan_cache[workspace_root] = nil
        workspace_clean[workspace_root] = nil
    else
        scan_cache = {}
        workspace_clean = {}
    end
end

--- Test-only: clear in-memory caches.
function M._reset_for_test()
    msbuild_cache = nil
    scan_cache = {}
    workspace_clean = {}
end

return M
