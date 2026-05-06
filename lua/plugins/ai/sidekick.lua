-- folke/sidekick.nvim — replaces greggh/claude-code.nvim. Bindings mirror
-- the keys we used to drive claude-code so muscle memory carries over.
-- Buffer-local <leader>cm in gitcommit buffers: ask Claude (in non-interactive
-- print mode) to generate a commit message, then insert it above the `#`
-- comment lines. We avoid the sidekick CLI window here because:
--   1. fugitive's commit layout uses floating windows that hide a vsplit.
--   2. nvim_put's bracketed paste makes sidekick's auto-submit unreliable.
-- Hash of git's empty tree, used to diff a root commit's content.
local GIT_EMPTY_TREE = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"

local function git(worktree, ...)
    local cmd = { "git", "-C", worktree, ... }
    local out = vim.fn.system(cmd)
    return out, vim.v.shell_error, cmd
end

-- Resolve the amend base: HEAD~ if it exists, otherwise the empty tree hash
-- (handles the root-commit edge case).
local function amend_base(worktree)
    local _, err = git(worktree, "rev-parse", "--verify", "HEAD~")
    return err == 0 and "HEAD~" or GIT_EMPTY_TREE
end

-- Detect amend by reading COMMIT_EDITMSG from disk: git pre-fills the previous
-- commit message there before invoking the editor. Reading the file (rather
-- than the buffer) is robust against fugitive's float reshuffling.
local function is_amend(path)
    local f = io.open(path, "r")
    if not f then return false end
    for line in f:lines() do
        if line:match("^#") then f:close(); return false end
        if line:match("%S") then f:close(); return true end
    end
    f:close()
    return false
end

