local _mixed_debug -- set by config(), called by lazy key

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
			{'<Leader>dM', function()
				require('dap')
				if _mixed_debug then _mixed_debug() end
			end, desc = "DAP mixed C#/C++ debug"},
		},
		config = function()

			local masonpath = vim.fn.stdpath('data') .. '/mason';
			local dap = require('dap');
			dap.set_log_level('TRACE');

			dap.adapters.coreclr = {
				type = 'executable',
				command = masonpath .. '/packages/netcoredbg/netcoredbg/netcoredbg.exe',
				args = {'--interpreter=vscode'}
			}

			-- Set to true to use local dev build instead of Mason-installed version
			local mixdbg_dev = false
			dap.adapters.mixdbg = {
				type = 'executable',
				command = mixdbg_dev
					and 'D:/Lars/Dokumente/coding/CLRApp3'
						.. '/mixdbg/src/bin/Debug'
						.. '/net10.0/win-x64/MixDbg.exe'
					or masonpath .. '/packages/mixdbg/MixDbg.exe',
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

			-- Cache the resolved DLL path so both `program` and
			-- `cwd` use the same value without running globs twice.
			local cs_dll_cache = nil

			-- Returns the best .NET DLL to debug, or nil if none
			-- found. Uses shallow fixed-depth globs (not **) to
			-- stay fast on Windows .NET trees with large
			-- bin/obj/.git directories.
			-- Covers two output layouts:
			--   Standard:  bin/Debug/{tfm}/Name.dll
			--   WinUI/SDK: bin/{Platform}/Debug/{tfm}/Name.dll
			local function find_cs_dll()
				local cwd = vim.fn.getcwd():gsub('\\', '/')
				-- Depth 1-3 only — never recurses into bin/obj/.git
				local csprojs = {}
				for _, pat in ipairs({
					'/*.csproj',
					'/*/*.csproj',
					'/*/*/*.csproj',
				}) do
					for _, p in ipairs(vim.fn.glob(
						cwd .. pat, false, true)) do
						table.insert(csprojs, p)
					end
				end
				local dlls = {}
				for _, csproj in ipairs(csprojs) do
					local name = vim.fn.fnamemodify(
						csproj, ':t:r')
					-- Skip test projects (*.Tests / *.Test)
					if not name:match('Tests?$') then
						local dir = vim.fn.fnamemodify(
							csproj, ':h'):gsub('\\', '/')
						-- Standard:  bin/Debug/{tfm}/
						-- WinUI/SDK: bin/{platform}/Debug/{tfm}/
						for _, pat in ipairs({
							dir .. '/bin/Debug/*/'
								.. name .. '.dll',
							dir .. '/bin/*/Debug/*/'
								.. name .. '.dll',
						}) do
							for _, d in ipairs(
								vim.fn.glob(pat, false, true)) do
								table.insert(dlls, d)
							end
						end
					end
				end
				-- Fall back to Release / any config
				if #dlls == 0 then
					for _, csproj in ipairs(csprojs) do
						local name = vim.fn.fnamemodify(
							csproj, ':t:r')
						if not name:match('Tests?$') then
							local dir = vim.fn.fnamemodify(
								csproj, ':h'):gsub('\\', '/')
							for _, pat in ipairs({
								dir .. '/bin/*/*/'
									.. name .. '.dll',
								dir .. '/bin/*/*/*/'
									.. name .. '.dll',
							}) do
								for _, d in ipairs(
									vim.fn.glob(
										pat, false, true)) do
									table.insert(dlls, d)
								end
							end
						end
					end
				end
				if #dlls == 0 then
					return nil
				end
				-- Auto-pick newest — no blocking UI
				-- in dap coroutine
				table.sort(dlls, function(a, b)
					return vim.fn.getftime(a)
						> vim.fn.getftime(b)
				end)
				return dlls[1]
			end

			-- Detect WinUI: check if the output dir
			-- contains Windows App SDK bootstrapper DLLs.
			local function is_winui(dll_path)
				if not dll_path then
					return false
				end
				local dir = vim.fn.fnamemodify(
					dll_path, ':h'):gsub('\\', '/')
				local marker = vim.fn.glob(
					dir .. '/Microsoft.WindowsAppRuntime'
						.. '.Bootstrap*.dll',
					false, true)
				return #marker > 0
			end

			-- Find PID of a running process by image name.
			-- Returns the first match or nil.
			local function find_pid(image_name)
				local h = io.popen(
					'tasklist /FI "IMAGENAME eq '
					.. image_name
					.. '" /FO CSV /NH 2>NUL')
				if not h then
					return nil
				end
				local out = h:read('*a')
				h:close()
				for pid in out:gmatch(
					'"[^"]-","(%d+)"') do
					return tonumber(pid)
				end
				return nil
			end

			dap.configurations.cs = {
				-- Normal .NET apps (console, ASP.NET, etc.)
				{
					type = "coreclr",
					name = "launch - netcoredbg",
					request = "launch",
					program = function()
						cs_dll_cache = find_cs_dll()
						if cs_dll_cache then
							return cs_dll_cache
						end
						vim.notify(
							'No .NET DLL found'
								.. ' — build first.',
							vim.log.levels.WARN)
						return vim.fn.input(
							'Path to dll: ',
							vim.fn.getcwd()
								.. '/bin/Debug/',
							'file')
					end,
					-- Set cwd to the DLL's output dir so
					-- self-contained runtime DLLs are found.
					cwd = function()
						local dll = cs_dll_cache
							or find_cs_dll()
						if dll then
							return vim.fn.fnamemodify(
								dll, ':h')
						end
						return vim.fn.getcwd()
					end,
				},
				-- WinUI / Windows App SDK apps: must launch
				-- the native .exe host then attach, because
				-- netcoredbg cannot launch WinUI apps via
				-- `dotnet exec` (the bootstrap is native).
				{
					type = "coreclr",
					name = "launch & attach - WinUI",
					request = "attach",
					processId = function()
						local dll = cs_dll_cache
							or find_cs_dll()
						if not dll then
							vim.notify(
								'No .NET output found'
									.. ' — build first.',
								vim.log.levels.WARN)
							return require('dap.utils')
								.pick_process()
						end
						local exe = dll:gsub(
							'%.dll$', '.exe')
						if vim.fn.filereadable(exe) ~= 1 then
							vim.notify(
								'No .exe found next to '
									.. dll,
								vim.log.levels.WARN)
							return require('dap.utils')
								.pick_process()
						end
						local img = vim.fn.fnamemodify(
							exe, ':t')
						-- Kill leftover instance if any
						local old = find_pid(img)
						if old then
							os.execute(
								'taskkill /PID '
								.. old .. ' /F >NUL 2>&1')
							vim.wait(500)
						end
						-- Launch the native exe host
						vim.fn.jobstart(
							{ exe },
							{ detach = true })
						-- Give it time to start .NET runtime
						vim.wait(2000)
						local pid = find_pid(img)
						if pid then
							return pid
						end
						vim.notify(
							'Could not find running '
								.. img,
							vim.log.levels.WARN)
						return require('dap.utils')
							.pick_process()
					end,
				},
			}

			dap.configurations.cpp = {
				{
					name = "Launch file",
					type = "codelldb",
					request = "launch",
					program = function()
						return vim.fn.input(
							'Path to executable: ',
							vim.fn.getcwd() .. '/',
							'file')
					end,
					cwd = '${workspaceFolder}',
					stopOnEntry = false,
				},
				{
					name = "Attach to process",
					type = "codelldb",
					request = "attach",
					pid = function()
						return require('dap.utils')
							.pick_process()
					end,
				},
				{
					name = "Launch & attach - .NET native",
					type = "codelldb",
					request = "attach",
					pid = function()
						-- Find the .NET exe the same way
						-- the C# config finds the DLL.
						local dll = find_cs_dll()
						if not dll then
							vim.notify(
								'No .NET DLL found'
									.. ' — build first.',
								vim.log.levels.WARN)
							return require('dap.utils')
								.pick_process()
						end
						local exe = dll:gsub(
							'%.dll$', '.exe')
						if vim.fn.filereadable(exe) ~= 1
						then
							vim.notify(
								'No .exe found next to '
									.. dll,
								vim.log.levels.WARN)
							return require('dap.utils')
								.pick_process()
						end
						local img = vim.fn.fnamemodify(
							exe, ':t')
						-- Kill leftover instance
						local old = find_pid(img)
						if old then
							os.execute(
								'taskkill /PID '
								.. old
								.. ' /F >NUL 2>&1')
							vim.wait(500)
						end
						-- Launch the app
						vim.fn.jobstart(
							{ exe },
							{ detach = true })
						vim.wait(2000)
						local pid = find_pid(img)
						if pid then
							return pid
						end
						vim.notify(
							'Could not find running '
								.. img,
							vim.log.levels.WARN)
						return require('dap.utils')
							.pick_process()
					end,
				},
			}

			-- Also register mixdbg config for C# files
			-- so it appears in the picker for both languages.
			local mixdbg_config = {
				name = "Mixed C#/C++ (mixdbg)",
				type = "mixdbg",
				request = "launch",
				program = function()
					local dll = find_cs_dll()
					if dll then
						return dll:gsub('%.dll$', '.exe')
					end
					return vim.fn.input(
						'Path to executable: ',
						vim.fn.getcwd() .. '/',
						'file')
				end,
				cwd = function()
					local dll = find_cs_dll()
					if dll then
						return vim.fn.fnamemodify(
							dll, ':h')
					end
					return vim.fn.getcwd()
				end,
			}
			table.insert(dap.configurations.cpp, mixdbg_config)
			table.insert(dap.configurations.cs, mixdbg_config)

			dap.configurations.c = dap.configurations.cpp
			dap.configurations.rust = dap.configurations.cpp

			-- Launch .NET app and attach a debugger.
			-- Windows only allows one debug port holder,
			-- so C# and C++ must be separate sessions.
			-- This picker lets you choose which layer to
			-- debug without leaving Neovim.
			local function launch_mixed_debug()
				local dll = find_cs_dll()
				if not dll then
					vim.notify(
						'No .NET DLL found'
							.. ' — build first.',
						vim.log.levels.WARN)
					return
				end
				local exe = dll:gsub(
					'%.dll$', '.exe')
				if vim.fn.filereadable(exe) ~= 1 then
					vim.notify(
						'No .exe found next to '
							.. dll,
						vim.log.levels.WARN)
					return
				end
				local img = vim.fn.fnamemodify(
					exe, ':t')
				vim.ui.select(
					{ 'C# (.NET)', 'C++ (native)' },
					{ prompt = 'Debug layer: ' },
					function(choice)
						if not choice then return end
						-- Terminate existing session
						if dap.session() then
							dap.terminate()
							vim.wait(1000)
						end
						-- Kill leftover app instance
						local old = find_pid(img)
						if old then
							os.execute(
								'taskkill /PID '
								.. old
								.. ' /F >NUL 2>&1')
							vim.wait(500)
						end
						-- Launch the app
						vim.fn.jobstart(
							{ exe },
							{ detach = true })
						vim.wait(2000)
						local pid = find_pid(img)
						if not pid then
							vim.notify(
								'Could not find '
								.. img,
								vim.log.levels.WARN)
							return
						end
						if choice == 'C# (.NET)' then
							dap.run({
								type = "coreclr",
								name = "C# (.NET)",
								request = "attach",
								processId = pid,
							})
						else
							dap.run({
								type = "codelldb",
								name = "C++ (native)",
								request = "attach",
								pid = pid,
								sourceLanguages = {
									"cpp", "c",
								},
							})
						end
					end)
			end

			_mixed_debug = launch_mixed_debug

			-- Force-load dapui when a session starts so its event
			-- listeners are active, even if the UI isn't visible yet.
			dap.listeners.after.event_initialized["load_dapui"] = function()
				pcall(require, "dapui")
			end

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
