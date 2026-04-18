-- Test: axsg-lsp go-to-definition support
-- Run: nvim --headless -c "set noswapfile" -c "luafile tests/test_xaml_gd.lua"
--
-- Uses tests/fixtures/WpfTestApp/ as a minimal WPF project.
-- Waits for axsg-lsp to initialize, then sends definition requests
-- and prints the server responses for manual inspection.

local fixture_dir = vim.fn.stdpath("config") .. "/tests/fixtures/WpfTestApp"
vim.cmd("edit " .. fixture_dir .. "/MainWindow.xaml")
vim.lsp.set_log_level("debug")

vim.defer_fn(function()
	local buf = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	print("Buffer: " .. #lines .. " lines")

	local clients = vim.lsp.get_clients({ bufnr = buf, name = "axsg_lsp" })
	if #clients == 0 then
		print("ERROR: axsg_lsp not attached")
		vim.cmd("qa!")
		return
	end
	local client = clients[1]
	print("axsg_lsp: initialized=" .. tostring(client.initialized))
	print("  definitionProvider=" .. tostring(client.server_capabilities.definitionProvider))

	local tests = {
		{ line = 5, col = 6, desc = "Grid element" },
		{ line = 6, col = 40, desc = "OnClick handler" },
		{ line = 1, col = 20, desc = "x:Class MainWindow" },
	}

	local i = 0
	local function run_next()
		i = i + 1
		if i > #tests then
			vim.cmd("qa!")
			return
		end
		local t = tests[i]
		vim.api.nvim_win_set_cursor(0, { t.line, t.col })
		local params = vim.lsp.util.make_position_params(0, "utf-16")
		print("\n-- Test " .. i .. ": " .. t.desc .. " (" .. t.line .. ":" .. t.col .. ")")
		client.request("textDocument/definition", params, function(err, result)
			if err then
				print("  Error: " .. vim.inspect(err))
			elseif not result or #result == 0 then
				print("  No locations returned")
			else
				for _, loc in ipairs(result) do
					print("  -> " .. (loc.uri or loc.targetUri or "?"))
					local r = loc.range or loc.targetRange
					if r then
						print("     line " .. r.start.line .. ":" .. r.start.character)
					end
				end
			end
			vim.defer_fn(run_next, 1000)
		end, buf)
	end

	run_next()
end, 20000)
