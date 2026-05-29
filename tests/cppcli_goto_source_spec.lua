-- Tests for lars.cppcli_goto_source — the `gd`/`gD` redirect that takes
-- Roslyn MetadataAsSource decompilation results and rewrites them to the
-- real C++/CLI source.
--
-- Pure-logic helpers and rg-runner-stubbed flows. No real rg spawns.

local m = require("lars.cppcli_goto_source")
local user_files = require("lars.cppcli_user_files")

describe("cppcli_goto_source.is_metadata_as_source", function()
    local tmpdir

    before_each(function()
        tmpdir = vim.fn.tempname()
        vim.fn.mkdir(tmpdir, "p")
    end)

    after_each(function()
        pcall(vim.fn.delete, tmpdir, "rf")
    end)

    --- Write a decompiled-style file mimicking Roslyn's MetadataAsSource
    --- header layout and return its path.
    local function make_decompiled(asm, opts)
        opts = opts or {}
        local dir = tmpdir
            .. "/MetadataAsSource/h1/DecompilationMetadataAsSourceFileProvider/h2"
        vim.fn.mkdir(dir, "p")
        local p = dir .. "/" .. asm .. ".cs"
        local f = io.open(p, "w")
        if opts.skip_region then
            f:write("// C:\\path\\to\\" .. asm .. ".dll\n")
            f:write("// Decompiled with ICSharpCode.Decompiler\n")
        else
            f:write("#region Assembly " .. asm
                .. ", Version=0.0.0.0, Culture=neutral, PublicKeyToken=null\n")
            f:write("// C:\\path\\to\\" .. asm .. ".dll\n")
            f:write("// Decompiled with ICSharpCode.Decompiler\n")
            f:write("#endregion\n\n")
            f:write("namespace " .. asm .. " { }\n")
        end
        f:close()
        return p
    end

    it("extracts the asm name from the #region Assembly header", function()
        local p = make_decompiled("CliWrapper")
        assert.equals("CliWrapper", m.is_metadata_as_source(p))
    end)

    it("falls back to the DLL comment line when #region is absent", function()
        local p = make_decompiled("CliWrapper", { skip_region = true })
        assert.equals("CliWrapper", m.is_metadata_as_source(p))
    end)

    it("returns nil for a path missing the MetadataAsSource segment", function()
        local p = tmpdir .. "/regular.cs"
        local f = io.open(p, "w"); f:write("// nothing"); f:close()
        assert.is_nil(m.is_metadata_as_source(p))
    end)

    it("returns nil for a SourceLink-style path", function()
        local p = tmpdir .. "/SourceLink/abc/src/Foo.cs"
        vim.fn.mkdir(vim.fs.dirname(p), "p")
        local f = io.open(p, "w"); f:write("// foo"); f:close()
        assert.is_nil(m.is_metadata_as_source(p))
    end)

    it("returns nil for a non-existent file under MetadataAsSource", function()
        assert.is_nil(m.is_metadata_as_source(
            tmpdir .. "/MetadataAsSource/h/P/Ghost.cs"))
    end)

    it("returns nil for empty / nil input", function()
        assert.is_nil(m.is_metadata_as_source(""))
        assert.is_nil(m.is_metadata_as_source(nil))
    end)

    it("is case-insensitive on the path segment", function()
        local p = tmpdir
            .. "/metadataassource/h1/DecompilationMetadataAsSourceFileProvider/h2/Foo.cs"
        vim.fn.mkdir(vim.fs.dirname(p), "p")
        local f = io.open(p, "w")
        f:write("#region Assembly Foo, Version=0.0.0.0\n")
        f:close()
        assert.equals("Foo", m.is_metadata_as_source(p))
    end)
end)

describe("cppcli_goto_source._parse_vimgrep", function()
    it("parses a typical rg --vimgrep line", function()
        local line = "D:/proj/CliWrapper/Calc.cpp:42:7:void ManagedCalculator::Add(int a, int b)"
        local item = m._parse_vimgrep(line)
        assert.equals("D:/proj/CliWrapper/Calc.cpp", item.filename)
        assert.equals(42, item.lnum)
        assert.equals(7, item.col)
        assert.equals("void ManagedCalculator::Add(int a, int b)", item.text)
    end)

    it("handles Windows drive-letter colons correctly", function()
        local line = "C:\\Users\\X\\proj\\Foo.h:10:1:ref class Foo"
        local item = m._parse_vimgrep(line)
        assert.equals("C:\\Users\\X\\proj\\Foo.h", item.filename)
        assert.equals(10, item.lnum)
        assert.equals(1, item.col)
    end)

    it("returns nil for malformed input", function()
        assert.is_nil(m._parse_vimgrep(""))
        assert.is_nil(m._parse_vimgrep("no colons at all"))
        assert.is_nil(m._parse_vimgrep("only:two:colons"))
    end)

    it("preserves text containing colons after the col field", function()
        local line = "D:/p/F.cpp:1:1:foo: bar: baz"
        local item = m._parse_vimgrep(line)
        assert.equals("foo: bar: baz", item.text)
    end)
end)

