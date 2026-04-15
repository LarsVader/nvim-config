vim.wo.number = true
vim.wo.relativenumber = true
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.smartindent = true
vim.opt.spell = true
vim.opt.undofile = true -- allows undo after quit and reopen
vim.opt.hlsearch = false
vim.opt.incsearch = true
vim.opt.scrolloff = 8 -- scroll when moving up or down with jk when 8 lines  away from top or bottom
vim.opt.termguicolors = true
vim.opt.guifont= "nerd-fonts" -- icons of eg lualine do not work without. Font needs to be installed on system
vim.opt.ignorecase = true
vim.opt.smartcase = true -- if search term contains upper case letters use case sensitive search
vim.opt.linebreak = true -- wrap at word boundaries, not mid-word

-- Treesitter-based code folding (all folds open by default)
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldlevel = 99
vim.opt.foldlevelstart = 99


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
