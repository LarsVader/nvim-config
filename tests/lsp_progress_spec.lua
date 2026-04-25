-- Tests for lua/lars/lsp-progress.lua — generic LSP progress notifications
local h = dofile(vim.fn.stdpath("config") .. "/tests/helpers.lua")

local function fresh_modules()
	package.loaded["lars.dispatch-notify"] = nil
	package.loaded["lars.lsp-progress"] = nil
	local notify = require("lars.dispatch-notify")
	local progress = require("lars.lsp-progress")
	return progress, notify
end

describe("lsp-progress", function()
	after_each(function()
		local ok, notify = pcall(require, "lars.dispatch-notify")
		if ok then notify.close() end
	end)

	describe("custom sources (add/remove)", function()
		it("shows notification when a custom source is added", function()
			local progress, notify = fresh_modules()
			progress.add("Roslyn", "Indexing solution")
			assert.is_true(notify.is_visible(), "notification should appear on add()")
		end)

		it("notification contains source name and title", function()
			local progress, notify = fresh_modules()
			progress.add("Roslyn", "Indexing solution")
			local lines = vim.api.nvim_buf_get_lines(notify._state.buf, 0, -1, false)
			assert.is_not_nil(lines[1]:find("Roslyn"), "should contain source name")
			assert.is_not_nil(lines[1]:find("Indexing"), "should contain title")
		end)

		it("closes notification when custom source is removed", function()
			local progress, notify = fresh_modules()
			progress.add("Roslyn", "Indexing solution")
			assert.is_true(notify.is_visible())
			progress.remove("Roslyn")
			vim.wait(200, function() return not notify.is_visible() end, 10)
			assert.is_false(notify.is_visible(), "notification should close after remove()")
		end)

		it("stays open when one of two sources is removed", function()
			local progress, notify = fresh_modules()
			progress.add("Roslyn", "Indexing solution")
			progress.add("clangd", "Indexing")
			assert.is_true(notify.is_visible())
			progress.remove("Roslyn")
			assert.is_true(notify.is_visible(), "should stay open while clangd is active")
			progress.remove("clangd")
			vim.wait(200, function() return not notify.is_visible() end, 10)
			assert.is_false(notify.is_visible(), "should close when all sources removed")
		end)
	end)

	describe("set_custom", function()
		it("marks a client name as custom-managed", function()
			local progress, _ = fresh_modules()
			progress.set_custom("roslyn")
			-- After set_custom, LspAttach for "roslyn" should be skipped.
			-- We cannot easily simulate LspAttach here, but verify no error.
			assert.has_no.errors(function() progress.set_custom("roslyn") end)
		end)
	end)

	describe("autocmd groups", function()
		it("LspProgressNotify augroup exists with LspAttach, LspProgress, and LspDetach", function()
			local _, _ = fresh_modules()
			local cmds = vim.api.nvim_get_autocmds({ group = "LspProgressNotify" })
			local events = {}
			for _, cmd in ipairs(cmds) do
				events[cmd.event] = true
			end
			assert.is_true(events["LspAttach"], "should have LspAttach autocmd")
			assert.is_true(events["LspProgress"], "should have LspProgress autocmd")
			assert.is_true(events["LspDetach"], "should have LspDetach autocmd")
		end)
	end)
end)
