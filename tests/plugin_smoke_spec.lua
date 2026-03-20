-- Tier 4: Plugin smoke tests — force-load plugins and verify APIs exist
local h = dofile(vim.fn.stdpath("config") .. "/tests/helpers.lua")

describe("plugin smoke tests", function()
    describe("harpoon", function()
        it("loads without error", function()
            local ok, err = h.force_load_plugin("harpoon")
            assert.is_true(ok, "harpoon failed to load: " .. tostring(err))
        end)

        it("list:add() does not error", function()
            local ok, err = pcall(function()
                require("harpoon"):list():add()
            end)
            assert.is_true(ok, "harpoon list:add() errored: " .. tostring(err))
        end)

        it("ui:toggle_quick_menu() does not error", function()
            local ok, err = pcall(function()
                local harpoon = require("harpoon")
                harpoon.ui:toggle_quick_menu(harpoon:list())
            end)
            -- Close any UI that opened
            pcall(function() vim.cmd("close") end)
            assert.is_true(ok, "harpoon toggle_quick_menu errored: " .. tostring(err))
        end)
    end)

    describe("telescope", function()
        it("loads without error", function()
            local ok, err = h.force_load_plugin("telescope.nvim")
            assert.is_true(ok, "telescope failed to load: " .. tostring(err))
        end)

        it("telescope.builtin.find_files is a function", function()
            local builtin = require("telescope.builtin")
            assert.equals("function", type(builtin.find_files), "find_files should be a function")
        end)
    end)

    describe("oil", function()
        it("loads without error", function()
            local ok, err = h.force_load_plugin("oil.nvim")
            assert.is_true(ok, "oil failed to load: " .. tostring(err))
        end)

        it("oil.open is callable", function()
            local oil = require("oil")
            assert.equals("function", type(oil.open), "oil.open should be a function")
        end)
    end)

    describe("fugitive", function()
        it("loads without error", function()
            local ok, err = h.force_load_plugin("vim-fugitive")
            assert.is_true(ok, "fugitive failed to load: " .. tostring(err))
        end)

        it(":G command exists", function()
            assert.is_true(vim.fn.exists(":G") > 0, ":G command should exist after loading fugitive")
        end)
    end)

    describe("dap", function()
        it("loads without error", function()
            local ok, err = h.force_load_plugin("nvim-dap")
            assert.is_true(ok, "nvim-dap failed to load: " .. tostring(err))
        end)

        it("dap.continue is a function", function()
            local dap = require("dap")
            assert.equals("function", type(dap.continue), "dap.continue should be a function")
        end)

        it("cs configuration exists with a program function", function()
            local dap = require("dap")
            local cs = dap.configurations.cs
            assert.is_not_nil(cs, "dap.configurations.cs should exist")
            assert.is_true(#cs >= 1, "cs should have at least one config")
            assert.equals("coreclr", cs[1].type)
            assert.equals("function", type(cs[1].program),
                "cs[1].program should be a function")
        end)

        it("cs program returns dll path when exactly one dll exists", function()
            local dap = require("dap")
            local program = dap.configurations.cs[1].program

            -- Use config dir: avoids Windows 8.3 short-path names
            -- (e.g. LARSVA~1) that break vim.fn.glob
            -- Tree: _tmp_dap/Foo/Foo.csproj
            --       _tmp_dap/Foo/bin/Debug/net9.0/Foo.dll
            local cfgdir = vim.fn.stdpath('config'):gsub('\\', '/')
            local tmpdir = cfgdir .. '/tests/_tmp_dap'
            vim.fn.mkdir(tmpdir .. '/Foo/bin/Debug/net9.0', 'p')
            local f1 = io.open(tmpdir .. '/Foo/Foo.csproj', 'w')
            assert.is_not_nil(f1, "failed to create test csproj")
            f1:close()
            local f2 = io.open(
                tmpdir .. '/Foo/bin/Debug/net9.0/Foo.dll', 'w')
            assert.is_not_nil(f2, "failed to create test dll")
            f2:close()

            local orig = vim.fn.getcwd()
            vim.api.nvim_set_current_dir(tmpdir)

            -- program() returns directly (no yield) when dll found
            local co = coroutine.create(program)
            local ok, result = coroutine.resume(co)

            vim.api.nvim_set_current_dir(orig)
            vim.fn.delete(tmpdir, 'rf')

            assert.is_true(ok, "program errored: " .. tostring(result))
            assert.is_not_nil(
                result and result:find('Foo%.dll'),
                "expected path containing Foo.dll, got: "
                .. tostring(result))
        end)

        it("cs program auto-picks newest when multiple dlls exist", function()
            local dap = require("dap")
            local program = dap.configurations.cs[1].program

            -- Two non-test projects; Lib.dll created first, App.dll
            -- created after — newest-first ordering should pick App.dll
            local cfgdir = vim.fn.stdpath('config'):gsub('\\', '/')
            local tmpdir = cfgdir .. '/tests/_tmp_dap2'
            vim.fn.mkdir(tmpdir .. '/App/bin/Debug/net9.0', 'p')
            vim.fn.mkdir(tmpdir .. '/Lib/bin/Debug/net9.0', 'p')
            io.open(tmpdir .. '/App/App.csproj', 'w'):close()
            io.open(tmpdir .. '/Lib/Lib.csproj', 'w'):close()
            -- Create Lib.dll first, then App.dll — App.dll is newer
            io.open(tmpdir .. '/Lib/bin/Debug/net9.0/Lib.dll', 'w'):close()
            local t = os.time()
            while os.time() == t do end
            io.open(tmpdir .. '/App/bin/Debug/net9.0/App.dll', 'w'):close()

            local orig = vim.fn.getcwd()
            vim.api.nvim_set_current_dir(tmpdir)
            local co = coroutine.create(program)
            local ok, result = coroutine.resume(co)
            vim.api.nvim_set_current_dir(orig)
            vim.fn.delete(tmpdir, 'rf')

            assert.is_true(ok, "program errored: " .. tostring(result))
            assert.is_not_nil(
                result and result:find('App%.dll'),
                "expected newest dll (App.dll), got: "
                .. tostring(result))
        end)

        it("cs program skips test projects (.Tests suffix)", function()
            local dap = require("dap")
            local program = dap.configurations.cs[1].program

            -- App is the main project; App.Tests is the test project.
            -- Tests.dll is newer, but must be skipped — App.dll wins.
            local cfgdir = vim.fn.stdpath('config'):gsub('\\', '/')
            local tmpdir = cfgdir .. '/tests/_tmp_dap3'
            vim.fn.mkdir(tmpdir .. '/App/bin/Debug/net9.0', 'p')
            vim.fn.mkdir(tmpdir .. '/App.Tests/bin/Debug/net9.0', 'p')
            io.open(tmpdir .. '/App/App.csproj', 'w'):close()
            io.open(tmpdir .. '/App.Tests/App.Tests.csproj', 'w'):close()
            -- App.dll first, then App.Tests.dll (newer)
            io.open(tmpdir .. '/App/bin/Debug/net9.0/App.dll', 'w'):close()
            local t = os.time()
            while os.time() == t do end
            io.open(
                tmpdir .. '/App.Tests/bin/Debug/net9.0/App.Tests.dll',
                'w'):close()

            local orig = vim.fn.getcwd()
            vim.api.nvim_set_current_dir(tmpdir)
            local co = coroutine.create(program)
            local ok, result = coroutine.resume(co)
            vim.api.nvim_set_current_dir(orig)
            vim.fn.delete(tmpdir, 'rf')

            assert.is_true(ok, "program errored: " .. tostring(result))
            -- result must be App.dll, NOT App.Tests.dll
            -- (use App%.dll — won't match App.Tests.dll)
            assert.is_not_nil(
                result and result:find('App%.dll'),
                "expected App.dll (not test dll), got: "
                .. tostring(result))
        end)

        it("cs program finds dll in WinUI bin/Platform/Debug layout", function()
            local dap = require("dap")
            local program = dap.configurations.cs[1].program

            -- WinUI/Windows App SDK outputs to bin/X64/Debug/{tfm}/
            local cfgdir = vim.fn.stdpath('config'):gsub('\\', '/')
            local tmpdir = cfgdir .. '/tests/_tmp_dap4'
            vim.fn.mkdir(
                tmpdir .. '/App/bin/X64/Debug/net9.0-windows', 'p')
            io.open(tmpdir .. '/App/App.csproj', 'w'):close()
            io.open(
                tmpdir
                .. '/App/bin/X64/Debug/net9.0-windows/App.dll',
                'w'):close()

            local orig = vim.fn.getcwd()
            vim.api.nvim_set_current_dir(tmpdir)
            local co = coroutine.create(program)
            local ok, result = coroutine.resume(co)
            vim.api.nvim_set_current_dir(orig)
            vim.fn.delete(tmpdir, 'rf')

            assert.is_true(ok, "program errored: " .. tostring(result))
            assert.is_not_nil(
                result and result:find('App%.dll'),
                "expected App.dll from WinUI layout, got: "
                .. tostring(result))
        end)
    end)

    describe("comment", function()
        it("loads without error", function()
            local ok, err = h.force_load_plugin("Comment.nvim")
            assert.is_true(ok, "Comment.nvim failed to load: " .. tostring(err))
        end)

        it("gc operator works on a buffer line", function()
            vim.cmd("enew!")
            vim.bo.buftype = "nofile"
            vim.bo.filetype = "lua"
            h.set_buf_lines({ "local x = 1" })
            vim.cmd("normal! gg")

            local ok, err = pcall(function()
                vim.cmd("normal gcc")
            end)
            assert.is_true(ok, "gcc errored: " .. tostring(err))

            local lines = h.get_buf_lines()
            -- The line should now be commented (starts with --)
            assert.is_not_nil(lines[1]:find("^%-%-"), "line should be commented after gcc")
        end)
    end)

    describe("surround", function()
        it("loads without error", function()
            local ok, err = h.force_load_plugin("vim-surround")
            assert.is_true(ok, "vim-surround failed to load: " .. tostring(err))
        end)
    end)

    describe("leap", function()
        it("loads without error", function()
            local ok, err = pcall(function()
                require("leap")
            end)
            assert.is_true(ok, "leap failed to require: " .. tostring(err))
        end)
    end)
end)
