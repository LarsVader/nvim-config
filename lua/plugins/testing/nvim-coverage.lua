return {
    {
        'andythigpen/nvim-coverage',
        dependencies = { 'nvim-lua/plenary.nvim' },
        lazy = true,
        keys = {
            {
                "<leader>tC",
                function()
                    require("coverage").toggle()
                end,
                desc = "Toggle coverage signs",
            },
            {
                "<leader>tL",
                function()
                    require("coverage").load(true)
                end,
                desc = "Load coverage data",
            },
            {
                "<leader>tS",
                function()
                    require("coverage").summary()
                end,
                desc = "Coverage summary",
            },
        },
        config = function()
            local Path = require("plenary.path")
            local util = require("coverage.util")
            local cs_signs = require("coverage.signs")

            local function find_coverage_file()
                local glob = vim.fn.glob(
                    "**/{TestResults,test*}/**/coverage.cobertura.xml",
                    false, true)
                local tmp = vim.fn.stdpath("run")
                if tmp and tmp ~= "" then
                    local parent = vim.fn.fnamemodify(tmp, ":h")
                    local neotest_glob = vim.fn.glob(
                        parent
                            .. "/**/coverage.cobertura.xml",
                        false, true)
                    vim.list_extend(glob, neotest_glob)
                end
                if #glob == 0 then return nil end
                table.sort(glob, function(a, b)
                    return vim.fn.getftime(a)
                        > vim.fn.getftime(b)
                end)
                return glob[1]
            end

            local function parse_cobertura(path)
                local xml = require("neotest.lib.xml")
                local content = table.concat(
                    vim.fn.readfile(path), "\n")
                local parsed = xml.parse(content)
                if not parsed or not parsed.coverage then
                    return nil
                end

                local data = { files = {}, totals = {} }
                local cov = parsed.coverage
                data.totals = {
                    statements = tonumber(
                        cov._attr["lines-valid"]) or 0,
                    missing = (
                        tonumber(cov._attr["lines-valid"]) or 0)
                        - (tonumber(
                            cov._attr["lines-covered"]) or 0),
                    branches = tonumber(
                        cov._attr["branches-valid"]) or 0,
                    partial = (
                        tonumber(
                            cov._attr["branches-valid"]) or 0)
                        - (tonumber(
                            cov._attr["branches-covered"])
                            or 0),
                }
                local stmts = data.totals.statements
                data.totals.coverage = stmts > 0
                    and (1 - data.totals.missing / stmts) * 100
                    or 100

                local sources = {}
                local src = cov.sources and cov.sources.source
                if type(src) == "string" then
                    sources = { src }
                elseif type(src) == "table" then
                    if src[1] then
                        sources = src
                    elseif src._value then
                        sources = { src._value }
                    end
                end

                local packages = cov.packages
                    and cov.packages.package
                if not packages then return data end
                if packages._attr then
                    packages = { packages }
                end

                for _, pkg in ipairs(packages) do
                    local classes = pkg.classes
                        and pkg.classes.class
                    if not classes then goto continue_pkg end
                    if classes._attr then
                        classes = { classes }
                    end
                    for _, cls in ipairs(classes) do
                        local fname = cls._attr.filename
                        if not fname then
                            goto continue_cls
                        end
                        fname = fname:gsub("\\", "/")
                        local full = fname
                        for _, s in ipairs(sources) do
                            local base = s:gsub("\\", "/")
                                :gsub("/$", "")
                            local candidate = base
                                .. "/" .. fname
                            if Path:new(candidate):exists()
                            then
                                full = candidate
                                break
                            end
                        end

                        if not data.files[full] then
                            data.files[full] = {
                                lines = {},
                                totals = {
                                    line = {
                                        covered = 0,
                                        missed = 0,
                                    },
                                    branch = {
                                        covered = 0,
                                        missed = 0,
                                    },
                                },
                            }
                        end

                        local lines = cls.lines
                            and cls.lines.line
                        if not lines then
                            goto continue_cls
                        end
                        if lines._attr then
                            lines = { lines }
                        end
                        for _, line in ipairs(lines) do
                            local nr = tonumber(
                                line._attr.number)
                            local hits = tonumber(
                                line._attr.hits)
                            if nr then
                                if hits and hits > 0 then
                                    data.files[full]
                                        .lines[nr] = "covered"
                                    data.files[full]
                                        .totals.line.covered =
                                        data.files[full]
                                        .totals.line.covered
                                        + 1
                                else
                                    data.files[full]
                                        .lines[nr] = "missed"
                                    data.files[full]
                                        .totals.line.missed =
                                        data.files[full]
                                        .totals.line.missed
                                        + 1
                                end
                            end
                        end
                        ::continue_cls::
                    end
                    ::continue_pkg::
                end
                return data
            end

            require("coverage").setup({
                auto_reload = true,
                lang = {
                    cs = {
                        coverage_file = find_coverage_file,
                    },
                },
            })

            -- Monkey-patch cs.lua: the plugin hardcodes
            -- lang.load and ignores config overrides.
            -- cs.lua wrongly uses lcov_to_table for what is
            -- actually Cobertura XML.
            local cs_lang = require("coverage.languages.cs")

            cs_lang.load = function(callback)
                local file = find_coverage_file()
                if not file then
                    vim.notify(
                        "No coverage file found.",
                        vim.log.levels.INFO)
                    return
                end
                local data = parse_cobertura(file)
                if not data then
                    vim.notify(
                        "Failed to parse coverage.",
                        vim.log.levels.ERROR)
                    return
                end
                callback(data)
            end

            cs_lang.sign_list = function(data)
                local signs = {}
                local funcs = {
                    covered = cs_signs.new_covered,
                    partial = cs_signs.new_partial,
                    missed = cs_signs.new_uncovered,
                }
                for fn, fdata in pairs(data.files) do
                    local bufnr = vim.fn.bufnr(fn, false)
                    if bufnr ~= -1 then
                        for lnum, what in pairs(
                            fdata.lines) do
                            table.insert(
                                signs,
                                funcs[what](bufnr, lnum))
                        end
                    end
                end
                return signs
            end

            cs_lang.summary = function(data)
                local cwd = vim.fn.getcwd():gsub("\\", "/")
                    :gsub("/$", "") .. "/"
                local report = { files = {} }
                for fn, fdata in pairs(data.files) do
                    local display = vim.fn.fnamemodify(
                        fn, ":t")
                    local stmts =
                        fdata.totals.line.covered
                        + fdata.totals.line.missed
                    local rep = {
                        filename = display,
                        statements = stmts,
                        missing =
                            fdata.totals.line.missed,
                        branches =
                            fdata.totals.branch.covered
                            + fdata.totals.branch.missed,
                        partial =
                            fdata.totals.branch.missed,
                        coverage = stmts > 0
                            and (1
                                - fdata.totals.line.missed
                                / stmts) * 100
                            or 100,
                    }
                    table.insert(report.files, rep)
                end
                report.totals = data.totals
                return report
            end
        end,
    },
}
