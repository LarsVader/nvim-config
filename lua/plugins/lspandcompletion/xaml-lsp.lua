-- XAML LSP via xaml-lsp (XamlToCSharpGenerator Language Server)
-- Binary: installed via Mason (:MasonInstall xaml-lsp)
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
-- Toggle: true = use local dotnet tool build, false = use Mason-installed binary.
local USE_LOCAL_BUILD = false

local cmd_path
if USE_LOCAL_BUILD then
	cmd_path = vim.fn.expand("~/.dotnet/tools/axsg-lsp.exe")
else
	cmd_path = vim.fn.stdpath("data") .. "/mason/packages/xaml-lsp/XamlToCSharpGenerator.LanguageServer.exe"
end

if not vim.uv.fs_stat(cmd_path) then
	vim.notify("xaml-lsp: binary not found at " .. cmd_path, vim.log.levels.WARN)
	return {}
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

-- Handle axsg-metadata:// URIs — opens decompiled C# source from the LSP.
-- The LSP sends go-to-definition responses pointing to these virtual URIs
-- for types defined in referenced assemblies.
vim.api.nvim_create_autocmd("BufReadCmd", {
	pattern = "axsg-metadata://*",
	callback = function(args)
		local buf = args.buf
		local bufname = vim.api.nvim_buf_get_name(buf)

		-- Extract the id parameter from the URI query string
		local id = bufname:match("id=([^&]+)")
		if not id then
			vim.notify("axsg-metadata: missing 'id' in URI: " .. bufname, vim.log.levels.ERROR)
			return
		end

		-- URL-decode the id (replace %XX hex escapes)
		id = id:gsub("%%(%x%x)", function(hex)
			return string.char(tonumber(hex, 16))
		end)

		-- Find an active axsg_lsp client
		local clients = vim.lsp.get_clients({ name = "axsg_lsp" })
		if #clients == 0 then
			vim.notify("axsg-metadata: no active axsg_lsp client found", vim.log.levels.ERROR)
			return
		end
		local client = clients[1]

		-- Request decompiled source from the LSP
		client:request("axsg/metadataDocument", { id = id }, function(err, result)
			if err then
				vim.notify("axsg/metadataDocument error: " .. tostring(err), vim.log.levels.ERROR)
				return
			end

			vim.schedule(function()
				local lines = vim.split(result, "\n", { plain = true })
				vim.bo[buf].modifiable = true
				vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
				vim.bo[buf].buftype = "nofile"
				vim.bo[buf].filetype = "cs"
				vim.bo[buf].modifiable = false
				vim.bo[buf].readonly = true
				vim.bo[buf].buflisted = true
			end)
		end, buf)
	end,
})

-- Return empty spec — no plugin to install, this file is
-- purely configuration sourced by Lazy.nvim's directory scan.
return {}
