-- Custom Telescope pickers for multi-submodule git operations:
--   <leader>gS  Commit in selected dirty submodules
--   <leader>gC  Checkout branch in selected submodules

local function get_all_submodules()
    local result = vim.fn.systemlist({
        "git", "submodule", "status",
    })
    if vim.v.shell_error ~= 0 then
        return {}
    end
    local subs = {}
    for _, line in ipairs(result) do
        local path = line:match("^[%s%+%-U]*%x+%s+(%S+)")
        if path and path ~= "" then
            -- Get current branch
            local branch_lines = vim.fn.systemlist({
                "git", "-C", path, "rev-parse", "--abbrev-ref", "HEAD",
            })
            local branch = (branch_lines[1] or "detached"):gsub("%s+$", "")
            table.insert(subs, { name = path, branch = branch })
        end
    end
    return subs
end

--- Build the status summary lines for the right-side float.
---@param names string[] submodule paths
---@return string[]
local function build_diff_summary(names)
    local lines = {}
    for i, name in ipairs(names) do
        if i > 1 then table.insert(lines, "") end
        table.insert(lines, "── " .. name .. " ──")
        -- Show full diff (staged + unstaged)
        local diff = vim.fn.systemlist({ "git", "-C", name, "diff", "HEAD" })
        if #diff == 0 then
            -- Maybe only untracked files
            local status = vim.fn.systemlist({ "git", "-C", name, "status", "--short" })
            if #status == 0 then
                table.insert(lines, "(no changes)")
            else
                for _, s in ipairs(status) do
                    table.insert(lines, s)
                end
            end
        else
            vim.list_extend(lines, diff)
        end
    end
    return lines
end

--- Execute git commit -am in each submodule, then update parent refs.
---@param names string[] submodule paths
---@param msg string commit message
local function do_submodule_commits(names, msg)
    local errors = {}
    local succeeded = {}
    local pending = #names
    local done_count = 0

    for _, name in ipairs(names) do
        vim.system(
            { "git", "-C", name, "commit", "-am", msg },
            { text = true },
            function(result)
                vim.schedule(function()
                    done_count = done_count + 1
                    if result.code == 0 then
                        table.insert(succeeded, name)
                    else
                        table.insert(errors, name .. ": " .. (result.stderr or "unknown error"))
                    end

                    if done_count == pending then
                        if #succeeded > 0 then
                            vim.notify(
                                "Committed in " .. #succeeded .. " submodule(s): " .. table.concat(succeeded, ", "),
                                vim.log.levels.INFO
                            )
                        end
                        if #errors > 0 then
                            vim.notify(
                                "Errors:\n" .. table.concat(errors, "\n"),
                                vim.log.levels.ERROR
                            )
                        end
                    end
                end)
            end
        )
    end
end

