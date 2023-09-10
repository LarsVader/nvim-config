local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", -- latest stable release
		lazypath,
	})
end

vim.opt.rtp:prepend(lazypath)


local plugins = {
	-- navigation
	{ 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' }, -- make fuzzy finder fast
	{ 'nvim-telescope/telescope.nvim', tag = '0.1.2', dependencies = { 'nvim-lua/plenary.nvim', } }, -- fuzzy finder :)
	{ 'stevearc/oil.nvim', dependencies = { "nvim-tree/nvim-web-devicons" }, }, -- file explorer that can be edited like a vim buffer
	{ 'ThePrimeagen/harpoon', dependencies = { 'nvim-lua/plenary.nvim' } }, -- pin buffers and jump to them fast
	-- ui
	"folke/tokyonight.nvim",
	'EdenEast/nightfox.nvim',
	{ "nvim-lualine/lualine.nvim", dependencies = { "nvim-tree/nvim-web-devicons", opt = true } }, -- nicely themed status bar showing mode git branch etc.
	-- { 'folke/which-key.nvim', opts = {} }, -- disabled because it destroys remaps (space nop and lsp gd etc)
	-- lsp and code completions
	{
		'VonHeikemen/lsp-zero.nvim',
		branch = 'v2.x',
		dependencies = {
			{'neovim/nvim-lspconfig'},             -- Required
			{'williamboman/mason.nvim'},           -- installer for lsp and more with :Mason
			{'williamboman/mason-lspconfig.nvim'}, -- Optional
			{'hrsh7th/nvim-cmp'},     -- auto completions
			{'hrsh7th/cmp-nvim-lsp'}, -- Required
			{'L3MON4D3/LuaSnip'},     -- snippets for lua 
		}
	},
	{"nvim-treesitter/nvim-treesitter", build = ":TSUpdate"},
	{ 'simrat39/rust-tools.nvim', dependencies = { 'neovim/nvim-lspconfig' }, },
	'timonv/vim-cargo', -- wrapped cargo commands. This will also configure make to use cargo 
	{
		'saecki/crates.nvim', -- completions on the cargo.toml file
		dependencies = { 'nvim-lua/plenary.nvim', },
		ft = {'rust', 'toml'},
		opts = {},
		config = function(_,opts)
			local crates = require('crates')
			crates.setup(opts)
			crates.show()
		end,
	},
	{ "folke/neodev.nvim", opts = {} }, -- auto completions in neovim config files
	{
		'windwp/nvim-autopairs',
		event = "InsertEnter",
		opts = {} -- this is equalent to setup({}) function
	}, -- automatically add closing brackets etc
	-- new text editing commands
	{ 'numToStr/Comment.nvim', opts = {} }, -- "gc" to comment visual regions/lines
	"tpope/vim-surround", -- adds the "s" command. For example siw" to surround with quotes
	"vim-scripts/ReplaceWithRegister", -- Example "griw" => go replace inside word
	"bkad/CamelCaseMotion", -- motion to move inside camel case words (use leader key in front of normal motion)
	'AndrewRadev/sideways.vim', -- move parameters left or right in a list
	-- Git
	'tpope/vim-fugitive', -- git integration
	'tommcdo/vim-fugitive-blame-ext', -- on the blame window from fugitive show the commit message of the current line
	'tpope/vim-rhubarb', -- configures :GBrowse to open GitHub in browser
	-- debugging
	{ "rcarriga/nvim-dap-ui", dependencies = { "mfussenegger/nvim-dap" } }, -- debugger
	-- other
	'ThePrimeagen/vim-be-good', -- game to get better with vim motions
}

require("lazy").setup(plugins)
