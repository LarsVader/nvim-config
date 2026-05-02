return {
    {
        'greggh/claude-code.nvim',
        dependencies = {
            'nvim-lua/plenary.nvim',
        },
        opts = {
            -- Launch claude with low priority and CPU affinity restricted
            -- to logical processors 1-3 (mask 0xE), leaving logical
            -- processor 0 free for the OS / foreground apps. /LOW and
            -- /AFFINITY are inherited by all descendants (dotnet build,
            -- tests, etc.), so the whole process tree is throttled.
            -- command = 'cmd /c start "" /B /WAIT /LOW /AFFINITY E claude',
            window = {
                split_ratio = 0.4,
                position = 'botright vsplit',
                enter_insert = true,
                hide_numbers = true,
                hide_signcolumn = true,
            },
            refresh = {
                enable = false,
            },
        },
        config = function(_, opts)
            require('claude-code').setup(opts)

            -- Custom file refresh: poll every 5s, but ONLY when no
            -- Claude terminal is visible in any window. This avoids the
            -- TUI repaint + :terminal viewport interaction that causes
            -- the scroll-through-transcript jank while Claude is on screen.
            local group = vim.api.nvim_create_augroup('ClaudeCodeCustomRefresh', { clear = true })

            local function is_claude_visible()
				return true;
				-- not working code:
                -- local ok, cc = pcall(require, 'claude-code')
                -- if not ok or not cc.claude_code or not cc.claude_code.instances then
                --     return false
                -- end
                -- -- Collect all Claude buffer numbers
                -- local claude_bufs = {}
                -- for _, bufnr in pairs(cc.claude_code.instances) do
                --     claude_bufs[bufnr] = true
                -- end
                -- -- Check if any visible window shows a Claude buffer
                -- for _, win in ipairs(vim.api.nvim_list_wins()) do
                --     if claude_bufs[vim.api.nvim_win_get_buf(win)] then
                --         return true
                --     end
                -- end
                -- return false
            end

            local function maybe_checktime()
                if not is_claude_visible() then
                    vim.cmd('silent! checktime')
                end
            end

            -- Immediate check when entering a buffer or refocusing nvim
            -- (only fires when the focused window is not Claude).
            vim.api.nvim_create_autocmd({ 'BufEnter', 'FocusGained' }, {
                group = group,
                callback = maybe_checktime,
                desc = 'Check file timestamps when Claude is not visible',
            })

            -- Background poll every 5s while Claude is hidden.
            local timer = vim.loop.new_timer()
            if timer then
                timer:start(5000, 5000, vim.schedule_wrap(maybe_checktime))
            end
        end,
        keys = {
            { '<C-,>', '<cmd>ClaudeCode<cr>',           desc = 'Toggle Claude' },
            { '<leader>ar', '<cmd>ClaudeCodeResume<cr>',  desc = 'Resume Claude' },
            { '<leader>as', '<cmd>ClaudeCodeSend<cr>',       mode = 'v', desc = 'Send selection to Claude' },
            { '<leader>ad', '<cmd>ClaudeCodeDiff<cr>',       desc = 'View Claude diff' },
            {
                '<leader>ak',
                function()
                    local cc = require('claude-code')
                    local bufnr = cc.claude_code.instances and cc.claude_code.instances.global
                    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
                        pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
                        vim.notify('Claude killed', vim.log.levels.INFO)
                    else
                        vim.notify('No Claude instance running', vim.log.levels.WARN)
                    end
                end,
                desc = 'Kill Claude terminal',
            },
        },
    },
}
