-- Shared test utilities
local M = {}

--- Search nvim_get_keymap for a mapping matching the given lhs
---@param mode string "n", "i", "v", "t", etc.
---@param lhs string the left-hand side to find (e.g. "<leader>ff")
---@return table|nil the keymap entry, or nil if not found
function M.find_keymap(mode, lhs)
    -- Normalize: expand <leader> to the actual leader key
    local leader = vim.g.mapleader or "\\"
    local normalized = lhs:gsub("<[Ll]eader>", leader)

    -- nvim_get_keymap stores <C-x> as <C-X> (uppercase letter after modifier)
    normalized = normalized:gsub("(<[CSMcsm]%-)(%a)(>)", function(pre, letter, post)
        return pre:upper() .. letter:upper() .. post
    end)

    for _, km in ipairs(vim.api.nvim_get_keymap(mode)) do
        if km.lhs == normalized then
            return km
        end
    end
    return nil
end

--- Check whether a keymap exists
---@param mode string
---@param lhs string
---@return boolean
function M.has_keymap(mode, lhs)
    return M.find_keymap(mode, lhs) ~= nil
end

--- Feed keys into Neovim (for behavioral tests)
---@param keys string raw key notation like "<C-d>" or "iHello<Esc>"
---@param mode? string feedkeys mode, defaults to "x" (execute immediately)
function M.feed(keys, mode)
    mode = mode or "x"
    local termcodes = vim.api.nvim_replace_termcodes(keys, true, false, true)
    vim.api.nvim_feedkeys(termcodes, mode, false)
end

--- Get all lines in the current buffer
---@return string[]
function M.get_buf_lines()
    return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

--- Set the current buffer contents
---@param lines string[]
function M.set_buf_lines(lines)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

--- Force-load a lazy.nvim plugin by name
---@param name string plugin name as registered in lazy.nvim
---@return boolean success
---@return string|nil error message
function M.force_load_plugin(name)
    local ok, err = pcall(function()
        require("lazy").load({ plugins = { name } })
    end)
    return ok, err
end

return M
