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
    local result = search(vim.fn.getcwd())
    if result then
        return result:gsub("/", "\\")
    end
    return nil
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

-- Parse the current buffer for a class inheritance list.
-- Returns a list of trimmed type names from "class Foo : Bar, IBaz, IQux"
local function parse_inheritance_list()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    for _, line in ipairs(lines) do
        local inheritance = line:match('class%s+%w+%s*:%s*(.+)')
        if inheritance then
            -- Strip anything after an opening brace or "where" clause
            inheritance = inheritance:match('^(.-)%s*{') or inheritance:match('^(.-)%s*where%s') or inheritance
            local types = {}
            for t in inheritance:gmatch('[^,]+') do
                local trimmed = t:match('^%s*(.-)%s*$')
                if trimmed and #trimmed > 0 then
                    types[#types + 1] = trimmed
                end
            end
            return types
        end
    end
    return {}
end

-- Returns true if a type name looks like a C# interface (starts with I + uppercase)
local function is_interface(name)
    return name:match('^I[A-Z]') ~= nil
end

-- Toggle between C/C++ header and source files
function M.goto_header_or_source()
    local full = vim.fn.expand('%:t')
    local base, ext

    -- Try header extensions
    base = full:match('^(.+)%.hpp$') or full:match('^(.+)%.h$')
    if base then
        -- Header -> source: try .cpp first, then .c
        local found = find_file(base .. '.cpp') or find_file(base .. '.c')
        if found then
            vim.cmd('edit ' .. vim.fn.fnameescape(found))
        else
            vim.notify('Source not found for: ' .. full, vim.log.levels.WARN)
        end
        return
    end

    -- Try source extensions
    base = full:match('^(.+)%.cpp$') or full:match('^(.+)%.c$')
    if base then
        -- Source -> header: try .h first, then .hpp
        local found = find_file(base .. '.h') or find_file(base .. '.hpp')
        if found then
            vim.cmd('edit ' .. vim.fn.fnameescape(found))
        else
            vim.notify('Header not found for: ' .. full, vim.log.levels.WARN)
        end
        return
    end

    vim.notify('Not a C/C++ file', vim.log.levels.WARN)
end

-- Jump to the first interface in the current C# file's class declaration
function M.goto_interface()
    local full = vim.fn.expand('%:t')
    if not full:match('%.cs$') then
        vim.notify('Not a C# file', vim.log.levels.WARN)
        return
    end

    local types = parse_inheritance_list()
    for _, t in ipairs(types) do
        if is_interface(t) then
            local found = find_file(t .. '.cs')
            if found then
                vim.cmd('edit ' .. vim.fn.fnameescape(found))
            else
                vim.notify('Interface not found: ' .. t .. '.cs', vim.log.levels.WARN)
            end
            return
        end
    end
    vim.notify('No interface found in class declaration', vim.log.levels.WARN)
end

-- Toggle between .xaml and .xaml.cs (codebehind)
function M.goto_xaml_or_codebehind()
    local full = vim.fn.expand('%:t')

    if full:match('%.xaml%.cs$') then
        -- Codebehind -> XAML
        local base = full:gsub('%.xaml%.cs$', '')
        local found = find_file(base .. '.xaml')
        if found then
            vim.cmd('edit ' .. vim.fn.fnameescape(found))
        else
            vim.notify('XAML not found: ' .. base .. '.xaml', vim.log.levels.WARN)
        end
    elseif full:match('%.xaml$') then
        -- XAML -> codebehind
        local base = full:gsub('%.xaml$', '')
        local found = find_file(base .. '.xaml.cs')
        if found then
            vim.cmd('edit ' .. vim.fn.fnameescape(found))
        else
            vim.notify('Codebehind not found: ' .. base .. '.xaml.cs', vim.log.levels.WARN)
        end
    else
        vim.notify('Not a XAML file', vim.log.levels.WARN)
    end
end

-- Jump to the base class in the current C# file's class declaration
function M.goto_base_class()
    local full = vim.fn.expand('%:t')
    if not full:match('%.cs$') then
        vim.notify('Not a C# file', vim.log.levels.WARN)
        return
    end

    local types = parse_inheritance_list()
    for _, t in ipairs(types) do
        if not is_interface(t) then
            local found = find_file(t .. '.cs')
            if found then
                vim.cmd('edit ' .. vim.fn.fnameescape(found))
            else
                vim.notify('Base class not found: ' .. t .. '.cs', vim.log.levels.WARN)
            end
            return
        end
    end
    vim.notify('No base class found in class declaration', vim.log.levels.WARN)
end

return M
