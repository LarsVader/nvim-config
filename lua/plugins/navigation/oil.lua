local oil_settings = function (subfolder)
	subfolder = subfolder or ''
	if vim.api.nvim_win_get_config(0).relative ~= '' then
		require('oil').open(vim.fn.stdpath('config') .. subfolder)
		return
	end

	local buf = vim.api.nvim_create_buf(false, true)
	local columns = vim.api.nvim_get_option('columns')
	local lines = vim.api.nvim_get_option('lines')
	vim.api.nvim_open_win(buf, true, {
		relative='editor',
		row=1,
		col=2,
		width=columns - 4,
		height=lines - 6,
		border='single',
		zindex=5,
	})
	require('oil').open(vim.fn.stdpath('config') .. subfolder)
end

return {
	{
		'stevearc/oil.nvim',
		dependencies = { "nvim-tree/nvim-web-devicons" },
		lazy = false, -- no point in lazy loading this as we want to replace netrw with this 
		opts = {
			skip_confirm_for_simple_edits = true,
			keymaps = {
				["g?"] = "actions.show_help",
				["<CR>"] = "actions.select",
				["<leader>ev"] = "actions.select_vsplit",
				["<leader>eh"] = "actions.select_split",
				["<leader>et"] = "actions.select_tab",
				["<leader>ep"] = "actions.preview",
				["<C-c>"] = "actions.close",
				["<C-l>"] = "actions.refresh",
				["-"] = "actions.parent",
				["_"] = "actions.open_cwd",
				["`"] = "actions.cd",
				["~"] = "actions.tcd",
				["g."] = "actions.toggle_hidden",
			},
			use_default_keymaps = false,
			view_options = {
				show_hidden = false,
				is_hidden_file = function(name, bufnr)
					return vim.startswith(name, ".")
				end,
				is_always_hidden = function(name, bufnr)
					return false
				end,
			},
		},
		keys = {
			{ '<leader>fe', function () require('oil').open(vim.fn.expand('%:h')) end, desc='oil file explorer' },
			{ '<leader>ss', function () oil_settings() end, desc = "Open nvim config root in oil" },
			{ '<leader>sp', function () oil_settings('/lua/plugins') end, desc = "Open plugins dir in oil" },
			{ '<leader>sl', function () oil_settings('/lua/lars') end, desc = "Open lars dir in oil" },
		}
	}
}
