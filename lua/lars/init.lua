require("lars.autocommands")
require("lars.keymap")
require("lars.options")
require("lars.plugin-load")


local function get_git_root()
    local dot_git_path = vim.fn.finddir(".git", ".;")
    return vim.fn.fnamemodify(dot_git_path, ":h")
end

vim.api.nvim_create_user_command("CdGitRoot", function()
    vim.api.nvim_set_current_dir(get_git_root())
end, {})
