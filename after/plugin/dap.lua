-- this is only required because of visual studio code installation.
-- Otherwise the default config_setup should work where handlers is just set to {}
local extension_path = vim.env.HOME .. '/.vscode/extensions/vadimcn.vscode-lldb-1.9.2/'
local codelldb_path = extension_path .. 'adapter/codelldb'
local liblldb_path = extension_path .. 'lldb/lib/liblldb.so'

require ('mason-nvim-dap').setup({
    ensure_installed = {'codelldb', 'netcoredbg',},
	automatic_installation = true,
    handlers = {
        function(config)
          require('mason-nvim-dap').default_setup(config)
        end,
        codelldb = function(config)
            config.adapters = {
	            type = "server",
				port = '${port}',
				host = "127.0.0.1",
				executable = {
					command = codelldb_path,
					args = { "--liblldb", liblldb_path, "--port", "${port}" },
				}
            }
            require('mason-nvim-dap').default_setup(config) -- don't forget this!
        end,
    },
})

local dap, dapui = require("dap"), require("dapui")
dapui.setup()

dap.listeners.after.event_initialized["dapui_config"] = function()
  dapui.open()
end
dap.listeners.before.event_terminated["dapui_config"] = function()
  dapui.close()
end
dap.listeners.before.event_exited["dapui_config"] = function()
  dapui.close()
end