--- Open two side-by-side floats: left = commit message editor, right = status summary.
--- :wq on the commit buffer triggers the commits.
---@param names string[] submodule paths
local function open_commit_float(names)
    -- Build full diff for the right panel
    local diff_lines = build_diff_summary(names)

    -- Create commit message buffer (left)
    -- buftype=acwrite + a buffer name so :w triggers BufWriteCmd without E32
    local commit_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(commit_buf, "SUBMODULE_COMMIT_MSG")
    local header = {
        "",
        "# Submodule commit: " .. table.concat(names, ", "),
        "# Write your commit message above, then :wq to commit.",
        "# Close or leave empty to cancel.",
    }
    vim.api.nvim_buf_set_lines(commit_buf, 0, -1, false, header)
    vim.bo[commit_buf].filetype = "gitcommit"
    vim.bo[commit_buf].bufhidden = "wipe"
    vim.bo[commit_buf].buftype = "acwrite"
    vim.bo[commit_buf].modifiable = true

    -- Create diff buffer (right)
    local status_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(status_buf, 0, -1, false, diff_lines)
    vim.bo[status_buf].modifiable = false
    vim.bo[status_buf].bufhidden = "wipe"
    vim.bo[status_buf].filetype = "diff"

    -- Layout: two side-by-side floats matching fugitive's commit style
    local total_w = math.floor(vim.o.columns * 0.9)
    local h = math.floor(vim.o.lines * 0.9)
    local commit_w = math.floor(total_w * 0.5)
    local status_w = total_w - commit_w - 2
    local row = math.floor((vim.o.lines - h) / 2)
    local col = math.floor((vim.o.columns - total_w) / 2)

    local commit_float = vim.api.nvim_open_win(commit_buf, true, {
        relative = "editor",
        width = commit_w, height = h,
        col = col, row = row,
        style = "minimal", border = "rounded",
        title = " Commit Message ", title_pos = "center",
    })

    local status_float = vim.api.nvim_open_win(status_buf, false, {
        relative = "editor",
        width = status_w, height = h,
        col = col + commit_w + 2, row = row,
        style = "minimal", border = "rounded",
        title = " Changes ", title_pos = "center",
    })

    -- Focus commit editor, cursor on first line
    vim.api.nvim_set_current_win(commit_float)
    vim.api.nvim_win_set_cursor(commit_float, { 1, 0 })
    vim.cmd("startinsert")

    -- Navigation between the two floats
    for _, map in ipairs({ "<C-w>w", "<C-w><C-w>", "<C-l>" }) do
        vim.keymap.set("n", map, function()
            if vim.api.nvim_win_is_valid(status_float) then
                vim.api.nvim_set_current_win(status_float)
            end
        end, { buffer = commit_buf })
    end
    for _, map in ipairs({ "<C-w>w", "<C-w><C-w>", "<C-h>" }) do
        vim.keymap.set("n", map, function()
            if vim.api.nvim_win_is_valid(commit_float) then
                vim.api.nvim_set_current_win(commit_float)
            end
        end, { buffer = status_buf })
    end

    -- Pending commit message: set by BufWriteCmd, consumed by WinClosed.
    local pending_msg = nil

    -- BufWriteCmd: extract the message and mark buffer saved.
    -- Do NOT close any windows — let :q (from :wq) close the commit float
    -- naturally, which fires WinClosed to clean up and run the commit.
    vim.api.nvim_create_autocmd("BufWriteCmd", {
        buffer = commit_buf,
        callback = function()
            local lines = vim.api.nvim_buf_get_lines(commit_buf, 0, -1, false)
            local msg_lines = {}
            for _, line in ipairs(lines) do
                if not line:match("^#") then
                    table.insert(msg_lines, line)
                end
            end
            while #msg_lines > 0 and msg_lines[1]:match("^%s*$") do
                table.remove(msg_lines, 1)
            end
            while #msg_lines > 0 and msg_lines[#msg_lines]:match("^%s*$") do
                table.remove(msg_lines)
            end
            pending_msg = table.concat(msg_lines, "\n")
            vim.bo[commit_buf].modified = false
        end,
    })

    -- WinClosed: when either float closes, clean up the other and
    -- run the commit if a message was written.
    local cleanup_group = vim.api.nvim_create_augroup("SubmoduleCommitCleanup", { clear = true })
    vim.api.nvim_create_autocmd("WinClosed", {
        group = cleanup_group,
        callback = function()
            vim.schedule(function()
                local commit_gone = not vim.api.nvim_win_is_valid(commit_float)
                local status_gone = not vim.api.nvim_win_is_valid(status_float)
                if not commit_gone and not status_gone then return end

                -- Delete the augroup FIRST to prevent re-entry when
                -- closing the other float triggers another WinClosed
                pcall(vim.api.nvim_del_augroup_by_name, "SubmoduleCommitCleanup")
                local msg = pending_msg
                pending_msg = nil

                if vim.api.nvim_win_is_valid(status_float) then
                    vim.api.nvim_win_close(status_float, true)
                end
                if vim.api.nvim_win_is_valid(commit_float) then
                    vim.api.nvim_win_close(commit_float, true)
                end

                if msg and msg ~= "" then
                    do_submodule_commits(names, msg)
                elseif msg == "" then
                    vim.notify("Empty commit message, cancelled", vim.log.levels.INFO)
                end
            end)
        end,
    })
end

