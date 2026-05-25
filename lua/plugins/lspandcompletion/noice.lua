return {
	"folke/noice.nvim",
	event = "VeryLazy",
	opts = {
		-- add any options here
	},
	dependencies = {
		-- if you lazy-load any plugin below, make sure to add proper `module="..."` entries
		"MunifTanjim/nui.nvim",
		-- OPTIONAL:
		--   `nvim-notify` is only needed, if you want to use the notification view.
		--   If not available, we use `mini` as the fallback
		"rcarriga/nvim-notify",
	},
	config = function()
		-- Press K (or gx) on a PascalCase / dotted identifier inside the
		-- hover popup to re-render the popup with the referenced symbol's
		-- hover. The source-window cursor stays put — only the popup
		-- content swaps. Flow: workspace/symbol → first exact match →
		-- textDocument/hover at its location → noice on_hover (which
		-- replaces the current popup). Falls back to telescope's
		-- workspace-symbol picker if no exact match exists.
		local function find_symbol(name)
			if type(name) ~= "string" or name == "" then
				return
			end

			local function fallback_to_telescope()
				vim.schedule(function()
					local ok, builtin = pcall(require, "telescope.builtin")
					if ok then
						builtin.lsp_dynamic_workspace_symbols({ default_text = name })
					else
						vim.lsp.buf.workspace_symbol(name)
					end
				end)
			end

			-- Switch focus to the source window before we trigger the new
			-- hover. The source-buffer cursor stays where it is; only the
			-- *focused* window changes. This is what unblocks noice's
			-- on_hover — otherwise the existing popup is still the
			-- current window, message:focus() short-circuits, and the
			-- new content never renders.
			local prev_win = vim.fn.win_getid(vim.fn.winnr("#"))
			if prev_win == 0 or prev_win == vim.api.nvim_get_current_win() then
				return fallback_to_telescope()
			end
			vim.api.nvim_set_current_win(prev_win)
			local src_buf = vim.api.nvim_win_get_buf(prev_win)

			local clients = vim.lsp.get_clients({ bufnr = src_buf })
			if #clients == 0 then
				clients = vim.lsp.get_clients()
			end
			if #clients == 0 then
				return fallback_to_telescope()
			end
			local client = clients[1]

			client:request("workspace/symbol", { query = name }, function(err, result)
				if err or not result or vim.tbl_isempty(result) then
					return fallback_to_telescope()
				end

				local exact = vim.tbl_filter(function(s)
					return s.name == name
				end, result)
				if #exact == 0 then
					return fallback_to_telescope()
				end
				local target = exact[1]

				local uri = target.location and target.location.uri or target.uri
				local range = target.location and target.location.range or target.range
				if not uri or not range then
					return fallback_to_telescope()
				end

				local target_buf = vim.uri_to_bufnr(uri)
				if not vim.api.nvim_buf_is_loaded(target_buf) then
					vim.fn.bufload(target_buf)
				end

				local hover_params = {
					textDocument = { uri = uri },
					position = range.start,
				}
				client:request("textDocument/hover", hover_params, function(_, hover_result)
					if not (hover_result and hover_result.contents) then
						vim.notify("no hover for " .. name, vim.log.levels.INFO)
						return
					end
					local ctx = {
						bufnr = src_buf,
						method = "textDocument/hover",
						client_id = client.id,
					}
					-- Tell the stack this is a dive so it pushes the current
					-- hover before the new one becomes current.
					require("lars.roslyn_hover_stack").start_dive()
					require("noice.lsp.hover").on_hover(nil, hover_result, ctx)
					-- Auto-focus the new popup so K-diving can keep going
					-- without an extra <C-w>w. Defer so the view has time
					-- to mount its window.
					vim.defer_fn(function()
						local msg = require("noice.lsp.docs")._messages
							and require("noice.lsp.docs")._messages["hover"]
						if msg then
							pcall(function()
								msg:focus()
							end)
						end
					end, 80)
				end, src_buf)
			end, src_buf)
		end

		require("noice").setup({
			lsp = {
				-- override markdown rendering so that **cmp** and other plugins use **Treesitter**
				override = {
					["vim.lsp.util.convert_input_to_markdown_lines"] = true,
					["vim.lsp.util.stylize_markdown"] = true,
					["cmp.entry.get_documentation"] = true, -- requires hrsh7th/nvim-cmp
				},
			},
			markdown = {
				hover = {
					-- noice defaults
					["|(%S-)|"] = vim.cmd.help, -- vim help tags
					["%[.-%]%((%S-)%)"] = require("noice.util").open, -- markdown links
					-- PascalCase / dotted identifiers in doc-comment prose
					["([A-Z][%w_]*[%w_%.]+)"] = find_symbol,
				},
				highlights = {
					-- noice defaults
					["|%S-|"] = "@text.reference",
					["@%S+"] = "@parameter",
					["^%s*(Parameters:)"] = "@text.title",
					["^%s*(Return:)"] = "@text.title",
					["^%s*(See also:)"] = "@text.title",
					["{%S-}"] = "@parameter",
					-- Colour type-shaped names in doc-comment prose as @type:
					-- qualified names (`Foo.Bar`) and multi-camelCase identifiers
					-- (`NativeDebuggerModel`). Single PascalCase words at the
					-- start of a sentence ("Sets", "Uses") wouldn't have a second
					-- uppercase, so they're skipped.
					["%f[%w]([A-Z][%w_]*%.[%w_%.]+)"] = "@type",
					["%f[%w]([A-Z][%w_]-[A-Z][%w_]*)"] = "@type",
				},
			},
			-- you can enable a preset for easier configuration
			presets = {
				bottom_search = true, -- use a classic bottom cmdline for search
				command_palette = true, -- position the cmdline and popupmenu together
				long_message_to_split = true, -- long messages will be sent to a split
				inc_rename = false, -- enables an input dialog for inc-rename.nvim
				lsp_doc_border = true, -- add a border to hover docs and signature help
			},
		})
	end,
}
