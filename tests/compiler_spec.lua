-- Tests for lua/lars/compiler.lua

local helpers = dofile(vim.fn.stdpath("config") .. "/tests/helpers.lua")

describe("compiler detection", function()
    local compiler = require("lars.compiler")

    describe("detect()", function()
        it("detects cargo", function()
            assert.same({ "cargo" }, compiler.detect("all:\n\tcargo build --release"))
        end)

        it("detects dotnet", function()
            assert.same({ "dotnet" }, compiler.detect("build:\n\tdotnet build"))
        end)

        it("detects msbuild (lowercase)", function()
            assert.same({ "msbuild" }, compiler.detect("build:\n\tmsbuild /p:Configuration=Release"))
        end)

        it("detects MSBuild (uppercase)", function()
            assert.same({ "msbuild" }, compiler.detect("build:\n\tMSBuild.exe Solution.sln"))
        end)

        it("detects gcc", function()
            assert.same({ "gcc" }, compiler.detect("main.o:\n\tgcc -c main.c"))
        end)

        it("detects g++", function()
            assert.same({ "gcc" }, compiler.detect("main.o:\n\tg++ -c main.cpp"))
        end)

        it("detects cmake and maps to gcc", function()
            assert.same({ "gcc" }, compiler.detect("build:\n\tcmake --build ."))
        end)

        it("falls back to make when no tool is recognized", function()
            assert.same({ "make" }, compiler.detect("all:\n\techo hello"))
        end)

        it("returns multiple compilers when multiple tools present", function()
            local result = compiler.detect("all:\n\tcargo build\n\tdotnet test")
            assert.same({ "cargo", "dotnet" }, result)
        end)

        it("returns multiple - dotnet and gcc", function()
            local result = compiler.detect("all:\n\tdotnet build\n\tgcc -o main main.c")
            assert.same({ "dotnet", "gcc" }, result)
        end)

        it("deduplicates compiler names (gcc and g++ both map to gcc)", function()
            local result = compiler.detect("all:\n\tgcc -c main.c\n\tg++ -c app.cpp")
            assert.same({ "gcc" }, result)
        end)

        it("deduplicates msbuild and MSBuild", function()
            local result = compiler.detect("all:\n\tmsbuild foo.sln\n\tMSBuild bar.sln")
            assert.same({ "msbuild" }, result)
        end)

        it("returns all three when cargo, dotnet, and gcc present", function()
            local result = compiler.detect("build:\n\tcargo build\ntest:\n\tdotnet test\ncc:\n\tgcc -c")
            assert.same({ "cargo", "dotnet", "gcc" }, result)
        end)
    end)

    describe("rules", function()
        it("has expected number of rules", function()
            assert.equals(7, #compiler.rules)
        end)

        it("cargo is first priority", function()
            assert.equals("cargo", compiler.rules[1][1])
        end)
    end)

    describe("resolve()", function()
        it("reads Makefile content from directory", function()
            local tmpdir = vim.fn.tempname()
            vim.fn.mkdir(tmpdir, "p")
            vim.fn.writefile({ "all:", "\tcargo build" }, tmpdir .. "/Makefile")

            local content = compiler.resolve(tmpdir, 0)
            assert.is_true(content:find("cargo") ~= nil)

            vim.fn.delete(tmpdir, "rf")
        end)

        it("reads GNUmakefile", function()
            local tmpdir = vim.fn.tempname()
            vim.fn.mkdir(tmpdir, "p")
            vim.fn.writefile({ "all:", "\tdotnet build" }, tmpdir .. "/GNUmakefile")

            local content = compiler.resolve(tmpdir, 0)
            assert.is_true(content:find("dotnet") ~= nil)

            vim.fn.delete(tmpdir, "rf")
        end)

        it("prefers GNUmakefile over Makefile", function()
            local tmpdir = vim.fn.tempname()
            vim.fn.mkdir(tmpdir, "p")
            vim.fn.writefile({ "all:", "\tcargo build" }, tmpdir .. "/GNUmakefile")
            vim.fn.writefile({ "all:", "\tdotnet build" }, tmpdir .. "/Makefile")

            local content = compiler.resolve(tmpdir, 0)
            assert.is_true(content:find("cargo") ~= nil)

            vim.fn.delete(tmpdir, "rf")
        end)

        it("follows $(MAKE) -C delegation to subfolder", function()
            local tmpdir = vim.fn.tempname()
            vim.fn.mkdir(tmpdir, "p")
            vim.fn.mkdir(tmpdir .. "/subproject", "p")
            vim.fn.writefile({ "all:", "\t$(MAKE) -C subproject" }, tmpdir .. "/Makefile")
            vim.fn.writefile({ "build:", "\tdotnet build" }, tmpdir .. "/subproject/Makefile")

            local content = compiler.resolve(tmpdir, 0)
            assert.is_true(content:find("dotnet") ~= nil)

            vim.fn.delete(tmpdir, "rf")
        end)

        it("follows make -C delegation to subfolder", function()
            local tmpdir = vim.fn.tempname()
            vim.fn.mkdir(tmpdir, "p")
            vim.fn.mkdir(tmpdir .. "/src", "p")
            vim.fn.writefile({ "all:", "\tmake -C src" }, tmpdir .. "/Makefile")
            vim.fn.writefile({ "build:", "\tgcc -o main main.c" }, tmpdir .. "/src/Makefile")

            local content = compiler.resolve(tmpdir, 0)
            assert.is_true(content:find("gcc") ~= nil)

            vim.fn.delete(tmpdir, "rf")
        end)

        it("returns empty string when no Makefile exists", function()
            local tmpdir = vim.fn.tempname()
            vim.fn.mkdir(tmpdir, "p")

            local content = compiler.resolve(tmpdir, 0)
            assert.equals("", content)

            vim.fn.delete(tmpdir, "rf")
        end)

        it("falls back to parent Makefile when delegation target has no Makefile", function()
            local tmpdir = vim.fn.tempname()
            vim.fn.mkdir(tmpdir, "p")
            vim.fn.mkdir(tmpdir .. "/missing", "p")
            vim.fn.writefile({ "all:", "\t$(MAKE) -C missing", "\tcargo build" }, tmpdir .. "/Makefile")

            local content = compiler.resolve(tmpdir, 0)
            assert.is_true(content:find("cargo") ~= nil)

            vim.fn.delete(tmpdir, "rf")
        end)

        it("respects max_depth limit", function()
            local tmpdir = vim.fn.tempname()
            vim.fn.mkdir(tmpdir, "p")

            local dir = tmpdir
            for i = 1, compiler.max_depth + 1 do
                local subdir = dir .. "/sub" .. i
                vim.fn.mkdir(subdir, "p")
                vim.fn.writefile({ "all:", "\t$(MAKE) -C sub" .. (i + 1) }, dir .. "/Makefile")
                dir = subdir
            end
            vim.fn.writefile({ "all:", "\tdotnet build" }, dir .. "/Makefile")

            local content = compiler.resolve(tmpdir, 0)
            assert.is_true(content:find("dotnet") == nil)

            vim.fn.delete(tmpdir, "rf")
        end)
    end)

    describe("get_errorformat()", function()
        it("returns non-empty errorformat for cargo", function()
            local efm = compiler.get_errorformat("cargo")
            assert.is_true(#efm > 0)
        end)

        it("returns non-empty errorformat for dotnet", function()
            local efm = compiler.get_errorformat("dotnet")
            assert.is_true(#efm > 0)
        end)

        it("returns different errorformats for different compilers", function()
            local cargo_efm = compiler.get_errorformat("cargo")
            local dotnet_efm = compiler.get_errorformat("dotnet")
            assert.is_not.equals(cargo_efm, dotnet_efm)
        end)

        it("includes dotnet test extra errorformat patterns", function()
            local efm = compiler.get_errorformat("dotnet")
            assert.is_true(efm:find("Failed", 1, true) ~= nil, "should contain Failed pattern for test output")
        end)

        it("dotnet errorformat parses test failure into quickfix", function()
            local efm = compiler.get_errorformat("dotnet")
            local saved_efm = vim.o.errorformat
            vim.o.errorformat = efm

            vim.fn.setqflist({}, " ", {
                lines = {
                    "  Failed MyNamespace.MyTests.TestMethod [42 ms]",
                    "   at MyNamespace.MyTests.TestMethod() in C:/src/MyTests.cs:line 42",
                },
            })
            local qf = vim.fn.getqflist()

            -- Debug: dump qf entries if assertion fails
            local debug_info = {}
            for i, item in ipairs(qf) do
                debug_info[#debug_info + 1] = string.format(
                    "qf[%d]: valid=%d lnum=%d type=%s bufname=%s text=%s",
                    i, item.valid, item.lnum, item.type,
                    vim.fn.bufname(item.bufnr), item.text)
            end

            local found = false
            for _, item in ipairs(qf) do
                if item.lnum == 42 then
                    found = true
                end
            end
            assert.is_true(found, "should parse stack trace into quickfix with file and line. Got:\n" ..
                table.concat(debug_info, "\n"))

            vim.o.errorformat = saved_efm
        end)

        it("dotnet errorformat still parses build errors", function()
            local efm = compiler.get_errorformat("dotnet")
            local saved_efm = vim.o.errorformat
            vim.o.errorformat = efm

            vim.fn.setqflist({}, " ", {
                lines = { "C:/src/Program.cs(10,5): error CS1002: ; expected" },
            })
            local qf = vim.fn.getqflist()
            local found = false
            for _, item in ipairs(qf) do
                if item.lnum == 10 and item.col == 5 then
                    found = true
                end
            end
            assert.is_true(found, "should still parse MSBuild-style errors")

            vim.o.errorformat = saved_efm
        end)
    end)

    describe("autocommand", function()
        it("LarsCompilerDetect augroup exists", function()
            local group_id = vim.api.nvim_create_augroup("LarsCompilerDetect", { clear = false })
            local autocmds = vim.api.nvim_get_autocmds({ group = group_id })
            assert.is_true(#autocmds > 0, "LarsCompilerDetect should have autocmds registered")
        end)

        it("has QuickFixCmdPre event with make pattern", function()
            local group_id = vim.api.nvim_create_augroup("LarsCompilerDetect", { clear = false })
            local autocmds = vim.api.nvim_get_autocmds({ group = group_id, event = "QuickFixCmdPre" })
            assert.is_true(#autocmds > 0, "should have QuickFixCmdPre autocmd")
            assert.equals("make", autocmds[1].pattern)
        end)
    end)

    describe("apply()", function()
        it("sets makeprg to make when Makefile exists in cwd", function()
            local tmpdir = vim.fn.tempname()
            vim.fn.mkdir(tmpdir, "p")
            vim.fn.writefile({ "all:", "\tgcc -o main main.c" }, tmpdir .. "/Makefile")

            local orig_cwd = vim.fn.getcwd()
            vim.cmd("cd " .. vim.fn.fnameescape(tmpdir))

            compiler._cache = {}
            compiler.apply()

            assert.equals("make", vim.o.makeprg)

            vim.cmd("cd " .. vim.fn.fnameescape(orig_cwd))
            compiler._cache = {}
        end)

        it("combines errorformats when multiple tools detected", function()
            local tmpdir = vim.fn.tempname()
            vim.fn.mkdir(tmpdir, "p")
            vim.fn.writefile({
                "build:", "\tdotnet build",
                "native:", "\tgcc -o lib lib.c",
            }, tmpdir .. "/Makefile")

            local orig_cwd = vim.fn.getcwd()
            vim.cmd("cd " .. vim.fn.fnameescape(tmpdir))

            compiler._cache = {}
            compiler.apply()

            local efm = vim.o.errorformat
            -- Should contain patterns from both dotnet and gcc
            local dotnet_efm = compiler.get_errorformat("dotnet")
            local gcc_efm = compiler.get_errorformat("gcc")
            assert.is_true(efm:find(dotnet_efm, 1, true) ~= nil, "should contain dotnet errorformat")
            assert.is_true(efm:find(gcc_efm, 1, true) ~= nil, "should contain gcc errorformat")

            vim.cmd("cd " .. vim.fn.fnameescape(orig_cwd))
            compiler._cache = {}
        end)

        it("detects correct compiler through delegation", function()
            local tmpdir = vim.fn.tempname()
            vim.fn.mkdir(tmpdir, "p")
            vim.fn.mkdir(tmpdir .. "/backend", "p")
            vim.fn.writefile({ "all:", "\t$(MAKE) -C backend" }, tmpdir .. "/Makefile")
            vim.fn.writefile({ "build:", "\tcargo build" }, tmpdir .. "/backend/Makefile")

            local orig_cwd = vim.fn.getcwd()
            vim.cmd("cd " .. vim.fn.fnameescape(tmpdir))

            compiler._cache = {}
            compiler.apply()

            assert.equals("make", vim.o.makeprg)

            vim.cmd("cd " .. vim.fn.fnameescape(orig_cwd))
            compiler._cache = {}
            vim.fn.delete(tmpdir, "rf")
        end)
    end)
end)
