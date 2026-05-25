local function has_treesitter_cli()
	return vim.fn.executable('tree-sitter') == 1
end

local wanted_parsers = {
	'cpp', 'rust', 'javascript', 'vimdoc', 'vim', 'lua', 'c_sharp',
	'xml', 'markdown', 'markdown_inline',
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
	{
		'nvim-treesitter/nvim-treesitter-textobjects',
		dependencies = { 'nvim-treesitter/nvim-treesitter' },
		keys = {
			-- Move: function
			{
				']m',
				function()
					require('nvim-treesitter-textobjects.move').goto_next_start('@function.outer')
					vim.schedule(function() vim.cmd('normal! zt') end)
				end,
				desc = "Jump to next function",
			},
			{
				'[m',
				function()
					require('nvim-treesitter-textobjects.move').goto_previous_start('@function.outer')
					vim.schedule(function() vim.cmd('normal! zt') end)
				end,
				desc = "Jump to previous function",
			},
			-- Move: class
			{
				']c',
				function()
					require('nvim-treesitter-textobjects.move').goto_next_start('@class.outer')
					vim.schedule(function() vim.cmd('normal! zt') end)
				end,
				desc = "Jump to next class",
			},
			{
				'[c',
				function()
					require('nvim-treesitter-textobjects.move').goto_previous_start('@class.outer')
					vim.schedule(function() vim.cmd('normal! zt') end)
				end,
				desc = "Jump to previous class",
			},
			-- Move: parameter
			{
				']a',
				function()
					require('nvim-treesitter-textobjects.move').goto_next_start('@parameter.outer')
				end,
				desc = "Jump to next parameter",
			},
			{
				'[a',
				function()
					require('nvim-treesitter-textobjects.move').goto_previous_start('@parameter.outer')
				end,
				desc = "Jump to previous parameter",
			},
			-- Move: block
			{
				']b',
				function()
					require('nvim-treesitter-textobjects.move').goto_next_start('@block.outer')
				end,
				desc = "Jump to next block",
			},
			{
				'[b',
				function()
					require('nvim-treesitter-textobjects.move').goto_previous_start('@block.outer')
				end,
				desc = "Jump to previous block",
			},
			-- Select: function
			{ 'af', function() require('nvim-treesitter-textobjects.select').select_textobject('@function.outer') end, mode = { 'x', 'o' }, desc = "Select around function" },
			{ 'if', function() require('nvim-treesitter-textobjects.select').select_textobject('@function.inner') end, mode = { 'x', 'o' }, desc = "Select inside function" },
			-- Select: class
			{ 'ac', function() require('nvim-treesitter-textobjects.select').select_textobject('@class.outer') end, mode = { 'x', 'o' }, desc = "Select around class" },
			{ 'ic', function() require('nvim-treesitter-textobjects.select').select_textobject('@class.inner') end, mode = { 'x', 'o' }, desc = "Select inside class" },
			-- Select: parameter
			{ 'aa', function() require('nvim-treesitter-textobjects.select').select_textobject('@parameter.outer') end, mode = { 'x', 'o' }, desc = "Select around parameter" },
			{ 'ia', function() require('nvim-treesitter-textobjects.select').select_textobject('@parameter.inner') end, mode = { 'x', 'o' }, desc = "Select inside parameter" },
			-- Select: block/scope
			{ 'ab', function() require('nvim-treesitter-textobjects.select').select_textobject('@block.outer') end, mode = { 'x', 'o' }, desc = "Select around block" },
			{ 'ib', function() require('nvim-treesitter-textobjects.select').select_textobject('@block.inner') end, mode = { 'x', 'o' }, desc = "Select inside block" },
		},
		config = function()
			require('nvim-treesitter-textobjects').setup({
				select = { lookahead = true },
			})
		end,
	},
}
