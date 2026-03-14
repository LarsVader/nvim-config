local capabilities = require('cmp_nvim_lsp').default_capabilities()
return {
	{
		'neovim/nvim-lspconfig',
		dependencies = { 'williamboman/mason.nvim', "folke/neodev.nvim"},
		ft = { 'rust', 'c', 'cpp', 'cs', 'toml', 'lua' },
		init = function ()
			vim.keymap.set('n', 'gl', vim.diagnostic.open_float, { desc = "Show line diagnostics" })
			vim.keymap.set('n', 'dn', vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
			vim.keymap.set('n', 'dN', vim.diagnostic.goto_next, { desc = "Next diagnostic" })
			vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = "Send diagnostics to location list" })
		end,
		config = function ()
			vim.lsp.config('omnisharp', {
				root_markers = { '.git', '.csproj', '.sln' },
			})
			vim.lsp.enable('omnisharp')

			vim.api.nvim_create_autocmd('LspAttach', {
				group = vim.api.nvim_create_augroup('UserLspConfig', {}),
				callback = function(ev)
					vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, { desc='goto declaration', buffer=ev.buf } )
					vim.keymap.set('n', 'gd', vim.lsp.buf.definition, { desc='goto definition', buffer=ev.buf  })
					vim.keymap.set('n', 'K', vim.lsp.buf.hover, { desc='hover help', buffer=ev.buf  })
					vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, { desc='goto implementation', buffer=ev.buf  })
					vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, { desc='hover signature help', buffer=ev.buf  })
					vim.keymap.set('n', 'gt', vim.lsp.buf.type_definition, { desc='goto type definition', buffer=ev.buf  })
					vim.keymap.set('n', '<F2>', vim.lsp.buf.rename, { desc='refactor rename', buffer=ev.buf  })
					vim.keymap.set({ 'n', 'v' }, '<C-space>', vim.lsp.buf.code_action, { desc='show code actions', buffer=ev.buf  })
					vim.keymap.set('n', 'gr', vim.lsp.buf.references, { desc='list references', buffer=ev.buf })
					vim.keymap.set('n', '<F3>',
						function()
							vim.lsp.buf.format { async = true }
						end, { desc='autoformat current file', buffer=ev.buf })
				end,
			})
		end,
	}
}
