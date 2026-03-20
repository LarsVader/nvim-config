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

    describe("claude-code", function()
        local keys = {
            { "<C-,>", "toggle" },
            { "<leader>ar", "resume" },
            { "<leader>ad", "diff" },
        }
        for _, k in ipairs(keys) do
            it(k[1] .. " (" .. k[2] .. ")", function()
                assert.is_true(h.has_keymap("n", k[1]), k[1] .. " not found")
            end)
        end
    end)
end)
