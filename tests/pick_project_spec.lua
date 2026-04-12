-- Tests for lua/lars/pick-project.lua
-- Focus: collect_projects() must ignore non-file oldfiles entries
-- (terminal URIs like `term://...` from claude-code.nvim, fugitive://,
-- deleted files, etc.) so the dashboard never tries to :edit them.

describe("pick-project", function()
    local pick_project

    -- Ensure a fresh require each run
    before_each(function()
        package.loaded['lars.pick-project'] = nil
        pick_project = require('lars.pick-project')
    end)

    it("exposes collect_projects and pick", function()
        assert.is_function(pick_project.collect_projects)
        assert.is_function(pick_project.pick)
    end)

    it("is still callable directly for backward compat", function()
        -- The dashboard uses `require('lars.pick-project')()` — the module
        -- must remain callable as a function via __call.
        local mt = getmetatable(pick_project)
        assert.is_table(mt)
        assert.is_function(mt.__call)
    end)

    describe("collect_projects", function()
        local tmp_root, real_file

        before_each(function()
            -- Create a real git project in a temp dir so filereadable()
            -- and finddir('.git') both succeed.
            tmp_root = vim.fn.tempname()
            vim.fn.mkdir(tmp_root, 'p')
            vim.fn.mkdir(tmp_root .. '/.git', 'p')
            real_file = tmp_root .. '/hello.txt'
            vim.fn.writefile({ 'hi' }, real_file)
        end)

        after_each(function()
            vim.fn.delete(tmp_root, 'rf')
        end)

        it("includes real readable files inside a git project", function()
            local projects = pick_project.collect_projects({ real_file })
            assert.equals(1, #projects)
            assert.equals(real_file, projects[1].recent_file)
            assert.equals(vim.fn.resolve(tmp_root), projects[1].root)
        end)

        it("skips terminal URI entries (claude-code, etc.)", function()
            local term_uri = 'term://' .. tmp_root .. '//12345:claude'
            local projects = pick_project.collect_projects({ term_uri, real_file })
            assert.equals(1, #projects, "only the real file should be kept")
            assert.equals(real_file, projects[1].recent_file)
        end)

        it("skips other scheme URIs (fugitive://, oil://)", function()
            local projects = pick_project.collect_projects({
                'fugitive://' .. tmp_root .. '//HEAD',
                'oil://' .. tmp_root,
                real_file,
            })
            assert.equals(1, #projects)
            assert.equals(real_file, projects[1].recent_file)
        end)

        it("skips paths to files that no longer exist on disk", function()
            local ghost = tmp_root .. '/deleted.txt'
            local projects = pick_project.collect_projects({ ghost, real_file })
            assert.equals(1, #projects)
            assert.equals(real_file, projects[1].recent_file)
        end)

        it("preserves recency order and dedupes by project root", function()
            local second_file = tmp_root .. '/second.txt'
            vim.fn.writefile({ 'two' }, second_file)
            -- Both files belong to the same git project; the first one
            -- (most recent in oldfiles) wins.
            local projects = pick_project.collect_projects({ second_file, real_file })
            assert.equals(1, #projects)
            assert.equals(second_file, projects[1].recent_file)
        end)

        it("handles an empty oldfiles list", function()
            local projects = pick_project.collect_projects({})
            assert.same({}, projects)
        end)

        it("handles nil oldfiles", function()
            local projects = pick_project.collect_projects(nil)
            assert.same({}, projects)
        end)
    end)
end)