--- Get all submodules with dirty status info (async), sorted dirty-first.
--- Calls callback(entries) when done.
---@param callback fun(entries: table[])
local function get_all_submodules_with_status(callback)
    vim.system(
        { "git", "submodule", "status" },
        { text = true },
        function(sm_result)
            vim.schedule(function()
                if sm_result.code ~= 0 or not sm_result.stdout or sm_result.stdout == "" then
                    callback({})
                    return
                end

                local paths = {}
                for _, line in ipairs(vim.split(sm_result.stdout, "\n", { trimempty = true })) do
                    local path = line:match("^[%s%+%-U]*%x+%s+(%S+)")
                    if path and path ~= "" then
                        table.insert(paths, path)
                    end
                end

                if #paths == 0 then
                    callback({})
                    return
                end

                local entries = {}
                -- 2 async calls per submodule: status + branch
                local pending = #paths * 2
                local status_map = {}  -- path -> status_lines
                local branch_map = {}  -- path -> branch name
                local function maybe_finish()
                    pending = pending - 1
                    if pending > 0 then return end
                    for _, path in ipairs(paths) do
                        local status_lines = status_map[path] or {}
                        local is_dirty = #status_lines > 0
                        local summary = is_dirty and string.format(" (%d changed)", #status_lines) or ""
                        local branch = branch_map[path] or "detached"
                        table.insert(entries, {
                            name = path, summary = summary,
                            dirty = is_dirty, branch = branch,
                        })
                    end
                    table.sort(entries, function(a, b)
                        if a.dirty ~= b.dirty then return a.dirty end
                        return a.name < b.name
                    end)
                    callback(entries)
                end

                for _, path in ipairs(paths) do
                    vim.system(
                        { "git", "-C", path, "status", "--porcelain" },
                        { text = true },
                        function(res)
                            vim.schedule(function()
                                if res.code == 0 and res.stdout and res.stdout ~= "" then
                                    status_map[path] = vim.split(res.stdout, "\n", { trimempty = true })
                                else
                                    status_map[path] = {}
                                end
                                maybe_finish()
                            end)
                        end
                    )
                    vim.system(
                        { "git", "-C", path, "rev-parse", "--abbrev-ref", "HEAD" },
                        { text = true },
                        function(res)
                            vim.schedule(function()
                                if res.code == 0 and res.stdout then
                                    branch_map[path] = vim.trim(res.stdout)
                                end
                                maybe_finish()
                            end)
                        end
                    )
                end
            end)
        end
    )
end

local function submodule_commit_picker()
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local previewers = require("telescope.previewers")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    get_all_submodules_with_status(function(subs)
    if #subs == 0 then
        vim.notify("No submodules found", vim.log.levels.INFO)
        return
    end

    pickers.new({}, {
        prompt_title = "Submodule Commit: select dirty submodules (<C-t> to multi-select)",
        finder = finders.new_table({
            results = subs,
            entry_maker = function(entry)
                local prefix = entry.dirty and "" or "  "
                local main = prefix .. entry.name .. entry.summary
                local branch_part = "  " .. entry.branch
                local full = main .. branch_part
                return {
                    value = entry,
                    display = function()
                        return full, { { { #main, #full }, "TelescopeResultsComment" } }
                    end,
                    ordinal = entry.name,
                }
            end,
        }),
        sorter = conf.generic_sorter({}),
        previewer = previewers.new_buffer_previewer({
            title = "Submodule Diff",
            define_preview = function(self, entry)
                if self._preview_job then
                    self._preview_job:kill()
                    self._preview_job = nil
                end

                local bufnr = self.state.bufnr
                local name = entry.value.name

                if not entry.value.dirty then
                    if vim.api.nvim_buf_is_valid(bufnr) then
                        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "(no changes)" })
                    end
                    return
                end

                if vim.api.nvim_buf_is_valid(bufnr) then
                    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Loading..." })
                end

                self._preview_job = vim.system(
                    { "git", "-C", name, "diff", "HEAD" },
                    { text = true },
                    function(result)
                        vim.schedule(function()
                            if not vim.api.nvim_buf_is_valid(bufnr) then return end
                            local lines
                            if result.code ~= 0 or not result.stdout or result.stdout == "" then
                                -- Fall back to status for untracked-only changes
                                local status = vim.fn.systemlist({ "git", "-C", name, "status", "--short" })
                                lines = #status > 0 and status or { "(no diff output)" }
                            else
                                lines = vim.split(result.stdout, "\n", { trimempty = true })
                            end
                            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
                            vim.bo[bufnr].filetype = "diff"
                        end)
                    end
                )
            end,
        }),
        attach_mappings = function(prompt_bufnr)
            -- Block multi-select toggle on clean submodules
            -- Use vim.schedule to override AFTER telescope sets up its default mappings
            vim.schedule(function()
                if not vim.api.nvim_buf_is_valid(prompt_bufnr) then return end
                vim.keymap.set({ "i", "n" }, "<C-t>", function()
                    local entry = action_state.get_selected_entry()
                    if entry and not entry.value.dirty then
                        vim.notify("Cannot select clean submodule: " .. entry.value.name, vim.log.levels.WARN)
                        return
                    end
                    actions.toggle_selection(prompt_bufnr)
                    actions.move_selection_worse(prompt_bufnr)
                end, { buffer = prompt_bufnr })
            end)

            actions.select_default:replace(function()
                local picker = action_state.get_current_picker(prompt_bufnr)
                local selections = picker:get_multi_selection()
                -- If no multi-selection, use the current entry
                if #selections == 0 then
                    local entry = action_state.get_selected_entry()
                    if entry then
                        if not entry.value.dirty then
                            vim.notify("Cannot select clean submodule: " .. entry.value.name, vim.log.levels.WARN)
                            return
                        end
                        selections = { entry }
                    end
                end
                actions.close(prompt_bufnr)

                if #selections == 0 then
                    vim.notify("No submodules selected", vim.log.levels.WARN)
                    return
                end

                local names = {}
                for _, sel in ipairs(selections) do
                    table.insert(names, sel.value.name)
                end

                open_commit_float(names)
            end)
            return true
        end,
    }):find()
    end) -- get_all_submodules_with_status callback
end

local function submodule_checkout_picker()
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    local subs = get_all_submodules()
    if #subs == 0 then
        vim.notify("No submodules found", vim.log.levels.INFO)
        return
    end

    pickers.new({}, {
        prompt_title = "Submodule Checkout: select submodules (<C-t> to multi-select)",
        finder = finders.new_table({
            results = subs,
            entry_maker = function(entry)
                local display = entry.name .. " [" .. entry.branch .. "]"
                return {
                    value = entry,
                    display = display,
                    ordinal = entry.name,
                }
            end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr)
            actions.select_default:replace(function()
                local picker = action_state.get_current_picker(prompt_bufnr)
                local selections = picker:get_multi_selection()
                if #selections == 0 then
                    local entry = action_state.get_selected_entry()
                    if entry then
                        selections = { entry }
                    end
                end
                actions.close(prompt_bufnr)

                if #selections == 0 then
                    vim.notify("No submodules selected", vim.log.levels.WARN)
                    return
                end

                local names = {}
                for _, sel in ipairs(selections) do
                    table.insert(names, sel.value.name)
                end

                vim.ui.input({ prompt = "Branch name: " }, function(branch)
                    if not branch or branch == "" then
                        vim.notify("Checkout cancelled", vim.log.levels.INFO)
                        return
                    end

                    local pending = #names
                    local done_count = 0
                    local results = {}

                    for _, name in ipairs(names) do
                        -- Try checkout existing branch first
                        vim.system(
                            { "git", "-C", name, "checkout", branch },
                            { text = true },
                            function(result)
                                if result.code == 0 then
                                    vim.schedule(function()
                                        done_count = done_count + 1
                                        table.insert(results, name .. ": checked out " .. branch)
                                        if done_count == pending then
                                            vim.notify(
                                                table.concat(results, "\n"),
                                                vim.log.levels.INFO
                                            )
                                        end
                                    end)
                                else
                                    -- Branch doesn't exist, try creating it
                                    vim.system(
                                        { "git", "-C", name, "checkout", "-b", branch },
                                        { text = true },
                                        function(create_result)
                                            vim.schedule(function()
                                                done_count = done_count + 1
                                                if create_result.code == 0 then
                                                    table.insert(results, name .. ": created and checked out " .. branch)
                                                else
                                                    table.insert(results, name .. ": FAILED - " .. (create_result.stderr or "unknown error"))
                                                end
                                                if done_count == pending then
                                                    local has_errors = false
                                                    for _, r in ipairs(results) do
                                                        if r:find("FAILED") then
                                                            has_errors = true
                                                            break
                                                        end
                                                    end
                                                    vim.notify(
                                                        table.concat(results, "\n"),
                                                        has_errors and vim.log.levels.WARN or vim.log.levels.INFO
                                                    )
                                                end
                                            end)
                                        end
                                    )
                                end
                            end
                        )
                    end
                end)
            end)
            return true
        end,
    }):find()
end

return {
    {
        "nvim-telescope/telescope.nvim",
        keys = {
            {
                "<leader>gS",
                submodule_commit_picker,
                desc = "Git submodule commit (multi-select)",
            },
            {
                "<leader>gC",
                submodule_checkout_picker,
                desc = "Git submodule checkout (multi-select)",
            },
        },
    },
}
