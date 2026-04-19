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

    describe("goto_header_or_source", function()
        it("navigates from .h to .cpp", function()
            local header = testroot .. "/src/Widget.h"
            local source = testroot .. "/src/Widget.cpp"
            vim.fn.writefile({ "" }, header)
            vim.fn.writefile({ "" }, source)

            vim.cmd("noautocmd edit " .. vim.fn.fnameescape(header))
            local old_cwd = vim.fn.getcwd()
            vim.cmd("cd " .. vim.fn.fnameescape(testroot))

            alt.goto_header_or_source()
            assert.equals("Widget.cpp", vim.fn.expand("%:t"), "should navigate to .cpp")

            -- Navigate back
            alt.goto_header_or_source()
            assert.equals("Widget.h", vim.fn.expand("%:t"), "should navigate back to .h")

            vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
        end)

        it("navigates from .hpp to .cpp", function()
            local header = testroot .. "/src/Engine.hpp"
            local source = testroot .. "/src/Engine.cpp"
            vim.fn.writefile({ "" }, header)
            vim.fn.writefile({ "" }, source)

            vim.cmd("noautocmd edit " .. vim.fn.fnameescape(header))
            local old_cwd = vim.fn.getcwd()
            vim.cmd("cd " .. vim.fn.fnameescape(testroot))

            alt.goto_header_or_source()
            assert.equals("Engine.cpp", vim.fn.expand("%:t"), "should navigate to .cpp from .hpp")

            vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
        end)

        it("navigates from .c to .h", function()
            local header = testroot .. "/src/util.h"
            local source = testroot .. "/src/util.c"
            vim.fn.writefile({ "" }, header)
            vim.fn.writefile({ "" }, source)

            vim.cmd("noautocmd edit " .. vim.fn.fnameescape(source))
            local old_cwd = vim.fn.getcwd()
            vim.cmd("cd " .. vim.fn.fnameescape(testroot))

            alt.goto_header_or_source()
            assert.equals("util.h", vim.fn.expand("%:t"), "should navigate to .h from .c")

            vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
        end)

        it("warns on non-C/C++ file", function()
            local warned = false
            local orig_notify = vim.notify
            vim.notify = function(msg, level)
                if level == vim.log.levels.WARN and msg:find("Not a C/C%+%+ file") then
                    warned = true
                end
            end

            vim.cmd("enew")
            vim.api.nvim_buf_set_name(0, "main.rs")
            alt.goto_header_or_source()
            assert.is_true(warned, "should warn on non-C/C++ file")

            vim.notify = orig_notify
        end)
    end)

    describe("goto_interface", function()
        it("jumps to the first interface in the inheritance list", function()
            local service = testroot .. "/src/FooService.cs"
            local iface = testroot .. "/src/IFooService.cs"
            vim.fn.writefile({
                "namespace App;",
                "public class FooService : IFooService",
                "{",
                "}",
            }, service)
            vim.fn.writefile({ "" }, iface)

            vim.cmd("noautocmd edit " .. vim.fn.fnameescape(service))
            local old_cwd = vim.fn.getcwd()
            vim.cmd("cd " .. vim.fn.fnameescape(testroot))

            alt.goto_interface()
            assert.equals("IFooService.cs", vim.fn.expand("%:t"), "should navigate to interface")

            vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
        end)

        it("skips base class and finds interface", function()
            local service = testroot .. "/src/BarService.cs"
            local iface = testroot .. "/src/IBarService.cs"
            local base = testroot .. "/src/ServiceBase.cs"
            vim.fn.writefile({
                "public class BarService : ServiceBase, IBarService",
                "{",
                "}",
            }, service)
            vim.fn.writefile({ "" }, iface)
            vim.fn.writefile({ "" }, base)

            vim.cmd("noautocmd edit " .. vim.fn.fnameescape(service))
            local old_cwd = vim.fn.getcwd()
            vim.cmd("cd " .. vim.fn.fnameescape(testroot))

            alt.goto_interface()
            assert.equals("IBarService.cs", vim.fn.expand("%:t"), "should skip base class and find interface")

            vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
        end)

        it("warns when no interface found", function()
            local service = testroot .. "/src/PlainService.cs"
            vim.fn.writefile({
                "public class PlainService : ServiceBase",
                "{",
                "}",
            }, service)

            local warned = false
            local orig_notify = vim.notify
            vim.notify = function(msg, level)
                if level == vim.log.levels.WARN and msg:find("No interface found") then
                    warned = true
                end
            end

            vim.cmd("noautocmd edit " .. vim.fn.fnameescape(service))
            local old_cwd = vim.fn.getcwd()
            vim.cmd("cd " .. vim.fn.fnameescape(testroot))

            alt.goto_interface()
            assert.is_true(warned, "should warn when no interface in declaration")

            vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
            vim.notify = orig_notify
        end)
    end)

    describe("goto_xaml_or_codebehind", function()
        it("navigates from .xaml to .xaml.cs", function()
            local xaml = testroot .. "/src/MainWindow.xaml"
            local cb = testroot .. "/src/MainWindow.xaml.cs"
            vim.fn.writefile({ "" }, xaml)
            vim.fn.writefile({ "" }, cb)

            vim.cmd("noautocmd edit " .. vim.fn.fnameescape(xaml))
            local old_cwd = vim.fn.getcwd()
            vim.cmd("cd " .. vim.fn.fnameescape(testroot))

            alt.goto_xaml_or_codebehind()
            assert.equals("MainWindow.xaml.cs", vim.fn.expand("%:t"), "should navigate to codebehind")

            -- Navigate back
            alt.goto_xaml_or_codebehind()
            assert.equals("MainWindow.xaml", vim.fn.expand("%:t"), "should navigate back to xaml")

            vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
        end)

        it("warns on non-xaml file", function()
            local warned = false
            local orig_notify = vim.notify
            vim.notify = function(msg, level)
                if level == vim.log.levels.WARN and msg:find("Not a XAML file") then
                    warned = true
                end
            end

            vim.cmd("enew")
            vim.api.nvim_buf_set_name(0, "Program.cs")
            alt.goto_xaml_or_codebehind()
            assert.is_true(warned, "should warn on non-xaml file")

            vim.notify = orig_notify
        end)
    end)

    describe("goto_base_class", function()
        it("jumps to the first non-interface type", function()
            local child = testroot .. "/src/ChildService.cs"
            local base = testroot .. "/src/ServiceBase.cs"
            vim.fn.writefile({
                "public class ChildService : ServiceBase, IChildService",
                "{",
                "}",
            }, child)
            vim.fn.writefile({ "" }, base)

            vim.cmd("noautocmd edit " .. vim.fn.fnameescape(child))
            local old_cwd = vim.fn.getcwd()
            vim.cmd("cd " .. vim.fn.fnameescape(testroot))

            alt.goto_base_class()
            assert.equals("ServiceBase.cs", vim.fn.expand("%:t"), "should navigate to base class")

            vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
        end)

        it("warns when only interfaces in inheritance", function()
            local svc = testroot .. "/src/OnlyIface.cs"
            vim.fn.writefile({
                "public class OnlyIface : IFoo, IBar",
                "{",
                "}",
            }, svc)

            local warned = false
            local orig_notify = vim.notify
            vim.notify = function(msg, level)
                if level == vim.log.levels.WARN and msg:find("No base class found") then
                    warned = true
                end
            end

            vim.cmd("noautocmd edit " .. vim.fn.fnameescape(svc))
            local old_cwd = vim.fn.getcwd()
            vim.cmd("cd " .. vim.fn.fnameescape(testroot))

            alt.goto_base_class()
            assert.is_true(warned, "should warn when no base class")

            vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
            vim.notify = orig_notify
        end)
    end)
end)
