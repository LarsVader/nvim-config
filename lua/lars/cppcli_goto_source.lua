-- Intercept `gd` / `gD` results in C# buffers when Roslyn would land on a
-- MetadataAsSource synthetic stub for a C++/CLI assembly. Redirect to the
-- real `.cpp` / `.h` source in the workspace's matching vcxproj instead.
--
-- High level (full design in plans/i-would-like-to-mossy-reef.md):
--   1. Roslyn returns a Location whose path contains `/MetadataAsSource/`.
--   2. Extract `<AssemblyName>` from that path.
--   3. Use `cppcli_user_files.find_vcxproj_dir_for_assembly` to find the
--      vcxproj directory whose output DLL matches.
--   4. `rg --vimgrep` the vcxproj dir for the cursor symbol with a small
--      set of C++/CLI-aware patterns (ref class, value class, T::method(,
--      property).
--   5. Filter the hits by extension based on which key was pressed:
--      `gd` prefers `.cpp` (definitions); `gD` prefers `.h`/`.hpp`
--      (declarations). Fall back to the other set if the preferred is empty.
--   6. 0 results overall -> call the default `on_list` so Roslyn's
--      decompiled stub still opens (no C++/CLI source available).
--      1 result -> show_document. 2+ results -> quickfix list.

local user_files = require("lars.cppcli_user_files")

local M = {}

-- Test seam: replace with a function `fn(args) -> { stdout = "..." }` to
-- avoid spawning `rg` in unit tests. Default uses `vim.system`.
local rg_runner = nil

local function default_rg_runner(args)
    return vim.system(args, { text = true }):wait()
end

--- Returns the assembly simple name if `path` looks like a Roslyn
--- MetadataAsSource decompilation target, otherwise nil.
---
--- Roslyn's path structure is
---   .../MetadataAsSource/<provider-hash>/DecompilationMetadataAsSourceFileProvider/<asm-hash>/<Type>.cs
--- — the assembly name is NOT in the path. It lives in the
--- `#region Assembly <name>, Version=...` line at the top of the file.
--- We do a cheap path pre-filter for the literal `MetadataAsSource`
--- segment and then read the file header to extract the real assembly
--- name (falling back to the `// <path>\<asm>.dll` comment line that
--- Roslyn emits right after the region header).
---@param path string
---@return string?
function M.is_metadata_as_source(path)
    if not path or path == "" then return nil end
    local norm = path:gsub("\\", "/"):lower()
    if not norm:find("/metadataassource/", 1, true) then return nil end
    local f = io.open(path, "r")
    if not f then return nil end
    local asm = nil
    local dll_fallback = nil
    for _ = 1, 20 do
        local line = f:read("*l")
        if not line then break end
        local m_asm = line:match("^#region%s+Assembly%s+([^,%s]+)")
        if m_asm then
            asm = m_asm
            break
        end
        if not dll_fallback then
            local d = line:match("^//%s*.-([^/\\]+)%.[Dd][Ll][Ll]%s*$")
            if d then dll_fallback = d end
        end
    end
    f:close()
    return asm or dll_fallback
end

--- Build the rg argument vector for a symbol search inside `dir`.
--- Multiple `-e` patterns are passed in a single invocation so we only
--- spawn the process once. Globbed to C++ source files.
---
--- Patterns (S = escaped symbol):
---   1. `ref class S`           — managed reference-class declaration
---   2. `value class S`         — managed value-class declaration
---   3. `\w+\s*::\s*S\s*\(`     — qualified method definition (`Foo::S(`)
---   4. `\w+\s+S\s*\(`          — preceded by a word + space — catches
---      declarations like `int S(...)`, `static int S(...)`, inline
---      definitions like `static int S(...) { ... }`. Skips bare call
---      sites like `S(1, 2)` and scope-qualified calls `Bar::S(...)`.
---   5. `property ... S`        — CLI property declarations.
---@param dir string
---@param symbol string
---@return string[]
local function build_rg_args(dir, symbol)
    local s = symbol:gsub("([^%w_])", "\\%1") -- escape regex metachars
    return {
        "rg", "--vimgrep", "--no-heading", "--color=never",
        "-g", "*.h", "-g", "*.hpp", "-g", "*.cpp",
        "-e", "\\bref class\\s+" .. s .. "\\b",
        "-e", "\\bvalue class\\s+" .. s .. "\\b",
        "-e", "\\w+\\s*::\\s*" .. s .. "\\s*\\(",
        "-e", "\\b\\w+\\s+" .. s .. "\\s*\\(",
        "-e", "\\bproperty\\s+[\\w:<>,\\s\\*&]+\\s+" .. s .. "\\b",
        dir,
    }
end

--- Parse a single `rg --vimgrep` line: `path:line:col:text`.
--- Walks left-to-right and finds the first three colons after any
--- Windows drive-letter prefix (e.g. `D:`). The match text often contains
--- C++ scope-resolution `::`, so finding-from-the-right doesn't work.
---@param line string
---@return { filename: string, lnum: integer, col: integer, text: string }?
local function parse_vimgrep(line)
    if not line or line == "" then return nil end
    local search_from = 1
    if line:sub(2, 2) == ":" and line:sub(1, 1):match("[A-Za-z]") then
        search_from = 3 -- skip the drive-letter colon
    end
    local p1 = line:find(":", search_from, true)
    if not p1 then return nil end
    local p2 = line:find(":", p1 + 1, true)
    if not p2 then return nil end
    local p3 = line:find(":", p2 + 1, true)
    if not p3 then return nil end
    local filename = line:sub(1, p1 - 1)
    local lnum = tonumber(line:sub(p1 + 1, p2 - 1))
    local col = tonumber(line:sub(p2 + 1, p3 - 1))
    if not lnum or not col then return nil end
    return {
        filename = filename,
        lnum = lnum,
        col = col,
        text = line:sub(p3 + 1),
    }
end

--- Search the vcxproj dir for the symbol and return hits filtered by the
--- preferred extension. `prefer` is `"cpp"` or `"header"`. Falls back to
--- the other set when the preferred set is empty.
---@param symbol string
---@param asm_name string
---@param workspace_root string
---@param prefer "cpp" | "header"
---@return { filename: string, lnum: integer, col: integer, text: string }[]
function M.find_definition(symbol, asm_name, workspace_root, prefer)
    if not symbol or symbol == "" then return {} end
    local dir = user_files.find_vcxproj_dir_for_assembly(workspace_root, asm_name)
    if not dir then return {} end

    local runner = rg_runner or default_rg_runner
    local args = build_rg_args(dir, symbol)
    local res = runner(args)
    if not res or res.code ~= 0 and res.code ~= 1 then return {} end
    -- rg returns 1 on "no matches"; treat as empty rather than failure.
    if not res.stdout or res.stdout == "" then return {} end

    local cpp_hits, hdr_hits = {}, {}
    for line in res.stdout:gmatch("[^\r\n]+") do
        local item = parse_vimgrep(line)
        if item then
            local ext = item.filename:lower():match("%.([^.]+)$")
            if ext == "cpp" then
                table.insert(cpp_hits, item)
            elseif ext == "h" or ext == "hpp" then
                table.insert(hdr_hits, item)
            end
        end
    end

    if prefer == "cpp" then
        if #cpp_hits > 0 then return cpp_hits end
        return hdr_hits
    else
        if #hdr_hits > 0 then return hdr_hits end
        return cpp_hits
    end
end

--- Build the `on_list` callback for `vim.lsp.buf.definition({ on_list=... })`.
--- Captures `symbol` (the `<cword>` from the keypress site, before the LSP
--- request) and `prefer`. Mutates MetadataAsSource items: replaces each
--- with C++/CLI source hits when the resolver finds matches; passes other
--- items through; falls through to Roslyn's stub when no MetadataAsSource
--- item could be resolved.
---@param symbol string
---@param prefer "cpp" | "header"
---@return fun(list: table)
function M.intercept(symbol, prefer)
    return function(list)
        if not list or not list.items or #list.items == 0 then
            -- Mirror nvim's default "no location" behavior.
            vim.notify("No definition found", vim.log.levels.INFO)
            return
        end

        local replaced_any = false
        local out = {}
        for _, item in ipairs(list.items) do
            local fname = item.filename or ""
            local asm = M.is_metadata_as_source(fname)
            if asm then
                local root = M._workspace_root_for_buffer(0)
                if root then
                    local hits = M.find_definition(symbol, asm, root, prefer)
                    if #hits > 0 then
                        replaced_any = true
                        for _, h in ipairs(hits) do
                            table.insert(out, {
                                filename = h.filename,
                                lnum = h.lnum,
                                col = h.col,
                                text = h.text or "",
                            })
                        end
                    else
                        -- Couldn't find a C++/CLI source for this MaS hit;
                        -- keep the stub as a fallback so the user still
                        -- lands somewhere.
                        table.insert(out, item)
                    end
                else
                    table.insert(out, item)
                end
            else
                table.insert(out, item)
            end
        end

        if #out == 0 then
            vim.notify("No definition found", vim.log.levels.INFO)
            return
        end

        if #out == 1 then
            local it = out[1]
            vim.cmd("edit " .. vim.fn.fnameescape(it.filename))
            pcall(vim.api.nvim_win_set_cursor, 0,
                { it.lnum or 1, math.max((it.col or 1) - 1, 0) })
            return
        end

        vim.fn.setqflist({}, " ", {
            title = "lsp: definition"
                .. (replaced_any and " (C++/CLI redirect)" or ""),
            items = out,
        })
        vim.cmd("cfirst")
        vim.cmd("copen")
    end
end

--- Resolve the workspace root for a buffer the same way the .user
--- generator does (walk up for .sln/.slnx, then .csproj).
---@param bufnr integer
---@return string?
function M._workspace_root_for_buffer(bufnr)
    local fname = vim.api.nvim_buf_get_name(bufnr)
    if fname == "" then return nil end
    fname = vim.fs.normalize(fname)
    return vim.fs.root(fname, function(name)
        return name:match("%.sln$") ~= nil or name:match("%.slnx$") ~= nil
    end) or vim.fs.root(fname, function(name)
        return name:match("%.csproj$") ~= nil
    end)
end

--- Test seam: install a stub for the rg runner. Pass nil to restore.
---@param fn? fun(args: string[]): { stdout: string?, code: integer? }
function M._set_rg_runner(fn)
    rg_runner = fn
end

-- Originals captured AFTER all the M.<...> assignments above run, so
-- _reset_for_test can restore them when tests monkey-patch the surface.
local original_is_metadata_as_source = M.is_metadata_as_source
local original_workspace_root_for_buffer = M._workspace_root_for_buffer
local original_find_definition = M.find_definition

--- Test seam: clear any installed rg-runner stub AND restore the public
--- functions that tests commonly monkey-patch (is_metadata_as_source,
--- _workspace_root_for_buffer, find_definition).
function M._reset_for_test()
    rg_runner = nil
    M.is_metadata_as_source = original_is_metadata_as_source
    M._workspace_root_for_buffer = original_workspace_root_for_buffer
    M.find_definition = original_find_definition
end

--- Test seam: parse a single rg --vimgrep line (exposed for testing).
M._parse_vimgrep = parse_vimgrep

--- Test seam: build rg args (exposed for testing).
M._build_rg_args = build_rg_args

return M
