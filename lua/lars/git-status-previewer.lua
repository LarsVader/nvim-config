-- Custom telescope previewer for git_status that shows staged and unstaged
-- diffs separately with clear section headers and diff highlighting.

local previewers = require("telescope.previewers")

--- Normalize a path to forward slashes and lowercase for comparison on Windows.
---@param p string
---@return string
local function norm(p)
    return vim.fs.normalize(p):gsub("\\", "/")
end

return function()
    return previewers.new_buffer_previewer({
        title = "Staged / Unstaged Diff",

        define_preview = function(self, entry)
            local abs_path = entry.path
            if not abs_path or abs_path == "" then return end

            -- Determine cwd via git rev-parse from the file's directory
            local dir = vim.fn.fnamemodify(abs_path, ":h")
            local roots = vim.fn.systemlist({ "git", "-C", dir, "rev-parse", "--show-toplevel" })
            local cwd = (vim.v.shell_error == 0 and roots[1]) or vim.fn.getcwd()

            -- Build relative path by stripping cwd prefix (normalize slashes first)
            local norm_cwd = norm(cwd)
            local norm_abs = norm(abs_path)
            local file
            if norm_abs:lower():sub(1, #norm_cwd) == norm_cwd:lower() then
                file = norm_abs:sub(#norm_cwd + 2) -- skip the trailing /
            else
                file = norm_abs
            end
            if not file or file == "" then return end

            local lines = {}

            local staged = vim.fn.systemlist({ "git", "-C", cwd, "diff", "--cached", "--", file })
            local unstaged = vim.fn.systemlist({ "git", "-C", cwd, "diff", "--", file })

            -- For new untracked files, show the file contents
            if #staged == 0 and #unstaged == 0 then
                if vim.fn.filereadable(abs_path) == 1 then
                    table.insert(lines, "══ NEW FILE (untracked) ══")
                    table.insert(lines, "")
                    vim.list_extend(lines, vim.fn.readfile(abs_path, "", 200))
                end
            else
                if #staged > 0 then
                    table.insert(lines, "══ STAGED ══")
                    table.insert(lines, "")
                    vim.list_extend(lines, staged)
                end

                if #staged > 0 and #unstaged > 0 then
                    table.insert(lines, "")
                end

                if #unstaged > 0 then
                    table.insert(lines, "══ UNSTAGED ══")
                    table.insert(lines, "")
                    vim.list_extend(lines, unstaged)
                end
            end

            if #lines == 0 then
                lines = { "(no diff)" }
            end

            vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
            vim.bo[self.state.bufnr].filetype = "diff"
        end,
    })
end
