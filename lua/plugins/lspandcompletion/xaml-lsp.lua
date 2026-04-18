-- XAML LSP via axsg-lsp (XamlToCSharpGenerator Language Server)
-- Binary: ~/.dotnet/tools/axsg-lsp (installed via dotnet tool)
-- Transport: stdio, accepts --workspace <path>

-- NOTE: nvim-cmp versions before commit 51260c0 (PR #1734) call the
-- removed vim.lsp.util.parse_snippet and crash on Neovim 0.11+.
-- If you hit "parse_snippet (a nil value)" errors, update nvim-cmp.

-- Register .xaml files as "xaml" filetype and use xml treesitter parser
vim.filetype.add({
	extension = {
		xaml = "xaml",
	},
})
vim.treesitter.language.register("xml", "xaml")

-- Map axsg-lsp custom semantic token types to Neovim highlight groups
vim.api.nvim_create_autocmd("LspTokenUpdate", {
	callback = function(args)
		local token = args.data.token
		if token.type == "xamlDelimiter" then
			vim.lsp.semantic_tokens.highlight_token(token, args.buf, args.data.client_id, "@punctuation.bracket")
		elseif token.type == "xamlName" then
			vim.lsp.semantic_tokens.highlight_token(token, args.buf, args.data.client_id, "@tag")
		elseif token.type == "xamlAttribute" then
			vim.lsp.semantic_tokens.highlight_token(token, args.buf, args.data.client_id, "@tag.attribute")
		elseif token.type == "xamlAttributeValue" then
			vim.lsp.semantic_tokens.highlight_token(token, args.buf, args.data.client_id, "@string")
		elseif token.type == "xamlAttributeQuotes" then
			vim.lsp.semantic_tokens.highlight_token(token, args.buf, args.data.client_id, "@string")
		elseif token.type == "xamlComment" then
			vim.lsp.semantic_tokens.highlight_token(token, args.buf, args.data.client_id, "@comment")
		elseif token.type == "xamlKeyword" then
			vim.lsp.semantic_tokens.highlight_token(token, args.buf, args.data.client_id, "@keyword")
		elseif token.type == "xamlMarkupExtensionClass" then
			vim.lsp.semantic_tokens.highlight_token(token, args.buf, args.data.client_id, "@type")
		elseif token.type == "xamlMarkupExtensionParameterName" then
			vim.lsp.semantic_tokens.highlight_token(token, args.buf, args.data.client_id, "@property")
		elseif token.type == "xamlMarkupExtensionParameterValue" then
			vim.lsp.semantic_tokens.highlight_token(token, args.buf, args.data.client_id, "@string")
		elseif token.type == "xamlNamespacePrefix" then
			vim.lsp.semantic_tokens.highlight_token(token, args.buf, args.data.client_id, "@module")
		elseif token.type == "xamlText" then
			vim.lsp.semantic_tokens.highlight_token(token, args.buf, args.data.client_id, "@string")
		end
	end,
})

-- Configure and enable axsg-lsp for XAML files.
-- Uses vim.lsp.config + vim.lsp.enable (Neovim 0.11+) which
-- auto-attaches via a FileType autocmd — no plugin needed.
local cmd_path = vim.fn.expand("~/.dotnet/tools/axsg-lsp")
if vim.fn.has("win32") == 1 then
	cmd_path = cmd_path .. ".exe"
end

vim.lsp.config("axsg_lsp", {
	cmd = { cmd_path },
	filetypes = { "xaml" },
	root_dir = function(bufnr, on_dir)
		local root = vim.fs.root(bufnr, function(name)
			return name:match("%.sln$") or name:match("%.csproj$")
		end)
		if root then
			on_dir(root)
		end
	end,
	capabilities = require("cmp_nvim_lsp").default_capabilities(),
	cmd_env = {
		VCTargetsPath = "C:/Program Files (x86)/Microsoft Visual Studio/18/BuildTools/MSBuild/Microsoft/VC/v180/",
		MSBuildSDKsPath = "C:/Program Files/dotnet/sdk/10.0.201/Sdks",
		DOTNET_HOST_PATH = "C:/Program Files/dotnet/dotnet.exe",
		MSBuildExtensionsPath = "C:/Program Files/dotnet/sdk/10.0.201/",
	},
})

vim.lsp.enable("axsg_lsp")

-- Return empty spec — no plugin to install, this file is
-- purely configuration sourced by Lazy.nvim's directory scan.
return {}
