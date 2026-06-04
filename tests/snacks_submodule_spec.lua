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
end)
