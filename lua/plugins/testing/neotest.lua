return {
    {
        'nvim-neotest/neotest',
        dependencies = {
            'nvim-neotest/nvim-nio',
            'nvim-lua/plenary.nvim',
            'antoinemadec/FixCursorHold.nvim',
            'nvim-treesitter/nvim-treesitter',
            'Issafalcon/neotest-dotnet',
        },
        lazy = true,
        keys = {
            {
                "<leader>tn",
                function()
                    require("neotest").run.run()
                end,
                desc = "Run nearest test",
            },
            {
                "<leader>tf",
                function()
                    require("neotest").run.run(
                        vim.fn.expand("%"))
                end,
                desc = "Run test file",
            },
            {
                "<leader>ta",
                function()
                    -- Pre-load test file buffers so neotest
                    -- can parse positions with treesitter.
                    -- local test_files = vim.fn.glob(
                    --     vim.fn.getcwd()
                    --         .. "/**/tests/**/*Tests.cs",
                    --     false, true)
                    -- for _, f in ipairs(test_files) do
                    --     local normalized = f:gsub("/", "\\")
                    --     if vim.fn.bufnr(normalized) == -1 then
                    --         vim.fn.bufadd(normalized)
                    --         vim.fn.bufload(normalized)
                    --     end
                    -- end
                    require("neotest").run.run(
                        vim.fn.getcwd())
                end,
                desc = "Run all tests",
            },
            {
                "<leader>to",
                function()
                    require("neotest").output_panel.toggle()
                end,
                desc = "Toggle test output panel",
            },
            {
                "<leader>tp",
                function()
                    require("neotest").summary.toggle()
                end,
                desc = "Toggle test summary",
            },
            {
                "<leader>tl",
                function()
                    require("neotest").run.run_last()
                end,
                desc = "Run last test",
            },
        },
        config = function()
            local runsettings = vim.fn.getcwd()
                .. "/coverage.runsettings"
            local use_runsettings =
                vim.fn.filereadable(runsettings) == 1
            local adapter = require("neotest-dotnet")({
                dotnet_additional_args = use_runsettings
                    and {
                        "--settings:" .. runsettings,
                    }
                    or {
                        '--collect:"XPlat Code Coverage"',
                    },
            })
            local lib = require("neotest.lib")
            adapter.root = function(path)
                return lib.files.match_root_pattern(
                        "*.sln")(path)
                    or lib.files.match_root_pattern(
                        ".git")(path)
            end
            require("neotest").setup({
                adapters = { adapter },
            })
        end,
    },
}
