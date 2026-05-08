-- lazydev.nvim — successor to neodev.nvim. Gives lua_ls awareness of the
-- Neovim Lua API by lazily injecting workspace.library paths into the
-- running lua_ls client based on which modules are actually require()d.
--
-- Works with vim.lsp.config (the modern framework that replaces the now
-- deprecated require("lspconfig") setup style). lua_ls itself is
-- configured separately in lua_ls.lua.
return {
	{
		"folke/lazydev.nvim",
		ft = "lua",
		opts = {
			library = {
				-- Pull in luvit (vim.uv) types when relevant.
				{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
			},
		},
	},
}
