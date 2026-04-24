-- Project-level build system detection
-- Reads the Makefile in cwd to determine which compiler(s)
-- errorformat to use, combining them when multiple tools are present.
-- Follows $(MAKE) -C / make -C delegations to subfolder Makefiles.

local M = {}

-- Cache: cwd -> true (already configured for this directory)
M._cache = {}

--- Detection rules: ordered list of { pattern, compiler_name }.
--- All matches are collected; their errorformats are combined.
M.rules = {
    { "cargo",   "cargo" },
    { "dotnet",  "dotnet" },
    { "msbuild", "msbuild" },
    { "MSBuild", "msbuild" },
    { "gcc",     "gcc" },
    { "g++",     "gcc" },
    { "cmake",   "gcc" },
}

--- Maximum depth for following -C delegations.
M.max_depth = 5

--- Find a Makefile in the given directory.
---@param dir string directory to search
---@return string|nil path to Makefile or nil
function M.find_makefile(dir)
    for _, name in ipairs({ "GNUmakefile", "Makefile", "makefile" }) do
        local candidate = dir .. "/" .. name
        if vim.fn.filereadable(candidate) == 1 then
            return candidate
        end
    end
    return nil
end

--- Read and resolve a Makefile, following -C delegations.
--- Returns the content of the final Makefile that contains actual build commands.
---@param dir string directory containing the Makefile
---@param depth number current recursion depth
---@return string content of the resolved Makefile
function M.resolve(dir, depth)
    depth = depth or 0
    local makefile_path = M.find_makefile(dir)
    if not makefile_path then
        return ""
    end

    local lines = vim.fn.readfile(makefile_path)
    local content = table.concat(lines, "\n")

    if depth >= M.max_depth then
        return content
    end

    -- Look for $(MAKE) -C <dir> or make -C <dir> delegations
    local subdir = content:match("%$%(MAKE%)%s+%-C%s+(%S+)")
        or content:match("make%s+%-C%s+(%S+)")
    if subdir then
        -- Resolve relative to current Makefile's directory
        local resolved_dir = dir .. "/" .. subdir
        local sub_content = M.resolve(resolved_dir, depth + 1)
        if sub_content ~= "" then
            return sub_content
        end
    end

    return content
end

--- Detect all matching compilers from Makefile content.
---@param content string the joined Makefile content
---@return string[] list of unique compiler names found (in rule order)
function M.detect(content)
    local seen = {}
    local compilers = {}
    for _, rule in ipairs(M.rules) do
        if content:find(rule[1], 1, true) and not seen[rule[2]] then
            seen[rule[2]] = true
            compilers[#compilers + 1] = rule[2]
        end
    end
    if #compilers == 0 then
        compilers[1] = "make"
    end
    return compilers
end

--- Extra errorformat patterns appended when a compiler is detected.
--- Keyed by compiler name.
M.extra_errorformat = {
    -- dotnet test failure output: "Failed TestName [xx ms]" + stack trace with file:line
    dotnet = table.concat({
        "%E\\ %#Failed\\ %m\\ [%.%#]",       -- "  Failed TestName [42 ms]" → error
        "%C\\ %#at\\ %.%#\\ in\\ %f:line\\ %l", -- "   at Ns.Class.Method() in file.cs:line 42"
        "%Z",                                  -- end of multi-line entry
    }, ","),
}

--- Collect the errorformat for a compiler by temporarily loading it.
---@param name string compiler name
---@return string errorformat value
function M.get_errorformat(name)
    local saved = vim.o.errorformat
    vim.cmd("compiler " .. name)
    local efm = vim.o.errorformat
    vim.o.errorformat = saved
    -- Prepend extra patterns if defined (before catch-all %-G%.%# rules)
    local extra = M.extra_errorformat[name]
    if extra then
        efm = extra .. "," .. efm
    end
    return efm
end

--- Apply compiler detection based on Makefile in cwd.
function M.apply()
    local cwd = vim.fn.getcwd()

    -- Already configured for this cwd
    if M._cache[cwd] then
        return
    end

    local content = M.resolve(cwd, 0)
    if content == "" then
        M._cache[cwd] = true
        return
    end

    local compilers = M.detect(content)

    -- Collect and combine errorformats from all detected compilers
    local combined = {}
    for _, name in ipairs(compilers) do
        combined[#combined + 1] = M.get_errorformat(name)
    end

    vim.opt.makeprg = "make"
    vim.o.errorformat = table.concat(combined, ",")

    M._cache[cwd] = true
end

--- Set up the autocommand for compiler detection.
function M.setup()
    vim.api.nvim_create_autocmd("QuickFixCmdPre", {
        group = vim.api.nvim_create_augroup("LarsCompilerDetect", { clear = true }),
        pattern = "make",
        callback = function()
            -- Clear cache so we always pick up Makefile changes
            M._cache = {}
            M.apply()
        end,
    })
end

M.setup()

return M
