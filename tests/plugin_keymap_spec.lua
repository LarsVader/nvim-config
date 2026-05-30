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
            { "<leader>de",  "break on CLR exception type" },
            { "<leader>dE",  "exception filters" },
        }
        for _, k in ipairs(keys) do
            it(k[1] .. " (" .. k[2] .. ")", function()
                assert.is_true(h.has_keymap("n", k[1]), k[1] .. " not found")
            end)
        end
    end)

    describe("dap-ui", function()
        local keys = {
            { "<leader>dui", "toggle UI" },
            { "<leader>dub", "float breakpoints" },
            { "<leader>duw", "float watches" },
            { "<leader>dur", "float REPL" },
        }
        for _, k in ipairs(keys) do
            it(k[1] .. " (" .. k[2] .. ")", function()
                assert.is_true(h.has_keymap("n", k[1]), k[1] .. " not found")
            end)
        end
    end)

    describe("fugitive", function()
        local keys = {
            { "<leader>gs", "status" },
            { "<leader>gb", "blame" },
            { "<leader>gc", "commit" },
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

    describe("snacks.image", function()
        it("<M-i> clears image placements (normal mode)", function()
            assert.is_true(h.has_keymap("n", "<M-i>"), "<M-i> not found in normal mode")
        end)

        it("<M-i> clears image placements (insert mode)", function()
            assert.is_true(h.has_keymap("i", "<M-i>"), "<M-i> not found in insert mode")
        end)

        it("<M-i> clears image placements (terminal mode)", function()
            assert.is_true(h.has_keymap("t", "<M-i>"), "<M-i> not found in terminal mode")
        end)
    end)

    describe("sidekick", function()
        local keys = {
            { "<C-,>", "toggle current CLI" },
            { "<M-n>", "new chat — restart current CLI" },
            { "<M-,>", "send message to active CLI (prompt)" },
            { "<M-1>", "send 1 to active CLI" },
            { "<M-2>", "send 2 to active CLI" },
            { "<M-3>", "send 3 to active CLI" },
            { "<M-4>", "send 4 to active CLI" },
            { "<M-5>", "send 5 to active CLI" },
            { "<M-6>", "send 6 to active CLI" },
            { "<M-7>", "send 7 to active CLI" },
            { "<M-8>", "send 8 to active CLI" },
            { "<M-9>", "send 9 to active CLI" },
            { "<M-G>", "scroll active CLI to bottom" },
            { "<M-j>", "scroll active CLI down one line" },
            { "<M-k>", "scroll active CLI up one line" },
            { "<M-d>", "scroll active CLI half page down" },
            { "<M-u>", "scroll active CLI half page up" },
            { "<leader>ac", "toggle Claude CLI" },
            { "<leader>ag", "toggle GitHub Copilot CLI" },
            { "<leader>ar", "resume Claude" },
            { "<leader>ak", "kill Claude session" },
            { "<leader>ap", "prompt → pick CLI/model" },
            { "<leader>adgf", "headless document via github (free)" },
            { "<leader>adgh", "headless document via github (haiku)" },
            { "<leader>adgs", "headless document via github (sonnet)" },
            { "<leader>adgo", "headless document via github (opus)" },
            { "<leader>adch", "headless document via claude (haiku)" },
            { "<leader>adcs", "headless document via claude (sonnet)" },
            { "<leader>adco", "headless document via claude (opus)" },
        }
        for _, k in ipairs(keys) do
            it(k[1] .. " (" .. k[2] .. ")", function()
                assert.is_true(h.has_keymap("n", k[1]), k[1] .. " not found")
            end)
        end

        it("<C-,> works in terminal mode", function()
            assert.is_true(h.has_keymap("t", "<C-,>"), "<C-,> not found in terminal mode")
        end)

        it("<M-n> works in terminal mode", function()
            assert.is_true(h.has_keymap("t", "<M-n>"), "<M-n> not found in terminal mode")
        end)

        it("<M-,> works in terminal mode", function()
            assert.is_true(h.has_keymap("t", "<M-,>"), "<M-,> not found in terminal mode")
        end)

        it("<leader>as (send selection, visual)", function()
            assert.is_true(h.has_keymap("x", "<leader>as"), "<leader>as not found in visual mode")
        end)

        it("opts.cli.win.keys.esc_send sends literal ESC byte in terminal mode", function()
            -- Buffer-local <Esc> mapping installed by sidekick inside CLI
            -- terminal buffers — bypasses nvim's :term key-encoding so the
            -- ESC byte reaches the CLI's job stdin (cancels Claude, dismisses
            -- /memory's menu, etc.). It's wired via sidekick's own
            -- opts.cli.win.keys table (not lazy.nvim's `keys`), so we assert
            -- against the plugin spec directly.
            h.force_load_plugin("sidekick.nvim")
            local specs = require("lazy").plugins()
            local entry
            for _, spec in ipairs(specs) do
                if spec.name == "sidekick.nvim" then
                    assert.is_table(spec.opts, "sidekick.nvim opts missing")
                    assert.is_table(spec.opts.cli, "opts.cli missing")
                    assert.is_table(spec.opts.cli.win, "opts.cli.win missing")
                    assert.is_table(spec.opts.cli.win.keys, "opts.cli.win.keys missing")
                    entry = spec.opts.cli.win.keys.esc_send
                    break
                end
            end
            assert.is_table(entry, "opts.cli.win.keys.esc_send not found")
            assert.are.equal("<Esc>", entry[1], "esc_send lhs should be <Esc>")
            assert.are.equal("t", entry.mode, "esc_send mode should be 't'")
            assert.is_function(entry[2], "esc_send action should be a function")
        end)

        it("<leader>cm registered buffer-local in gitcommit filetype", function()
            local buf = vim.api.nvim_create_buf(false, true)
            vim.bo[buf].filetype = "gitcommit"
            local found = false
            for _, km in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
                if km.lhs == " cm" then
                    found = true
                    break
                end
            end
            vim.api.nvim_buf_delete(buf, { force = true })
            assert.is_true(found, "<leader>cm not registered for gitcommit buffer")
        end)
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

    describe("treesitter-textobjects", function()
        local normal_keys = {
            { "]m", "next function" },
            { "[m", "previous function" },
            { "]c", "next class" },
            { "[c", "previous class" },
            { "]b", "next block" },
            { "[b", "previous block" },
            { "]a", "next parameter" },
            { "[a", "previous parameter" },
        }
        for _, k in ipairs(normal_keys) do
            it(k[1] .. " (" .. k[2] .. ")", function()
                assert.is_true(h.has_keymap("n", k[1]), k[1] .. " not found")
            end)
        end

        local select_keys = {
            { "af", "around function" },
            { "if", "inside function" },
            { "ac", "around class" },
            { "ic", "inside class" },
            { "aa", "around parameter" },
            { "ia", "inside parameter" },
            { "ab", "around block" },
            { "ib", "inside block" },
        }
        for _, k in ipairs(select_keys) do
            it(k[1] .. " (" .. k[2] .. ") visual", function()
                assert.is_true(h.has_keymap("x", k[1]), k[1] .. " not found in visual mode")
            end)
            it(k[1] .. " (" .. k[2] .. ") operator", function()
                assert.is_true(h.has_keymap("o", k[1]), k[1] .. " not found in operator mode")
            end)
        end
    end)

    describe("diffview", function()
        local keys = {
            { "<leader>dv", "open" },
            { "<leader>dh", "file history" },
            { "<leader>dc", "close" },
            { "<leader>dm", "diff against main" },
            { "<leader>do", "diff against origin" },
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
