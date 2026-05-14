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

        it("list:add() stores relative path (no backslashes)", function()
            local harpoon = require("harpoon")
            -- Clear the list
            local list = harpoon:list()
            for i = list:length(), 1, -1 do
                list:remove_at(i)
            end
            -- Add current buffer
            list:add()
            if list:length() > 0 then
                local item = list:get(1)
                assert.is_not_nil(item, "expected a list item")
                assert.is_nil(
                    item.value:match("\\"),
                    "harpoon path contains backslashes: " .. item.value
                )
                -- Should not be an absolute path (no drive letter like C:)
                assert.is_nil(
                    item.value:match("^%a:"),
                    "harpoon path is absolute: " .. item.value
                )
            end
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

        it("remaps Tab/S-Tab to move_selection_previous/next (inverted)", function()
            local conf = require("telescope.config").values
            local actions = require("telescope.actions")
            local i_mappings = conf.mappings.i
            local n_mappings = conf.mappings.n
            assert.equals(actions.move_selection_previous, i_mappings["<Tab>"],
                "insert mode <Tab> should be move_selection_previous")
            assert.equals(actions.move_selection_next, i_mappings["<S-Tab>"],
                "insert mode <S-Tab> should be move_selection_next")
            assert.equals(actions.move_selection_previous, n_mappings["<Tab>"],
                "normal mode <Tab> should be move_selection_previous")
            assert.equals(actions.move_selection_next, n_mappings["<S-Tab>"],
                "normal mode <S-Tab> should be move_selection_next")
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

        it("mixdbg adapter is registered as executable", function()
            local dap = require("dap")
            local adapter = dap.adapters.mixdbg
            assert.is_not_nil(adapter, "mixdbg adapter should be registered")
            assert.equals("executable", adapter.type)
            assert.equals("string", type(adapter.command),
                "mixdbg adapter command should be a string")
            assert.is_true(adapter.command:lower():find('mixdbg') ~= nil,
                "mixdbg adapter command should reference MixDbg")
        end)

        local function find_mixdbg_config(configs, request)
            for _, c in ipairs(configs) do
                if c.type == "mixdbg" and c.request == request then
                    return c
                end
            end
            return nil
        end

        it("mixdbg launch config exists in cs and cpp", function()
            local dap = require("dap")
            local cs = find_mixdbg_config(
                dap.configurations.cs, "launch")
            local cpp = find_mixdbg_config(
                dap.configurations.cpp, "launch")
            assert.is_not_nil(cs,
                "mixdbg launch config should exist in cs")
            assert.is_not_nil(cpp,
                "mixdbg launch config should exist in cpp")
            assert.equals("Mixed C#/C++ (mixdbg)", cs.name)
            assert.equals("Mixed C#/C++ (mixdbg)", cpp.name)
            assert.equals("function", type(cs.program),
                "launch.program should be a function")
        end)

        it("mixdbg attach config exists in cs and cpp", function()
            local dap = require("dap")
            local cs = find_mixdbg_config(
                dap.configurations.cs, "attach")
            local cpp = find_mixdbg_config(
                dap.configurations.cpp, "attach")
            assert.is_not_nil(cs,
                "mixdbg attach config should exist in cs")
            assert.is_not_nil(cpp,
                "mixdbg attach config should exist in cpp")
            assert.equals("Mixed C#/C++ attach (mixdbg)", cs.name)
            assert.equals("Mixed C#/C++ attach (mixdbg)", cpp.name)
            assert.equals("function", type(cs.pid),
                "attach.pid should be a function (PID picker)")
            -- Same config table is inserted in both cs and cpp
            assert.equals(cs, cpp,
                "cs and cpp should share the same attach config table")
        end)

        it("mixdbg attach config does not declare symbolPath", function()
            local dap = require("dap")
            local attach = find_mixdbg_config(
                dap.configurations.cs, "attach")
            assert.is_not_nil(attach,
                "mixdbg attach config should exist")
            -- symbolPath was removed because the prompt confused
            -- users. mixdbg's attach handler treats a missing
            -- symbolPath as null, which is the correct default.
            assert.is_nil(attach.symbolPath,
                "attach.symbolPath should not be set")
        end)

        it("mixdbg attach config resolves cleanly with filtered picker", function()
            -- Verify the pid function loads and is wired up correctly:
            -- it must remain a function, and the config table itself
            -- must resolve to a valid table with the expected shape.
            -- We don't actually invoke the picker (it requires real
            -- running processes and a UI prompt).
            local dap = require("dap")
            local attach = find_mixdbg_config(
                dap.configurations.cs, "attach")
            assert.is_not_nil(attach,
                "mixdbg attach config should exist")
            assert.equals("function", type(attach.pid),
                "attach.pid should be a function (filtered PID picker)")
            -- Confirm dap.utils is available and exposes both the
            -- get_processes (for filtered counting) and pick_process
            -- (for the prompt) APIs the new implementation depends on.
            local ok, utils = pcall(require, 'dap.utils')
            assert.is_true(ok,
                "dap.utils should be requireable: " .. tostring(utils))
            assert.equals("function", type(utils.get_processes),
                "dap.utils.get_processes must exist for filtered counting")
            assert.equals("function", type(utils.pick_process),
                "dap.utils.pick_process must exist for the picker UI")
        end)
    end)

    describe("neotest", function()
        it("loads without error", function()
            local ok, err = h.force_load_plugin("neotest")
            assert.is_true(ok, "neotest failed to load: " .. tostring(err))
        end)

        it("neotest.run.run is a function", function()
            local neotest = require("neotest")
            assert.equals("function", type(neotest.run.run), "neotest.run.run should be a function")
        end)
    end)

    describe("nvim-coverage", function()
        it("loads without error", function()
            local ok, err = h.force_load_plugin("nvim-coverage")
            assert.is_true(ok, "nvim-coverage failed to load: " .. tostring(err))
        end)

        it("coverage.toggle is a function", function()
            local coverage = require("coverage")
            assert.equals("function", type(coverage.toggle), "coverage.toggle should be a function")
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

    describe("diffview", function()
        it("loads without error", function()
            local ok, err = h.force_load_plugin("diffview.nvim")
            assert.is_true(ok, "diffview failed to load: " .. tostring(err))
        end)

        it("diffview module is requireable", function()
            local ok, err = pcall(function()
                require("diffview")
            end)
            assert.is_true(ok, "diffview failed to require: " .. tostring(err))
        end)
    end)

    describe("git-submodules", function()
        it("submodule_commit_picker keymap is registered", function()
            local map = h.find_keymap("n", "<leader>gS")
            assert.is_not_nil(map, "<leader>gS keymap should be registered")
        end)

        it("submodule_checkout_picker keymap is registered", function()
            local map = h.find_keymap("n", "<leader>gC")
            assert.is_not_nil(map, "<leader>gC keymap should be registered")
        end)
    end)

    describe("themery", function()
        it("loads without error", function()
            local ok, err = h.force_load_plugin("themery.nvim")
            assert.is_true(ok, "themery failed to load: " .. tostring(err))
        end)

        it("themery module is requireable", function()
            local ok, err = pcall(function()
                require("themery")
            end)
            assert.is_true(ok, "themery failed to require: " .. tostring(err))
        end)
    end)

    describe("gitsigns", function()
        it("loads without error", function()
            local ok, err = h.force_load_plugin("gitsigns.nvim")
            assert.is_true(ok, "gitsigns failed to load: " .. tostring(err))
        end)

        it("gitsigns module is requireable", function()
            local ok, err = pcall(function()
                require("gitsigns")
            end)
            assert.is_true(ok, "gitsigns failed to require: " .. tostring(err))
        end)

        it("gitsigns.stage_buffer is a function", function()
            local gs = require("gitsigns")
            assert.equals("function", type(gs.stage_buffer), "stage_buffer should be a function")
        end)

        it("gitsigns.diffthis is a function", function()
            local gs = require("gitsigns")
            assert.equals("function", type(gs.diffthis), "diffthis should be a function")
        end)
    end)

    describe("treesitter-textobjects", function()
        it("loads without error", function()
            local ok, err = h.force_load_plugin("nvim-treesitter-textobjects")
            assert.is_true(ok, "nvim-treesitter-textobjects failed to load: " .. tostring(err))
        end)

        it("move module is requireable", function()
            local ok, err = pcall(function()
                require("nvim-treesitter-textobjects.move")
            end)
            assert.is_true(ok, "move module failed to require: " .. tostring(err))
        end)
    end)

    describe("sidekick", function()
        it("loads without error", function()
            local ok, err = h.force_load_plugin("sidekick.nvim")
            assert.is_true(ok, "sidekick failed to load: " .. tostring(err))
        end)

        it("sidekick.cli.toggle is a function", function()
            local cli = require("sidekick.cli")
            assert.equals("function", type(cli.toggle), "sidekick.cli.toggle should be a function")
        end)
    end)

    describe("xaml-lsp", function()
        -- When Mason/xaml-lsp is not installed, the plugin returns {} early
        -- and skips vim.lsp.config registration. Detect this so tests that
        -- depend on the LSP config can be skipped gracefully.
        local has_axsg_config = vim.lsp.config["axsg_lsp"] ~= nil

        it("registers xaml filetype for .xaml extension", function()
            local ft = vim.filetype.match({ filename = "MainPage.xaml" })
            assert.equals("xaml", ft, ".xaml should be detected as xaml filetype")
        end)

        it("axsg_lsp is configured via vim.lsp.config (requires Mason)", function()
            if not has_axsg_config then
                pending("xaml-lsp not installed via Mason — skipping")
                return
            end
            local cfg = vim.lsp.config["axsg_lsp"]
            assert.is_not_nil(cfg, "axsg_lsp should be registered in vim.lsp.config")
        end)

        it("axsg_lsp config has correct filetypes (requires Mason)", function()
            if not has_axsg_config then
                pending("xaml-lsp not installed via Mason — skipping")
                return
            end
            local cfg = vim.lsp.config["axsg_lsp"]
            assert.is_not_nil(cfg.filetypes, "filetypes should be set")
            assert.same({ "xaml" }, cfg.filetypes)
        end)

        it("axsg_lsp cmd resolves via Mason to LanguageServer exe", function()
            if not has_axsg_config then
                pending("xaml-lsp not installed via Mason — skipping")
                return
            end
            local cfg = vim.lsp.config["axsg_lsp"]
            assert.equals("table", type(cfg.cmd), "cmd should be a table")
            assert.truthy(cfg.cmd[1]:match("LanguageServer"), "cmd should contain LanguageServer binary")
        end)

        it("BufReadCmd autocmd is registered for axsg-metadata:// URIs", function()
            if not has_axsg_config then
                pending("xaml-lsp not installed via Mason — skipping")
                return
            end
            local autocmds = vim.api.nvim_get_autocmds({
                event = "BufReadCmd",
                pattern = "axsg-metadata://*",
            })
            assert.is_true(#autocmds > 0, "BufReadCmd autocmd for axsg-metadata://* should exist")
        end)
    end)

    describe("smear-cursor", function()
        it("loads without error", function()
            local ok, err = h.force_load_plugin("smear-cursor.nvim")
            assert.is_true(ok, "smear-cursor.nvim failed to load: " .. tostring(err))
        end)

        it("smear_cursor module is requireable", function()
            local ok, mod = pcall(require, "smear_cursor")
            assert.is_true(ok, "smear_cursor module failed to require: " .. tostring(mod))
        end)
    end)

    describe("snacks.image", function()
        it("loads without error", function()
            local ok, err = h.force_load_plugin("snacks.nvim")
            assert.is_true(ok, "snacks.nvim failed to load: " .. tostring(err))
        end)

        it("Snacks.image module is requireable", function()
            local ok, mod = pcall(require, "snacks.image")
            assert.is_true(ok, "snacks.image module failed to require: " .. tostring(mod))
        end)
    end)

    describe("lazydev + lua_ls", function()
        it("lazydev loads without error", function()
            local ok, err = h.force_load_plugin("lazydev.nvim")
            assert.is_true(ok, "lazydev failed to load: " .. tostring(err))
        end)

        it("lazydev module is requireable", function()
            h.force_load_plugin("lazydev.nvim")
            local ok, mod = pcall(require, "lazydev")
            assert.is_true(ok, "lazydev module failed to require: " .. tostring(mod))
        end)

        it("lua_ls is registered via vim.lsp.config", function()
            local cfg = vim.lsp.config["lua_ls"]
            assert.is_not_nil(cfg, "lua_ls should be registered in vim.lsp.config")
        end)

        it("lua_ls config has correct filetypes", function()
            local cfg = vim.lsp.config["lua_ls"]
            assert.same({ "lua" }, cfg.filetypes)
        end)

        it("lua_ls cmd resolves via Mason to lua-language-server", function()
            local cfg = vim.lsp.config["lua_ls"]
            assert.equals("table", type(cfg.cmd), "cmd should be a table")
            assert.truthy(cfg.cmd[1]:match("lua%-language%-server"),
                "cmd should reference lua-language-server, got: " .. tostring(cfg.cmd[1]))
        end)
    end)
end)
