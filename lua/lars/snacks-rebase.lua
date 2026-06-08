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

    picker:close()
    M.pending = { tags = tags_in_range, order = order }
    M.tags = {}
    if dropped > 0 then
        Snacks.notify.warn(("Ignored %d mark(s) not on HEAD's history"):format(dropped), { title = "Git Rebase" })
    end

    -- Interactive rebase needs an editor for the todo list. Delegate to Fugitive
    -- (loaded on :G), which wires GIT_SEQUENCE_EDITOR/GIT_EDITOR back into nvim.
    -- Fugitive resolves the repo from the *current buffer*, not the window cwd --
    -- so open the rebase in a fresh tab whose [No Name] buffer pins no repo, with
    -- tcd set to the picker's cwd, so Fugitive resolves the repo from that cwd.
    -- <commit>^ makes the base commit itself editable; the root commit has no
    -- parent, so fall back to --root (rebase from the very first commit).
    vim.schedule(function()
        local has_parent = git(cwd, "rev-parse", "--verify", "--quiet", oldest .. "^").code == 0
        local range = has_parent and ("-i " .. oldest .. "^") or "-i --root"
        vim.cmd("tabnew")
        vim.cmd("tcd " .. vim.fn.fnameescape(cwd))
        local ok, err = pcall(vim.cmd, "G rebase " .. range)
        if not ok then
            M.pending = nil
            vim.cmd("silent! tabclose")
            Snacks.notify.error("Interactive rebase failed: " .. tostring(err), { title = "Git Rebase" })
        end
    end)
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
        if applied > 0 or reordered then
            vim.api.nvim_buf_set_lines(ev.buf, 0, -1, false, new_lines)
            local parts = {}
            if reordered then parts[#parts + 1] = "reordered" end
            if applied > 0 then parts[#parts + 1] = applied .. " action(s)" end
            vim.notify(("Rebase todo: %s -- review and :wq"):format(table.concat(parts, ", ")),
                vim.log.levels.INFO, { title = "Git Rebase" })
        end
    end,
})

return M
