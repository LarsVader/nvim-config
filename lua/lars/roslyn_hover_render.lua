-- Roslyn-aware renderer for a noice hover Message.
-- Extracted from the on_hover patch so go_back can call it directly,
-- skipping noice's focus-already-open short-circuit.
local M = {}

---@param message NoiceMessage clean noice message (already cleared)
---@param content_str string raw markdown value from Roslyn's hover
---@param ft string filetype to apply as syntax over the signature lines
---@return boolean true when the signature paragraph was rendered
function M.render(message, content_str, ft)
	local split = require("lars.roslyn_hover_format").split
	local Format = require("noice.lsp.format")
	local Markdown = require("noice.text.markdown")
	local NoiceText = require("noice.text")

	local sig_lines, rest_lines = split(content_str)
	if #sig_lines == 0 then
		return false
	end

	local count = message:height()
	for i, line in ipairs(sig_lines) do
		message:append(line)
		if i < #sig_lines then
			message:newline()
		end
	end
	message:append(NoiceText.syntax(ft, message:height() - count))

	if #rest_lines > 0 then
		message:newline()
		Markdown.horizontal_line(message)
		Format.format(message, table.concat(rest_lines, "\n"), { ft = ft })
	end

	return not message:is_empty()
end

return M
