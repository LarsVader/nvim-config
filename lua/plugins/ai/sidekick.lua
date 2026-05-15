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

-- Walk treesitter ancestors from cursor looking for a function-ish node so the
-- headless prompt has something meaningful to chew on when invoked from normal
-- mode without a selection.
local function enclosing_function_range()
    local ok, node = pcall(vim.treesitter.get_node)
    if not ok or not node then return nil end
    while node do
        local t = node:type()
        if t:match("function") or t:match("method") or t:match("declaration") or t:match("constructor") then
            local r1, _, r2 = node:range()
            return r1, r2 + 1
        end
        node = node:parent()
    end
    return nil
end

-- Resolve the insertion row + context text for a headless prompt. Priority:
-- visual selection → enclosing function (treesitter) → current line.
-- Returns (insert_row_0indexed, context_text).
local function headless_target()
    local m = vim.fn.mode()
    if m == "v" or m == "V" or m == "\22" then
        local s = vim.fn.getpos("v")
        local e = vim.fn.getpos(".")
        if s[2] > e[2] or (s[2] == e[2] and s[3] > e[3]) then
            s, e = e, s
        end
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
        local r1, r2 = s[2] - 1, e[2]
        local lines = vim.api.nvim_buf_get_lines(0, r1, r2, false)
        return r1, table.concat(lines, "\n")
    end
    local r1, r2 = enclosing_function_range()
    if r1 then
        local lines = vim.api.nvim_buf_get_lines(0, r1, r2, false)
        return r1, table.concat(lines, "\n")
    end
    local row = vim.api.nvim_win_get_cursor(0)[1] - 1
    return row, vim.api.nvim_get_current_line()
end

-- Templates for the headless prompt shortcuts. Phrased to elicit a bare,
-- insertable response — no code fences, no surrounding prose. The placeholders
-- are filled with the buffer's filetype and the captured context.
local HEADLESS_PROMPTS = {
    document = "Add documentation comments for the following %s code. Return ONLY the documentation block (no code, no fences, no prose) in the conventional comment style for %s.\n\n%s",
}

