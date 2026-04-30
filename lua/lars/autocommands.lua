-- Resolve Windows Documents folder redirection so that
-- all paths use the canonical D:\ location.
-- Without this, plugins (neotest, coverage) see duplicate
-- roots via C:\Users\...\Documents vs D:\Lars\Dokumente.
if vim.fn.has("win32") == 1 then
	local docs = vim.fn.expand("~") .. "\\Documents"
	local docs_lower = docs:lower()
	local target = vim.fn.resolve(docs)

	-- Fix cwd on startup
	local cwd = vim.fn.getcwd()
	if cwd:sub(1, #docs):lower() == docs_lower then
		local resolved = target .. cwd:sub(#docs + 1)
		vim.cmd("cd " .. vim.fn.fnameescape(resolved))
	end

	-- Rewrite buffer names so every plugin sees canonical
	-- paths — prevents neotest/coverage path mismatches.
	vim.api.nvim_create_autocmd("BufReadPost", {
		group = vim.api.nvim_create_augroup(
			"ResolveDocumentsPath", {}),
		callback = function(ev)
			local name = vim.api.nvim_buf_get_name(ev.buf)
			if name:sub(1, #docs):lower() == docs_lower then
				local resolved = target .. name:sub(#docs + 1)
				vim.api.nvim_buf_set_name(ev.buf, resolved)
				vim.cmd("silent! bwipeout #")
			end
		end,
	})
end

-- Clean up stale ShaDa temp files left behind when Neovim is
-- force-closed (e.g. clicking the window X button).
-- Only removes files from before today to avoid interfering
-- with other running instances.
if vim.fn.has("win32") == 1 then
	local shada_dir = vim.fn.stdpath("data") .. "/shada"
	local today = os.date("*t")
	local today_start = os.time({ year = today.year, month = today.month, day = today.day })
	for name, type in vim.fs.dir(shada_dir) do
		if type == "file" and name:match("^main%.shada%.tmp") then
			local path = shada_dir .. "/" .. name
			local stat = vim.uv.fs_stat(path)
			if stat and stat.mtime.sec < today_start then
				os.remove(path)
			end
		end
	end
end

vim.api.nvim_create_autocmd("FileType", {
	pattern = "cs",
	callback = function()
		vim.opt_local.colorcolumn = "100"
	end,
})

vim.api.nvim_create_autocmd({ "VimEnter", "DirChanged" }, {
    group = vim.api.nvim_create_augroup("GitCachePrewarm", {}),
    callback = function()
        vim.defer_fn(function()
            local ok, gc = pcall(require, "lars.git-cache")
            if ok then gc.prewarm() end
        end, 100)
    end,
})

local colorize = function()
	vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
	vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
end
local group = vim.api.nvim_create_augroup("Colors", {})
vim.api.nvim_create_autocmd("ColorScheme", { callback = colorize, group = group, })
