vim.lsp.config('clangd', {
	cmd = { vim.fn.stdpath('data') .. '/mason/bin/clangd.cmd' },
	filetypes = { 'c', 'cpp', 'objc', 'objcpp' },
	root_markers = { '.clangd', 'compile_commands.json', 'compile_flags.txt', '.git' },
})
vim.lsp.enable('clangd')

return {}
