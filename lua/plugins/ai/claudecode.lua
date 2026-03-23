return {
    {
        'greggh/claude-code.nvim',
        dependencies = {
            'nvim-lua/plenary.nvim',
        },
        opts = {
            window = {
                width_ratio = 0.33,
                position = 'float',
                enter_insert = true,
                hide_numbers = true,
                hide_signcolumn = true,
            },
            refresh = {
                enable = true,
                updatetime = 100,
                timer_interval = 1000,
                show_notifications = true,
            },
        },
        keys = {
            { '<C-,>', '<cmd>ClaudeCode<cr>',           desc = 'Toggle Claude' },
            { '<leader>ar', '<cmd>ClaudeCodeResume<cr>',  desc = 'Resume Claude' },
            { '<leader>as', '<cmd>ClaudeCodeSend<cr>',       mode = 'v', desc = 'Send selection to Claude' },
            { '<leader>ad', '<cmd>ClaudeCodeDiff<cr>',       desc = 'View Claude diff' },
        },
    },
}
