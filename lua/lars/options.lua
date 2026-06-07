vim.wo.number = true
vim.wo.relativenumber = true
vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.smartindent = true
vim.opt.spell = true
vim.opt.spelllang = { "en", "de" }
vim.opt.undofile = true -- allows undo after quit and reopen
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.scrolloff = 8 -- scroll when moving up or down with jk when 8 lines  away from top or bottom
vim.opt.termguicolors = true
vim.opt.guifont= "nerd-fonts" -- icons of eg lualine do not work without. Font needs to be installed on system
vim.opt.ignorecase = true
vim.opt.smartcase = true -- if search term contains upper case letters use case sensitive search
vim.opt.linebreak = true -- wrap at word boundaries, not mid-word
vim.o.signcolumn = "yes:1"

-- Show invisible characters
vim.opt.list = true
vim.opt.listchars = {
    tab = "» ",
    trail = "·",
    nbsp = "␣",
    extends = "›",
    precedes = "‹",
    space = "·",
}

-- Treesitter-based code folding (all folds open by default)
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldlevel = 99
vim.opt.foldlevelstart = 99

-- After treesitter computes folds, set foldlevel to the actual max depth so
-- that zm immediately starts closing folds (instead of decrementing from 99).
local treesitter_fold_group = vim.api.nvim_create_augroup("treesitter_fold_level", { clear = true })
vim.api.nvim_create_autocmd("BufWinEnter", {
    group = treesitter_fold_group,
    callback = function()
        -- Defer to let treesitter finish computing fold levels
        vim.defer_fn(function()
            if not vim.api.nvim_buf_is_valid(vim.api.nvim_get_current_buf()) then
                return
            end
            -- Don't override foldlevel in diff mode (it uses foldmethod=diff)
            if vim.wo.diff then return end
            local max_level = 0
            local line_count = vim.api.nvim_buf_line_count(0)
            for lnum = 1, line_count do
                local level = vim.fn.foldlevel(lnum)
                if level > max_level then
                    max_level = level
                end
            end
            if max_level > 0 then
                vim.wo.foldlevel = max_level
            end
        end, 100)
    end,
})

if vim.g.neovide then
	vim.g.neovide_scale_factor = 0.8
	local change_scale_factor = function(delta)
		vim.g.neovide_scale_factor = vim.g.neovide_scale_factor * delta
	end
	vim.keymap.set("n", "<C-=>", function()
		change_scale_factor(1.25)
	end)
	vim.keymap.set("n", "<C-->", function()
		change_scale_factor(1/1.25)
	end)
end
