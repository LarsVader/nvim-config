return {
	{
		'seblyng/roslyn.nvim',
		ft = 'cs',
		dependencies = { 'williamboman/mason.nvim', 'folke/noice.nvim' },
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

			-- Refresh diagnostics on all open cs buffers once the solution
			-- has loaded — the first buffer opened before the solution loaded
			-- will have stale diagnostics (all usings flagged as unnecessary).
			vim.api.nvim_create_autocmd("User", {
				group = vim.api.nvim_create_augroup("RoslynDiagnosticRefresh", {}),
				pattern = "RoslynInitialized",
				callback = function()
					vim.lsp.diagnostic._refresh()
				end,
			})

			-- Noice renders Roslyn's hover content as markdown. Roslyn does
			-- NOT wrap the C# signature in a code fence, so the first line
			-- comes out dim with visible `\<` / `\>` escapes. Fencing the
			-- signature as ```csharp triggers an off-by-one in noice's
			-- NoiceText.syntax range math (raises Index out of bounds in
			-- vim.treesitter._range when a code block is followed by more
			-- markdown), so instead we replicate what noice's signature_help
			-- does: append the signature lines raw and stamp ft-syntax on
			-- them with NoiceText.syntax(ft, n).
			local ok_noice, noice_hover = pcall(require, "noice.lsp.hover")
			if ok_noice then
				-- Stash the unmodified original once so re-running this config
				-- (e.g. :Lazy reload) re-wraps the original, never our wrapper.
				if not noice_hover.__roslyn_original then
					noice_hover.__roslyn_original = noice_hover.on_hover
				end
				local Docs = require("noice.lsp.docs")
				local Markdown = require("noice.text.markdown")
				local renderer = require("lars.roslyn_hover_render")
				local original = noice_hover.__roslyn_original

				local function render_cs_hover(content_str, ft)
					local message = Docs.get("hover")
					if message:focus() then
						return true
					end
					if not renderer.render(message, content_str, ft) then
						return false
					end
					Docs.show(message)
					return true
				end

				local hover_stack = require("lars.roslyn_hover_stack")

				noice_hover.on_hover = function(err, result, ctx, ...)
					-- Track every successful hover invocation so <C-o> in
					-- the popup can pop back to the previous one.
					if result and result.contents and ctx
						and vim.api.nvim_buf_is_valid(ctx.bufnr) then
						hover_stack.set_current(result, ctx)
					end

					if not (result and result.contents and ctx
						and vim.api.nvim_buf_is_valid(ctx.bufnr)
						and vim.bo[ctx.bufnr].filetype == "cs") then
						return original(err, result, ctx, ...)
					end

					local c = result.contents
					local content_str
					if type(c) == "string" then
						content_str = c
					elseif type(c) == "table" and c.kind == "markdown" and type(c.value) == "string" then
						content_str = c.value
					end

					if not content_str then
						return original(err, result, ctx, ...)
					end

					local ok, handled = pcall(render_cs_hover, content_str, "cs")
					if ok and handled then
						return
					end
					return original(err, result, ctx, ...)
				end

				-- Bind <C-o> / <C-i> inside any noice markdown popup for
				-- hover history navigation. Markdown.keys is the natural
				-- hook — noice calls it whenever it lays a markdown
				-- syntax decorator on a buffer, and that buffer IS the
				-- popup.
				if not Markdown.__roslyn_back_patched then
					Markdown.__roslyn_back_patched = true
					local original_keys = Markdown.keys
					Markdown.keys = function(buf)
						original_keys(buf)
						if vim.b[buf].roslyn_nav_mapped then
							return
						end
						vim.b[buf].roslyn_nav_mapped = true
						vim.keymap.set("n", "<C-o>", function()
							hover_stack.go_back()
						end, { buffer = buf, silent = true, desc = "hover: go back" })
						vim.keymap.set("n", "<C-i>", function()
							hover_stack.go_forward()
						end, { buffer = buf, silent = true, desc = "hover: go forward" })
					end
				end
			end
		end,
	},
}
