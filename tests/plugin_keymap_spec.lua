-- Tier 1: Verify lazy.nvim registered trigger keymaps for all plugins
local h = dofile(vim.fn.stdpath("config") .. "/tests/helpers.lua")

describe("plugin keymaps", function()
    describe("telescope", function()
        local keys = {
            { "<leader>ff", "find files" },
            { "<C-p>",      "git files" },
            { "<leader>fg", "grep" },
            { "<leader>fs", "string" },
            { "<leader>fu", "buffer" },
            { "<leader>fh", "help" },
            { "<leader>fr", "resume" },
            { "<leader>fl", "commits" },
            { "<leader>fc", "branch commits" },
            { "<leader>fb", "branch" },
            { "<leader>fS", "git status" },
            { "<leader>fk", "keymap" },
        }
        for _, k in ipairs(keys) do
            it(k[1] .. " (" .. k[2] .. ")", function()
                assert.is_true(h.has_keymap("n", k[1]), k[1] .. " not found")
            end)
        end
    end)

    describe("harpoon", function()
        it("<leader>ha (add)", function()
            assert.is_true(h.has_keymap("n", "<leader>ha"), "<leader>ha not found")
        end)
        it("<leader>hh (menu)", function()
            assert.is_true(h.has_keymap("n", "<leader>hh"), "<leader>hh not found")
        end)
        for i = 1, 9 do
            it("<leader>" .. i .. " (file " .. i .. ")", function()
                assert.is_true(h.has_keymap("n", "<leader>" .. i), "<leader>" .. i .. " not found")
            end)
        end
    end)

    describe("oil", function()
        local keys = {
            { "<leader>fe", "file explorer" },
            { "<leader>ss", "config root" },
            { "<leader>sp", "plugins dir" },
            { "<leader>sl", "lars dir" },
        }
        for _, k in ipairs(keys) do
            it(k[1] .. " (" .. k[2] .. ")", function()
                assert.is_true(h.has_keymap("n", k[1]), k[1] .. " not found")
            end)
        end
    end)

    describe("nvim-tree", function()
        it("<leader>te (toggle)", function()
            assert.is_true(h.has_keymap("n", "<leader>te"), "<leader>te not found")
        end)
        it("<leader>ts (find file)", function()
            assert.is_true(h.has_keymap("n", "<leader>ts"), "<leader>ts not found")
        end)
    end)

    describe("leap", function()
        it("s (leap search)", function()
            assert.is_true(h.has_keymap("n", "s"), "s not found")
        end)
    end)

    describe("sideways", function()
        it("<C-h> (move left)", function()
            assert.is_true(h.has_keymap("n", "<C-h>"), "<C-h> not found")
        end)
        it("<C-l> (move right)", function()
            assert.is_true(h.has_keymap("n", "<C-l>"), "<C-l> not found")
        end)
    end)

    describe("comment", function()
        it("gc (line comment)", function()
            assert.is_true(h.has_keymap("n", "gc"), "gc not found")
        end)
        it("gb (block comment)", function()
            assert.is_true(h.has_keymap("n", "gb"), "gb not found")
        end)
    end)

    describe("surround", function()
        it("ys (add)", function()
            assert.is_true(h.has_keymap("n", "ys"), "ys not found")
        end)
        it("cs (change)", function()
            assert.is_true(h.has_keymap("n", "cs"), "cs not found")
        end)
        it("ds (delete)", function()
            assert.is_true(h.has_keymap("n", "ds"), "ds not found")
        end)
    end)

    describe("dap", function()
        local keys = {
            { "<F5>",        "continue" },
            { "<F10>",       "step over" },
            { "<F11>",       "step into" },
            { "<F12>",       "step out" },
            { "<leader>db",  "toggle breakpoint" },
            { "<leader>dB",  "set breakpoint" },
            { "<leader>dlb", "log point" },
            { "<leader>dr",  "REPL" },
            { "<leader>dl",  "run last" },
        }
        for _, k in ipairs(keys) do
            it(k[1] .. " (" .. k[2] .. ")", function()
                assert.is_true(h.has_keymap("n", k[1]), k[1] .. " not found")
            end)
        end
    end)

    describe("dap-ui", function()
        it("du (toggle UI)", function()
            assert.is_true(h.has_keymap("n", "du"), "du not found")
        end)
    end)

    describe("fugitive", function()
        local keys = {
            { "<leader>gs", "status" },
            { "<leader>gb", "blame" },
            { "<leader>gd", "diff" },
            { "<leader>gm", "diffsplit" },
        }
        for _, k in ipairs(keys) do
            it(k[1] .. " (" .. k[2] .. ")", function()
                assert.is_true(h.has_keymap("n", k[1]), k[1] .. " not found")
            end)
        end
    end)

    describe("neotest", function()
        local keys = {
            { "<leader>tn", "run nearest" },
            { "<leader>tf", "run file" },
            { "<leader>ta", "run all" },
            { "<leader>to", "toggle output" },
            { "<leader>tp", "toggle summary" },
            { "<leader>tl", "run last" },
        }
        for _, k in ipairs(keys) do
            it(k[1] .. " (" .. k[2] .. ")", function()
                assert.is_true(h.has_keymap("n", k[1]), k[1] .. " not found")
            end)
        end
    end)

    describe("nvim-coverage", function()
        local keys = {
            { "<leader>tC", "toggle coverage" },
            { "<leader>tL", "load coverage" },
            { "<leader>tS", "coverage summary" },
        }
        for _, k in ipairs(keys) do
            it(k[1] .. " (" .. k[2] .. ")", function()
                assert.is_true(h.has_keymap("n", k[1]), k[1] .. " not found")
            end)
        end
    end)

    describe("claude-code", function()
        local keys = {
            { "<C-,>", "toggle" },
            { "<leader>ar", "resume" },
            { "<leader>ad", "diff" },
            { "<leader>ak", "kill" },
        }
        for _, k in ipairs(keys) do
            it(k[1] .. " (" .. k[2] .. ")", function()
                assert.is_true(h.has_keymap("n", k[1]), k[1] .. " not found")
            end)
        end
    end)

    describe("git-cherry-pick", function()
        it("<leader>gp (cherry-pick from branch)", function()
            assert.is_true(h.has_keymap("n", "<leader>gp"), "<leader>gp not found")
        end)
    end)

    describe("git-submodules", function()
        local keys = {
            { "<leader>gS", "submodule commit" },
            { "<leader>gC", "submodule checkout" },
        }
        for _, k in ipairs(keys) do
            it(k[1] .. " (" .. k[2] .. ")", function()
                assert.is_true(h.has_keymap("n", k[1]), k[1] .. " not found")
            end)
        end
    end)

    describe("diffview", function()
        local keys = {
            { "<leader>dv", "open" },
            { "<leader>dh", "file history" },
            { "<leader>dc", "close" },
            { "<leader>dm", "diff against main" },
        }
        for _, k in ipairs(keys) do
            it(k[1] .. " (" .. k[2] .. ")", function()
                assert.is_true(h.has_keymap("n", k[1]), k[1] .. " not found")
            end)
        end
    end)

    describe("themery", function()
        it("<leader>ut (theme switcher)", function()
            assert.is_true(h.has_keymap("n", "<leader>ut"), "<leader>ut not found")
        end)
    end)

    describe("gitsigns", function()
        -- gitsigns uses on_attach so keymaps only exist in buffers with git.
        -- We manually invoke the on_attach callback from the plugin spec to
        -- register buffer-local keymaps on the current buffer.
        h.force_load_plugin("gitsigns.nvim")
        local specs = require("lazy").plugins()
        for _, spec in ipairs(specs) do
            if spec.name == "gitsigns.nvim" and spec.opts and spec.opts.on_attach then
                spec.opts.on_attach(vim.api.nvim_get_current_buf())
                break
            end
        end

        local normal_keys = {
            { "]h",          "next hunk" },
            { "[h",          "prev hunk" },
            { "<leader>hs",  "stage hunk" },
            { "<leader>hr",  "reset hunk" },
            { "<leader>hu",  "undo stage hunk" },
            { "<leader>hS",  "stage buffer" },
            { "<leader>hR",  "reset buffer" },
            { "<leader>hp",  "preview hunk inline" },
            { "<leader>hd",  "diff this" },
            { "<leader>htd", "toggle deleted" },
            { "<leader>htb", "toggle line blame" },
        }
        for _, k in ipairs(normal_keys) do
            it(k[1] .. " (" .. k[2] .. ")", function()
                -- Buffer-local keymaps from on_attach; check current buffer
                local found = h.has_keymap("n", k[1])
                if not found then
                    -- Also check buffer-local keymaps
                    local maps = vim.api.nvim_buf_get_keymap(0, "n")
                    for _, m in ipairs(maps) do
                        if m.lhs == vim.api.nvim_replace_termcodes(k[1]:gsub("<leader>", vim.g.mapleader or "\\"), true, true, true) then
                            found = true
                            break
                        end
                    end
                end
                assert.is_true(found, k[1] .. " not found")
            end)
        end

        -- Visual mode keymaps
        local visual_keys = {
            { "<leader>hs", "stage hunk (visual)" },
            { "<leader>hr", "reset hunk (visual)" },
        }
        for _, k in ipairs(visual_keys) do
            it(k[1] .. " (" .. k[2] .. ")", function()
                local found = h.has_keymap("v", k[1])
                if not found then
                    local maps = vim.api.nvim_buf_get_keymap(0, "v")
                    for _, m in ipairs(maps) do
                        if m.lhs == vim.api.nvim_replace_termcodes(k[1]:gsub("<leader>", vim.g.mapleader or "\\"), true, true, true) then
                            found = true
                            break
                        end
                    end
                end
                assert.is_true(found, k[1] .. " not found in visual mode")
            end)
        end
    end)
end)
