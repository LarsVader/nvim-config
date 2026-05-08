-- Lua language server (lua-language-server, aka lua_ls).
-- Binary: installed via Mason (:MasonInstall lua-language-server).
--
-- Neovim Lua API awareness (vim.api.*, vim.uv.*, vim.fn.* etc.) is
-- provided by lazydev.nvim — it injects workspace.library entries onto
-- the running lua_ls client lazily as you require() modules. We only
-- supply the bare cmd + filetype/root config here; nvim-lspconfig ships
-- sensible default settings for lua_ls that vim.lsp.config merges in.
vim.lsp.config('lua_ls', {
	cmd = { vim.fn.stdpath('data') .. '/mason/bin/lua-language-server.cmd' },
	filetypes = { 'lua' },
	root_markers = {
		'.luarc.json',
		'.luarc.jsonc',
		'.luacheckrc',
		'.stylua.toml',
		'stylua.toml',
		'selene.toml',
		'selene.yml',
		'.git',
	},
})
vim.lsp.enable('lua_ls')

return {}
