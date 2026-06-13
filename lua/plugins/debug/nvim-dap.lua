local _mixed_debug -- set by config(), called by lazy key
local _exception_picker -- set by config(), called by lazy key
local _exception_typed -- set by config(), called by lazy key

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
			{'<Leader>de', function()
				require('dap')
				if _exception_typed then _exception_typed() end
			end, desc = "DAP break on CLR exception type"},
			{'<Leader>dE', function()
				require('dap')
				if _exception_picker then _exception_picker() end
			end, desc = "DAP exception breakpoint filters"},
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

			-- Attach variant: pick a running process (or
			-- enter a PID manually) and attach mixdbg.
			--
			-- Process picker behaviour, in priority order:
			--   1. If exactly one process matches the
			--      mixdbg testapp filter (WpfApp /
			--      LateCliWrapper / NativeLib host /
			--      CliWrapper-hosting exe), attach to it
			--      directly without prompting.
			--   2. If more than one matches, show only
			--      those in the picker.
			--   3. If zero match, fall back to the
			--      unfiltered picker.
			--   4. If dap.utils itself is unavailable,
			--      fall back to manual PID input.
			local function is_mixdbg_testapp(proc)
				local name = (proc.name or ''):lower()
				-- Match TestApp solution executables.
				-- WpfApp.exe is the primary integration
				-- target; LateCliWrapper.exe also runs
				-- as a standalone host in some scenarios.
				return name:find('wpfapp', 1, true) ~= nil
					or name:find('latecliwrapper', 1, true)
						~= nil
			end
			local mixdbg_attach_config = {
				name = "Mixed C#/C++ attach (mixdbg)",
				type = "mixdbg",
				request = "attach",
				pid = function()
					local ok, utils = pcall(
						require, 'dap.utils')
					if ok and utils.pick_process then
						-- Count matching testapp procs
						-- so we can skip the picker
						-- when there is exactly one.
						local procs = utils.get_processes({
							filter = is_mixdbg_testapp,
						}) or {}
						if #procs == 1 then
							vim.notify(
								'mixdbg: auto-attaching to '
									.. procs[1].name
									.. ' (pid '
									.. procs[1].pid
									.. ')',
								vim.log.levels.INFO)
							return procs[1].pid
						end
						if #procs > 1 then
							local picked =
								utils.pick_process({
									filter =
										is_mixdbg_testapp,
									prompt =
										'Select mixdbg '
										.. 'testapp: ',
								})
							if picked then
								return picked
							end
						else
							-- Zero matches: show
							-- unfiltered picker so the
							-- user can still attach
							-- to any other process.
							vim.notify(
								'mixdbg: no testapp '
									.. 'process found '
									.. '— showing all '
									.. 'processes.',
								vim.log.levels.INFO)
							local picked =
								utils.pick_process()
							if picked then
								return picked
							end
						end
					end
					-- Fallback: prompt for PID manually
					local s = vim.fn.input(
						'PID to attach to: ')
					local n = tonumber(s)
					if not n then
						vim.notify(
							'Invalid PID: '
								.. tostring(s),
							vim.log.levels.WARN)
						return require('dap')
							.ABORT
					end
					return n
				end,
			}
			table.insert(
				dap.configurations.cpp, mixdbg_attach_config)
			table.insert(
				dap.configurations.cs, mixdbg_attach_config)

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

			-- Multi-toggle picker over the live session's
			-- exceptionBreakpointFilters. nvim-dap's built-in
			-- prompt is a single vim.fn.input string — this
			-- replaces it with a vim.ui.select toggle loop.
			-- Filters and their meaning come from the adapter:
			-- netcoredbg advertises 'all' and 'user-unhandled',
			-- codelldb 'cpp_throw' / 'cpp_catch'.
			local function pick_exception_filters()
				local sess = dap.session()
				if not sess then
					vim.notify(
						'No active DAP session — '
							.. 'start the debugger first',
						vim.log.levels.WARN)
					return
				end
				local cap = sess.capabilities
					.exceptionBreakpointFilters
				if not cap or vim.tbl_isempty(cap) then
					vim.notify(
						'Adapter does not advertise '
							.. 'exception breakpoint filters',
						vim.log.levels.INFO)
					return
				end
				local state = {}
				for _, f in ipairs(cap) do
					state[f.filter] = f.default == true
				end
				local function build_items()
					local items = {}
					for _, f in ipairs(cap) do
						local mark = state[f.filter]
							and '[x]' or '[ ]'
						table.insert(items, {
							filter = f.filter,
							label = mark .. ' '
								.. (f.label or f.filter),
						})
					end
					table.insert(items, {
						action = 'apply', label = '-- Apply --',
					})
					table.insert(items, {
						action = 'cancel',
						label = '-- Cancel --',
					})
					return items
				end
				local function loop()
					vim.ui.select(build_items(), {
						prompt = 'Toggle exception filter:',
						format_item = function(item)
							return item.label
						end,
					}, function(choice)
						if not choice
							or choice.action == 'cancel' then
							return
						end
						if choice.action == 'apply' then
							local enabled = {}
							for f, on in pairs(state) do
								if on then
									table.insert(enabled, f)
								end
							end
							dap.set_exception_breakpoints(
								enabled)
							vim.notify(
								'Exception filters: '
									.. (#enabled == 0
										and '(none)'
										or table.concat(
											enabled, ', ')),
								vim.log.levels.INFO)
							return
						end
						state[choice.filter] =
							not state[choice.filter]
						vim.schedule(loop)
					end)
				end
				loop()
			end

			-- VS-style "break when these CLR types are thrown".
			-- Opens a snacks multi-select picker over the
			-- curated BCL list plus project-local exception
			-- types discovered async via ripgrep.
			--
			-- Selection is persisted per-cwd (see
			-- lars.dap_exception_state) and re-applied to every
			-- new session via the event_initialized listener
			-- below — so configuring before the session starts
			-- works exactly like Visual Studio's Exception
			-- Settings.
			local exc_state =
				require('lars.dap_exception_state')

			-- Send the stored types as a single filterOption to
			-- the session. netcoredbg parses `condition` by
			-- replacing commas with spaces and splitting on
			-- whitespace into a set of fully qualified type
			-- names — at runtime, a thrown exception breaks if
			-- its type is in that set.
			--
			-- Two adapter capabilities must hold before sending:
			--   1. supportsExceptionFilterOptions (DAP 1.43+)
			--   2. an 'all' entry in exceptionBreakpointFilters
			-- netcoredbg has both. Other adapters (codelldb's
			-- cpp_throw/cpp_catch, mixdbg, etc.) lack one or
			-- the other and we bail with an info notice
			-- instead of sending an invalid filterId.
			local function apply_exception_filter_options(sess)
				local types = exc_state.get()
				if #types == 0 then return end
				if not sess.capabilities
					.supportsExceptionFilterOptions then
					vim.notify(
						'Adapter does not support '
							.. 'filterOptions — stored CLR '
							.. 'type breakpoints not '
							.. 'applied',
						vim.log.levels.INFO)
					return
				end
				local adv = sess.capabilities
					.exceptionBreakpointFilters or {}
				local has_all = false
				for _, f in ipairs(adv) do
					if f.filter == 'all' then
						has_all = true
						break
					end
				end
				if not has_all then
					vim.notify(
						"Adapter does not advertise the "
							.. "'all' exception filter — "
							.. "stored CLR type breakpoints "
							.. "not applied",
						vim.log.levels.INFO)
					return
				end
				sess:request(
					'setExceptionBreakpoints',
					{
						filters = {},
						filterOptions = {
							{
								-- netcoredbg's DAP filter IDs
								-- are 'all' (any thrown) and
								-- 'user-unhandled'. Internal
								-- enum names like 'throw' are
								-- not valid here and trigger
								-- E_INVALIDARG.
								filterId = 'all',
								condition = table.concat(
									types, ','),
							},
						},
					},
					function(err)
						if err then
							vim.notify(
								'setExceptionBreakpoints'
									.. ' failed: '
									.. vim.inspect(err),
								vim.log.levels.ERROR)
						end
					end)
			end

			-- Re-apply stored CLR exception types on every
			-- session start. Runs after nvim-dap's own initial
			-- setExceptionBreakpoints (sent inside the
			-- internal event_initialized handler) so ours wins.
			dap.listeners.after.event_initialized
				["lars_apply_exc_filter_opts"] =
				function(session, _)
					if #exc_state.get() == 0 then return end
					apply_exception_filter_options(session)
				end

			local function break_on_clr_exception_type()
				require('lars.dap_exception_picker').open(
					exc_state.get(),
					function(types)
						exc_state.set(types)
						if #types == 0 then
							vim.notify(
								'Cleared CLR type '
									.. 'breakpoints',
								vim.log.levels.INFO)
						else
							vim.notify(
								'CLR type breakpoints '
									.. 'stored: '
									.. table.concat(
										types, ', '),
								vim.log.levels.INFO)
						end
						local sess = dap.session()
						if sess then
							apply_exception_filter_options(
								sess)
						end
					end)
			end

			_exception_picker = pick_exception_filters
			_exception_typed = break_on_clr_exception_type

			-- Force-load dapui when a session starts so its event
			-- listeners are active, and open the console layout.
			-- The console-open is duplicated here (dap-ui also
			-- registers an event_initialized listener) because on
			-- the first session of an nvim instance dap-ui is
			-- still being lazy-loaded *during* this dispatch, so
			-- its own listener isn't registered yet.
			dap.listeners.after.event_initialized["load_dapui"] = function()
				local ok, dapui = pcall(require, "dapui")
				if ok then
					dapui.open({ layout = 2 })
				end
			end

			-- In the nvim-dap REPL, make <Tab> trigger omni-completion.
			-- nvim-dap sets the REPL buffer's `omnifunc` to its DAP
			-- completions request, so <C-x><C-o> normally completes
			-- locals/members. This wires the standard smart-Tab
			-- pattern, buffer-local to the dap-repl filetype:
			--   * popup visible → <C-n>/<C-p> cycle the menu
			--   * col 0 / preceding whitespace → literal <Tab> (indent)
			--   * otherwise → <C-x><C-o> omni-completion
			-- Typing "." also auto-triggers member completion (mixdbg
			-- reports "." as a completionTriggerCharacter, but nvim-dap
			-- doesn't act on that itself — this wires it up).
			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup(
					"DapReplTabComplete", {}),
				pattern = "dap-repl",
				callback = function(ev)
					vim.keymap.set("i", "<Tab>", function()
						if vim.fn.pumvisible() == 1 then
							return "<C-n>"
						end
						local col = vim.fn.col(".") - 1
						if col == 0
							or vim.fn.getline("."):sub(col, col)
								:match("%s") then
							return "<Tab>"
						end
						return "<C-x><C-o>"
					end, {
						buffer = ev.buf,
						expr = true,
						replace_keycodes = true,
						desc = "DAP REPL omni-complete",
					})
					vim.keymap.set("i", "<S-Tab>", function()
						return vim.fn.pumvisible() == 1
							and "<C-p>" or "<S-Tab>"
					end, {
						buffer = ev.buf,
						expr = true,
						replace_keycodes = true,
						desc = "DAP REPL completion prev",
					})
					-- Auto-trigger member completion when "." is typed:
					-- accept any open popup (<C-y>), insert the dot, then
					-- fire omni-completion for the new path segment.
					vim.keymap.set("i", ".", function()
						local lead = vim.fn.pumvisible() == 1
							and "<C-y>." or "."
						return lead .. "<C-x><C-o>"
					end, {
						buffer = ev.buf,
						expr = true,
						replace_keycodes = true,
						desc = "DAP REPL complete after .",
					})
				end,
			})

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