-- Headless dispatch for the <leader>a{d,e,f}{g,c}{f,h,s,o} shortcuts. Mirrors
-- the UX of <leader>cm: no sidekick CLI window, response is inserted directly
-- above the target range.
local function run_headless_prompt(action, cli, model)
    local tmpl = HEADLESS_PROMPTS[action]
    if not tmpl then
        vim.notify("Unknown headless action: " .. tostring(action), vim.log.levels.ERROR)
        return
    end

    local bufnr = vim.api.nvim_get_current_buf()
    local insert_row, context_text = headless_target()
    if not context_text or context_text:match("^%s*$") then
        vim.notify("No context to send", vim.log.levels.WARN)
        return
    end

    local ft = vim.bo[bufnr].filetype
    if ft == "" then ft = "source" end
    local prompt = string.format(tmpl, ft, ft, context_text)

    local cmd, opts
    if cli == "claude" then
        cmd = { "claude", "-p", "--model", model }
        opts = { text = true, stdin = prompt }
    elseif cli == "copilot" then
        -- --allow-all-tools is required by the copilot CLI for -p/non-interactive
        -- mode; --silent strips the trailing stats so stdout is just the answer.
        cmd = { "copilot", "-p", prompt, "--model", model, "--allow-all-tools", "--silent" }
        opts = { text = true }
    else
        vim.notify("Unknown CLI: " .. tostring(cli), vim.log.levels.ERROR)
        return
    end

    vim.notify(("[%s] %s/%s working..."):format(action, cli, model), vim.log.levels.INFO)
    vim.system(cmd, opts, function(result)
        vim.schedule(function()
            if not vim.api.nvim_buf_is_valid(bufnr) then return end
            if result.code ~= 0 then
                vim.notify(("%s failed: %s"):format(cli, result.stderr or ""), vim.log.levels.ERROR)
                return
            end
            local out = (result.stdout or ""):gsub("^%s+", ""):gsub("%s+$", "")
            out = out:gsub("^```[%w]*\n", ""):gsub("\n```$", "")
            if out == "" then
                vim.notify(cli .. " returned an empty response", vim.log.levels.WARN)
                return
            end
            local new_lines = vim.split(out, "\n", { plain = true })
            table.insert(new_lines, "")
            vim.api.nvim_buf_set_lines(bufnr, insert_row, insert_row, false, new_lines)
            vim.notify(("[%s] inserted %d lines"):format(action, #new_lines - 1), vim.log.levels.INFO)
        end)
    end)
end

-- Find the most-recently-used running sidekick terminal whose tool name belongs
-- to a family (e.g. all `claude*` or all `copilot*` variants). Used by the
-- reworked <leader>ap picker so "use existing session" entries reuse whichever
-- model variant is already open.
local function most_recent_in_family(prefix)
    local ok, Terminal = pcall(require, "sidekick.cli.terminal")
    if not ok then return nil end
    local recent
    for _, t in pairs(Terminal.terminals or {}) do
        local name = t.tool and t.tool.name
        local matches = name == prefix or (name and name:sub(1, #prefix + 1) == prefix .. "_")
        if matches and not t.closed and t:is_running() then
            if not recent or (t.atime or 0) > (recent.atime or 0) then
                recent = t
            end
        end
    end
    return recent
end

-- Close + immediately reopen the sidekick CLI that's currently focused (or, if
-- the cursor is in a regular buffer, the most-recently-used one). Each fresh
-- spawn gets a new session UUID, so the previous chat is preserved in the
-- CLI's history and reachable via --resume — unlike /clear which discards
-- context in-place.
local function new_chat_of_active_cli()
    local ok, Terminal = pcall(require, "sidekick.cli.terminal")
    if not ok then
        vim.notify("sidekick terminal module not available", vim.log.levels.ERROR)
        return
    end
    local cli = require("sidekick.cli")
    local cur_buf = vim.api.nvim_get_current_buf()

    local target
    for _, t in pairs(Terminal.terminals or {}) do
        if t.buf == cur_buf and not t.closed then
            target = t
            break
        end
    end
    if not target then
        for _, t in pairs(Terminal.terminals or {}) do
            if not t.closed and t:is_running() then
                if not target or (t.atime or 0) > (target.atime or 0) then
                    target = t
                end
            end
        end
    end

    local name = target and target.tool and target.tool.name
    if not name then
        vim.notify("No active sidekick CLI to restart", vim.log.levels.WARN)
        return
    end

    -- cli.close's internals are double-scheduled (State.with wraps both the
    -- `use` callback and the final `cb` in vim.schedule_wrap), so a single
    -- vim.schedule fires cli.show before State.detach has actually run — show
    -- then sees claude still attached and just re-focuses the old terminal,
    -- which the queued detach immediately tears down. defer_fn past the close
    -- chain (two schedule hops + the terminal:close call) is the only way to
    -- guarantee show sees an unattached state and spawns a fresh session.
    cli.close({ name = name })
    vim.defer_fn(function()
        cli.show({ name = name, focus = true })
    end, 200)
end

-- Two-step picker for <leader>ap: first pick a prompt (sidekick's built-in
-- picker, callback form), then always pick a CLI/model destination — even when
-- only one CLI is open. Existing-session entries route to whichever model
-- variant of that family is most recent.
local function pick_prompt_and_send()
    require("sidekick.cli").prompt({
        cb = function(msg)
            if not msg or msg == "" then return end

            local choices = {}
            local copilot_recent = most_recent_in_family("copilot")
            if copilot_recent then
                table.insert(choices, { label = "github (use existing session)", name = copilot_recent.tool.name })
            end
            local claude_recent = most_recent_in_family("claude")
            if claude_recent then
                table.insert(choices, { label = "claude (use existing session)", name = claude_recent.tool.name })
            end
            table.insert(choices, { label = "new github 5.5mini", name = "copilot_free"   })
            table.insert(choices, { label = "new github haiku",   name = "copilot_haiku"  })
            table.insert(choices, { label = "new github sonnet",  name = "copilot_sonnet" })
            table.insert(choices, { label = "new github opus",    name = "copilot_opus"   })
            table.insert(choices, { label = "new claude haiku",   name = "claude_haiku"   })
            table.insert(choices, { label = "new claude sonnet", name = "claude_sonnet" })
            table.insert(choices, { label = "new claude opus",    name = "claude_opus"    })

            vim.ui.select(choices, {
                prompt = "Send to:",
                format_item = function(c) return c.label end,
            }, function(choice)
                if not choice then return end
                require("sidekick.cli").send({ msg = msg, name = choice.name, focus = true })
            end)
        end,
    })
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
                    -- Model-pinned variants so the <leader>ap picker (and the
                    -- headless <leader>a*{c,g}* shortcuts) can target a specific
                    -- model. Each variant is a distinct sidekick "tool" because
                    -- sidekick keys sessions by tool name.
                    claude_haiku = {
                        cmd = { "claude", "--model", "haiku" },
                        url = "https://github.com/anthropics/claude-code",
                    },
                    claude_sonnet = {
                        cmd = { "claude", "--model", "sonnet" },
                        url = "https://github.com/anthropics/claude-code",
                    },
                    claude_opus = {
                        cmd = { "claude", "--model", "opus" },
                        url = "https://github.com/anthropics/claude-code",
                    },
                    copilot_free = {
                        cmd = { "copilot", "--banner", "--model", "gpt-5-mini" },
                    },
                    copilot_haiku = {
                        cmd = { "copilot", "--banner", "--model", "claude-haiku-4.5" },
                    },
                    copilot_sonnet = {
                        cmd = { "copilot", "--banner", "--model", "claude-sonnet-4.5" },
                    },
                    copilot_opus = {
                        cmd = { "copilot", "--banner", "--model", "claude-opus-4.1" },
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
                '<M-n>',
                function() new_chat_of_active_cli() end,
                mode = { 'n', 't' },
                desc = 'New chat — restart current CLI (preserves history)',
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
                function()
                    -- Open the regular `claude` tool and send the /resume slash
                    -- command so the resumed session lives inside the same
                    -- terminal/tool identity as a normal claude chat. That way
                    -- <M-n> from a resumed chat respawns plain `claude` instead
                    -- of looping back into `claude --resume`'s picker.
                    -- The defer gives claude's TUI a chance to spawn its welcome
                    -- screen before we type into it; if claude is already
                    -- running, the wait is just dead time.
                    local cli = require('sidekick.cli')
                    cli.show({ name = 'claude', focus = true })
                    vim.defer_fn(function()
                        cli.send({ name = 'claude', msg = '/resume', submit = true })
                    end, 500)
                end,
                desc = 'Resume Claude (/resume in claude session)',
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
            -- Headless one-shot document prompts: send selection (or enclosing
            -- function) to a hard-coded CLI/model and insert the doc comments
            -- above the target range. No sidekick window is opened — same UX
            -- as <leader>cm. Naming: <leader>ad<cli><model> where
            --   <cli>   = g (github) / c (claude)
            --   <model> = f (free=gpt-5-mini, github only) / h (haiku) /
            --             s (sonnet) / o (opus)
            {
                '<leader>adgf',
                function() run_headless_prompt('document', 'copilot', 'gpt-5-mini') end,
                mode = { 'n', 'x' },
                desc = 'AI document — github (gpt-5-mini), headless',
            },
            {
                '<leader>adgh',
                function() run_headless_prompt('document', 'copilot', 'claude-haiku-4.5') end,
                mode = { 'n', 'x' },
                desc = 'AI document — github (haiku), headless',
            },
            {
                '<leader>adgs',
                function() run_headless_prompt('document', 'copilot', 'claude-sonnet-4.5') end,
                mode = { 'n', 'x' },
                desc = 'AI document — github (sonnet), headless',
            },
            {
                '<leader>adgo',
                function() run_headless_prompt('document', 'copilot', 'claude-opus-4.1') end,
                mode = { 'n', 'x' },
                desc = 'AI document — github (opus), headless',
            },
            {
                '<leader>adch',
                function() run_headless_prompt('document', 'claude', 'haiku') end,
                mode = { 'n', 'x' },
                desc = 'AI document — claude (haiku), headless',
            },
            {
                '<leader>adcs',
                function() run_headless_prompt('document', 'claude', 'sonnet') end,
                mode = { 'n', 'x' },
                desc = 'AI document — claude (sonnet), headless',
            },
            {
                '<leader>adco',
                function() run_headless_prompt('document', 'claude', 'opus') end,
                mode = { 'n', 'x' },
                desc = 'AI document — claude (opus), headless',
            },
            {
                '<leader>ap',
                function() pick_prompt_and_send() end,
                mode = { 'n', 'x' },
                desc = 'Sidekick prompt → pick CLI/model',
            },
        },
    },
}
