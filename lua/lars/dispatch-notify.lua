-- Floating notification for running dispatch/make jobs.
-- Shows a semi-transparent window in the upper-right corner while a job runs.

local M = {}

M._state = {
	win = nil,
	buf = nil,
	timer = nil,
	dots = 0,
	label = "",
}

function M.close()
	local s = M._state
	if s.timer then
		s.timer:stop()
		s.timer:close()
		s.timer = nil
	end
	if s.win and vim.api.nvim_win_is_valid(s.win) then
		vim.api.nvim_win_close(s.win, true)
	end
	if s.buf and vim.api.nvim_buf_is_valid(s.buf) then
		vim.api.nvim_buf_delete(s.buf, { force = true })
	end
	s.win = nil
	s.buf = nil
	s.dots = 0
	s.label = ""
end

function M.is_visible()
	local s = M._state
	return s.win ~= nil and vim.api.nvim_win_is_valid(s.win)
end

function M.update_label(label)
	local s = M._state
	if s.buf and vim.api.nvim_buf_is_valid(s.buf) then
		s.label = " ⚙ " .. label .. " "
		local dots = string.rep(".", s.dots)
		vim.api.nvim_buf_set_lines(s.buf, 0, -1, false, { s.label .. dots })

		local width = #s.label + 3
		if s.win and vim.api.nvim_win_is_valid(s.win) then
			vim.api.nvim_win_set_config(s.win, { width = width })
		end
	end
end

function M.show(cmd, opts)
	M.close()

	opts = opts or {}
	local s = M._state
	s.label = " ⚙ " .. cmd .. " "
	local width = #s.label + 3

	s.buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(s.buf, 0, -1, false, { s.label .. "..." })

	s.win = vim.api.nvim_open_win(s.buf, false, {
		relative = "editor",
		anchor = "NE",
		row = 1,
		col = vim.o.columns - 1,
		width = width,
		height = 1,
		style = "minimal",
		border = "rounded",
		focusable = false,
	})
	vim.api.nvim_set_option_value("winblend", 40, { win = s.win })
	vim.api.nvim_set_option_value("winhighlight",
		"Normal:DiagnosticInfo,FloatBorder:DiagnosticInfo", { win = s.win })

	-- If caller provides an is_running predicate, poll it to auto-close
	local is_running = opts.is_running
	if is_running then
		local interval = opts.poll_interval or 500
		s.timer = vim.uv.new_timer()
		s.timer:start(interval, interval, vim.schedule_wrap(function()
			if not s.buf or not vim.api.nvim_buf_is_valid(s.buf) then
				M.close()
				return
			end
			if not is_running() then
				M.close()
				return
			end
			s.dots = (s.dots + 1) % 4
			local dots = string.rep(".", s.dots)
			vim.api.nvim_buf_set_lines(s.buf, 0, -1, false, { s.label .. dots })
		end))
	end
end

return M
