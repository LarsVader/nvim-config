return {
	{
		-- pin buffers and jump to them fast
		'ThePrimeagen/harpoon',
		branch = 'harpoon2',
		dependencies = { 'nvim-lua/plenary.nvim' },
		config = function()
			require('harpoon'):setup({
				settings = {
					-- Fix Windows path normalization: plenary.path:make_relative()
					-- fails with mixed forward/backslashes, causing absolute paths
					-- to be stored instead of relative ones.
					key = function()
						return vim.loop.cwd():gsub("\\", "/")
					end,
				},
				default = {
					create_list_item = function(config, name)
						name = name or vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
						local buf_name = name:gsub("\\", "/")
						local cwd = vim.loop.cwd():gsub("\\", "/")
						-- Strip cwd prefix to get a relative path
						if buf_name:sub(1, #cwd) == cwd then
							buf_name = buf_name:sub(#cwd + 2) -- +2 to skip the trailing slash
						end
						local bufnr = vim.fn.bufnr(name, false)
						local pos = { 1, 0 }
						if bufnr ~= -1 then
							local mark = vim.api.nvim_buf_get_mark(bufnr, '"')
							if mark[1] > 0 then
								pos = mark
							end
						end
						return {
							value = buf_name,
							context = { row = pos[1], col = pos[2] },
						}
					end,
				},
			})
		end,
		keys = (function()
			local k = {
				{"<leader>ha", function() require('harpoon'):list():add() end, desc='harpoon add'},
				{"<leader>hh", function()
					local h = require('harpoon')
					h.ui:toggle_quick_menu(h:list())
				end, desc='harpoon menu'},
			}
			for i = 1, 9 do
				table.insert(k, {"<leader>"..i, function() require('harpoon'):list():select(i) end, desc='harpoon file '..i})
			end
			return k
		end)(),
	},
}
