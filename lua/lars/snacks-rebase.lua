--- Prepare an interactive rebase from the snacks git_log picker.
---
-- The snacks picker cannot reorder its own rows (the order comes from the
-- `git log` finder), so this module splits the job: you *mark* commits with
-- rebase actions (edit/reword/squash/fixup/drop) directly in the picker, then
-- <c-r>i launches the rebase and the native git-rebase-todo buffer opens
-- PRE-FILLED with those actions -- where reordering lines is trivial. Save the
-- buffer (:wq) to run, or quit without writing to abort.
--
-- Flow:
--   1. `tag(picker, action)`  -- mark the selected/cursor commit(s). Marks are
--      keyed by full hash and accumulate across scrolling/selection.
--   2. `launch(picker, item)` -- compute the rebase base (parent of the oldest
--      commit among the cursor + all marks that are ancestors of HEAD), stash
--      the marks in `M.pending`, and open `:G rebase -i <base>` in a fresh tab
--      scoped (tcd) to the picker's cwd so Fugitive resolves the right repo
--      (incl. submodules selected via the <c-g> switcher).
--   3. The `FileType gitrebase` autocmd below sees `M.pending`, rewrites the
--      `pick` lines whose hash matches a mark, and clears it (one-shot).

local M = {}

--- commit full-hash -> rebase action ("edit"|"reword"|"squash"|"fixup"|"drop"|"pick")
---@type table<string, string>
M.tags = {}

--- Marks captured for the in-flight rebase, consumed by the gitrebase autocmd.
---@type table<string, string>|nil
M.pending = nil

--- Repo cwd of the most recent launch, so the in-progress rebase can be found
--- again from anywhere (the rebase no longer runs in a dedicated tab/cwd).
---@type string|nil
M.last_cwd = nil

--- rebase-merge state dir of the most recent launch -- the lualine progress
--- fast path reads it directly (no subprocess).
---@type string|nil
M.rebase_state_dir = nil

-- "pick" is the implicit default, so marking pick just removes the mark.
local ACTIONS = { edit = true, reword = true, squash = true, fixup = true, drop = true, pick = true }

-- Per-action picker badge (text + highlight). Standard diagnostic groups so we
-- never depend on a snacks-specific highlight existing.
local BADGE = {
    edit = { "edit", "DiagnosticWarn" },
    reword = { "reword", "DiagnosticInfo" },
    squash = { "squash", "DiagnosticHint" },
    fixup = { "fixup", "DiagnosticHint" },
    drop = { "drop", "DiagnosticError" },
}
-- Width of the badge column (longest label + a trailing space), so marked and
-- unmarked rows stay aligned once any mark exists.
local BADGE_W = 7

-- git-rebase-todo short verbs -> full names, for the in-progress todo view.
local VERB = {
    p = "pick", e = "edit", r = "reword", s = "squash",
    f = "fixup", d = "drop", x = "exec", b = "break",
}

-- Status glyph + highlight for each step in the in-progress rebase view.
local STATUS = {
    done = { "✓", "Comment" },          -- already applied
    stop = { "▶", "DiagnosticWarn" },   -- where the rebase is paused (current)
    todo = { "·", "DiagnosticHint" },   -- still to do
}

--- Any marks pending?
---@return boolean
function M.has_marks()
    return next(M.tags) ~= nil
end

