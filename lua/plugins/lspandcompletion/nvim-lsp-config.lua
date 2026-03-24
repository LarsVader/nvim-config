local capabilities = require('cmp_nvim_lsp').default_capabilities()
return {
	{
		'neovim/nvim-lspconfig',
		dependencies = { 'williamboman/mason.nvim', "folke/neodev.nvim"},
		ft = { 'rust', 'c', 'cpp', 'toml', 'lua' },
		init = function ()
			vim.keymap.set('n', 'gl', vim.diagnostic.open_float, { desc = "Show line diagnostics" })
			vim.keymap.set('n', 'dn', vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
			vim.keymap.set('n', 'dN', vim.diagnostic.goto_next, { desc = "Next diagnostic" })
			vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = "Send diagnostics to location list" })

			-- LspAttach keymaps — registered eagerly so they apply to ALL
			-- LSP servers (lspconfig, roslyn.nvim, etc.), not just the ones
			-- managed by nvim-lspconfig.
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
					vim.keymap.set({ 'n', 'v' }, '<C-.>', vim.lsp.buf.code_action, { desc='show code actions', buffer=ev.buf  })
					vim.keymap.set('n', 'gr', vim.lsp.buf.references, { desc='list references', buffer=ev.buf })
					vim.keymap.set('n', '<F3>',
						function()
							vim.lsp.buf.format { async = true }
						end, { desc='autoformat current file', buffer=ev.buf })
				end,
			})
		end,
		config = function ()
			local lspconfig = require('lspconfig')

			-- Lazy-load race fix: this config runs in response to a FileType
			-- event, but lspconfig.setup() registers its own FileType autocmd
			-- which missed the event that triggered us. Re-attach for any
			-- buffers that already have a matching filetype.
			local function reattach_buffers()
				for _, buf in ipairs(vim.api.nvim_list_bufs()) do
					if vim.api.nvim_buf_is_loaded(buf) then
						local ft = vim.bo[buf].filetype
						if ft ~= "" then
							vim.api.nvim_exec_autocmds("FileType", { buffer = buf })
						end
					end
				end
			end

			-- Add lspconfig.setup() calls for non-Roslyn servers here
			-- (Roslyn/C# is handled by roslyn.nvim)

			reattach_buffers()
		end,
	}
}