local function send_commit_prompt(bufnr)
    local path = vim.api.nvim_buf_get_name(bufnr)
    if not path:match("COMMIT_EDITMSG$") then
        vim.notify("Not a git commit buffer", vim.log.levels.WARN)
        return
    end

    local worktree = vim.fn.FugitiveWorkTree()
    if worktree == "" then
        worktree = vim.fn.getcwd()
    end

    -- Amend → diff the full new commit (HEAD's tree + index) vs its parent so
    -- Claude sees the complete picture, including any newly-staged work on top
    -- of the original commit. Regular commit → just staged changes.
    local amend = is_amend(path)
    local diff, err
    if amend then
        diff, err = git(worktree, "diff", "--cached", amend_base(worktree))
    else
        diff, err = git(worktree, "diff", "--cached")
    end
    if err ~= 0 then
        vim.notify("git diff failed: " .. diff, vim.log.levels.ERROR)
        return
    end
    if diff == "" then
        vim.notify("No changes to summarize", vim.log.levels.WARN)
        return
    end

    local prompt = table.concat({
        "Write a Conventional Commits style commit message for the following ",
        "changes. Subject line under 70 chars in imperative mood. Add a body ",
        "(separated by a blank line) only if the change is non-trivial. ",
        "Return ONLY the message text — no quotes, no backticks, no explanations, ",
        "no Co-Authored-By footer.\n\n",
        diff,
    })

    vim.notify(
        amend and "Generating amended commit message via Claude..."
              or "Generating commit message via Claude...",
        vim.log.levels.INFO
    )

    vim.system({ "claude", "-p", "--model", "sonnet" }, { text = true, stdin = prompt, cwd = worktree }, function(result)
        vim.schedule(function()
            if not vim.api.nvim_buf_is_valid(bufnr) then return end
            if result.code ~= 0 then
                vim.notify("claude -p failed: " .. (result.stderr or ""), vim.log.levels.ERROR)
                return
            end
            local out = (result.stdout or ""):gsub("^%s+", ""):gsub("%s+$", "")
            out = out:gsub("^```[%w]*\n", ""):gsub("\n```$", "")
            if out == "" then
                vim.notify("Claude returned an empty message", vim.log.levels.WARN)
                return
            end

            -- Replace everything above the first `#` comment with Claude's
            -- output. This is correct for both fresh commits (nothing to
            -- replace) and amends (overwrite the previous message).
            local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
            local first_comment = #lines + 1
            for i, line in ipairs(lines) do
                if line:match("^#") then
                    first_comment = i
                    break
                end
            end
            local new_top = vim.split(out, "\n", { plain = true })
            table.insert(new_top, "")
            vim.api.nvim_buf_set_lines(bufnr, 0, first_comment - 1, false, new_top)
            vim.notify("Commit message inserted", vim.log.levels.INFO)
        end)
    end)
end

return {
    {
        'folke/sidekick.nvim',
        dependencies = {
            'folke/snacks.nvim',
        },
        init = function()
            vim.api.nvim_create_autocmd("FileType", {
                pattern = "gitcommit",
                group = vim.api.nvim_create_augroup("sidekick_commit_message", { clear = true }),
                callback = function(ev)
                    vim.keymap.set("n", "<leader>cm", function() send_commit_prompt(ev.buf) end, {
                        buffer = ev.buf,
                        desc = "Commit message via Claude",
                    })
                end,
            })
        end,
        opts = {
            -- Next Edit Suggestions need copilot-language-server. Off
            -- until/unless we install Copilot LSP.
            nes = { enabled = false },
            cli = {
                watch = true,
                win = {
                    layout = "right",
                    split = { width = 80 },
                },
                tools = {
                    claude = {},
                    -- Separate tool entry so <leader>ar can spawn `claude --resume`.
                    -- Sidekick exposes `resume`/`continue` fields on tool configs but
                    -- has no public API to invoke them, so we model resume as its
                    -- own session.
                    claude_resume = {
                        cmd = { "claude", "--resume" },
                        url = "https://github.com/anthropics/claude-code",
                    },
                },
            },
        },
        keys = {
            {
                '<C-,>',
                function()
                    -- Toggle whichever sidekick CLI is currently in play:
                    --   1. visible  → hide it
                    --   2. hidden but running → show the most-recently-used one
                    --   3. nothing running → open Claude as the default
                    local cli = require('sidekick.cli')
                    local terminals = require('sidekick.cli.terminal').terminals
                    for _, t in pairs(terminals) do
                        if not t.closed and t:is_open() then
                            t:hide()
                            return
                        end
                    end
                    local recent
                    for _, t in pairs(terminals) do
                        if not t.closed and t:is_running() then
                            if not recent or (t.atime or 0) > (recent.atime or 0) then
                                recent = t
                            end
                        end
                    end
                    if recent then
                        recent:show()
                        recent:focus()
                        return
                    end
                    cli.toggle({ name = 'claude', focus = true })
                end,
                mode = { 'n', 't' },
                desc = 'Toggle current CLI (default Claude)',
            },
            {
                '<leader>ac',
                function() require('sidekick.cli').toggle({ name = 'claude', focus = true }) end,
                mode = { 'n' },
                desc = 'Toggle Claude CLI',
            },
            {
                '<leader>ag',
                function() require('sidekick.cli').toggle({ name = 'copilot', focus = true }) end,
                mode = { 'n' },
                desc = 'Toggle GitHub Copilot CLI',
            },
            {
                '<leader>ar',
                function() require('sidekick.cli').toggle({ name = 'claude_resume', focus = true }) end,
                desc = 'Resume Claude',
            },
            {
                '<leader>as',
                function() require('sidekick.cli').send({ msg = '{selection}', name = 'claude' }) end,
                mode = 'x',
                desc = 'Send selection to Claude',
            },
            {
                '<leader>ak',
                function() require('sidekick.cli').close({ all = true }) end,
                desc = 'Kill Claude session',
            },
            {
                '<leader>ap',
                function() require('sidekick.cli').prompt() end,
                mode = { 'n', 'x' },
                desc = 'Sidekick prompt',
            },
        },
    },
}
