-- Ruff LSP for Python linting and formatting
-- Binary: installed via Mason (:MasonInstall ruff)

local cmd_path = vim.fn.stdpath("data") .. "/mason/packages/ruff/venv/Scripts/ruff.exe"

vim.lsp.config("ruff", {
	cmd = { cmd_path, "server", "--preview" },
	filetypes = { "python" },
	root_dir = function(bufnr, on_dir)
		local root = vim.fs.root(bufnr, function(name)
			return name:match("pyproject%.toml$") or name:match("setup%.py$") or name:match("%.git$")
		end)
		if root then
			on_dir(root)
		end
	end,
	capabilities = require("cmp_nvim_lsp").default_capabilities(),
	init_options = {
		settings = {
			args = {},
		},
	},
})

vim.lsp.enable("ruff")

return {}
