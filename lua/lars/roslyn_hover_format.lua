-- Split Roslyn's hover markdown into (signature lines, rest lines).
--
-- Roslyn returns the C# signature as the first paragraph of the markdown
-- blob with `<` / `>` etc. escaped as `\<` / `\>`. We hand the signature
-- lines back unescaped so the caller can drop them into a noice message
-- as raw text and apply ft-syntax over them directly — the same trick
-- noice's signature_help uses for `sig.label` (see noice/lsp/signature.lua).
-- This avoids both noice's `NoiceText.syntax` off-by-one for fenced code
-- blocks followed by markdown, and the visible-backtick problem of inline
-- code spans.
local M = {}

local ESCAPED_PUNCT = "\\([<>%[%]\\`*_{}()#+%-.!])"

---@param value string raw markdown returned by Roslyn's textDocument/hover
---@return string[] sig signature paragraph lines (markdown-unescaped, fences stripped)
---@return string[] rest remaining lines (markdown, unchanged)
function M.split(value)
	if type(value) ~= "string" or value == "" then
		return {}, {}
	end

	value = value:gsub("\r\n", "\n"):gsub("\r", "\n")

	local lines = vim.split(value, "\n", { plain = true })

	-- Roslyn wraps the signature paragraph in a ```csharp ... ``` fence.
	-- Strip the opening fence so the inner content reads as raw C#.
	local start_idx = 1
	if lines[start_idx] and lines[start_idx]:match("^%s*```%S*%s*$") then
		start_idx = start_idx + 1
	end

	-- Walk forward collecting signature lines until we hit either a blank
	-- line OR the closing ``` fence — whichever comes first.
	local sig = {}
	local consumed_to = start_idx - 1
	for i = start_idx, #lines do
		local line = lines[i]
		if line:match("^%s*```%s*$") then
			consumed_to = i
			break
		end
		if line:match("^%s*$") then
			consumed_to = i - 1
			break
		end
		sig[#sig + 1] = (line:gsub(ESCAPED_PUNCT, "%1"))
		consumed_to = i
	end

	if #sig == 0 then
		return {}, lines
	end

	-- Roslyn also escapes `<` and `>` inside body prose (e.g. unresolved
	-- doc-comment references), but noice's conceal list doesn't cover
	-- angle brackets, so they render as visible `\<` / `\>`. Other markdown
	-- escapes noice handles via its own conceal pass — leave those alone
	-- so legitimately-escaped `*` / `_` / etc. still survive.
	local rest = {}
	for i = consumed_to + 1, #lines do
		rest[#rest + 1] = (lines[i]:gsub("\\([<>])", "%1"))
	end
	return sig, rest
end

return M
