return {
	{
		"mfussenegger/nvim-dap",
		lazy = true,
		keys = {
			{'<F5>', function() require('dap').continue() end, desc = "DAP continue"},
			{'<F10>', function() require('dap').step_over() end, desc = "DAP step over"},
			{'<F11>', function() require('dap').step_into() end, desc = "DAP step into"},
			{'<F12>', function() require('dap').step_out() end, desc = "DAP step out"},
			{'<Leader>db', function() require('dap').toggle_breakpoint() end, desc = "DAP toggle breakpoint"},
			{'<Leader>dB', function() require('dap').set_breakpoint() end, desc = "DAP set conditional breakpoint"},
			{'<Leader>dlb', function() require('dap').set_breakpoint(nil, nil, vim.fn.input('Log point message: ')) end, desc = "DAP set log point"},
			{'<Leader>dr', function() require('dap').repl.open() end, desc = "DAP open REPL"},
			{'<Leader>dl', function() require('dap').run_last() end, desc = "DAP re-run last session"},
		},
		config = function()

			local masonpath = vim.fn.stdpath('data') .. '/mason';
			local dap = require('dap');

			dap.adapters.coreclr = {
				type = 'executable',
				command = masonpath .. '/packages/netcoredbg/netcoredbg/netcoredbg.exe',
				args = {'--interpreter=vscode'}
			}

			local codelldb_path = masonpath .. '/packages/codelldb/extension/adapter/codelldb'

			dap.adapters.codelldb = {
				type = 'server',
				port = "${port}",
				executable = {
					command = codelldb_path,
					args = {"--port", "${port}"},
					-- On windows you may have to uncomment this:
					-- detached = false,
				}
			}

			dap.configurations.cs = {
				{
					type = "coreclr",
					name = "launch - netcoredbg",
					request = "launch",
					program = function()
						return vim.fn.input('Path to dll', vim.fn.getcwd() .. '/bin/Debug/', 'file')
					end,
				},
			}

			dap.configurations.cpp = {
				{
					name = "Launch file",
					type = "codelldb",
					request = "launch",
					program = function()
						return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
					end,
					cwd = '${workspaceFolder}',
					stopOnEntry = false,
				},
			}

			dap.configurations.c = dap.configurations.cpp
			dap.configurations.rust = dap.configurations.cpp

			vim.keymap.set({'n', 'v'}, '<Leader>dh', function()
				require('dap.ui.widgets').hover()
			end, { desc = "DAP hover value" })
			vim.keymap.set({'n', 'v'}, '<Leader>dp', function()
				require('dap.ui.widgets').preview()
			end, { desc = "DAP preview value" })
			vim.keymap.set('n', '<Leader>df', function()
				local widgets = require('dap.ui.widgets')
				widgets.centered_float(widgets.frames)
			end, { desc = "DAP show stack frames" })
			vim.keymap.set('n', '<Leader>ds', function()
				local widgets = require('dap.ui.widgets')
				widgets.centered_float(widgets.scopes)
			end, { desc = "DAP show scopes" })
		end
	}
}