--- The action marked for a (possibly abbreviated) commit hash, or nil. Matches
--- by abbrev-hash prefix against the full-hash mark keys -- no git call.
---@param commit string|nil
---@return string|nil
function M.action_for(commit)
    if not commit then return nil end
    commit = commit:lower()
    for full, action in pairs(M.tags) do
        if full:sub(1, #commit) == commit then return action end
    end
    return nil
end

--- A snacks format() that prepends a fixed-width rebase-mark badge to the
--- default git_log row. The badge column only appears once something is marked,
--- so an unmarked log renders exactly as stock snacks.
---@param item table
---@param picker table
---@return table[] highlights
function M.format(item, picker)
    local ret = Snacks.picker.format.git_log(item, picker)
    if not M.has_marks() then return ret end
    local align = Snacks.picker.util.align
    local badge = BADGE[M.action_for(item.commit) or ""]
    if badge then
        table.insert(ret, 1, { " " })
        table.insert(ret, 1, { align(badge[1], BADGE_W), badge[2] })
    else
        table.insert(ret, 1, { align("", BADGE_W + 1) })
    end
    return ret
end

-- Force the visible rows to re-run format() so badges appear/update/clear.
local function redraw(picker)
    if picker and picker.list then picker.list:update({ force = true }) end
end

local function git(cwd, ...)
    return vim.system({ "git", "-C", cwd, ... }):wait()
end

--- Resolve a (possibly abbreviated) commit-ish to its full hash, or nil.
---@param cwd string
---@param commit string
---@return string|nil
function M.resolve_full(cwd, commit)
    local res = git(cwd, "rev-parse", "--verify", "--quiet", commit .. "^{commit}")
    if res.code ~= 0 then return nil end
    return (res.stdout or ""):gsub("%s+$", "")
end

--- Is `a` an ancestor of (or equal to) `b`?
---@param cwd string
---@param a string
---@param b string
---@return boolean
function M.is_ancestor(cwd, a, b)
    return git(cwd, "merge-base", "--is-ancestor", a, b).code == 0
end

--- The ancestor-most (oldest) commit in the list, by pairwise ancestry.
---@param cwd string
---@param commits string[]
---@return string|nil
function M.oldest(cwd, commits)
    local oldest
    for _, c in ipairs(commits) do
        if not oldest or M.is_ancestor(cwd, c, oldest) then oldest = c end
    end
    return oldest
end

-- The marked action for a todo line's abbreviated hash (prefix match against
-- the full-hash mark keys), excluding the implicit "pick". nil if unmarked.
local function tag_action(hash, tags)
    for full, action in pairs(tags) do
        if action ~= "pick" and full:sub(1, #hash) == hash then return action end
    end
    return nil
end

--- Rebuild a git-rebase-todo from `tags` (full hash -> action) and an optional
--- `order` (commit hashes, OLDEST first). The `pick` command lines are sorted
--- to match `order` (matched by hash prefix; commits absent from `order` keep
--- their original relative order) and have their keyword swapped per `tags`.
--- Comment/blank lines stay in their original slots. Because it only permutes
--- and re-keywords the lines git itself generated, the commit set is always
--- exactly what git expects. Pure -- the unit tests exercise this directly.
---@param lines string[]
---@param tags table<string, string>
---@param order? string[] desired commit order, oldest first
---@return string[] new_lines, integer applied, boolean reordered
function M.apply_to_lines(lines, tags, order)
    -- Collect the command (pick) lines and the file slots they occupy.
    local slots, cmds = {}, {}
    for i, line in ipairs(lines) do
        local kw, hash = line:match("^(%a+)%s+([0-9a-fA-F]+)")
        if kw == "pick" or kw == "p" then
            slots[#slots + 1] = i
            cmds[#cmds + 1] = { orig = #slots, line = line, hash = hash:lower() }
        end
    end

    -- Rank a command by its position in `order`; unknown commits rank last and
    -- keep their original relative order (stable).
    local function rank(hash)
        if order then
            for k, oh in ipairs(order) do
                oh = oh:lower()
                local n = math.min(#oh, #hash)
                if oh:sub(1, n) == hash:sub(1, n) then return k end
            end
        end
        return math.huge
    end
    table.sort(cmds, function(a, b)
        local ra, rb = rank(a.hash), rank(b.hash)
        if ra ~= rb then return ra < rb end
        return a.orig < b.orig
    end)

    local applied, reordered = 0, false
    for n, c in ipairs(cmds) do
        if c.orig ~= n then reordered = true end
        local action = tag_action(c.hash, tags)
        if action then
            c.line = action .. c.line:match("^%a+(.*)$")
            applied = applied + 1
        end
    end

    local out = vim.deepcopy(lines)
    for n, slot in ipairs(slots) do out[slot] = cmds[n].line end
    return out, applied, reordered
end

--- Move the commit under the cursor one row up (dir -1) or down (dir 1) by
--- permuting the displayed `list.items` in place. Only valid with an empty
--- filter: with no pattern the list is unsorted (no score ranking, no topk), so
--- its order is the rebase order and a swap reorders the rendered rows. With an
--- active filter the rows are a score-sorted subset, so we refuse.
---@param picker table
---@param dir integer -1 (up) or 1 (down)
function M.move(picker, dir)
    local list = picker and picker.list
    if not list then return end
    if picker.matcher and not picker.matcher:empty() then
        return Snacks.notify.warn("Clear the filter to reorder commits", { title = "Git Rebase" })
    end
    local i = list.cursor
    -- Reverse layouts invert the index direction of "up"/"down" on screen.
    local neighbor = i + (list.reverse and -dir or dir)
    if neighbor < 1 or neighbor > #list.items then return end
    list.items[i], list.items[neighbor] = list.items[neighbor], list.items[i]
    list.dirty = true
    list:move(dir) -- re-render and follow the moved commit
end

--- Mark the selected (or cursor) commit(s) with a rebase action. "pick" clears
--- the mark. Marks accumulate in `M.tags` until launch or `clear()`.
---@param picker table snacks picker
---@param action string one of ACTIONS
function M.tag(picker, action)
    if not ACTIONS[action] then return end
    local items = picker:selected({ fallback = true })
    local marked = 0
    for _, item in ipairs(items or {}) do
        if item and item.commit then
            local cwd = item.cwd or picker:cwd()
            local full = M.resolve_full(cwd, item.commit)
            if full then
                M.tags[full] = action ~= "pick" and action or nil
                marked = marked + 1
            end
        end
    end
    if marked == 0 then
        return Snacks.notify.warn("No commit under cursor", { title = "Git Rebase" })
    end
    redraw(picker)
    local total = vim.tbl_count(M.tags)
    local verb = action == "pick" and "unmarked" or ("marked " .. action)
    Snacks.notify(("%s %d commit(s) -- %d mark(s) pending (<c-r>i to start)"):format(verb, marked, total),
        { title = "Git Rebase" })
end

--- Drop all pending marks.
---@param picker table|nil snacks picker (to refresh badges)
function M.clear(picker)
    local had = vim.tbl_count(M.tags)
    M.tags = {}
    redraw(picker)
    Snacks.notify(("Cleared %d rebase mark(s)"):format(had), { title = "Git Rebase" })
end

--- Launch the interactive rebase, seeding the todo with the pending marks and
--- the picker's current order. With no marks and no reordering this is a plain
--- interactive rebase from the cursor commit.
---@param picker table snacks picker
---@param item table commit item under the cursor
function M.launch(picker, item)
    if not (item and item.commit) then
        return Snacks.notify.warn("No commit under cursor", { title = "Git Rebase" })
    end
    local cwd = item.cwd or picker:cwd()

    -- Range floor = oldest of {cursor} + {marks that are ancestors of HEAD}.
    -- Marks off HEAD's history can't appear in the todo, so exclude them from
    -- the base computation (and warn) rather than widen to unrelated history.
    local set, dropped = {}, 0
    local cursor_full = M.resolve_full(cwd, item.commit)
    if cursor_full then set[cursor_full] = true end
    local tags_in_range = {}
    for full, action in pairs(M.tags) do
        if M.is_ancestor(cwd, full, "HEAD") then
            set[full] = true
            tags_in_range[full] = action
        else
            dropped = dropped + 1
        end
    end
    local oldest = M.oldest(cwd, vim.tbl_keys(set))
    if not oldest then
        return Snacks.notify.error("Could not resolve a rebase base", { title = "Git Rebase" })
    end

    -- Capture the picker's display order (newest first) as the desired rebase
    -- order, reversed to oldest-first to match the todo. Read list.items (what's
    -- actually rendered, and what move() permutes), not finder.items which keeps
    -- the original order. Unmodified this equals git's natural order -- a no-op.
    local order = {}
    local disp = (picker.list and picker.list.items) or {}
    for k = #disp, 1, -1 do
        local c = disp[k] and disp[k].commit
        if c then order[#order + 1] = c end
    end

    M.last_cwd = cwd
    picker:close()
    M.pending = { tags = tags_in_range, order = order }
    M.tags = {}
    if dropped > 0 then
        Snacks.notify.warn(("Ignored %d mark(s) not on HEAD's history"):format(dropped), { title = "Git Rebase" })
    end

    -- Interactive rebase needs an editor for the todo list, so delegate to
    -- Fugitive (it wires GIT_SEQUENCE_EDITOR/GIT_EDITOR back into nvim). Fugitive
    -- normally resolves the repo from the current buffer, but fugitive#Command
    -- takes an explicit git dir as its last argument -- so we scope to the
    -- picker's repo directly, with NO tab/tcd and no change to the current
    -- buffer. Our gitrebase autocmd seeds + auto-confirms the todo. <commit>^
    -- makes the base commit editable; the root commit has no parent, so fall
    -- back to --root (rebase from the very first commit).
    vim.schedule(function()
        require("lazy").load({ plugins = { "vim-fugitive" } })
        local has_parent = git(cwd, "rev-parse", "--verify", "--quiet", oldest .. "^").code == 0
        local range = has_parent and ("-i " .. oldest .. "^") or "-i --root"
        local gitdir = vim.trim((git(cwd, "rev-parse", "--absolute-git-dir").stdout or ""))
        if gitdir == "" then
            M.pending = nil
            return Snacks.notify.error("Could not resolve the git dir", { title = "Git Rebase" })
        end
        -- Remember the state dir for the cheap lualine progress check (no
        -- subprocess on the fast path). Cleared implicitly when it stops existing.
        M.rebase_state_dir = vim.fs.normalize(gitdir .. "/rebase-merge")
        -- args: (line1, line2, range, bang, mods, arg, dir)
        local ok, after = pcall(vim.fn["fugitive#Command"], 0, 0, 0, 0, "", "rebase " .. range, gitdir)
        if not ok then
            M.pending = nil
            return Snacks.notify.error("Interactive rebase failed: " .. tostring(after), { title = "Git Rebase" })
        end
        -- fugitive#Command returns an Ex "after" string the :Git wrapper runs.
        if type(after) == "string" and after ~= "" then pcall(vim.cmd, after) end
    end)
end

-- The state dir of an in-progress rebase for `cwd`'s repo, or nil. Interactive
-- rebases use rebase-merge, plain ones rebase-apply. --git-path always returns a
-- path (rebase or not), so existence of the dir is the actual test.
local function rebase_dir(cwd)
    for _, kind in ipairs({ "rebase-merge", "rebase-apply" }) do
        local res = git(cwd, "rev-parse", "--git-path", kind)
        if res.code == 0 then
            local path = (res.stdout or ""):gsub("%s+$", "")
            if path ~= "" then
                -- --git-path returns a path relative to cwd unless already absolute.
                if not (path:match("^%a:[/\\]") or path:match("^/")) then
                    path = cwd .. "/" .. path
                end
                path = vim.fs.normalize(path)
                if vim.fn.isdirectory(path) == 1 then return path end
            end
        end
    end
    return nil
end

-- All directories worth probing for an in-progress rebase: the repo we last
-- launched one in, every open file's directory, and every window/tab cwd. Broad
-- on purpose -- the rebase no longer runs in a dedicated cwd, so it can be found
-- from wherever any related buffer or window happens to be.
local function candidate_dirs()
    local seen, out = {}, {}
    local function add(c)
        if c and c ~= "" and not seen[c] then
            seen[c] = true
            out[#out + 1] = c
        end
    end
    add(M.last_cwd)
    add(vim.fn.getcwd())
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(b) then
            local name = vim.api.nvim_buf_get_name(b)
            if name ~= "" and not name:match("^%w+://") then add(vim.fs.dirname(name)) end
        end
    end
    for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
            local ok, wcwd = pcall(vim.fn.getcwd, vim.api.nvim_win_get_number(win), vim.api.nvim_tabpage_get_number(tab))
            if ok then add(wcwd) end
        end
    end
    return out
end

--- Is a rebase in progress? With no `cwd`, probes a broad set of candidate repos
--- (see candidate_dirs). Returns the state dir and the repo it belongs to.
---@param cwd string|nil
---@return boolean active, string|nil dir, string|nil repo_cwd
function M.in_progress(cwd)
    local candidates = cwd and { cwd } or candidate_dirs()
    for _, c in ipairs(candidates) do
        local dir = rebase_dir(c)
        if dir then return true, dir, c end
    end
    return false, nil, nil
end

-- Parse commit-bearing steps from a rebase state file, tagging each with status.
-- exec/break/label/merge lines carry no hash and simply don't match.
local function parse_steps(file, status, into)
    if vim.fn.filereadable(file) ~= 1 then return end
    for _, line in ipairs(vim.fn.readfile(file)) do
        local verb, hash, subject = line:match("^(%a+)%s+(%x%x%x%x+)%s+(.*)$")
        if verb then
            into[#into + 1] = { status = status, action = VERB[verb] or verb, commit = hash, subject = subject }
        end
    end
end

--- Parse the REMAINING steps from a rebase-merge dir's git-rebase-todo.
---@param dir string
---@return { action: string, commit: string, subject: string }[]
function M.read_todo(dir)
    local items = {}
    parse_steps(dir .. "/git-rebase-todo", "todo", items)
    return items
end

--- Parse the full rebase picture: completed steps from `done` (the last of which
--- is the current stop), then the remaining steps from git-rebase-todo. When the
--- rebase is paused on an `edit` of the newest commit, git-rebase-todo is empty
--- and only `done` carries the (stopped) commit -- which is exactly the one the
--- user wants to see, so a remaining-only view would wrongly look empty.
---@param dir string
---@return { status: string, action: string, commit: string, subject: string }[]
function M.read_steps(dir)
    local steps = {}
    parse_steps(dir .. "/done", "done", steps)
    if #steps > 0 then steps[#steps].status = "stop" end -- last done = current
    parse_steps(dir .. "/git-rebase-todo", "todo", steps)
    return steps
end

--- Entry point for <leader>fi: show the in-progress rebase's steps, or report
--- that none is running.
function M.open_todo()
    local active, dir, repo = M.in_progress()
    if active then
        return M.show_todo(repo, dir)
    end
    Snacks.notify("No rebase in progress", { title = "Git Rebase" })
end

local function read_num(path)
    if vim.fn.filereadable(path) ~= 1 then return nil end
    return tonumber((vim.fn.readfile(path)[1] or ""):match("%d+"))
end

--- "<current>/<total>" progress for a rebase state dir, or nil. Reads git's own
--- step counters (msgnum/end for interactive, next/last for am-based) -- plain
--- file reads, no subprocess.
---@param dir string|nil rebase-merge (or rebase-apply) state dir
---@return string|nil
function M.progress_for(dir)
    if not (dir and vim.fn.isdirectory(dir) == 1) then return nil end
    local cur = read_num(dir .. "/msgnum") or read_num(dir .. "/next")
    local total = read_num(dir .. "/end") or read_num(dir .. "/last")
    return (cur and total) and string.format("%d/%d", cur, total) or nil
end

-- Throttle the progress lookup so the lualine component never spawns more than
-- one git subprocess per second (the fast path -- a launched rebase's cached
-- state dir -- spawns none).
local prog_cache = { t = -1e9, val = nil }

--- Cheap, throttled rebase progress ("2/4") for the statusline, or nil.
---@return string|nil
function M.progress()
    local now = vim.loop.now()
    if now - prog_cache.t < 900 then return prog_cache.val end
    prog_cache.t = now
    local dir = M.rebase_state_dir
    if not (dir and vim.fn.isdirectory(dir) == 1) then
        -- No cached dir (e.g. after a restart): resolve from the current buffer's
        -- repo -- the right scope for a per-window statusline. One subprocess,
        -- throttled by prog_cache.
        local bufname = vim.api.nvim_buf_get_name(0)
        local base = (bufname ~= "" and not bufname:match("^%w+://")) and vim.fs.dirname(bufname) or vim.fn.getcwd()
        dir = rebase_dir(base)
    end
    prog_cache.val = M.progress_for(dir)
    return prog_cache.val
end

--- Lualine component: "⟳ rebase 2/4" while a rebase is in progress, else "".
---@return string
function M.lualine()
    local p = M.progress()
    return p and ("⟳ rebase " .. p) or ""
end

--- Open a picker showing the in-progress rebase: completed steps, the current
--- stop, and the remaining steps -- each with its action and a `git show`
--- preview. Used by <leader>fi while rebasing.
---@param cwd string
---@param dir string rebase-merge state directory
function M.show_todo(cwd, dir)
    local steps = M.read_steps(dir)
    if #steps == 0 then
        return Snacks.notify("No rebase steps found", { title = "Git Rebase" })
    end

    -- The current stop (an `edit` pause, or a conflict) isn't finished from the
    -- user's point of view, so it counts as remaining alongside the todo steps.
    local left = 0
    for _, s in ipairs(steps) do
        if s.status == "todo" or s.status == "stop" then left = left + 1 end
    end

    Snacks.picker.pick({
        source = "rebase_todo",
        title = ("Rebase: %d step(s), %d left"):format(#steps, left),
        finder = function()
            -- Reverse to newest/upcoming-first so it reads like the git_log picker
            -- (read_steps yields oldest->newest execution order).
            local ret = {}
            for i = #steps, 1, -1 do
                local s = steps[i]
                ret[#ret + 1] = {
                    text = (#steps - i + 1) .. " " .. s.action .. " " .. s.commit .. " " .. s.subject,
                    idx = #ret + 1,
                    status = s.status,
                    action = s.action,
                    commit = s.commit,
                    cwd = cwd,
                    subject = s.subject,
                }
            end
            return ret
        end,
        format = function(item)
            local align = Snacks.picker.util.align
            local st = STATUS[item.status] or STATUS.todo
            local dim = item.status == "done"
            local label = (BADGE[item.action] or { item.action })[1]
            local action_hl = dim and "Comment" or (BADGE[item.action] or { nil, "SnacksPickerGitCommit" })[2]
            return {
                { st[1] .. " ", st[2] },
                { align(label, BADGE_W), action_hl },
                { " " },
                { align(item.commit, 8, { truncate = true }), dim and "Comment" or "SnacksPickerGitCommit" },
                { " " },
                { item.subject or "", dim and "Comment" or nil },
            }
        end,
        preview = "git_show",
    })
end

-- Apply the pending plan (marks + order) to the native rebase-todo buffer the
-- moment it opens. One-shot: cleared on the first gitrebase buffer so unrelated
-- rebases (or a no-op <c-r>i) are never touched.
vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("LarsSnacksRebasePlan", { clear = true }),
    pattern = "gitrebase",
    callback = function(ev)
        if not M.pending then return end
        local plan = M.pending
        M.pending = nil
        local lines = vim.api.nvim_buf_get_lines(ev.buf, 0, -1, false)
        local new_lines, applied, reordered = M.apply_to_lines(lines, plan.tags or {}, plan.order)
        -- Nothing prepared (bare <c-r>i) -> leave the todo open for manual edit.
        if applied == 0 and not reordered then return end
        vim.api.nvim_buf_set_lines(ev.buf, 0, -1, false, new_lines)
        local parts = {}
        if reordered then parts[#parts + 1] = "reordered" end
        if applied > 0 then parts[#parts + 1] = applied .. " action(s)" end
        vim.notify(("Rebase: %s -- running"):format(table.concat(parts, ", ")),
            vim.log.levels.INFO, { title = "Git Rebase" })
        -- Skip the review step: confirm the seeded todo immediately (same as the
        -- user pressing :wq), so the rebase runs straight away. reword/squash
        -- message buffers (gitcommit, not gitrebase) are untouched and still open
        -- for editing; an `edit` stop just pauses the rebase as usual.
        local buf = ev.buf
        vim.schedule(function()
            if not vim.api.nvim_buf_is_valid(buf) then return end
            local win = vim.fn.bufwinid(buf)
            if win ~= -1 then
                vim.api.nvim_set_current_win(win)
                pcall(vim.cmd, "silent write")
                pcall(vim.cmd, "quit")
            else
                pcall(function() vim.api.nvim_buf_call(buf, function() vim.cmd("silent write") end) end)
                pcall(vim.cmd, "silent! bwipeout " .. buf)
            end
        end)
    end,
})

return M
