-- Tier 2: Unit tests for lua/lars/alternate.lua logic
local alt = require("lars.alternate")

-- Use a temp dir under the config path (avoids Windows short path name issue with globpath)
local testroot = vim.fn.stdpath("config") .. "/tests/.tmp_alt_test"

describe("alternate", function()
    before_each(function()
        -- Ensure clean state
        vim.fn.delete(testroot, "rf")
        vim.fn.mkdir(testroot .. "/src", "p")
    end)

    after_each(function()
        vim.fn.delete(testroot, "rf")
    end)

    describe("goto_test_or_source", function()
        it("navigates from source to test file", function()
            local src = testroot .. "/src/FooService.cs"
            local test = testroot .. "/src/FooServiceTests.cs"
            vim.fn.writefile({ "" }, src)
            vim.fn.writefile({ "" }, test)

            vim.cmd("noautocmd edit " .. vim.fn.fnameescape(src))
            local old_cwd = vim.fn.getcwd()
            vim.cmd("cd " .. vim.fn.fnameescape(testroot))

            alt.goto_test_or_source()
            assert.equals("FooServiceTests.cs", vim.fn.expand("%:t"), "should navigate to test file")

            -- Navigate back
            alt.goto_test_or_source()
            assert.equals("FooService.cs", vim.fn.expand("%:t"), "should navigate back to source")

            vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
        end)

        it("warns on non-.cs file", function()
            local warned = false
            local orig_notify = vim.notify
            vim.notify = function(msg, level)
                if level == vim.log.levels.WARN and msg:find("Not a C# file") then
                    warned = true
                end
            end

            vim.cmd("enew")
            vim.api.nvim_buf_set_name(0, "readme.md")
            alt.goto_test_or_source()
            assert.is_true(warned, "should warn on non-.cs file")

            vim.notify = orig_notify
        end)
    end)

    describe("goto_view_or_viewmodel", function()
        it("navigates from View to ViewModel", function()
            local view = testroot .. "/src/AddRepositoryView.xaml.cs"
            local vm = testroot .. "/src/AddRepositoryViewModel.cs"
            vim.fn.writefile({ "" }, view)
            vim.fn.writefile({ "" }, vm)

            vim.cmd("noautocmd edit " .. vim.fn.fnameescape(view))
            local old_cwd = vim.fn.getcwd()
            vim.cmd("cd " .. vim.fn.fnameescape(testroot))

            alt.goto_view_or_viewmodel()
            assert.equals("AddRepositoryViewModel.cs", vim.fn.expand("%:t"), "should navigate to ViewModel")

            -- Navigate back
            alt.goto_view_or_viewmodel()
            assert.equals("AddRepositoryView.xaml.cs", vim.fn.expand("%:t"), "should navigate back to View")

            vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
        end)

        it("navigates from Page to ViewModel", function()
            local page = testroot .. "/src/AddRepositoryPage.xaml.cs"
            local vm = testroot .. "/src/AddRepositoryViewModel.cs"
            vim.fn.writefile({ "" }, page)
            vim.fn.writefile({ "" }, vm)

            vim.cmd("noautocmd edit " .. vim.fn.fnameescape(page))
            local old_cwd = vim.fn.getcwd()
            vim.cmd("cd " .. vim.fn.fnameescape(testroot))

            alt.goto_view_or_viewmodel()
            assert.equals("AddRepositoryViewModel.cs", vim.fn.expand("%:t"), "should navigate to ViewModel")

            -- Navigate back: ViewModel -> Page (when no View exists)
            alt.goto_view_or_viewmodel()
            assert.equals("AddRepositoryPage.xaml.cs", vim.fn.expand("%:t"), "should navigate back to Page")

            vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
        end)

        it("navigates from ViewModel to View preferring View over Page", function()
            local view = testroot .. "/src/FooView.xaml.cs"
            local page = testroot .. "/src/FooPage.xaml.cs"
            local vm = testroot .. "/src/FooViewModel.cs"
            vim.fn.writefile({ "" }, view)
            vim.fn.writefile({ "" }, page)
            vim.fn.writefile({ "" }, vm)

            vim.cmd("noautocmd edit " .. vim.fn.fnameescape(vm))
            local old_cwd = vim.fn.getcwd()
            vim.cmd("cd " .. vim.fn.fnameescape(testroot))

            alt.goto_view_or_viewmodel()
            assert.equals("FooView.xaml.cs", vim.fn.expand("%:t"), "should prefer View over Page")

            vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
        end)

        it("warns when file has no View/Page or ViewModel suffix", function()
            local warned = false
            local orig_notify = vim.notify
            vim.notify = function(msg, level)
                if level == vim.log.levels.WARN and msg:find("Not a View/Page or ViewModel") then
                    warned = true
                end
            end

            vim.cmd("enew")
            vim.api.nvim_buf_set_name(0, "SomeService.cs")
            alt.goto_view_or_viewmodel()
            assert.is_true(warned, "should warn when no View/Page/ViewModel suffix")

            vim.notify = orig_notify
        end)

        it("warns on non-.cs/.xaml file", function()
            local warned = false
            local orig_notify = vim.notify
            vim.notify = function(msg, level)
                if level == vim.log.levels.WARN and msg:find("Not a .cs or .xaml") then
                    warned = true
                end
            end

            vim.cmd("enew")
            vim.api.nvim_buf_set_name(0, "styles.css")
            alt.goto_view_or_viewmodel()
            assert.is_true(warned, "should warn on non-.cs/.xaml file")

            vim.notify = orig_notify
        end)
    end)
end)
