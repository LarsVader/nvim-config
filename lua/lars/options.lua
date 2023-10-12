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
vim.opt.wrap = false

vim.diagnostic.config {
  virtual_text = false,
  signs = true,
  underline = true,
}
