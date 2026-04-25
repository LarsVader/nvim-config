-- Tests for lua/lars/dispatch-notify.lua — floating notification module
local h = dofile(vim.fn.stdpath("config") .. "/tests/helpers.lua")

-- Fresh module instance for each test (clear cached state)
local function fresh_notify()
	package.loaded["lars.dispatch-notify"] = nil
	return require("lars.dispatch-notify")
end

describe("dispatch-notify", function()
	after_each(function()
		-- Always clean up windows/timers between tests
		local ok, notify = pcall(require, "lars.dispatch-notify")
		if ok then notify.close() end
	end)

	describe("show", function()
		it("creates a floating window", function()
			local notify = fresh_notify()
			notify.show("Make build")
			assert.is_true(notify.is_visible(), "window should be visible after show()")
		end)

		it("window contains the command label", function()
			local notify = fresh_notify()
			notify.show("Make test")
			local lines = vim.api.nvim_buf_get_lines(notify._state.buf, 0, -1, false)
			assert.is_not_nil(lines[1]:find("Make test"), "buffer should contain command label")
		end)

		it("window is not focusable", function()
			local notify = fresh_notify()
			notify.show("Make build")
			local config = vim.api.nvim_win_get_config(notify._state.win)
			assert.is_false(config.focusable, "notification window should not be focusable")
		end)

		it("window has transparency (winblend > 0)", function()
			local notify = fresh_notify()
			notify.show("Make build")
			local blend = vim.api.nvim_get_option_value("winblend", { win = notify._state.win })
			assert.is_true(blend > 0, "winblend should be > 0 for transparency")
		end)
	end)

	describe("close", function()
		it("closes the floating window", function()
			local notify = fresh_notify()
			notify.show("Make build")
			assert.is_true(notify.is_visible())
			notify.close()
			assert.is_false(notify.is_visible(), "window should be gone after close()")
		end)

		it("is safe to call when nothing is open", function()
			local notify = fresh_notify()
			assert.has_no.errors(function() notify.close() end)
		end)

		it("is safe to call twice", function()
			local notify = fresh_notify()
			notify.show("Make build")
			notify.close()
			assert.has_no.errors(function() notify.close() end)
		end)

		it("cleans up the buffer", function()
			local notify = fresh_notify()
			notify.show("Make build")
			local buf = notify._state.buf
			notify.close()
			assert.is_false(vim.api.nvim_buf_is_valid(buf), "buffer should be deleted after close()")
		end)
	end)

	describe("show replaces previous", function()
		it("closes old window when show is called again", function()
			local notify = fresh_notify()
			notify.show("Make build")
			local first_win = notify._state.win
			notify.show("Make test")
			assert.is_false(vim.api.nvim_win_is_valid(first_win),
				"first window should be closed when show() is called again")
			assert.is_true(notify.is_visible(), "new window should be visible")
		end)
	end)

	describe("auto-close via is_running", function()
		it("closes when is_running returns false", function()
			local notify = fresh_notify()
			local running = true
			notify.show("Make build", {
				is_running = function() return running end,
				poll_interval = 30, -- fast poll for testing
			})
			assert.is_true(notify.is_visible())

			-- Simulate job completing
			running = false

			-- Give the timer a chance to fire (need to process timers)
			-- We pump the event loop by sleeping briefly
			vim.wait(200, function() return not notify.is_visible() end, 10)

			assert.is_false(notify.is_visible(),
				"notification should auto-close when is_running returns false")
		end)

		it("stays open while is_running returns true", function()
			local notify = fresh_notify()
			notify.show("Make build", {
				is_running = function() return true end,
				poll_interval = 30,
			})

			vim.wait(150, function() return false end, 10)

			assert.is_true(notify.is_visible(),
				"notification should remain visible while is_running returns true")
			notify.close()
		end)
	end)

	describe("update_label", function()
		it("changes the displayed text", function()
			local notify = fresh_notify()
			notify.show("First label")
			notify.update_label("Second label")
			local lines = vim.api.nvim_buf_get_lines(notify._state.buf, 0, -1, false)
			assert.is_not_nil(lines[1]:find("Second label"), "buffer should contain updated label")
		end)

		it("resizes the window for longer labels", function()
			local notify = fresh_notify()
			notify.show("Short")
			local config_before = vim.api.nvim_win_get_config(notify._state.win)
			notify.update_label("A much longer label text")
			local config_after = vim.api.nvim_win_get_config(notify._state.win)
			assert.is_true(config_after.width >= config_before.width,
				"window should grow for longer labels")
		end)

		it("is safe when no window is open", function()
			local notify = fresh_notify()
			assert.has_no.errors(function() notify.update_label("No window") end)
		end)
	end)

	describe("is_visible", function()
		it("returns false when nothing is shown", function()
			local notify = fresh_notify()
			assert.is_false(notify.is_visible())
		end)

		it("returns false after external window close", function()
			local notify = fresh_notify()
			notify.show("Make build")
			-- Simulate user closing the window externally
			vim.api.nvim_win_close(notify._state.win, true)
			assert.is_false(notify.is_visible())
		end)
	end)
end)
