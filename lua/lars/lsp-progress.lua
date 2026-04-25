-- Generic LSP progress notifications.
-- Shows a floating window (via dispatch-notify) whenever any LSP server
-- is starting or reports background work via $/progress.
-- Also exposes add/remove for custom progress sources (e.g. Roslyn).

local notify = require("lars.dispatch-notify")
local M = {}

-- { [source_key] = { [token] = title } }
-- source_key is client_id (number) for standard LSP, or a string for custom.
local active = {}

-- Clients managed by custom sources (add/remove) — skip LspAttach for these.
local custom_clients = {}

-- Pending attach timers: auto-close "Starting" after a timeout if no
-- $/progress events arrive (server started fast or doesn't send progress).
local attach_timers = {} -- { [client_id] = uv_timer }

local function get_display_label()
	for source_key, tokens in pairs(active) do
		local name
		if type(source_key) == "number" then
			local client = vim.lsp.get_client_by_id(source_key)
			name = client and client.name or "LSP"
		else
			name = source_key
		end
		for _, title in pairs(tokens) do
			return name .. ": " .. title
		end
	end
	return nil
end

local function has_active()
	for _, tokens in pairs(active) do
		if next(tokens) then
			return true
		end
	end
	return false
end

local function refresh()
	local label = get_display_label()
	if label then
		if notify.is_visible() then
			notify.update_label(label)
		else
			notify.show(label, {
				is_running = has_active,
				poll_interval = 400,
			})
		end
	else
		notify.close()
	end
end

local function cancel_attach_timer(client_id)
	local timer = attach_timers[client_id]
	if timer then
		timer:stop()
		timer:close()
		attach_timers[client_id] = nil
	end
end

local function remove_client(client_id)
	cancel_attach_timer(client_id)
	active[client_id] = nil
	refresh()
end

--- Register a client name as custom-managed (skips generic LspAttach).
function M.set_custom(client_name)
	custom_clients[client_name] = true
end

--- Register a custom progress source (e.g. Roslyn indexing).
function M.add(source_name, title)
	custom_clients[source_name] = true
	active[source_name] = active[source_name] or {}
	active[source_name]["custom"] = title
	refresh()
end

--- Remove a custom progress source.
function M.remove(source_name)
	active[source_name] = nil
	refresh()
end

local group = vim.api.nvim_create_augroup("LspProgressNotify", {})

-- Show "Starting" on attach for any server not handled by a custom source.
-- Auto-closes after 5s if the server never sends $/progress events.
vim.api.nvim_create_autocmd("LspAttach", {
	group = group,
	callback = function(ev)
		local client = vim.lsp.get_client_by_id(ev.data.client_id)
		if not client then return end
		if custom_clients[client.name] then return end

		local client_id = ev.data.client_id
		active[client_id] = active[client_id] or {}
		active[client_id]["_attach"] = "Starting"
		refresh()

		-- Auto-close after 5s if no $/progress replaces this
		cancel_attach_timer(client_id)
		local timer = vim.uv.new_timer()
		attach_timers[client_id] = timer
		timer:start(5000, 0, vim.schedule_wrap(function()
			cancel_attach_timer(client_id)
			if active[client_id] then
				active[client_id]["_attach"] = nil
				if not next(active[client_id]) then
					active[client_id] = nil
				end
			end
			refresh()
		end))
	end,
})

-- Track standard $/progress notifications from any server.
vim.api.nvim_create_autocmd("LspProgress", {
	group = group,
	callback = function(ev)
		local client_id = ev.data.client_id
		local val = ev.data.params.value
		local token = ev.data.params.token

		if val.kind == "begin" then
			active[client_id] = active[client_id] or {}
			-- Clear the generic "Starting" entry — real progress info is better
			active[client_id]["_attach"] = nil
			cancel_attach_timer(client_id)
			active[client_id][token] = val.title or "Working"
			refresh()
		elseif val.kind == "end" then
			if active[client_id] then
				active[client_id][token] = nil
				if not next(active[client_id]) then
					active[client_id] = nil
				end
			end
			refresh()
		end
	end,
})

-- Clean up when a client detaches.
vim.api.nvim_create_autocmd("LspDetach", {
	group = group,
	callback = function(ev)
		remove_client(ev.data.client_id)
	end,
})

return M
