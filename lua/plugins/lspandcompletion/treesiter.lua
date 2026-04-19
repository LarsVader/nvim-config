local function has_treesitter_cli()
	return vim.fn.executable('tree-sitter') == 1
end

local wanted_parsers = {
	'cpp', 'rust', 'javascript', 'vimdoc', 'vim', 'lua', 'c_sharp', 'xml'
}

local function winget_install(id, label, on_success)
	if vim.fn.has('win32') ~= 1 then
		return
	end
	vim.notify(
		label .. ' not found. Installing via winget...',
		vim.log.levels.INFO
	)
	local function on_output(_, data)
		if not data then return end
		for _, line in ipairs(data) do
			local trimmed = line:gsub('%s+$', '')
			if trimmed ~= '' then
				vim.schedule(function()
					vim.notify(label .. ': ' .. trimmed, vim.log.levels.INFO)
				end)
			end
		end
	end
	vim.fn.jobstart(
		'winget install -e --id ' .. id
			.. ' --accept-package-agreements'
			.. ' --accept-source-agreements',
		{
			stdout_buffered = false,
			stderr_buffered = false,
			on_stdout = on_output,
			on_stderr = on_output,
			on_exit = function(_, code)
				vim.schedule(function()
					if code ~= 0 then
						vim.notify(
							label .. ' install failed (exit ' .. code .. ').',
							vim.log.levels.ERROR
						)
					else
						vim.notify(
							label .. ' installed. Restart Neovim.',
							vim.log.levels.WARN
						)
						if on_success then on_success() end
					end
				end)
			end,
		}
	)
end

return {
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		build = function()
			if has_treesitter_cli() then
				vim.cmd('TSUpdate')
			end
		end,
		config = function()
			if has_treesitter_cli() then
				local cfg = require('nvim-treesitter.config')
				local installed = cfg.get_installed()
				local missing = vim.tbl_filter(function(p)
					return not vim.list_contains(installed, p)
				end, wanted_parsers)
				if #missing > 0 then
					require('nvim-treesitter').install(missing)
				end
				return
			end

			-- No tree-sitter CLI — auto-install via winget on Windows
			winget_install('tree-sitter.tree-sitter-cli', 'tree-sitter-cli')
		end,
	},
	{
		'nvim-treesitter/nvim-treesitter-context',
		dependencies = { 'nvim-treesitter/nvim-treesitter' },
	},
}
