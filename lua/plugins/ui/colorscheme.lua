return {
	-- Colorscheme plugins (loaded as themery dependencies)
	{ "folke/tokyonight.nvim", lazy = true },
	{ 'EdenEast/nightfox.nvim', lazy = true },
	{ 'catppuccin/nvim', name = 'catppuccin', lazy = true },
	{ 'rose-pine/neovim', name = 'rose-pine', lazy = true },
	{ 'rebelot/kanagawa.nvim', lazy = true },
	{ 'sainnhe/everforest', lazy = true },

	-- Theme switcher with persistence
	{
		'zaldih/themery.nvim',
		lazy = false,
		priority = 1000,
		dependencies = {
			'EdenEast/nightfox.nvim',
			'folke/tokyonight.nvim',
			'catppuccin/nvim',
			'rose-pine/neovim',
			'rebelot/kanagawa.nvim',
			'sainnhe/everforest',
		},
		keys = {
			{ "<leader>ut", "<cmd>Themery<cr>", desc = "Theme switcher" },
		},
		config = function()
			require("themery").setup({
				themes = {
					-- Nightfox variants
					{ name = "Nightfox", colorscheme = "nightfox" },
					{ name = "Dayfox", colorscheme = "dayfox" },
					{ name = "Dawnfox", colorscheme = "dawnfox" },
					{ name = "Duskfox", colorscheme = "duskfox" },
					{ name = "Nordfox", colorscheme = "nordfox" },
					{ name = "Terafox", colorscheme = "terafox" },
					{ name = "Carbonfox", colorscheme = "carbonfox" },
					-- Tokyonight variants
					{ name = "Tokyonight Storm", colorscheme = "tokyonight-storm" },
					{ name = "Tokyonight Night", colorscheme = "tokyonight-night" },
					{ name = "Tokyonight Moon", colorscheme = "tokyonight-moon" },
					{ name = "Tokyonight Day", colorscheme = "tokyonight-day" },
					-- Catppuccin variants
					{ name = "Catppuccin Mocha", colorscheme = "catppuccin-mocha" },
					{ name = "Catppuccin Macchiato", colorscheme = "catppuccin-macchiato" },
					{ name = "Catppuccin Frappe", colorscheme = "catppuccin-frappe" },
					{ name = "Catppuccin Latte", colorscheme = "catppuccin-latte" },
					-- Rose Pine variants
					{ name = "Rose Pine", colorscheme = "rose-pine" },
					{ name = "Rose Pine Moon", colorscheme = "rose-pine-moon" },
					{ name = "Rose Pine Dawn", colorscheme = "rose-pine-dawn" },
					-- Kanagawa variants
					{ name = "Kanagawa Wave", colorscheme = "kanagawa-wave" },
					{ name = "Kanagawa Dragon", colorscheme = "kanagawa-dragon" },
					{ name = "Kanagawa Lotus", colorscheme = "kanagawa-lotus" },
					-- Everforest
					{ name = "Everforest", colorscheme = "everforest" },
				},
				livePreview = true,
			})

			-- Themery restores the persisted theme on setup.
			-- On first run (no state file yet), fall back to carbonfox.
			local current = vim.g.colors_name
			if not current or current == "default" then
				vim.cmd.colorscheme("carbonfox")
			end
		end,
	},
}
