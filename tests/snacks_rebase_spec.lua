-- The interactive rebase must run in the picker's repo even when that differs
-- from the current buffer's repo (e.g. a submodule-scoped log while a parent-repo
-- file is open). Rather than juggling a tab/tcd to redirect Fugitive, launch()
-- passes the picker's git dir straight to fugitive#Command (which accepts an
-- explicit dir as its last argument). This test pins the current buffer to a
-- PARENT repo, then drives a scoped command against a SUBMODULE and asserts it
-- lands in the submodule -- the exact cross-repo case the old tab worked around.
local h = dofile(vim.fn.stdpath("config") .. "/tests/helpers.lua")

describe("snacks git_log interactive rebase repo scoping", function()
    local root, main, sub

    local function git(dir, ...)
        return vim.system({ "git", "-C", dir, ... }):wait()
    end

    before_each(function()
        require("lazy").load({ plugins = { "vim-fugitive" } })
        root = vim.fs.normalize(vim.fn.tempname())
        main = root .. "/main"
        sub = main .. "/sub"
        vim.fn.mkdir(sub, "p")
        for _, dir in ipairs({ main, sub }) do
            git(dir, "init", "-q")
            git(dir, "config", "user.email", "t@t.t")
            git(dir, "config", "user.name", "t")
        end
        vim.fn.writefile({ "main" }, main .. "/m.txt")
        git(main, "add", "m.txt"); git(main, "commit", "-qm", "main init")
        vim.fn.writefile({ "sub" }, sub .. "/s.txt")
        git(sub, "add", "s.txt"); git(sub, "commit", "-qm", "sub init")

        -- Pin the current buffer to the PARENT repo, mimicking a main-repo file
        -- being open when the submodule-scoped picker launches the rebase.
        vim.cmd("silent! tabonly")
        vim.cmd("edit " .. vim.fn.fnameescape(main .. "/m.txt"))
    end)

    after_each(function()
        vim.cmd("silent! tabonly")
        vim.cmd("silent! %bwipeout!")
        if root then vim.fn.delete(root, "rf") end
    end)

    it("Fugitive resolves the current buffer to the PARENT repo", function()
        -- Sanity: without explicit scoping, Fugitive would target the parent.
        assert.are.equal(vim.fs.normalize(main .. "/.git"), vim.fs.normalize(vim.fn.FugitiveGitDir()))
    end)

    it("fugitive#Command with the submodule git dir acts on the submodule", function()
        -- This is how launch() scopes: pass the target repo's git dir as the
        -- last arg, no tab/tcd, current buffer still pinned to the parent.
        local gitdir = vim.trim(git(sub, "rev-parse", "--absolute-git-dir").stdout)
        local ok = pcall(vim.fn["fugitive#Command"], 0, 0, 0, 0, "", "tag scope-probe", gitdir)
        assert.is_true(ok, "fugitive#Command errored")
        vim.wait(2000, function() return vim.trim(git(sub, "tag").stdout) ~= "" end)
        -- Tag landed in the submodule...
        assert.are.equal("scope-probe", vim.trim(git(sub, "tag").stdout))
        -- ...and NOT in the parent, despite the current buffer being parent-scoped.
        assert.are.equal("", vim.trim(git(main, "tag").stdout))
    end)
end)

describe("snacks git_log rebase actions", function()
    -- The actions live inline in opts.picker.actions; verify they are wired.
    local function picker_opts()
        h.force_load_plugin("snacks.nvim")
        for _, spec in ipairs(require("lazy").plugins()) do
            if spec.name == "snacks.nvim" then return spec.opts.picker end
        end
        error("snacks.nvim spec not found")
    end

    it("git_rebase_interactive is a function", function()
        assert.is_function(picker_opts().actions.git_rebase_interactive)
    end)

    it("mark/clear actions are functions", function()
        local actions = picker_opts().actions
        for _, name in ipairs({
            "git_rebase_mark_edit", "git_rebase_mark_reword", "git_rebase_mark_squash",
            "git_rebase_mark_fixup", "git_rebase_mark_drop", "git_rebase_mark_pick",
            "git_rebase_clear",
        }) do
            assert.is_function(actions[name], name .. " missing")
        end
    end)
end)

