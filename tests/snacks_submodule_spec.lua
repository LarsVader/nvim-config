local h = dofile(vim.fn.stdpath("config") .. "/tests/helpers.lua")

describe("snacks-submodule", function()
    local ssm = require("lars.snacks-submodule")

    describe("submodule_cwd", function()
        it("returns root unchanged for dot", function()
            assert.equals("/fake/root", ssm.submodule_cwd("/fake/root", "."))
        end)

        it("appends submodule path for non-root", function()
            local cwd = ssm.submodule_cwd("/fake/root", "libs/core")
            local sep = vim.fn.has("win32") == 1 and "\\" or "/"
            assert.equals("/fake/root" .. sep .. "libs" .. sep .. "core", cwd)
        end)
    end)

    describe("parse_submodules", function()
        it("always includes root as first entry", function()
            assert.equals(".", ssm.parse_submodules({})[1])
        end)

        it("extracts submodule paths from git status output", function()
            local lines = {
                " 1234abcd libs/core (heads/main)",
                "+deadbeef libs/util (v1.0)",
                "-cafef00d vendor/dep (heads/dev)",
            }
            local subs = ssm.parse_submodules(lines)
            assert.are.same({ ".", "libs/core", "libs/util", "vendor/dep" }, subs)
        end)
    end)

    describe("current_submodule", function()
        it("returns dot when buffer is outside any submodule", function()
            local subs = { ".", "libs/core" }
            local result = ssm.current_submodule("/repo", subs, "/repo/src/main.lua")
            assert.equals(".", result)
        end)

        it("matches the submodule containing the buffer", function()
            local subs = { ".", "libs/core", "libs/core/nested" }
            local result = ssm.current_submodule("/repo", subs, "/repo/libs/core/file.lua")
            assert.equals("libs/core", result)
        end)

        it("prefers the deepest matching submodule", function()
            local subs = { ".", "libs/core", "libs/core/nested" }
            local result = ssm.current_submodule("/repo", subs, "/repo/libs/core/nested/file.lua")
            assert.equals("libs/core/nested", result)
        end)

        it("returns dot when buffer path is empty", function()
            assert.equals(".", ssm.current_submodule("/repo", { ".", "libs/core" }, ""))
        end)
    end)

    describe("git_log", function()
        it("is a callable function", function()
            assert.equals("function", type(ssm.git_log))
        end)
    end)

    describe("open / wrap", function()
        it("open is a callable function", function()
            assert.equals("function", type(ssm.open))
        end)

        it("wrap returns a callable for a given source", function()
            local fn = ssm.wrap("git_status")
            assert.equals("function", type(fn))
        end)
    end)

    describe("git_log keymap", function()
        it("<leader>gl is registered", function()
            assert.is_true(h.has_keymap("n", "<leader>gl"), "<leader>gl not found")
        end)
    end)

    describe("discover", function()
        -- Shared by the picker switcher and the fugitive <c-g> status switcher.
        local dir

        after_each(function()
            if dir then vim.fn.delete(dir, "rf") end
        end)

        local function run_discover(cwd)
            local done, root, subs = false, nil, nil
            ssm.discover(cwd, function(r, s) root, subs, done = r, s, true end)
            vim.wait(5000, function() return done end, 25)
            return done, root, subs
        end

        it("returns the git root and a root entry for a plain repo", function()
            dir = vim.fs.normalize(vim.fn.tempname())
            vim.fn.mkdir(dir, "p")
            vim.fn.system({ "git", "-C", dir, "init" })
            local done, root, subs = run_discover(dir)
            assert.is_true(done, "discover callback never fired")
            assert.are.equal(dir, vim.fs.normalize(root or ""))
            assert.are.same({ "." }, subs)
        end)

        it("calls back with nil outside a git repository", function()
            dir = vim.fs.normalize(vim.fn.tempname())
            vim.fn.mkdir(dir, "p")
            local done, root = run_discover(dir)
            assert.is_true(done, "discover callback never fired")
            assert.is_nil(root)
        end)
    end)

    describe("initial_cwd", function()
        -- Opening the picker from a file should scope to that file's
        -- repo/submodule, not the global cwd's root. A submodule is detected by
        -- its `.git` *file* (vs the root repo's `.git` dir); both satisfy get_root.
        local root, main, sub

        before_each(function()
            require("lazy").load({ plugins = { "snacks.nvim" } })
            root = vim.fs.normalize(vim.fn.tempname())
            main = root .. "/main"
            sub = main .. "/sub"
            vim.fn.mkdir(sub .. "/deep", "p")
            vim.fn.mkdir(main .. "/.git", "p")       -- root repo: .git dir
            vim.fn.writefile({ "gitdir: x" }, sub .. "/.git") -- submodule: .git file
            vim.fn.writefile({ "" }, main .. "/y.txt")
            vim.fn.writefile({ "" }, sub .. "/x.txt")
            vim.fn.writefile({ "" }, sub .. "/deep/z.txt")
        end)

        after_each(function()
            if root then vim.fn.delete(root, "rf") end
        end)

        it("scopes a submodule file to the submodule root", function()
            assert.are.equal(sub, vim.fs.normalize(ssm.initial_cwd(sub .. "/x.txt")))
        end)

        it("scopes a nested submodule file to the submodule root", function()
            assert.are.equal(sub, vim.fs.normalize(ssm.initial_cwd(sub .. "/deep/z.txt")))
        end)

        it("scopes a root-repo file to the root", function()
            assert.are.equal(main, vim.fs.normalize(ssm.initial_cwd(main .. "/y.txt")))
        end)

        it("returns nil for an empty/virtual buffer path", function()
            assert.is_nil(ssm.initial_cwd(""))
        end)

        it("returns nil for a non-existent path", function()
            assert.is_nil(ssm.initial_cwd(main .. "/does-not-exist.txt"))
        end)
    end)
end)
