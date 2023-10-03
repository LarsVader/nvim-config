local capabilities = require('cmp_nvim_lsp').default_capabilities()
return {
	{
		'neovim/nvim-lspconfig',
		dependencies = { 'williamboman/mason.nvim' },
		ft = { 'rust', 'c', 'cpp', 'cs', 'toml', 'lua' },
		init = function ()
			vim.keymap.set('n', 'gl', vim.diagnostic.open_float)
			vim.keymap.set('n', 'dn', vim.diagnostic.goto_prev)
			vim.keymap.set('n', 'dN', vim.diagnostic.goto_next)
			vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist)
		end,
		config = function ()
			local lspconfig = require('lspconfig')
			lspconfig.rust_analyzer.setup {
				settings = {
					['rust-analyzer'] = {},
				},
				capabilities = capabilities,
			}
			lspconfig.lua_ls.setup({
				settings = {
					Lua = {
						runtime = { version = 'LuaJIT' },
						diagnostics = { globals = {'vim'}, },
						workspace = { library = { vim.env.VIMRUNTIME, } }
					}
				},
				capabilities = capabilities,
			})
			vim.api.nvim_create_autocmd('LspAttach', {
				group = vim.api.nvim_create_augroup('UserLspConfig', {}),
				callback = function(ev)
					vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, { desc='goto declaration' } )
					vim.keymap.set('n', 'gd', vim.lsp.buf.definition, { desc='goto definition' })
					vim.keymap.set('n', 'K', vim.lsp.buf.hover, { desc='hover help' })
					vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, { desc='goto implementation' })
					vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, { desc='hover signature help' })
					vim.keymap.set('n', 'gt', vim.lsp.buf.type_definition, { desc='goto type definition' })
					vim.keymap.set('n', '<F2>', vim.lsp.buf.rename, { desc='refactor rename' })
					vim.keymap.set({ 'n', 'v' }, '<C-space>', vim.lsp.buf.code_action, { desc='show code actions' })
					vim.keymap.set('n', 'gr', vim.lsp.buf.references, { desc='list references'})
					vim.keymap.set('n', '<F3>', function()
						vim.lsp.buf.format { async = true }
					end, { desc='autoformat current file'})
				end,
			})
		end,
	}
}
