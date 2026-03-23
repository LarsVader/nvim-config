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

			-- Buttons (use require() so Telescope gets lazy-loaded on first use)
			dashboard.section.buttons.val = {
				dashboard.button("f", "  Find file",         "<cmd>lua require('telescope.builtin').find_files()<cr>"),
				dashboard.button("g", "  Live grep",         "<cmd>lua require('telescope.builtin').live_grep()<cr>"),
				dashboard.button("r", "  Recent files",      "<cmd>lua require('telescope.builtin').oldfiles()<cr>"),
				dashboard.button("p", "  Recent projects",   "<cmd>lua require('lars.pick-project')()<cr>"),
				dashboard.button("k", "  Keymaps",           "<cmd>lua require('telescope.builtin').keymaps()<cr>"),
				dashboard.button("q", "  Quit",              "<cmd>qa<cr>"),
			}

			-- Cheat sheet footer
			dashboard.section.footer.val = {
				"",
				"  ── Navigation ───────────────────────────────────────",
				"  ␣ff   Find files       ␣fg   Live grep",
				"  ␣fs   Find word        ␣fu   Buffers",
				"  <c-p>  Git files        ␣fk   Keymaps",
				"  ␣ha   Harpoon add      ␣hh   Harpoon menu",
				"  ␣1-9  Harpoon jump",
				"",
				"  ── LSP ──────────────────────────────────────────────",
				"  gd  Go to definition          gr   References",
				"  K   Hover docs                <F2> Rename",
				"  <F3> Format                   gl   Line diagnostics",
				"  dN / dn  Next/prev diagnostic",
				"",
				"  ── Debug ────────────────────────────────────────────",
				"  <F5> Continue   <F10> Step over   <F11> Step into",
				"  ␣db  Toggle breakpoint          ␣dr  REPL",
				"",
				"  ── Git ──────────────────────────────────────────────",
				"  ␣gs  Status    ␣gb  Blame",
				"  ␣gd  Diff      ␣fl  Commits",
				"",
				"  ── Text editing ─────────────────────────────────────",
				"  ys{motion}{char}  Surround add      cs{old}{new}  Change",
				"  gc{motion}        Comment line       gb{motion}    Block",
				"  <c-h> / <c-l>     Move argument left/right",
				"",
				"  ── AI / Claude ──────────────────────────────────────",
				"  ␣ac  Toggle Claude     ␣af  Focus Claude",
				"  ␣ar  Resume session    ␣ab  Add buffer to context",
				"  ␣as  Send selection    ␣aa  Accept diff   ␣ad  Deny diff",
				"",
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
