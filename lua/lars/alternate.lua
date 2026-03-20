-- Alternate file navigation: test <-> source, view <-> viewmodel
local M = {}

local uv = vim.uv or vim.loop

-- Directories to skip during file search (build artifacts, VCS, caches)
local skip_dirs = {
    obj = true, bin = true, ['.git'] = true,
    node_modules = true, ['.vs'] = true, ['.claude'] = true,
}

-- Recursively search for a file by exact name, skipping build/cache directories.
-- Uses libuv fs_scandir which is fast and avoids the globpath ** freeze on Windows.
local function find_file(name)
    local function search(dir)
        local handle = uv.fs_scandir(dir)
        if not handle then return nil end
        local subdirs = {}
        while true do
            local entry, typ = uv.fs_scandir_next(handle)
            if not entry then break end
            if typ == 'file' and entry == name then
                return dir .. '/' .. entry
            elseif typ == 'directory' and not skip_dirs[entry] then
                subdirs[#subdirs + 1] = dir .. '/' .. entry
            end
        end
        for _, subdir in ipairs(subdirs) do
            local result = search(subdir)
            if result then return result end
        end
        return nil
    end
    return search(vim.fn.getcwd())
end

-- Toggle between test file and source file under test
function M.goto_test_or_source()
    local full_filename = vim.fn.expand('%:t')
    if not full_filename:match('%.cs$') then
        vim.notify('Not a C# file', vim.log.levels.WARN)
        return
    end
    local base = full_filename:gsub('%.cs$', '')

    if base:match('Tests$') then
        local source = base:gsub('Tests$', '')
        local found = find_file(source .. '.cs')
        if found then
            vim.cmd('edit ' .. vim.fn.fnameescape(found))
        else
            vim.notify('Source not found: ' .. source .. '.cs', vim.log.levels.WARN)
        end
    else
        local test = base .. 'Tests'
        local found = find_file(test .. '.cs')
        if found then
            vim.cmd('edit ' .. vim.fn.fnameescape(found))
        else
            vim.notify('Test not found: ' .. test .. '.cs', vim.log.levels.WARN)
        end
    end
end

-- Toggle between View/Page (.xaml / .xaml.cs) and ViewModel (.cs)
function M.goto_view_or_viewmodel()
    local full_filename = vim.fn.expand('%:t')
    local base

    if full_filename:match('%.xaml%.cs$') then
        base = full_filename:gsub('%.xaml%.cs$', '')
    elseif full_filename:match('%.xaml$') then
        base = full_filename:gsub('%.xaml$', '')
    elseif full_filename:match('%.cs$') then
        base = full_filename:gsub('%.cs$', '')
    else
        vim.notify('Not a .cs or .xaml file', vim.log.levels.WARN)
        return
    end

    -- Check ViewModel$ first so "FooViewModel" doesn't match View$ or Page$
    if base:match('ViewModel$') then
        local stem = base:gsub('ViewModel$', '')
        local found = find_file(stem .. 'View.xaml.cs')
            or find_file(stem .. 'Page.xaml.cs')
            or find_file(stem .. 'View.xaml')
            or find_file(stem .. 'Page.xaml')
        if found then
            vim.cmd('edit ' .. vim.fn.fnameescape(found))
        else
            vim.notify('View/Page not found for: ' .. base, vim.log.levels.WARN)
        end
    elseif base:match('View$') or base:match('Page$') then
        local stem = base:gsub('View$', ''):gsub('Page$', '')
        local vm = stem .. 'ViewModel'
        local found = find_file(vm .. '.cs')
        if found then
            vim.cmd('edit ' .. vim.fn.fnameescape(found))
        else
            vim.notify('ViewModel not found: ' .. vm .. '.cs', vim.log.levels.WARN)
        end
    else
        vim.notify('Not a View/Page or ViewModel file', vim.log.levels.WARN)
    end
end

return M
