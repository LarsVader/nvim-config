local function has_compiler()
	return vim.fn.executable('cc') == 1
		or vim.fn.executable('gcc') == 1
		or vim.fn.executable('clang') == 1
		or vim.fn.executable('cl') == 1
		or vim.fn.executable('zig') == 1
end

local wanted_parsers = {
	'cpp', 'rust', 'javascript', 'vimdoc', 'vim', 'lua', 'c_sharp',
}

return {
	{
		"nvim-treesitter/nvim-treesitter",
		build = function()
			if has_compiler() then
				vim.cmd('TSUpdate')
			end
		end,
		config = function()
			local function setup_treesitter(parsers)
				require('nvim-treesitter.configs').setup {
					ensure_installed = parsers,
					sync_install = false,
					auto_install = false,
					ignore_install = {},
					highlight = { enable = true },
					indent = { enable = true },
					incremental_selection = {
						enable = true,
						keymaps = {
							init_selection = '<c-space>',
							node_incremental = '<c-space>',
							scope_incremental = '<c-s>',
							node_decremental = '<M-space>',
						},
					},
				}
			end

			if has_compiler() then
				setup_treesitter(wanted_parsers)
				vim.defer_fn(function()
					vim.cmd('TSUpdate')
				end, 5000)
				return
			end

			-- No compiler — try to install zig, then set up parsers
			setup_treesitter({})
			if vim.fn.has('win32') ~= 1 then
				return
			end
			vim.notify(
				'No C compiler found. Installing zig via winget...',
				vim.log.levels.INFO
			)
			local function on_output(_, data)
				if not data then return end
				for _, line in ipairs(data) do
					local trimmed = line:gsub('%s+$', '')
					if trimmed ~= '' then
						vim.schedule(function()
							vim.notify(
								'zig install: ' .. trimmed,
								vim.log.levels.INFO
							)
						end)
					end
				end
			end
			vim.fn.jobstart(
				'winget install -e --id zig.zig'
					.. ' --accept-package-agreements'
					.. ' --accept-source-agreements',
				{
					stdout_buffered = false,
					stderr_buffered = false,
					on_stdout = on_output,
					on_stderr = on_output,
					on_exit = function(_, code)
						if code ~= 0 then
							vim.schedule(function()
								vim.notify(
									'zig install failed (exit '
										.. code .. ').'
										.. ' Install a C compiler manually.',
									vim.log.levels.ERROR
								)
							end)
							return
						end
						vim.schedule(function()
							vim.notify(
								'zig installed. Restart Neovim'
									.. ' to compile treesitter parsers.',
								vim.log.levels.WARN
							)
						end)
					end,
				}
			)
		end,
	},
	{
		'nvim-treesitter/nvim-treesitter-context',
		dependencies = { 'nvim-treesitter/nvim-treesitter' },
	},
}
