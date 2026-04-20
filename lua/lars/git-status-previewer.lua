-- Custom telescope previewer for git_status that shows staged and unstaged
-- diffs separately with clear section headers and diff highlighting.
-- All git commands run asynchronously to avoid blocking the UI.

local previewers = require("telescope.previewers")

--- Normalize a path to forward slashes and lowercase for comparison on Windows.
---@param p string
---@return string
local function norm(p)
    return vim.fs.normalize(p):gsub("\\", "/")
end

--- Cancel all in-flight jobs tracked on the previewer instance.
---@param self table
local function cancel_jobs(self)
    if self._jobs then
        for _, job in ipairs(self._jobs) do
            if not job.is_shutdown then
                pcall(function() job:shutdown() end)
            end
        end
    end
    self._jobs = {}
end

--- Safely write lines to the preview buffer, checking validity first.
---@param bufnr number
---@param lines string[]
---@param filetype string|nil
local function safe_buf_write(bufnr, lines, filetype)
    vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(bufnr) then return end
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        if filetype then
            vim.bo[bufnr].filetype = filetype
        end
    end)
end

--- Spawn an async git command via vim.system (Neovim 0.10+).
--- Returns the SystemObj so it can be cancelled.
---@param args string[] git subcommand args (without "git" prefix)
---@param cwd string working directory
---@param callback fun(lines: string[]) called with output lines on completion
---@return vim.SystemObj
local function async_git(args, cwd, callback)
    local cmd = vim.list_extend({ "git", "-C", cwd }, args)
    return vim.system(cmd, { text = true }, function(result)
        local lines = {}
        if result.code == 0 and result.stdout and result.stdout ~= "" then
            lines = vim.split(result.stdout, "\n", { trimempty = true })
        end
        callback(lines)
    end)
end

return function()
    return previewers.new_buffer_previewer({
        title = "Staged / Unstaged Diff",

        define_preview = function(self, entry)
            local abs_path = entry.path
            if not abs_path or abs_path == "" then return end

            -- Cancel any previous in-flight jobs
            cancel_jobs(self)

            local bufnr = self.state.bufnr

            -- Show loading indicator immediately
            safe_buf_write(bufnr, { "Loading..." }, nil)

            -- Step 1: async git rev-parse to get the repo root
            local dir = vim.fn.fnamemodify(abs_path, ":h")
            local job = async_git({ "rev-parse", "--show-toplevel" }, dir, function(roots)
                local cwd = (roots[1] and roots[1] ~= "") and roots[1] or vim.fn.getcwd()

                -- Build relative path by stripping cwd prefix
                local norm_cwd = norm(cwd)
                local norm_abs = norm(abs_path)
                local file
                if norm_abs:lower():sub(1, #norm_cwd) == norm_cwd:lower() then
                    file = norm_abs:sub(#norm_cwd + 2) -- skip the trailing /
                else
                    file = norm_abs
                end
                if not file or file == "" then return end

                -- Step 2: run staged and unstaged diffs in parallel
                local staged_lines = nil
                local unstaged_lines = nil
                local completed = 0

                local function on_both_done()
                    completed = completed + 1
                    if completed < 2 then return end

                    -- Compose final output
                    local lines = {}

                    if #staged_lines == 0 and #unstaged_lines == 0 then
                        -- Untracked file: read contents synchronously (local I/O)
                        vim.schedule(function()
                            if not vim.api.nvim_buf_is_valid(bufnr) then return end
                            local content = {}
                            if vim.fn.filereadable(abs_path) == 1 then
                                table.insert(content, "══ NEW FILE (untracked) ══")
                                table.insert(content, "")
                                vim.list_extend(content, vim.fn.readfile(abs_path, "", 200))
                            end
                            if #content == 0 then
                                content = { "(no diff)" }
                            end
                            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
                            vim.bo[bufnr].filetype = "diff"
                        end)
                        return
                    end

                    if #staged_lines > 0 then
                        table.insert(lines, "══ STAGED ══")
                        table.insert(lines, "")
                        vim.list_extend(lines, staged_lines)
                    end

                    if #staged_lines > 0 and #unstaged_lines > 0 then
                        table.insert(lines, "")
                    end

                    if #unstaged_lines > 0 then
                        table.insert(lines, "══ UNSTAGED ══")
                        table.insert(lines, "")
                        vim.list_extend(lines, unstaged_lines)
                    end

                    if #lines == 0 then
                        lines = { "(no diff)" }
                    end

                    safe_buf_write(bufnr, lines, "diff")
                end

                local job_staged = async_git({ "diff", "--cached", "--", file }, cwd, function(result)
                    staged_lines = result
                    on_both_done()
                end)
                table.insert(self._jobs, job_staged)

                local job_unstaged = async_git({ "diff", "--", file }, cwd, function(result)
                    unstaged_lines = result
                    on_both_done()
                end)
                table.insert(self._jobs, job_unstaged)
            end)
            table.insert(self._jobs, job)
        end,

        teardown = function(self)
            cancel_jobs(self)
        end,
    })
end
