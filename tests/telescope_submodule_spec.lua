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

        it("caches results", function()
            -- First call populates the cache, second should return same value
            local r1 = tsm.is_dirty("/some/nonexistent/path", ".")
            local r2 = tsm.is_dirty("/some/nonexistent/path", ".")
            assert.equals(r1, r2)
        end)
    end)

    describe("TtlCache", function()
        local TtlCache = tsm._TtlCache

        it("returns cached value within TTL", function()
            local c = TtlCache.new(60)
            c:set("key", "value")
            assert.equals("value", c:get("key"))
        end)

        it("returns nil for missing key", function()
            local c = TtlCache.new(60)
            assert.is_nil(c:get("missing"))
        end)

        it("expires entries after TTL", function()
            local c = TtlCache.new(0) -- 0-second TTL
            c:set("key", "value")
            -- Force expiration by backdating the timestamp
            c.entries["key"].ts = c.entries["key"].ts - 1000
            assert.is_nil(c:get("key"))
        end)

        it("clears all entries", function()
            local c = TtlCache.new(60)
            c:set("a", 1)
            c:set("b", 2)
            c:clear()
            assert.is_nil(c:get("a"))
            assert.is_nil(c:get("b"))
        end)
    end)

    describe("PersistentTtlCache stale behavior", function()
        local PersistentTtlCache = tsm._TtlCache

        it("returns value and is_stale=false within fresh TTL", function()
            local c = PersistentTtlCache.new(60, 120)
            c:set("key", "value")
            local val, is_stale = c:get("key")
            assert.equals("value", val)
            assert.is_false(is_stale)
        end)

        it("returns value and is_stale=true after fresh but before stale TTL", function()
            local c = PersistentTtlCache.new(10, 120)
            c:set("key", "value")
            c.entries["key"].ts = c.entries["key"].ts - 30
            local val, is_stale = c:get("key")
            assert.equals("value", val)
            assert.is_true(is_stale)
        end)

        it("returns nil after stale TTL", function()
            local c = PersistentTtlCache.new(10, 60)
            c:set("key", "value")
            c.entries["key"].ts = c.entries["key"].ts - 120
            local val = c:get("key")
            assert.is_nil(val)
        end)
    end)

    describe("git-cache persistence", function()
        local gc = require("lars.git-cache")

        after_each(function()
            gc.clear_cache()
        end)

        it("round-trips data through JSON", function()
            gc._buckets.toplevel:set("/test/path", "/test/root")
            gc._persist_to_disk()
            gc._buckets.toplevel:clear()
            assert.is_nil(gc._buckets.toplevel:get("/test/path"))
            gc._load_from_disk()
            local val = gc._buckets.toplevel:get("/test/path")
            assert.equals("/test/root", val)
        end)

        it("handles corrupt JSON gracefully", function()
            local f = io.open(gc._cache_path, "w")
            if f then
                f:write("not valid json{{{")
                f:close()
            end
            assert.has_no.errors(function()
                gc._load_from_disk()
            end)
        end)

        it("overwrites existing cache file on persist", function()
            gc._buckets.toplevel:set("/old", "/old/root")
            gc._persist_to_disk()
            gc._buckets.toplevel:clear()
            gc._buckets.toplevel:set("/new", "/new/root")
            gc._persist_to_disk()
            gc._buckets.toplevel:clear()
            gc._load_from_disk()
            assert.is_nil(gc._buckets.toplevel:get("/old"))
            assert.equals("/new/root", gc._buckets.toplevel:get("/new"))
        end)

        it("clear_cache removes persistent file", function()
            gc._buckets.toplevel:set("/test", "/root")
            gc._persist_to_disk()
            gc.clear_cache()
            local f = io.open(gc._cache_path, "r")
            assert.is_nil(f)
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
