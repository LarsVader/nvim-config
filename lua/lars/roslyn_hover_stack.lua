-- Back/forward history for the noice hover popup.
--
-- The popup is a singleton (one noice "hover" message + one popup window),
-- so we can't visually stack popups — but we can keep two stacks of
-- (result, ctx) pairs and re-render the popup in place when the user
-- presses <C-o> / <C-i>. Each successful primary/dive render is recorded
-- as M._current via set_current; navigation (go_back / go_forward)
-- shuffles the stacks explicitly and re-renders without going through
-- on_hover.
local M = {}

M._current = nil ---@type {result: table, ctx: table}|nil
M._back = {} ---@type {result: table, ctx: table}[]
M._forward = {} ---@type {result: table, ctx: table}[]
M._dive_pending = false

--- Called by find_symbol right before triggering a nested hover.
function M.start_dive()
	M._dive_pending = true
end

--- Called by the patched on_hover after a successful render. A dive
--- pushes the previous current onto _back and invalidates the forward
--- history; a fresh K from source resets both stacks.
function M.set_current(result, ctx)
	if M._dive_pending then
		if M._current then
			table.insert(M._back, M._current)
		end
		M._forward = {}
		M._dive_pending = false
	else
		-- Fresh K from source — reset both stacks so <C-o>/<C-i> don't
		-- jump back to hovers from a previous session.
		M._back = {}
		M._forward = {}
	end
	M._current = { result = result, ctx = ctx }
end

--- Recreate the hover popup with `target`'s content. We can't just
--- re-render in place: noice's view caches its popup dimensions on first
--- show and doesn't recompute on a content-only update, so the new
--- (smaller) payload renders inside the old (larger) frame and the
--- border looks broken. Closing the window forces a re-mount, but the
--- close also fires CursorMoved which would trip noice's autohide
--- on_close and kill the new popup — so we suspend the autohide
--- autocmd around the close/render and reinstate it once the view has
--- mounted.
---@param target {result: table, ctx: table}
local function render_into_popup(target)
	local Docs = require("noice.lsp.docs")
	Docs._autohide = "__roslyn_nav_pending"
	vim.api.nvim_create_augroup("noice_lsp_docs", { clear = true })

	pcall(function()
		local renderer = require("lars.roslyn_hover_render")
		local result = target.result
		local ctx = target.ctx
		local ft = vim.api.nvim_buf_is_valid(ctx.bufnr) and vim.bo[ctx.bufnr].filetype or "cs"

		local c = result.contents
		local content_str
		if type(c) == "string" then
			content_str = c
		elseif type(c) == "table" and c.kind == "markdown" and type(c.value) == "string" then
			content_str = c.value
		end

		local existing = Docs._messages and Docs._messages["hover"]
		if existing then
			local existing_win = existing:win()
			if existing_win and vim.api.nvim_win_is_valid(existing_win) then
				pcall(vim.api.nvim_win_close, existing_win, true)
			end
			Docs.hide(existing)
		end

		local message = Docs.get("hover")
		if content_str and renderer.render(message, content_str, ft) then
			Docs.show(message)
			M._current = { result = result, ctx = ctx }
		end
	end)

	vim.defer_fn(function()
		Docs._autohide = nil
		Docs.autohide()
		local msg = Docs._messages and Docs._messages["hover"]
		if msg then
			pcall(function()
				msg:focus()
			end)
		end
	end, 150)
end

--- Pop the back-stack and re-render the previous hover.
function M.go_back()
	local prev = table.remove(M._back)
	if not prev then
		vim.notify("no previous hover", vim.log.levels.INFO)
		return
	end
	if M._current then
		table.insert(M._forward, M._current)
	end
	render_into_popup(prev)
end

--- Pop the forward-stack and re-render the next hover.
function M.go_forward()
	local prev = table.remove(M._forward)
	if not prev then
		vim.notify("no forward hover", vim.log.levels.INFO)
		return
	end
	if M._current then
		table.insert(M._back, M._current)
	end
	render_into_popup(prev)
end

return M