describe("cppcli_goto_source._build_rg_args", function()
    it("escapes regex metacharacters in the symbol", function()
        local args = m._build_rg_args("/some/dir", "Foo+Bar")
        local joined = table.concat(args, " ")
        assert.is_truthy(joined:find("Foo\\+Bar", 1, true))
    end)

    it("includes the C++/CLI patterns and globs to h/hpp/cpp", function()
        local args = m._build_rg_args("/some/dir", "Sym")
        local joined = table.concat(args, " ")
        assert.is_truthy(joined:find("ref class", 1, true))
        assert.is_truthy(joined:find("value class", 1, true))
        -- qualified definition: `Foo::Sym(`
        assert.is_truthy(joined:find("\\w+\\s*::\\s*Sym\\s*\\(", 1, true))
        -- preceded by return-type word: `int Sym(`
        assert.is_truthy(joined:find("\\b\\w+\\s+Sym\\s*\\(", 1, true))
        assert.is_truthy(joined:find("property", 1, true))
        assert.is_truthy(joined:find("*.h", 1, true))
        assert.is_truthy(joined:find("*.hpp", 1, true))
        assert.is_truthy(joined:find("*.cpp", 1, true))
    end)

    it("ends with the target directory", function()
        local args = m._build_rg_args("/some/dir", "Sym")
        assert.equals("/some/dir", args[#args])
    end)
end)

describe("cppcli_goto_source.find_definition", function()
    local vcxproj_dir = "D:/repo/CliWrapper"

    before_each(function()
        user_files._reset_for_test()
        m._reset_for_test()
        -- Pretend the resolver always succeeds, pointing at vcxproj_dir.
        user_files.find_vcxproj_dir_for_assembly = function(_, _) return vcxproj_dir end
    end)

    local function set_rg_output(stdout, code)
        m._set_rg_runner(function(_)
            return { stdout = stdout, code = code or 0 }
        end)
    end

    it("returns only .cpp hits when prefer='cpp' and .cpp hits exist", function()
        set_rg_output(table.concat({
            "D:/repo/CliWrapper/Calc.cpp:42:7:void Foo::Bar(int)",
            "D:/repo/CliWrapper/Calc.h:10:14:void Bar(int);",
        }, "\n"))
        local hits = m.find_definition("Bar", "CliWrapper", "D:/repo", "cpp")
        assert.equals(1, #hits)
        assert.is_truthy(hits[1].filename:match("%.cpp$"))
    end)

    it("returns only header hits when prefer='header' and headers exist", function()
        set_rg_output(table.concat({
            "D:/repo/CliWrapper/Calc.cpp:42:7:void Foo::Bar(int)",
            "D:/repo/CliWrapper/Calc.h:10:14:void Bar(int);",
            "D:/repo/CliWrapper/Calc.hpp:1:1:struct Helper { void Bar() {} };",
        }, "\n"))
        local hits = m.find_definition("Bar", "CliWrapper", "D:/repo", "header")
        assert.equals(2, #hits)
        for _, h in ipairs(hits) do
            assert.is_truthy(h.filename:lower():match("%.hp?p?$"))
        end
    end)

    it("falls back to header hits when prefer='cpp' but no .cpp hits", function()
        set_rg_output("D:/repo/CliWrapper/Foo.h:5:1:ref class Bar")
        local hits = m.find_definition("Bar", "CliWrapper", "D:/repo", "cpp")
        assert.equals(1, #hits)
        assert.is_truthy(hits[1].filename:match("%.h$"))
    end)

    it("falls back to .cpp hits when prefer='header' but no header hits", function()
        set_rg_output("D:/repo/CliWrapper/Foo.cpp:5:1:void Bar::M() {}")
        local hits = m.find_definition("Bar", "CliWrapper", "D:/repo", "header")
        assert.equals(1, #hits)
        assert.is_truthy(hits[1].filename:match("%.cpp$"))
    end)

    it("returns an empty list when rg finds nothing", function()
        set_rg_output("", 1) -- rg exit code 1 == no matches
        local hits = m.find_definition("NoSuchSym", "CliWrapper", "D:/repo", "cpp")
        assert.same({}, hits)
    end)

    it("returns empty when the resolver can't find the vcxproj", function()
        user_files.find_vcxproj_dir_for_assembly = function(_, _) return nil end
        local hits = m.find_definition("Sym", "GhostAsm", "D:/repo", "cpp")
        assert.same({}, hits)
    end)

    it("returns empty for an empty symbol", function()
        assert.same({}, m.find_definition("", "X", "D:/repo", "cpp"))
    end)
end)

describe("cppcli_goto_source.intercept", function()
    local original_show
    local original_setqf
    local original_cmd
    local original_notify
    local captured

    before_each(function()
        user_files._reset_for_test()
        m._reset_for_test()
        captured = { setqflist = nil, edit = nil, notify = nil, cmds = {} }

        original_show = vim.lsp.util.show_document
        original_setqf = vim.fn.setqflist
        original_cmd = vim.cmd
        original_notify = vim.notify

        vim.lsp.util.show_document = function(loc, _)
            captured.show_doc = loc
            return true
        end
        vim.fn.setqflist = function(_, _, ctx)
            captured.setqflist = ctx
        end
        vim.notify = function(msg, _)
            captured.notify = msg
        end
        -- Intercept :edit / :cfirst / :copen so the test never actually
        -- opens a buffer or window.
        vim.cmd = setmetatable({}, {
            __call = function(_, c)
                table.insert(captured.cmds, c)
            end,
            __index = function(_, k)
                return function(...) table.insert(captured.cmds, k) end
            end,
        })
    end)

    after_each(function()
        vim.lsp.util.show_document = original_show
        vim.fn.setqflist = original_setqf
        vim.cmd = original_cmd
        vim.notify = original_notify
    end)

    local function stub_resolver_returning(hits)
        -- Make _workspace_root_for_buffer succeed without a real buffer name.
        m._workspace_root_for_buffer = function(_) return "D:/repo" end
        -- Stub the asm-name extractor so the intercept tests can use
        -- synthetic paths without writing real decompiled-style files.
        m.is_metadata_as_source = function(path)
            if path and path:find("MetadataAsSource", 1, true) then
                return "CliWrapper"
            end
            return nil
        end
        user_files.find_vcxproj_dir_for_assembly = function(_, _) return "D:/repo/CliWrapper" end
        m._set_rg_runner(function(_)
            local lines = {}
            for _, h in ipairs(hits) do
                table.insert(lines, string.format("%s:%d:%d:%s",
                    h.filename, h.lnum, h.col, h.text or ""))
            end
            return { stdout = table.concat(lines, "\n"), code = #hits == 0 and 1 or 0 }
        end)
    end

    it("rewrites a single MetadataAsSource hit to a single C++/CLI source jump", function()
        stub_resolver_returning({
            { filename = "D:/repo/CliWrapper/Calc.cpp", lnum = 42, col = 5, text = "void X::Add(int a, int b) {}" },
        })
        local cb = m.intercept("Add", "cpp")
        cb({
            items = {
                { filename = "C:/Temp/MetadataAsSource/hash/CliWrapper/X.cs", lnum = 10, col = 1 },
            },
            context = {},
        })

        local edited = false
        for _, c in ipairs(captured.cmds) do
            if type(c) == "string" and c:match("^edit ") and c:match("Calc%.cpp") then
                edited = true
            end
        end
        assert.is_true(edited)
        assert.is_nil(captured.setqflist)
    end)

    it("pushes multiple hits to a quickfix list and opens it", function()
        stub_resolver_returning({
            { filename = "D:/repo/CliWrapper/A.cpp", lnum = 1, col = 1, text = "a" },
            { filename = "D:/repo/CliWrapper/B.cpp", lnum = 2, col = 2, text = "b" },
        })
        local cb = m.intercept("M", "cpp")
        cb({
            items = {
                { filename = "C:/Temp/MetadataAsSource/h/CliWrapper/X.cs", lnum = 5, col = 1 },
            },
            context = {},
        })
        assert.is_not_nil(captured.setqflist)
        assert.equals(2, #captured.setqflist.items)
        local saw_cfirst, saw_copen = false, false
        for _, c in ipairs(captured.cmds) do
            if c == "cfirst" then saw_cfirst = true end
            if c == "copen" then saw_copen = true end
        end
        assert.is_true(saw_cfirst)
        assert.is_true(saw_copen)
    end)

    it("falls through to the MetadataAsSource stub when the resolver finds nothing", function()
        m._workspace_root_for_buffer = function(_) return "D:/repo" end
        m.is_metadata_as_source = function(_) return "Ghost" end -- a valid MaS hit
        user_files.find_vcxproj_dir_for_assembly = function(_, _) return nil end
        local cb = m.intercept("Ghost", "cpp")
        cb({
            items = {
                { filename = "C:/Temp/MetadataAsSource/h/Ghost/X.cs", lnum = 1, col = 1 },
            },
            context = {},
        })
        -- The single fallthrough item is the MaS stub itself.
        local edited_meta = false
        for _, c in ipairs(captured.cmds) do
            if type(c) == "string" and c:match("MetadataAsSource") then
                edited_meta = true
            end
        end
        assert.is_true(edited_meta)
    end)

    it("passes non-MetadataAsSource items through unchanged", function()
        local cb = m.intercept("Foo", "cpp")
        cb({
            items = {
                { filename = "D:/repo/src/Real.cs", lnum = 3, col = 4 },
            },
            context = {},
        })
        local edited_real = false
        for _, c in ipairs(captured.cmds) do
            if type(c) == "string" and c:match("Real%.cs") then
                edited_real = true
            end
        end
        assert.is_true(edited_real)
    end)

    it("notifies and bails when the LSP reported no locations", function()
        local cb = m.intercept("Foo", "cpp")
        cb({ items = {}, context = {} })
        assert.is_truthy(captured.notify)
    end)
end)

