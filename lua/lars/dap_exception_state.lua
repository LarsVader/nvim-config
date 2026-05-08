-- Persistent storage of CLR exception types selected for
-- per-type DAP breakpoints. State lives in a JSON file
-- under stdpath('data'), keyed by absolute cwd so each
-- project carries its own list across nvim restarts.
--
-- get/set are file-roundtripping so external edits or
-- cwd changes mid-session are honoured.

local M = {}

-- Override-able for tests.
M._path = function()
	return vim.fn.stdpath("data")
		.. "/lars-dap-exceptions.json"
end

local function read_all()
	local p = M._path()
	if vim.fn.filereadable(p) ~= 1 then
		return {}
	end
	local lines = vim.fn.readfile(p)
	if #lines == 0 then return {} end
	local contents = table.concat(lines, "\n")
	if contents == "" then return {} end
	local ok, decoded = pcall(vim.json.decode, contents)
	if not ok or type(decoded) ~= "table" then
		vim.notify(
			p .. " is corrupt — treating as empty",
			vim.log.levels.WARN)
		return {}
	end
	return decoded
end

local function write_all(data)
	local p = M._path()
	vim.fn.mkdir(vim.fn.fnamemodify(p, ":h"), "p")
	local ok_enc, encoded = pcall(vim.json.encode, data)
	if not ok_enc then
		vim.notify(
			"failed to encode exception state",
			vim.log.levels.ERROR)
		return
	end
	-- writefile expects an array of lines; one-line JSON
	-- is fine.
	local ok_w = pcall(
		vim.fn.writefile, { encoded }, p)
	if not ok_w then
		vim.notify(
			"failed to write " .. p,
			vim.log.levels.ERROR)
	end
end

-- Returns the array of stored type names for the given cwd
-- (defaults to vim.fn.getcwd()). Always reads from disk so
-- cwd changes and external edits work.
function M.get(cwd)
	cwd = cwd or vim.fn.getcwd()
	local data = read_all()
	local entry = data[cwd]
	if not entry or type(entry.types) ~= "table" then
		return {}
	end
	-- Defensive copy so callers can't mutate the cache.
	local out = {}
	for _, t in ipairs(entry.types) do
		if type(t) == "string" then
			table.insert(out, t)
		end
	end
	return out
end

-- Persists the array of type names for the given cwd. An
-- empty array deletes the cwd's entry to keep the file tidy.
function M.set(types, cwd)
	cwd = cwd or vim.fn.getcwd()
	local data = read_all()
	if not types or #types == 0 then
		data[cwd] = nil
	else
		local copy = {}
		for _, t in ipairs(types) do
			table.insert(copy, t)
		end
		data[cwd] = { types = copy }
	end
	write_all(data)
end

return M
