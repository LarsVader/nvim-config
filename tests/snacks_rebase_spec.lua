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
end)
