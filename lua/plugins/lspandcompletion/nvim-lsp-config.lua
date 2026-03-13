local capabilities = require('cmp_nvim_lsp').default_capabilities()
return {
	{
		'neovim/nvim-lspconfig',
		dependencies = { 'williamboman/mason.nvim', "folke/neodev.nvim"},
		ft = { 'rust', 'c', 'cpp', 'cs', 'toml', 'lua' },
		-- event = { "BufReadPre", "BufNewFile" }, -- <<< this ensures the plugin loads for all files
		lazy = false,
		init = function ()
			vim.keymap.set('n', 'gl', vim.diagnostic.open_float)
			vim.keymap.set('n', 'dn', vim.diagnostic.goto_prev)
			vim.keymap.set('n', 'dN', vim.diagnostic.goto_next)
			vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist)
		end,
		config = function ()

			local root_file = vim.fs.find(
				function(name)
					return name == ".sln" or name == ".git"
				end,
				{ upward = true, type = "file", stop = vim.loop.os_homedir() }
			)
			local root_dir = vim.fs.dirname(root_file[1]);

			vim.lsp.config('omnisharp', {
				-- cmd = { "omnisharp" },
			 	-- filetypes = { "cs", },
				root_markers = { '.git', '.csproj', '.sln' },
				-- root_dir = root_dir,
			 -- 	init_options = {
				-- 	AutomaticWorkspaceInit = true
				-- },
			 -- 	on_attach = function(client, bufnr)
			 -- 		print("C# LSP attached")
			 -- 	end,
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
