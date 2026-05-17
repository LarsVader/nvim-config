return {
	{
		"rcarriga/nvim-dap-ui",
		dependencies = { "mfussenegger/nvim-dap" },
		keys = {
			{ '<leader>dui', function() require("dapui").toggle() end, desc = "Toggle DAP UI" },
			{
				'<leader>dub',
				function()
					---@diagnostic disable-next-line: missing-fields
					require("dapui").float_element('breakpoints', { width = 50, height = 13, enter = true })
				end,
				desc = "DAP-UI float breakpoints list"
			},
			{
				'<leader>duw',
				function()
					---@diagnostic disable-next-line: missing-fields
					require("dapui").float_element('watches', { width = 50, height = 13, enter = true })
				end,
				desc = "DAP-UI float watches"
			},
			{
				'<leader>dur',
				function()
					---@diagnostic disable-next-line: missing-fields
					require("dapui").float_element('repl', { width = 60, height = 15, enter = true })
				end,
				desc = "DAP-UI float REPL"
			},
		},
		config = function()
			local dap = require('dap')
			local dapui = require('dapui');
			---@diagnostic disable-next-line: missing-fields
			dapui.setup({
				layouts = {
					{
						elements = {
							{ id = "scopes", size = 0.6 },
							{ id = "stacks", size = 0.4 },
						},
						size = 40,
						position = "left",
					},
					{
						elements = {
							{ id = "repl", size = 1.0 },
						},
						size = 10,
						position = "bottom",
					},
				},
			});

			-- Open console-only layout when a session starts.
			-- (Sidebar opens later via event_stopped.) The first
			-- session of an nvim instance is also handled by
			-- nvim-dap.lua's `load_dapui` listener, since this
			-- listener is only registered after dap-ui finishes
			-- lazy-loading.
			dap.listeners.after.event_initialized["dapui_console"] = function()
				dapui.open({ layout = 2 })
			end

			-- Auto-show sidebar (layout 1: scopes + stacks) when stopped
			-- at a breakpoint/step, and hide on continue.
			dap.listeners.after.event_stopped["dapui_sidebar"] = function()
				dapui.open({ layout = 1 })
			end
			-- Hook the *continue request* listener rather than
			-- `event_continued`, because many adapters (netcoredbg,
			-- codelldb) don't reliably emit the `continued` event.
			-- The request listener is driven by nvim-dap itself, so
			-- it always fires. Step requests are intentionally NOT
			-- hooked — the sidebar stays open during stepping.
			local function hide_sidebar()
				dapui.close({ layout = 1 })
			end
			dap.listeners.before.continue["dapui_sidebar"] = hide_sidebar
			-- Keep event_continued too, as a no-op safety net for
			-- adapters that do send it.
			dap.listeners.after.event_continued["dapui_sidebar"] = hide_sidebar

			-- Close the entire UI (both layouts) when the session
			-- ends. Hook both the events and the disconnect/terminate
			-- request listeners, because many adapters don't reliably
			-- emit `terminated`/`exited`. The request listeners are
			-- driven by nvim-dap itself during session teardown, so
			-- at least one of these always fires.
			local function close_all()
				dapui.close()
			end
			dap.listeners.before.event_terminated["dapui_config"] = close_all
			dap.listeners.before.event_exited["dapui_config"] = close_all
			dap.listeners.after.disconnect["dapui_config"] = close_all
			dap.listeners.after.terminate["dapui_config"] = close_all
		end
	}
}
