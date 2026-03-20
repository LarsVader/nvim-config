-- Tier 2: Verify editor options from lua/lars/options.lua

describe("editor options", function()
    it("line numbers enabled", function()
        assert.is_true(vim.wo.number, "number should be true")
    end)

    it("relative line numbers enabled", function()
        assert.is_true(vim.wo.relativenumber, "relativenumber should be true")
    end)

    it("tabstop = 4", function()
        assert.equals(4, vim.opt.tabstop:get())
    end)

    it("softtabstop = 4", function()
        assert.equals(4, vim.opt.softtabstop:get())
    end)

    it("shiftwidth = 4", function()
        assert.equals(4, vim.opt.shiftwidth:get())
    end)

    it("smartindent enabled", function()
        assert.is_true(vim.opt.smartindent:get(), "smartindent should be true")
    end)

    it("spell enabled", function()
        assert.is_true(vim.opt.spell:get(), "spell should be true")
    end)

    it("hlsearch disabled", function()
        assert.is_false(vim.opt.hlsearch:get(), "hlsearch should be false")
    end)

    it("incsearch enabled", function()
        assert.is_true(vim.opt.incsearch:get(), "incsearch should be true")
    end)

    it("scrolloff = 8", function()
        assert.equals(8, vim.opt.scrolloff:get())
    end)

    it("termguicolors enabled", function()
        assert.is_true(vim.opt.termguicolors:get(), "termguicolors should be true")
    end)

    it("ignorecase enabled", function()
        assert.is_true(vim.opt.ignorecase:get(), "ignorecase should be true")
    end)

    it("smartcase enabled", function()
        assert.is_true(vim.opt.smartcase:get(), "smartcase should be true")
    end)

    it("leader is space", function()
        assert.equals(" ", vim.g.mapleader, "mapleader should be space")
    end)
end)