describe("snacks-rebase apply_to_lines", function()
    local rb = require("lars.snacks-rebase")

    -- A typical git-rebase-todo: pick lines (oldest first), then a comment block.
    local function todo()
        return {
            "pick a1b2c3d first commit",
            "pick d4e5f6a second commit",
            "pick 789abcd third commit",
            "",
            "# Rebase abc..def onto abc",
            "# p, pick <commit> = use commit",
        }
    end

    it("swaps the keyword for matched commits, by abbrev-hash prefix", function()
        -- full hashes whose prefixes match the abbreviated hashes in the todo
        local tags = {
            ["a1b2c3d0000000000000000000000000000000ab"] = "edit",
            ["789abcd0000000000000000000000000000000ab"] = "squash",
        }
        local out, applied = rb.apply_to_lines(todo(), tags)
        assert.equals(2, applied)
        assert.equals("edit a1b2c3d first commit", out[1])
        assert.equals("pick d4e5f6a second commit", out[2]) -- untouched
        assert.equals("squash 789abcd third commit", out[3])
    end)

    it("preserves the hash and subject verbatim, only swapping the verb", function()
        local tags = { ["d4e5f6a0000000000000000000000000000000ab"] = "drop" }
        local out, applied = rb.apply_to_lines(todo(), tags)
        assert.equals(1, applied)
        assert.equals("drop d4e5f6a second commit", out[2])
    end)

    it("never rewrites comment or blank lines", function()
        local tags = { ["a1b2c3d0000000000000000000000000000000ab"] = "edit" }
        local out = rb.apply_to_lines(todo(), tags)
        assert.equals("", out[4])
        assert.equals("# Rebase abc..def onto abc", out[5])
    end)

    it("treats a 'pick' mark as a no-op (implicit default)", function()
        local tags = { ["a1b2c3d0000000000000000000000000000000ab"] = "pick" }
        local out, applied = rb.apply_to_lines(todo(), tags)
        assert.equals(0, applied)
        assert.equals("pick a1b2c3d first commit", out[1])
    end)

    it("ignores marks that match no todo line", function()
        local tags = { ["ffffffffffffffffffffffffffffffffffffffff"] = "edit" }
        local _, applied = rb.apply_to_lines(todo(), tags)
        assert.equals(0, applied)
    end)

    it("expands a split mark into pick + exec reset (the dirty tree stops git)", function()
        local tags = { ["a1b2c3d0000000000000000000000000000000ab"] = "split" }
        local out, applied = rb.apply_to_lines(todo(), tags)
        assert.equals(1, applied)
        assert.equals("pick a1b2c3d first commit", out[1])
        assert.equals("exec git reset HEAD~1", out[2])
        -- the other commits follow, then the comment block
        assert.equals("pick d4e5f6a second commit", out[3])
        assert.equals("pick 789abcd third commit", out[4])
        assert.equals("", out[5])
        assert.equals("# Rebase abc..def onto abc", out[6])
    end)

    it("splits in the reordered position", function()
        local order = { "789abcd", "a1b2c3d", "d4e5f6a" } -- third, first, second
        local tags = { ["a1b2c3d0000000000000000000000000000000ab"] = "split" }
        local out = rb.apply_to_lines(todo(), tags, order)
        assert.equals("pick 789abcd third commit", out[1])
        assert.equals("pick a1b2c3d first commit", out[2])
        assert.equals("exec git reset HEAD~1", out[3])
        assert.equals("pick d4e5f6a second commit", out[4])
    end)

    it("reports reordered=false when order matches the natural sequence", function()
        local order = { "a1b2c3d", "d4e5f6a", "789abcd" } -- oldest first, as-is
        local _, _, reordered = rb.apply_to_lines(todo(), {}, order)
        assert.is_false(reordered)
    end)

    it("permutes the pick lines to match the given order", function()
        -- request reverse order (oldest-first): third, second, first
        local order = { "789abcd", "d4e5f6a", "a1b2c3d" }
        local out, applied, reordered = rb.apply_to_lines(todo(), {}, order)
        assert.equals(0, applied)
        assert.is_true(reordered)
        assert.equals("pick 789abcd third commit", out[1])
        assert.equals("pick d4e5f6a second commit", out[2])
        assert.equals("pick a1b2c3d first commit", out[3])
        -- comment block stays put
        assert.equals("", out[4])
        assert.equals("# Rebase abc..def onto abc", out[5])
    end)

    it("reorders and re-keywords together", function()
        local order = { "789abcd", "a1b2c3d", "d4e5f6a" }
        local tags = {
            ["789abcd0000000000000000000000000000000ab"] = "edit",
            ["d4e5f6a0000000000000000000000000000000ab"] = "drop",
        }
        local out, applied, reordered = rb.apply_to_lines(todo(), tags, order)
        assert.equals(2, applied)
        assert.is_true(reordered)
        assert.equals("edit 789abcd third commit", out[1])
        assert.equals("pick a1b2c3d first commit", out[2])
        assert.equals("drop d4e5f6a second commit", out[3])
    end)

    it("keeps commits absent from order in their original relative position", function()
        -- only pin the third commit to the front; the rest keep their order
        local order = { "789abcd" }
        local out, _, reordered = rb.apply_to_lines(todo(), {}, order)
        assert.is_true(reordered)
        assert.equals("pick 789abcd third commit", out[1])
        assert.equals("pick a1b2c3d first commit", out[2])
        assert.equals("pick d4e5f6a second commit", out[3])
    end)
end)

