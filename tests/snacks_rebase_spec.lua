-- Reproduces the "interactive rebase runs in the wrong repo after switching
-- submodule" bug. The snacks git_log picker can be scoped to a submodule cwd via
-- the <c-g> switcher, but Fugitive (which drives the interactive rebase) resolves
-- the repository from the CURRENT BUFFER, not the window's cwd. So an `lcd` into
-- the submodule does NOT redirect Fugitive -- it keeps operating on the parent
-- repo, and `git rebase -i <hash>^` fails with "invalid upstream" because <hash>
-- only exists in the submodule.
--
-- The fix (git_rebase_interactive in lua/plugins/ui/snacks.lua) opens the rebase
-- in a fresh tab whose [No Name] buffer pins no repo, with `tcd` set to the
-- picker's cwd, so Fugitive resolves the repo from that cwd. These tests pin a
-- buffer to a parent repo and assert that resolution mechanism.
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

    local function gitdir() return vim.fs.normalize(vim.fn.FugitiveGitDir()) end

    it("lcd into the submodule does NOT redirect Fugitive (the bug)", function()
        vim.cmd("lcd " .. vim.fn.fnameescape(sub))
        -- Still the parent repo -- this is exactly why the old code failed.
        assert.are.equal(vim.fs.normalize(main .. "/.git"), gitdir())
    end)

    it("fresh tab + tcd scopes Fugitive to the submodule (the fix)", function()
        vim.cmd("tabnew")
        vim.cmd("tcd " .. vim.fn.fnameescape(sub))
        assert.are.equal(vim.fs.normalize(sub .. "/.git"), gitdir())
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
