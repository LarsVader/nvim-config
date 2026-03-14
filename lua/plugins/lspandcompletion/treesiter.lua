return {
	{
		"nvim-treesitter/nvim-treesitter",
		build = function()
			local has_compiler = vim.fn.executable('cc') == 1
				or vim.fn.executable('gcc') == 1
				or vim.fn.executable('clang') == 1
				or vim.fn.executable('cl') == 1
				or vim.fn.executable('zig') == 1
			if not has_compiler and vim.fn.has('win32') == 1 then
				vim.notify('No C compiler found. Installing zig via winget...', vim.log.levels.INFO)
				vim.fn.system('winget install -e --id zig.zig --accept-package-agreements --accept-source-agreements')
				vim.notify('zig installed. Restart Neovim for PATH to take effect, then run :Lazy build nvim-treesitter', vim.log.levels.WARN)
			else
				vim.cmd('TSUpdate')
			end
		end,
		config = function()
			local has_compiler = vim.fn.executable('cc') == 1
				or vim.fn.executable('gcc') == 1
				or vim.fn.executable('clang') == 1
				or vim.fn.executable('cl') == 1
				or vim.fn.executable('zig') == 1
			require('nvim-treesitter.configs').setup {
				ensure_installed = has_compiler and { 'cpp', 'rust', 'javascript', 'vimdoc', 'vim', 'lua', 'c_sharp' } or {},
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
		end,
	},
	{
		'nvim-treesitter/nvim-treesitter-context',
		dependencies = { 'nvim-treesitter/nvim-treesitter' },
	},
}