describe("snacks-rebase badges", function()
    local rb = require("lars.snacks-rebase")

    before_each(function() rb.tags = {} end)
    after_each(function() rb.tags = {} end)

    it("has_marks / action_for match by abbreviated-hash prefix", function()
        assert.is_false(rb.has_marks())
        rb.tags["a1b2c3d0000000000000000000000000000000ab"] = "squash"
        assert.is_true(rb.has_marks())
        assert.equals("squash", rb.action_for("a1b2c3d"))
        assert.equals("squash", rb.action_for("a1b2")) -- shorter prefix still matches
        assert.is_nil(rb.action_for("deadbee"))
        assert.is_nil(rb.action_for(nil))
    end)

    it("format prepends a badge only when a row is marked", function()
        h.force_load_plugin("snacks.nvim")
        local orig = Snacks.picker.format.git_log
        Snacks.picker.format.git_log = function() return { { "ROW" } } end
        local ok, err = pcall(function()
            -- no marks -> stock row, unchanged
            local out = rb.format({ commit = "a1b2c3d" }, {})
            assert.equals(1, #out)
            assert.equals("ROW", out[1][1])

            -- marked -> badge segment prepended, text starts with the action
            rb.tags["a1b2c3d0000000000000000000000000000000ab"] = "drop"
            out = rb.format({ commit = "a1b2c3d" }, {})
            assert.is_true(#out > 1)
            assert.is_truthy(out[1][1]:match("^drop"))

            -- marks exist but THIS row is unmarked -> blank padded badge (alignment)
            out = rb.format({ commit = "fffffff" }, {})
            assert.is_truthy(out[1][1]:match("^%s+$"))
        end)
        Snacks.picker.format.git_log = orig
        assert.is_true(ok, tostring(err))
    end)
end)

describe("snacks-rebase in-progress todo view", function()
    local rb = require("lars.snacks-rebase")

    it("read_todo keeps commit steps, normalizes short verbs, drops the rest", function()
        local dir = vim.fs.normalize(vim.fn.tempname())
        vim.fn.mkdir(dir, "p")
        vim.fn.writefile({
            "pick a1b2c3d first commit",
            "e d4e5f6a second commit", -- short verb
            "squash 789abcd third commit",
            "exec make test", -- no hash -> dropped
            "",
            "# Rebase abc..def onto abc",
        }, dir .. "/git-rebase-todo")

        local ok, err = pcall(function()
            local steps = rb.read_todo(dir)
            assert.equals(3, #steps)
            assert.same({ status = "todo", action = "pick", commit = "a1b2c3d", subject = "first commit" }, steps[1])
            assert.equals("edit", steps[2].action) -- e -> edit
            assert.equals("squash", steps[3].action)
        end)
        vim.fn.delete(dir, "rf")
        assert.is_true(ok, tostring(err))
    end)

    it("read_todo returns empty for a missing todo file", function()
        assert.same({}, rb.read_todo(vim.fs.normalize(vim.fn.tempname())))
    end)

    it("read_steps shows done + current stop even when nothing remains", function()
        local dir = vim.fs.normalize(vim.fn.tempname())
        vim.fn.mkdir(dir, "p")
        -- Paused on an `edit` of the newest commit: two done, last = stop, no todo.
        vim.fn.writefile({ "pick aaaa1111 first", "edit bbbb2222 second" }, dir .. "/done")
        vim.fn.writefile({ "", "# Rebase ..." }, dir .. "/git-rebase-todo")
        local ok, err = pcall(function()
            local steps = rb.read_steps(dir)
            assert.equals(2, #steps)
            assert.equals("done", steps[1].status)
            assert.equals("stop", steps[2].status) -- last done = where it's paused
            assert.equals("edit", steps[2].action)
            -- remaining-only view would have been empty here:
            assert.equals(0, #rb.read_todo(dir))
        end)
        vim.fn.delete(dir, "rf")
        assert.is_true(ok, tostring(err))
    end)

    it("read_steps marks remaining steps as todo", function()
        local dir = vim.fs.normalize(vim.fn.tempname())
        vim.fn.mkdir(dir, "p")
        vim.fn.writefile({ "pick aaaa1111 first" }, dir .. "/done")
        vim.fn.writefile({ "pick cccc3333 third", "squash dddd4444 fourth" }, dir .. "/git-rebase-todo")
        local ok, err = pcall(function()
            local steps = rb.read_steps(dir)
            assert.equals(3, #steps)
            assert.equals("stop", steps[1].status)
            assert.equals("todo", steps[2].status)
            assert.equals("todo", steps[3].status)
        end)
        vim.fn.delete(dir, "rf")
        assert.is_true(ok, tostring(err))
    end)

    it("progress_for reads git's step counters as <cur>/<total>", function()
        local dir = vim.fs.normalize(vim.fn.tempname())
        vim.fn.mkdir(dir, "p")
        vim.fn.writefile({ "2" }, dir .. "/msgnum")
        vim.fn.writefile({ "4" }, dir .. "/end")
        local ok, err = pcall(function()
            assert.equals("2/4", rb.progress_for(dir))
        end)
        vim.fn.delete(dir, "rf")
        assert.is_true(ok, tostring(err))
    end)

    it("progress_for falls back to am-based next/last counters", function()
        local dir = vim.fs.normalize(vim.fn.tempname())
        vim.fn.mkdir(dir, "p")
        vim.fn.writefile({ "1" }, dir .. "/next")
        vim.fn.writefile({ "3" }, dir .. "/last")
        local ok, err = pcall(function()
            assert.equals("1/3", rb.progress_for(dir))
        end)
        vim.fn.delete(dir, "rf")
        assert.is_true(ok, tostring(err))
    end)

    it("progress_for is nil for a missing/empty state dir", function()
        assert.is_nil(rb.progress_for(nil))
        assert.is_nil(rb.progress_for(vim.fs.normalize(vim.fn.tempname())))
    end)

    it("in_progress is false in a fresh non-rebasing repo", function()
        local root = vim.fs.normalize(vim.fn.tempname())
        vim.fn.mkdir(root, "p")
        vim.fn.system({ "git", "-C", root, "init", "-q" })
        local ok, active = pcall(rb.in_progress, root)
        vim.fn.delete(root, "rf")
        assert.is_true(ok, tostring(active))
        assert.is_false(active)
    end)
end)
