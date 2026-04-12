return {
	{
		"rcarriga/nvim-dap-ui",
		dependencies = { "mfussenegger/nvim-dap" },
		keys = {
			{'du', function() require("dapui").toggle() end, desc = "Toggle DAP UI"},
		},
		config = function ()
			local dap = require('dap')
			local dapui = require('dapui');
			dapui.setup();

			dap.listeners.before.event_terminated["dapui_config"] = function()
				dapui.close()
			end
			dap.listeners.before.event_exited["dapui_config"] = function()
				dapui.close()
			end
		end
	}
}
