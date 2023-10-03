return {
	'simrat39/rust-tools.nvim',
	enabled = false, -- is it really needed if lsp and debugger are properly set up? I don't think so therefore i will test a while with it diabled
	config = function ()
		local rt = require("rust-tools")

		local extension_path = vim.env.HOME .. '/.vscode/extensions/vadimcn.vscode-lldb-1.9.2/'
		-- local extension_path = vim.env.HOME .. '/.local/share/nvim/mason/packages/codelldb/extensions/lldb/'
		local codelldb_path = extension_path .. 'adapter/codelldb'
		local liblldb_path = extension_path .. 'lldb/lib/liblldb.so'


		local opts = {
			tools = { -- rust-tools options
				-- callback to execute once rust-analyzer is done initializing the workspace
				-- The callback receives one parameter indicating the `health` of the server: "ok" | "warning" | "error"
				on_initialized = nil,

				-- These apply to the default RustSetInlayHints command
				inlay_hints = {
					auto = true,
					only_current_line = false,
					show_parameter_hints = true,
					parameter_hints_prefix = "<- ",
					other_hints_prefix = "=> ",
					max_len_align = false,
					highlight = "Comment",
				},

				hover_actions = {
					auto_focus = true, -- important!! for example debugger popup when leader space on main
				},
			},

			-- all the opts to send to nvim-lspconfig
			-- these override the defaults set by rust-tools.nvim
			-- see https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#rust_analyzer
			server = {
				capabilities = require("cmp_nvim_lsp").default_capabilities(),
				standalone = true, -- necessary. otherwise c-space only works in main.rs and not in the modules (is that a bug?)
				on_attach = function(_, bufnr)
					vim.keymap.set("n", "<c-space>", rt.hover_actions.hover_actions, { buffer = bufnr})
					vim.keymap.set("n", "<leader>a", rt.code_action_group.code_action_group, {buffer = bufnr })
				end,
			}, -- rust-analyzer options

			dap = {
				adapter = require('rust-tools.dap').get_codelldb_adapter(
					codelldb_path, liblldb_path)
			},
		}

		rt.setup(opts)
	end,
}
