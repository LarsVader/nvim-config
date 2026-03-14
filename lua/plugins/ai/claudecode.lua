return {
    {
        'coder/claudecode.nvim',
        opts = {
            terminal = {
                provider = 'native',
                split_side = 'right',
                split_width_percentage = 0.35,
                auto_close = true,
            },
        },
        keys = {
            { '<leader>ac', '<cmd>ClaudeCode<cr>',            desc = 'Toggle Claude' },
            { '<leader>af', '<cmd>ClaudeCodeFocus<cr>',       desc = 'Focus Claude' },
            { '<leader>ar', '<cmd>ClaudeCode --resume<cr>',   desc = 'Resume Claude' },
            { '<leader>ab', '<cmd>ClaudeCodeAdd %<cr>',       desc = 'Add buffer to Claude' },
            { '<leader>as', '<cmd>ClaudeCodeSend<cr>',        mode = 'v', desc = 'Send selection to Claude' },
            { '<leader>aa', '<cmd>ClaudeCodeDiffAccept<cr>',  desc = 'Accept diff' },
            { '<leader>ad', '<cmd>ClaudeCodeDiffDeny<cr>',    desc = 'Deny diff' },
        },
    },
}
