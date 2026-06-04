return {
	-- Colorscheme plugins (loaded as themery dependencies)
	{ "folke/tokyonight.nvim", lazy = true },
	{ 'EdenEast/nightfox.nvim', lazy = true },
	{ 'catppuccin/nvim', name = 'catppuccin', lazy = true },
	{ 'rose-pine/neovim', name = 'rose-pine', lazy = true },
	{ 'rebelot/kanagawa.nvim', lazy = true },
	{ 'sainnhe/everforest', lazy = true },
	{
		"eldritch-theme/eldritch.nvim",
		lazy = false,
		priority = 1000,
		opts = {
			transparent = true,
			on_colors = function(global_colors)
				-- Define all color overrides in a single table
				local color_definitions = {
					-- https://github.com/eldritch-theme/eldritch.nvim/blob/master/lua/eldritch/colors.lua
					bg = "#0D1116",
					fg = "#ebfafa",
					selection = "#e9b3fd",
					comment = "#a5afc2",
					red = "#5fa9f4", -- default #f16c75
					orange = "#1682ef", -- default #f7c67f
					yellow = "#19dfcf", -- default #f1fc79
					green = "#37f499",
					purple = "#987afb", -- default #a48cf2
					cyan = "#04d1f9",
					pink = "#949ae5", -- default #f265b5
					bright_red = "#5fa9f4",
					bright_green = "#37f499",
					bright_yellow = "#19dfcf",
					bright_blue = "#987af",
					bright_magenta = "#949ae5",
					bright_cyan = "#04d1f9",
					bright_white = "#ebfafa",
					menu = "#0D1116",
					visual = "#e9b3fd",
					gutter_fg = "#e9b3fd",
					nontext = "#e9b3fd",
					white = "#ebfafa",
					black = "#0D1116",
					git = {
						change = "#04d1f9",
						add = "#37f499",
						delete = "#f16c75",
					},
					gitSigns = {
						change = "#04d1f9",
						add = "#37f499",
						delete = "#f16c75",
					},
					bg_dark = "#314154",
					-- Lualine line across
					bg_highlight = "#141b22",
					terminal_black = "#314154",
					fg_dark = "#ebfafa",
					fg_gutter = "#314154",
					dark3 = "#314154",
					dark5 = "#314154",
					bg_visual = "#e9b3fd",
					dark_cyan = "#04d1f9",
					magenta = "#949ae5",
					magenta2 = "#949ae5",
					magenta3 = "#949ae5",
					dark_yellow = "#19dfcf",
					dark_green = "#37f499",
				}
				-- Apply each color definition to global_colors
				for key, value in pairs(color_definitions) do
					global_colors[key] = value
				end
			end,
			on_highlights = function(highlights, colors)
				-- Flash dims everything except match labels via FlashBackdrop.
				-- The theme default (dark3 = #314154) is almost invisible on the
				-- dark bg, making text unreadable during a jump. Lift it to a
				-- mid-gray so non-matched text stays legible but de-emphasized.
				highlights.FlashBackdrop = { fg = "#7d8ba3" }
			end,
		},
	},
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
			'eldritch-theme/eldritch.nvim',
		},
		keys = {
			{ "<leader>ut", "<cmd>Themery<cr>", desc = "Theme switcher" },
		},
		config = function()
			-- Suppress false-positive deprecation warning (Themery bug:
			-- normalizePaths sets themeConfigFile even when not configured).
			-- Temporarily redirect print to swallow the one known message.
			local _print = print
			print = function(msg)
				if type(msg) == "string" and msg:match("themeConfigFile") then return end
				_print(msg)
			end

			require("themery").setup({
				themes = {
					-- Nightfox variants
					{ name = "Nightfox", colorscheme = "nightfox" },
					{ name = "Carbonfox", colorscheme = "carbonfox" },
					-- Tokyonight variants
					{ name = "Tokyonight Storm", colorscheme = "tokyonight-storm" },
					{ name = "Tokyonight Night", colorscheme = "tokyonight-night" },
					{ name = "Tokyonight Moon", colorscheme = "tokyonight-moon" },
					-- Catppuccin variants
					{ name = "Catppuccin Mocha", colorscheme = "catppuccin-mocha" },
					{ name = "Catppuccin Macchiato", colorscheme = "catppuccin-macchiato" },
					{ name = "Catppuccin Frappe", colorscheme = "catppuccin-frappe" },
					-- Rose Pine variants
					{ name = "Rose Pine", colorscheme = "rose-pine" },
					-- Kanagawa variants
					{ name = "Kanagawa Wave", colorscheme = "kanagawa-wave" },
					-- Everforest
					{ name = "linkarzu eldritch", colorscheme = "eldritch" },
				},
				livePreview = true,
			})
			print = _print

			-- Themery restores the persisted theme on setup.
			-- On first run (no state file yet), fall back to carbonfox.
			local current = vim.g.colors_name
			if not current or current == "default" then
				vim.cmd.colorscheme("carbonfox")
			end
		end,
	},
}
