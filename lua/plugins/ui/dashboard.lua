return {
	{
		'goolord/alpha-nvim',
		event = "VimEnter",
		dependencies = { 'nvim-tree/nvim-web-devicons' },
		config = function()
			local alpha = require('alpha')
			local dashboard = require('alpha.themes.dashboard')

			-- Header
			dashboard.section.header.val = {
				"",
				"  ███╗   ██╗██╗   ██╗██╗███╗   ███╗  ",
				"  ████╗  ██║██║   ██║██║████╗ ████║  ",
				"  ██╔██╗ ██║██║   ██║██║██╔████╔██║  ",
				"  ██║╚██╗██║╚██╗ ██╔╝██║██║╚██╔╝██║  ",
				"  ██║ ╚████║ ╚████╔╝ ██║██║ ╚═╝ ██║  ",
				"  ╚═╝  ╚═══╝  ╚═══╝  ╚═╝╚═╝     ╚═╝  ",
				"",
			}

			-- Buttons (fff for file/grep, snacks.picker for the rest)
			dashboard.section.buttons.val = {
				dashboard.button("f", "  Find file",         "<cmd>lua require('fff').find_files()<cr>"),
				dashboard.button("g", "  Live grep",         "<cmd>lua require('fff').live_grep()<cr>"),
				dashboard.button("r", "  Recent files",      "<cmd>lua Snacks.picker.recent()<cr>"),
				dashboard.button("p", "  Projects",          "<cmd>lua Snacks.picker.projects()<cr>"),
				dashboard.button("k", "  Keymaps",           "<cmd>lua Snacks.picker.keymaps()<cr>"),
				dashboard.button("q", "  Quit",              "<cmd>qa<cr>"),
			}

			dashboard.section.footer.opts.hl = "Comment"
			dashboard.section.header.opts.hl = "Include"
			dashboard.section.buttons.opts.hl = "Keyword"

			-- Only show dashboard when no file arguments given
			local config = dashboard.config
			config.opts.noautocmd = true

			alpha.setup(config)

			-- Don't show dashboard if opening a file
			vim.api.nvim_create_autocmd("User", {
				pattern = "AlphaReady",
				callback = function()
					vim.opt_local.foldenable = false
				end,
			})
		end,
	},
}
