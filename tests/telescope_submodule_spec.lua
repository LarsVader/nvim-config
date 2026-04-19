local h = dofile(vim.fn.stdpath("config") .. "/tests/helpers.lua")

describe("telescope-submodule", function()
    local tsm = require("lars.telescope-submodule")

    after_each(function()
        tsm.clear_cache()
    end)

    describe("sm_label via prompt title", function()
        it("returns (root) for dot", function()
            -- We test indirectly through the state/label logic
            -- The module uses "." for the root repo
            local cwd = tsm.submodule_cwd("/fake/root", ".")
            assert.equals("/fake/root", cwd)
        end)

        it("appends submodule path for non-root", function()
            local cwd = tsm.submodule_cwd("/fake/root", "libs/core")
            local sep = vim.fn.has("win32") == 1 and "\\" or "/"
            assert.equals("/fake/root" .. sep .. "libs" .. sep .. "core", cwd)
        end)
    end)

    describe("current_submodule", function()
        it("returns dot when buffer is in root", function()
            -- With no submodules cached, should return "."
            local result = tsm.current_submodule("/some/nonexistent/path")
            assert.equals(".", result)
        end)
    end)

    describe("get_submodules", function()
        it("always includes root as first entry", function()
            -- For a path without git, returns at least {"."}
            local subs = tsm.get_submodules("/some/nonexistent/path")
            assert.equals(".", subs[1])
        end)

        it("caches results", function()
            local subs1 = tsm.get_submodules("/some/nonexistent/path")
            local subs2 = tsm.get_submodules("/some/nonexistent/path")
            assert.are.same(subs1, subs2)
            -- After clear, fresh call
            tsm.clear_cache()
            local subs3 = tsm.get_submodules("/some/nonexistent/path")
            assert.are.same(subs1, subs3)
        end)
    end)

    describe("wrap_git_picker", function()
        it("returns a callable function", function()
            local fn = tsm.wrap_git_picker("git_files")
            assert.equals("function", type(fn))
        end)
    end)

    describe("is_dirty", function()
        it("returns boolean", function()
            local result = tsm.is_dirty("/some/nonexistent/path", ".")
            assert.equals("boolean", type(result))
        end)
    end)

    describe("picker keymaps still registered", function()
        local keys = {
            { "<C-p>",      "git files" },
            { "<leader>fg", "grep" },
            { "<leader>fs", "string" },
            { "<leader>fl", "commits" },
            { "<leader>fc", "branch commits" },
            { "<leader>fb", "branch" },
            { "<leader>fS", "git status" },
        }
        for _, k in ipairs(keys) do
            it(k[1] .. " (" .. k[2] .. ")", function()
                assert.is_true(h.has_keymap("n", k[1]), k[1] .. " not found")
            end)
        end
    end)
end)
