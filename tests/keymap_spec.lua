-- Tier 1: Verify all global keymaps from lua/lars/keymap.lua are registered
local h = dofile(vim.fn.stdpath("config") .. "/tests/helpers.lua")

describe("global keymaps", function()
    -- Normal mode keymaps
    describe("normal mode", function()
        it("scroll down centered <C-d>", function()
            local km = h.find_keymap("n", "<C-d>")
            assert.is_not_nil(km, "<C-d> not found")
            assert.is_not_nil(km.desc:lower():find("scroll down"), "desc missing 'scroll down'")
        end)

        it("scroll up centered <C-u>", function()
            local km = h.find_keymap("n", "<C-u>")
            assert.is_not_nil(km, "<C-u> not found")
            assert.is_not_nil(km.desc:lower():find("scroll up"), "desc missing 'scroll up'")
        end)

        it("next quickfix <leader>n", function()
            local km = h.find_keymap("n", "<leader>n")
            assert.is_not_nil(km, "<leader>n not found")
            assert.is_not_nil(km.desc:lower():find("next quickfix"), "desc missing 'next quickfix'")
        end)

        it("previous quickfix <leader>N", function()
            local km = h.find_keymap("n", "<leader>N")
            assert.is_not_nil(km, "<leader>N not found")
            assert.is_not_nil(km.desc:lower():find("previous quickfix"), "desc missing 'previous quickfix'")
        end)

        it("yank to clipboard <leader>y", function()
            local km = h.find_keymap("n", "<leader>y")
            assert.is_not_nil(km, "<leader>y not found")
            assert.is_not_nil(km.desc:lower():find("yank to system"), "desc missing 'yank to system'")
        end)

        it("paste from clipboard <leader>p", function()
            local km = h.find_keymap("n", "<leader>p")
            assert.is_not_nil(km, "<leader>p not found")
            assert.is_not_nil(km.desc:lower():find("paste from system"), "desc missing 'paste from system'")
        end)

        it("paste and re-indent p", function()
            local km = h.find_keymap("n", "p")
            assert.is_not_nil(km, "p not found")
            assert.is_not_nil(km.desc:lower():find("paste and re%-indent"), "desc missing 'paste and re-indent'")
        end)

        it("alternate test/source <leader>jt", function()
            local km = h.find_keymap("n", "<leader>jt")
            assert.is_not_nil(km, "<leader>jt not found")
            assert.is_not_nil(km.desc:lower():find("test"), "desc missing 'test'")
        end)

        it("alternate view/viewmodel <leader>jv", function()
            local km = h.find_keymap("n", "<leader>jv")
            assert.is_not_nil(km, "<leader>jv not found")
            assert.is_not_nil(km.desc:lower():find("view"), "desc missing 'view'")
        end)
    end)

    -- Insert mode keymaps
    describe("insert mode", function()
        it("exit insert and undo <C-c>", function()
            local km = h.find_keymap("i", "<C-c>")
            assert.is_not_nil(km, "<C-c> not found in insert mode")
            assert.is_not_nil(km.desc:lower():find("leave insert"), "desc missing 'leave insert'")
        end)
    end)

    -- Terminal mode keymaps
    describe("terminal mode", function()
        it("exit terminal <Esc><Esc>", function()
            local km = h.find_keymap("t", "<Esc><Esc>")
            assert.is_not_nil(km, "<Esc><Esc> not found in terminal mode")
            assert.is_not_nil(km.desc:lower():find("exit terminal"), "desc missing 'exit terminal'")
        end)

        local terminal_nav = {
            { "<C-w>h", "left" },
            { "<C-w>l", "right" },
            { "<C-w>j", "down" },
            { "<C-w>k", "up" },
            { "<C-w>w", "cycle" },
        }
        for _, nav in ipairs(terminal_nav) do
            it("terminal nav " .. nav[1], function()
                local km = h.find_keymap("t", nav[1])
                assert.is_not_nil(km, nav[1] .. " not found in terminal mode")
                assert.is_not_nil(km.desc:lower():find("terminal"), "desc missing 'terminal'")
            end)
        end
    end)

    -- LSP diagnostic keymaps (set in nvim-lsp-config init, always global)
    describe("LSP diagnostic keymaps", function()
        it("show line diagnostics gl", function()
            local km = h.find_keymap("n", "gl")
            assert.is_not_nil(km, "gl not found")
        end)

        it("previous diagnostic dn", function()
            local km = h.find_keymap("n", "dn")
            assert.is_not_nil(km, "dn not found")
        end)

        it("next diagnostic dN", function()
            local km = h.find_keymap("n", "dN")
            assert.is_not_nil(km, "dN not found")
        end)

        it("diagnostics to loclist <leader>q", function()
            local km = h.find_keymap("n", "<leader>q")
            assert.is_not_nil(km, "<leader>q not found")
        end)
    end)
end)
