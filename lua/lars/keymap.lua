vim.g.mapleader = " "
vim.g.camelcasemotion_key = "<leader>"

vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })
-- vim.keymap.set('n', '<leader>e', vim.cmd.Ex, {})
vim.keymap.set('n', '<leader>fe', ':edit .<CR>', {})
vim.keymap.set('n', '<c-d>', '<c-d>zz', {})
vim.keymap.set('n', '<c-u>', '<c-u>zz', {})

vim.keymap.set('n', '<leader>g', ':G<CR>:only<CR>', {})
vim.keymap.set('n', '<leader>gb', ':G blame<CR>', {})
vim.keymap.set('n', '<leader>bg', '<c-w>l:only<CR>', {})
vim.keymap.set('n', '<leader>gd', ':G diff<CR>:only<CR>', {})
vim.keymap.set('n', '<leader>gl', ':G log<CR>:only<CR>', {})
vim.keymap.set('n', '<leader>gf', ':Gdiffsplit<CR>', {})
vim.keymap.set('n', '<leader>mr', ':wa<CR>:make run<CR>', {}) -- todo make specific for rust.
vim.keymap.set('n', '<leader>n', ':cnext<CR>', {})
vim.keymap.set('n', '<leader>N', ':cprev<CR>', {})

vim.keymap.set('n', '<leader>s', ':e ~/.config/nvim/<CR>', {})
vim.keymap.set('n', '<leader>y', '"+y', {})
vim.keymap.set('n', '<leader>p', '"+p', {})

vim.keymap.set('n', '<c-h>', ':SidewaysLeft<cr>', {})
vim.keymap.set('n', '<c-l>', ':SidewaysRight<cr>', {})

-- todo most of these are the example from :help dap.txt
-- some do not work and must be tweaked
vim.keymap.set('n', '<F5>', function() require('dap').continue() end)
vim.keymap.set('n', '<F10>', function() require('dap').step_over() end)
vim.keymap.set('n', '<F11>', function() require('dap').step_into() end)
vim.keymap.set('n', '<F12>', function() require('dap').step_out() end)
vim.keymap.set('n', '<Leader>db', function() require('dap').toggle_breakpoint() end)
vim.keymap.set('n', '<Leader>dB', function() require('dap').set_breakpoint() end)
vim.keymap.set('n', '<Leader>dlb', function() require('dap').set_breakpoint(nil, nil, vim.fn.input('Log point message: ')) end)
vim.keymap.set('n', '<Leader>dr', function() require('dap').repl.open() end)
vim.keymap.set('n', '<Leader>dl', function() require('dap').run_last() end)
vim.keymap.set({'n', 'v'}, '<Leader>dh', function()
	require('dap.ui.widgets').hover()
end)
vim.keymap.set({'n', 'v'}, '<Leader>dp', function()
	require('dap.ui.widgets').preview()
end)
vim.keymap.set('n', '<Leader>df', function()
	local widgets = require('dap.ui.widgets')
	widgets.centered_float(widgets.frames)
end)
vim.keymap.set('n', '<Leader>ds', function()
	local widgets = require('dap.ui.widgets')
	widgets.centered_float(widgets.scopes)
end)
