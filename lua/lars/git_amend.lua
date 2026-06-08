-- Helpers for the fugitive commit-float diff view.
-- The right-hand diff pane should reflect what the commit being authored
-- will represent: for a normal commit that's `git diff --cached`, but for
-- an amend it's `parent-of-HEAD .. staging-area` so the user sees the full
-- amended commit, not just the latest tweak being added.

local M = {}

local function trim_empties(lines)
    local out = {}
    for _, line in ipairs(lines) do table.insert(out, line) end
    while #out > 0 and out[#out] == '' do table.remove(out) end
    while #out > 0 and out[1] == '' do table.remove(out, 1) end
    return out
end

local function strip_comments(lines)
    local out = {}
    for _, line in ipairs(lines) do
        if not line:match('^#') then
            table.insert(out, line)
        end
    end
    return out
end

--- Heuristic: a commit-message buffer is amending if its (non-comment) content
--- equals HEAD's commit message. `git commit --amend` pre-fills COMMIT_EDITMSG
--- with the previous commit's message, so this matches reliably.
---@param commit_lines string[] raw lines from the gitcommit buffer
---@param head_message_lines string[] lines from `git log -1 --format=%B`
---@return boolean
function M.is_amending(commit_lines, head_message_lines)
    local current = trim_empties(strip_comments(commit_lines or {}))
    local head = trim_empties(head_message_lines or {})
    if #current == 0 or #head == 0 then return false end
    if #current ~= #head then return false end
    for i = 1, #current do
        if current[i] ~= head[i] then return false end
    end
    return true
end

--- Merge a saved commit message into a fresh commit buffer for the soft-reset
--- amend flow (<leader>ga): prepend `saved` above the buffer's template, but
--- only when the buffer has no message yet (so an unrelated commit that already
--- carries text is left alone). Returns the new lines, or nil to leave as-is.
---@param saved string[] the previous commit's message lines
---@param lines string[] current commit-buffer lines (template + comments)
---@return string[]|nil
function M.merge_message(saved, lines)
    for _, l in ipairs(lines) do
        if l ~= '' and not l:match('^#') then return nil end -- already has a message
    end
    local new = {}
    for _, l in ipairs(saved) do new[#new + 1] = l end
    new[#new + 1] = ''
    for _, l in ipairs(lines) do new[#new + 1] = l end
    return new
end

--- Returns the diff lines to show in the commit-float right pane.
--- For amends: parent-of-HEAD .. staged (cumulative amended diff).
--- Falls back to the empty-tree comparison when HEAD has no parent
--- (amending the initial commit).
---@param worktree string path passed to `git -C`
---@param is_amend boolean
---@return string[]
function M.get_diff_lines(worktree, is_amend)
    if is_amend then
        vim.fn.system({ 'git', '-C', worktree, 'rev-parse', '--verify', 'HEAD~1' })
        if vim.v.shell_error == 0 then
            return vim.fn.systemlist({ 'git', '-C', worktree, 'diff', '--cached', 'HEAD~1' })
        end
        -- Initial-commit amend: diff staging area against the empty tree.
        local empty_tree = '4b825dc642cb6eb9a060e54bf8d69288fbee4904'
        return vim.fn.systemlist({ 'git', '-C', worktree, 'diff', '--cached', empty_tree })
    end

    local lines = vim.fn.systemlist({ 'git', '-C', worktree, 'diff', '--cached' })
    if #lines == 0 then
        lines = vim.fn.systemlist({ 'git', '-C', worktree, 'diff', 'HEAD' })
    end
    return lines
end

return M
