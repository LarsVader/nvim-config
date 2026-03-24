-- LSP integration tests — verify each configured server starts and attaches
--
-- Cannot use plenary busted (synchronous) because LSP servers need the event
-- loop to run for 10-30 seconds. This script runs standalone:
--
--   cd ~/AppData/Local/nvim
--   nvim --headless -u tests/minimal_init.lua +"luafile tests/lsp_integration.lua"
--
-- Output format matches plenary so run_lsp.sh can parse pass/fail.

local configdir = vim.fn.stdpath("config"):gsub("\\", "/")
local fixtures = configdir .. "/tests/fixtures"

--- LSP servers to test. Each entry:
---   name      = lspconfig server name (must match get_clients() result)
---   file      = fixture file to open (triggers filetype → LSP attach)
---   cwd       = directory to cd into before opening (isolates root_dir)
---   timeout   = max seconds to wait for attach
---   skip_if   = optional function; return true to skip (e.g. missing toolchain)
local servers = {
    {
        name = "roslyn",
        file = fixtures .. "/cs/Test.cs",
        cwd = fixtures .. "/cs",
        timeout = 60,
        skip_if = function()
            return vim.fn.executable("dotnet") == 0
        end,
    },
    -- Add more servers here as they are configured, e.g.:
    -- {
    --     name = "rust_analyzer",
    --     file = fixtures .. "/rs/src/lib.rs",
    --     cwd = fixtures .. "/rs",
    --     timeout = 20,
    --     skip_if = function()
    --         return vim.fn.executable("rust-analyzer") == 0
    --     end,
    -- },
}

-- ── Test runner ────────────────────────────────────────────────────────

local passed = 0
local failed = 0
local skipped = 0
local results = {}
local original_cwd = vim.fn.getcwd()

local function log(msg)
    io.stdout:write(msg .. "\n")
    io.stdout:flush()
end

local function run_next(index)
    if index > #servers then
        -- Restore original cwd
        vim.api.nvim_set_current_dir(original_cwd)

        -- Print summary
        log("")
        log("========================================")
        log("LSP integration results")
        log("========================================")
        for _, r in ipairs(results) do
            log(r)
        end
        log("")
        log("Success: " .. passed)
        log("Failed : " .. failed)
        log("Skipped: " .. skipped)
        -- These lines are what run_lsp.sh greps for
        log("Errors : 0")
        log("Failed : " .. failed)
        vim.cmd("qa!")
        return
    end

    local srv = servers[index]

    if srv.skip_if and srv.skip_if() then
        local msg = "  SKIP: " .. srv.name .. " (prerequisite missing)"
        log(msg)
        table.insert(results, msg)
        skipped = skipped + 1
        run_next(index + 1)
        return
    end

    log("  Testing " .. srv.name .. " (timeout " .. srv.timeout .. "s) ...")

    -- Isolate root_dir: cd to the fixture directory so lspconfig's
    -- root_pattern doesn't walk up and find unrelated .sln/.csproj files
    if srv.cwd then
        vim.api.nvim_set_current_dir(srv.cwd)
    end

    -- Open the fixture file in a fresh buffer
    vim.cmd("edit " .. srv.file)

    -- Ensure filetype is detected
    if vim.bo.filetype == "" then
        vim.cmd("filetype detect")
    end

    log("    filetype=" .. vim.bo.filetype)

    -- Poll for client attachment
    local elapsed = 0
    local poll_interval = 3 -- seconds

    local function poll()
        elapsed = elapsed + poll_interval
        local clients = vim.lsp.get_clients({ name = srv.name })
        local attached = false
        for _, c in ipairs(clients) do
            if c.initialized then
                attached = true
                break
            end
        end

        if attached then
            local msg = "  PASS: " .. srv.name
                .. " attached after ~" .. elapsed .. "s"
            log(msg)
            table.insert(results, msg)
            passed = passed + 1
            -- Stop the client and close buffer before next test
            for _, c in ipairs(vim.lsp.get_clients({ name = srv.name })) do
                vim.lsp.stop_client(c.id)
            end
            vim.cmd("bdelete!")
            vim.defer_fn(function() run_next(index + 1) end, 2000)
        elseif elapsed >= srv.timeout then
            -- Show what we do have for debugging
            local all = vim.lsp.get_clients()
            local debug_info = " (all_clients=" .. #all
            for _, c in ipairs(all) do
                debug_info = debug_info .. " " .. c.name
                    .. ":init=" .. tostring(c.initialized)
            end
            debug_info = debug_info .. ")"

            local msg = "  FAIL: " .. srv.name
                .. " did not attach within " .. srv.timeout .. "s"
                .. debug_info
            log(msg)
            table.insert(results, msg)
            failed = failed + 1
            vim.cmd("bdelete!")
            vim.defer_fn(function() run_next(index + 1) end, 2000)
        else
            if elapsed % 15 == 0 then
                local all = vim.lsp.get_clients()
                log("    " .. elapsed .. "s: " .. #all .. " client(s)")
            end
            vim.defer_fn(poll, poll_interval * 1000)
        end
    end

    vim.defer_fn(poll, poll_interval * 1000)
end

log("LSP integration tests")
log("----------------------------------------")
run_next(1)
