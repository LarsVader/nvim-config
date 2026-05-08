-- Tests for the git_amend helper used by the fugitive commit float.
-- Bug: when amending, the right-side diff was always `git diff --cached`,
-- which only shows newly-staged changes — not the cumulative diff that the
-- amended commit will represent.

local function run(cmd)
    return vim.fn.system(cmd)
end

local function init_repo()
    local repo = vim.fn.tempname()
    vim.fn.mkdir(repo, 'p')
    run({ 'git', '-C', repo, 'init', '-q' })
    run({ 'git', '-C', repo, 'config', 'user.email', 't@t.com' })
    run({ 'git', '-C', repo, 'config', 'user.name', 'Test' })
    run({ 'git', '-C', repo, 'config', 'commit.gpgsign', 'false' })
    return repo
end

describe("git_amend helper", function()
    describe("is_amending", function()
        local M
        before_each(function()
            package.loaded['lars.git_amend'] = nil
            M = require('lars.git_amend')
        end)

        it("returns true when buffer message matches HEAD message", function()
            local commit_lines = {
                'initial commit',
                '',
                '# Please enter the commit message',
                '# Date: whatever',
            }
            local head_msg = { 'initial commit' }
            assert.is_true(M.is_amending(commit_lines, head_msg))
        end)

        it("returns true for multi-line messages that match", function()
            local commit_lines = {
                'subject',
                '',
                'body line 1',
                'body line 2',
                '',
                '# comment',
            }
            local head_msg = { 'subject', '', 'body line 1', 'body line 2', '' }
            assert.is_true(M.is_amending(commit_lines, head_msg))
        end)

        it("returns false when buffer is empty (new commit)", function()
            local commit_lines = {
                '',
                '# Please enter the commit message',
            }
            assert.is_false(M.is_amending(commit_lines, { 'previous commit' }))
        end)

        it("returns false when message differs from HEAD", function()
            local commit_lines = {
                'a different message',
                '',
                '# comment',
            }
            assert.is_false(M.is_amending(commit_lines, { 'previous commit' }))
        end)

        it("returns false when HEAD message is empty", function()
            local commit_lines = { 'something', '# c' }
            assert.is_false(M.is_amending(commit_lines, {}))
        end)
    end)

    describe("get_diff_lines", function()
        local M
        local repo
        before_each(function()
            package.loaded['lars.git_amend'] = nil
            M = require('lars.git_amend')
            repo = init_repo()
        end)
        after_each(function()
            vim.fn.delete(repo, 'rf')
        end)

        it("non-amend: returns only staged changes", function()
            vim.fn.writefile({ 'v1' }, repo .. '/file.txt')
            run({ 'git', '-C', repo, 'add', 'file.txt' })
            run({ 'git', '-C', repo, 'commit', '-q', '-m', 'first' })

            vim.fn.writefile({ 'v2' }, repo .. '/file.txt')
            run({ 'git', '-C', repo, 'add', 'file.txt' })

            local diff = table.concat(M.get_diff_lines(repo, false), '\n')
            assert.is_truthy(diff:find('-v1'), "expected -v1 in non-amend diff")
            assert.is_truthy(diff:find('+v2'), "expected +v2 in non-amend diff")
        end)

        it("amend: includes the original commit's content plus staged changes", function()
            -- First commit (parent)
            vim.fn.writefile({ 'parent' }, repo .. '/parent.txt')
            run({ 'git', '-C', repo, 'add', 'parent.txt' })
            run({ 'git', '-C', repo, 'commit', '-q', '-m', 'parent commit' })

            -- Second commit (HEAD — the one being amended)
            vim.fn.writefile({ 'orig-content' }, repo .. '/orig.txt')
            run({ 'git', '-C', repo, 'add', 'orig.txt' })
            run({ 'git', '-C', repo, 'commit', '-q', '-m', 'HEAD commit' })

            -- Stage additional changes for the amend
            vim.fn.writefile({ 'amend-added' }, repo .. '/added.txt')
            run({ 'git', '-C', repo, 'add', 'added.txt' })

            local diff = table.concat(M.get_diff_lines(repo, true), '\n')
            -- Original HEAD content must appear (the bug was that this was missing)
            assert.is_truthy(diff:find('orig%.txt'),
                "amend diff must include the original commit's file (orig.txt)")
            assert.is_truthy(diff:find('orig%-content'),
                "amend diff must include the original commit's added content")
            -- New staged content must also appear
            assert.is_truthy(diff:find('added%.txt'),
                "amend diff must include the newly-staged file (added.txt)")
            -- Parent's content should NOT appear (it's part of HEAD~1, not the amend)
            assert.is_nil(diff:find('parent%.txt'),
                "amend diff must not include the parent commit's content")
        end)

        it("amend on initial commit (no parent) still shows full content", function()
            vim.fn.writefile({ 'first-content' }, repo .. '/first.txt')
            run({ 'git', '-C', repo, 'add', 'first.txt' })
            run({ 'git', '-C', repo, 'commit', '-q', '-m', 'initial' })

            -- Stage additional change
            vim.fn.writefile({ 'extra' }, repo .. '/extra.txt')
            run({ 'git', '-C', repo, 'add', 'extra.txt' })

            local diff = table.concat(M.get_diff_lines(repo, true), '\n')
            assert.is_truthy(diff:find('first%.txt'),
                "initial-commit amend must include the original file")
            assert.is_truthy(diff:find('extra%.txt'),
                "initial-commit amend must include the staged file")
        end)
    end)
end)
