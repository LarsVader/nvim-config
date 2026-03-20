-- Tier 3: Behavioral tests — feed keystrokes and verify buffer/editor state
local h = dofile(vim.fn.stdpath("config") .. "/tests/helpers.lua")

describe("behavior", function()
    before_each(function()
        -- Start with a clean scratch buffer
        vim.cmd("enew!")
        vim.bo.buftype = "nofile"
    end)

    describe("yank to clipboard", function()
        it("<leader>y yanks to system clipboard", function()
            h.set_buf_lines({ "hello world" })
            -- Select the line in visual mode and yank to clipboard
            h.feed("ggV")
            h.feed(" y") -- <leader>y
            vim.cmd("normal! \\<Esc>")

            local clipboard = vim.fn.getreg("*")
            assert.is_not_nil(clipboard:find("hello world"), "clipboard should contain yanked text")
        end)
    end)

    describe("quickfix navigation", function()
        it("<leader>n moves to next quickfix item", function()
            -- Create two temp files with content so quickfix entries are valid
            local f1 = vim.fn.tempname() .. ".txt"
            local f2 = vim.fn.tempname() .. ".txt"
            vim.fn.writefile({"line one"}, f1)
            vim.fn.writefile({"line two"}, f2)

            vim.fn.setqflist({
                { filename = f1, lnum = 1, text = "first" },
                { filename = f2, lnum = 1, text = "second" },
            })
            vim.cmd("cfirst")
            local before = vim.fn.expand("%:p")

            h.feed(" n") -- <leader>n = :cnext
            vim.cmd("redraw")

            local after = vim.fn.expand("%:p")
            assert.are_not.equals(before, after, "cursor should have moved to next quickfix entry")

            -- Cleanup
            vim.fn.delete(f1)
            vim.fn.delete(f2)
        end)
    end)

    describe("scroll centering", function()
        it("<C-d> scrolls down with zz (cursor moves from line 1)", function()
            -- Create a tall buffer (100 lines)
            local lines = {}
            for i = 1, 100 do
                lines[i] = "line " .. i
            end
            h.set_buf_lines(lines)

            -- Start at line 1
            vim.cmd("normal! gg")
            local before = vim.fn.line(".")
            assert.equals(1, before, "should start at line 1")

            -- <C-d>zz scrolls down — cursor should move past line 1
            -- Use normal (not normal!) to trigger the mapped <C-d> → <C-d>zz
            vim.cmd([[execute "normal \<C-d>"]])
            vim.cmd("redraw")

            local after = vim.fn.line(".")
            assert.is_true(after > 1, "cursor should have moved down from line 1, now at " .. after)
        end)
    end)
end)
