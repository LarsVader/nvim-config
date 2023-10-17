return {
	{
		"mfussenegger/nvim-dap",
		dependencies = { 'williamboman/mason.nvim' },
		build = {
			':MasonInstall netcoredbg',
		},
		lazy = true,
		keys = {
			{'<F5>', function() require('dap').continue() end},
			{'<F10>', function() require('dap').step_over() end},
			{'<F11>', function() require('dap').step_into() end},
			{'<F12>', function() require('dap').step_out() end},
			{'<Leader>db', function() require('dap').toggle_breakpoint() end},
			{'<Leader>dB', function() require('dap').set_breakpoint() end},
			{'<Leader>dlb', function() require('dap').set_breakpoint(nil, nil, vim.fn.input('Log point message: ')) end},
			{'<Leader>dr', function() require('dap').repl.open() end},
			{'<Leader>dl', function() require('dap').run_last() end},
		},
		config = function()

			local masonpath = vim.fn.stdpath('data') .. '/mason';
			local dap = require('dap');

			dap.adapters.coreclr = {
				type = 'executable',
				command = masonpath .. '/packages/netcoredbg/netcoredbg/netcoredbg.exe',
				args = {'--interpreter=vscode'}
			}

			local extension_path = vim.env.HOME .. '/.vscode/extensions/vadimcn.vscode-lldb-1.9.2/'
			local codelldb_path = extension_path .. 'adapter/codelldb'

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

			local function get_dll()
				return coroutine.create(function(dap_run_co)
					local items= vim.fn.globpath(vim.fn.getcwd(), 'DentalCAD/DentalCADApp/bin/x64/**/**/DentalCADApp.exe', 0,1)
					local opts = {
						format_item = function(path)
							return path -- vim.fn.fnamemodify(path, ':.')
						end,
					}
					local function cont(choice)
						if choice == nil then
							return nil
						else
							coroutine.resume(dap_run_co, choice)
						end
					end

					vim.ui.select(items, opts, cont)
				end)
			end

			local function get_pid()
				return coroutine.create(function(luaisstrange)
					local function cont(choice)
						if choice == nil then
							return nil
						else
							coroutine.resume(luaisstrange, choice)
						end
					end
					vim.ui.input({}, cont)
				end)
			end

			dap.configurations.cs = {
				{
					type = "coreclr",
					name = "launch - netcoredbg",
					request = "launch",
					program = get_dll(),
				},
				{
					type = "coreclr",
					name = "attach - netcoredbg",
					request = "attach",
					processId = get_pid(),
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
				{
					name = 'Attach',
					type = 'codelldb',
					request = 'attach',
					pid = get_pid(),
					cwd = '${workdspaceFolder}',
					stopOnEntry = false,
				}
			}

			dap.configurations.c = dap.configurations.cpp
			dap.configurations.rust = dap.configurations.cpp

			vim.keymap.set({'n', 'v'}, '<Leader>dh', function()
				require('dap.ui.widgets').hover()
			end)
			vim.keymap.set({'n', 'v'}, '<Leader>dp', function()
				require('dap.ui.widgets').preview()
			end)
			vim.keymap.set('n', '<Leader>df', function()
				local widgets = require('dap.ui.widgets')
				widgets.centered_float(widgets.frames)
			end)
			vim.keymap.set('n', '<Leader>ds', function()
				local widgets = require('dap.ui.widgets')
				widgets.centered_float(widgets.scopes)
			end)
		end
	}
}
