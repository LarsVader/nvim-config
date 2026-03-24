return {
	{
		'seblyng/roslyn.nvim',
		ft = 'cs',
		dependencies = { 'williamboman/mason.nvim' },
		opts = {
			filewatching = "roslyn",
		},
		config = function(_, opts)
			require('roslyn').setup(opts)

			-- Override LSP-level settings via vim.lsp.config (merged with
			-- the defaults from roslyn.nvim's lsp/roslyn.lua)
			vim.lsp.config('roslyn', {
				capabilities = require('cmp_nvim_lsp').default_capabilities(),
				settings = {
					["csharp|inlay_hints"] = {
						csharp_enable_inlay_hints_for_implicit_object_creation = true,
						csharp_enable_inlay_hints_for_implicit_variable_types = true,
						csharp_enable_inlay_hints_for_lambda_parameter_types = true,
						csharp_enable_inlay_hints_for_types = true,
						dotnet_enable_inlay_hints_for_indexer_parameters = true,
						dotnet_enable_inlay_hints_for_literal_parameters = true,
						dotnet_enable_inlay_hints_for_object_creation_parameters = true,
						dotnet_enable_inlay_hints_for_other_parameters = true,
						dotnet_enable_inlay_hints_for_parameters = true,
						dotnet_suppress_inlay_hints_for_parameters_that_differ_only_by_suffix = true,
						dotnet_suppress_inlay_hints_for_parameters_that_match_argument_name = true,
						dotnet_suppress_inlay_hints_for_parameters_that_match_method_intent = true,
					},
					["csharp|code_lens"] = {
						dotnet_enable_references_code_lens = true,
						dotnet_enable_tests_code_lens = true,
					},
				},
			})

			-- Lazy-load race fix: plugin/roslyn.lua calls vim.lsp.enable("roslyn")
			-- which registers a FileType autocmd, but the cs FileType event that
			-- triggered this lazy load has already fired. Re-trigger for existing
			-- cs buffers so the server attaches.
			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "cs" then
					vim.api.nvim_exec_autocmds("FileType", { buffer = buf })
				end
			end

			-- Progress popup: show while Roslyn is indexing the solution.
			-- Only on the initial attach (before RoslynInitialized fires).
			local notify = require("lars.dispatch-notify")
			local group = vim.api.nvim_create_augroup("RoslynProgress", {})
			local initialized = false

			vim.api.nvim_create_autocmd("LspAttach", {
				group = group,
				callback = function(ev)
					local client = vim.lsp.get_client_by_id(ev.data.client_id)
					if client and client.name == "roslyn" and not initialized then
						notify.show("Roslyn indexing", {
							is_running = function()
								return not initialized
							end,
							poll_interval = 400,
						})
					end
				end,
			})

			vim.api.nvim_create_autocmd("User", {
				group = group,
				pattern = "RoslynInitialized",
				callback = function()
					initialized = true
					notify.close()
				end,
			})
		end,
	},
}
