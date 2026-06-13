-- Tier 1: Verify lazy.nvim registered trigger keymaps for all plugins
local h = dofile(vim.fn.stdpath("config") .. "/tests/helpers.lua")

describe("plugin keymaps", function()
    -- Telescope was replaced by snacks.nvim (lua/plugins/ui/snacks.lua)
    -- for the git/util pickers and fff.nvim (lua/plugins/navigation/fff.lua)
    -- for file finding + live grep. These are the trigger keymaps that
    -- replaced the old telescope <leader>f* set.
    describe("snacks/fff pickers", function()
        local keys = {
            { "<C-p>",      "fff find files" },
            { "fg",         "fff live grep" },
            { "<leader>fl", "snacks git log" },
            { "<leader>fb", "snacks git branches" },
            { "<leader>fS", "snacks git status" },
            { "<leader>fc", "snacks git log file" },
            { "<leader>fh", "snacks help" },
            { "<leader>fk", "snacks keymaps" },
            { "<leader>fr", "snacks resume" },
            { "<leader>fq", "snacks quickfix" },
            { "<leader>fp", "snacks projects" },
            { "<leader>fd", "snacks diagnostics" },
            { "<leader>fu", "snacks buffers" },
        }
        for _, k in ipairs(keys) do
            it(k[1] .. " (" .. k[2] .. ")", function()
                assert.is_true(h.has_keymap("n", k[1]), k[1] .. " not found")
            end)
        end
    end)

    describe("snacks git_log rebase", function()
        -- Rebase keys are wired through snacks' own picker config
        -- (opts.picker.sources.git_log.win.input.keys), not lazy.nvim's `keys`,
        -- and only exist inside the open picker window -- so we assert against the
        -- plugin spec directly rather than via has_keymap.
        local function snacks_picker_opts()
            h.force_load_plugin("snacks.nvim")
            for _, spec in ipairs(require("lazy").plugins()) do
                if spec.name == "snacks.nvim" then
                    assert.is_table(spec.opts, "snacks.nvim opts missing")
                    assert.is_table(spec.opts.picker, "opts.picker missing")
                    return spec.opts.picker
                end
            end
            error("snacks.nvim spec not found")
        end

        it("git_rebase / git_rebase_interactive are picker actions", function()
            local picker = snacks_picker_opts()
            assert.is_table(picker.actions, "opts.picker.actions missing")
            assert.is_function(picker.actions.git_rebase, "git_rebase action missing")
            assert.is_function(picker.actions.git_rebase_interactive,
                "git_rebase_interactive action missing")
        end)

        it("git_log_toggle_files action and preview function are wired", function()
            local picker = snacks_picker_opts()
            assert.is_function(picker.actions.git_log_toggle_files,
                "git_log_toggle_files action missing")
            local preview = vim.tbl_get(picker, "sources", "git_log", "preview")
            assert.is_function(preview, "git_log preview function missing")
            local format = vim.tbl_get(picker, "sources", "git_log", "format")
            assert.is_function(format, "git_log format function missing")
        end)

        it("git_rebase mark/clear actions are picker functions", function()
            local picker = snacks_picker_opts()
            for _, name in ipairs({
                "git_rebase_mark_edit", "git_rebase_mark_reword", "git_rebase_mark_squash",
                "git_rebase_mark_fixup", "git_rebase_mark_drop", "git_rebase_mark_pick",
                "git_rebase_mark_split", "git_rebase_clear", "git_rebase_move_up", "git_rebase_move_down",
            }) do
                assert.is_function(picker.actions[name], name .. " action missing")
            end
        end)

        local keymaps = {
            { lhs = "<c-r>r", action = "git_rebase" },
            { lhs = "<c-r>i", action = "git_rebase_interactive" },
            { lhs = "<c-r>e", action = "git_rebase_mark_edit" },
            { lhs = "<c-r>w", action = "git_rebase_mark_reword" },
            { lhs = "<c-r>s", action = "git_rebase_mark_squash" },
            { lhs = "<c-r>f", action = "git_rebase_mark_fixup" },
            { lhs = "<c-r>d", action = "git_rebase_mark_drop" },
            { lhs = "<c-r>m", action = "git_rebase_mark_split" },
            { lhs = "<c-r>p", action = "git_rebase_mark_pick" },
            { lhs = "<c-r>x", action = "git_rebase_clear" },
            { lhs = "<c-k>", action = "git_rebase_move_up" },
            { lhs = "<c-j>", action = "git_rebase_move_down" },
            { lhs = "<c-d>", action = "diffview_open" },
            { lhs = "<M-l>", action = "git_log_toggle_files" },
        }
        for _, k in ipairs(keymaps) do
            it(k.lhs .. " -> " .. k.action .. " in git_log", function()
                local picker = snacks_picker_opts()
                local keys = vim.tbl_get(picker, "sources", "git_log", "win", "input", "keys")
                assert.is_table(keys, "git_log input keys missing")
                local entry = keys[k.lhs]
                assert.is_table(entry, k.lhs .. " mapping missing")
                assert.are.equal(k.action, entry[1], k.lhs .. " should map to " .. k.action)
                assert.are.same({ "n", "i" }, entry.mode, k.lhs .. " should bind n+i modes")
            end)
        end

        it("git_status frees <Tab> back to list_down navigation", function()
            local picker = snacks_picker_opts()
            local keys = vim.tbl_get(picker, "sources", "git_status", "win", "input", "keys")
            assert.is_table(keys, "git_status input keys missing")
            assert.are.equal("list_down", keys["<Tab>"][1], "<Tab> should be list_down, not git_stage")
        end)

        -- Selecting a change in the status list stages it: stage keys chain
        -- git_stage with a list move, replacing the generic select_and_* keys.
        local stage_keys = { ["<c-n>"] = "list_down", ["<c-t>"] = "list_down", ["<c-p>"] = "list_up" }
        for lhs, move in pairs(stage_keys) do
            it(lhs .. " stages then " .. move .. " in git_status", function()
                local picker = snacks_picker_opts()
                local keys = vim.tbl_get(picker, "sources", "git_status", "win", "input", "keys")
                local entry = keys[lhs]
                assert.is_table(entry, lhs .. " mapping missing")
                assert.are.same({ "git_stage", move }, entry[1], lhs .. " should chain git_stage + " .. move)
                assert.are.same({ "n", "i" }, entry.mode, lhs .. " should bind n+i modes")
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

    describe("flash", function()
        it("s (flash jump)", function()
            assert.is_true(h.has_keymap("n", "s"), "s not found")
        end)
        it("S (flash treesitter)", function()
            assert.is_true(h.has_keymap("n", "S"), "S not found")
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
            { "<leader>ga", "amend (soft reset)" },
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

    describe("termcontrol", function()
        -- Generic terminal-interaction bindings live in the separate
        -- termcontrol.nvim plugin (lua/plugins/ai/termcontrol.lua). They were
        -- previously inline in sidekick.lua.
        h.force_load_plugin("termcontrol.nvim")
        local keys = {
            { "<M-n>", "new chat — restart active sidekick CLI" },
            { "<M-,>", "send message to active terminal (prompt)" },
            { "<M-1>", "send 1 to active terminal" },
            { "<M-2>", "send 2 to active terminal" },
            { "<M-3>", "send 3 to active terminal" },
            { "<M-4>", "send 4 to active terminal" },
            { "<M-5>", "send 5 to active terminal" },
            { "<M-6>", "send 6 to active terminal" },
            { "<M-7>", "send 7 to active terminal" },
            { "<M-8>", "send 8 to active terminal" },
            { "<M-9>", "send 9 to active terminal" },
            { "<M-G>", "scroll active terminal to bottom" },
            { "<M-j>", "scroll active terminal down one line" },
            { "<M-k>", "scroll active terminal up one line" },
            { "<M-d>", "scroll active terminal half page down" },
            { "<M-u>", "scroll active terminal half page up" },
        }
        for _, k in ipairs(keys) do
            it(k[1] .. " (" .. k[2] .. ")", function()
                assert.is_true(h.has_keymap("n", k[1]), k[1] .. " not found")
            end)
        end

        it("<M-n> works in terminal mode", function()
            assert.is_true(h.has_keymap("t", "<M-n>"), "<M-n> not found in terminal mode")
        end)

        it("<M-,> works in terminal mode", function()
            assert.is_true(h.has_keymap("t", "<M-,>"), "<M-,> not found in terminal mode")
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
