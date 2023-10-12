vim.g.mapleader = " "

vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })
vim.keymap.set('n', '<c-d>', '<c-d>zz', {})
vim.keymap.set('n', '<c-u>', '<c-u>zz', {})

vim.keymap.set('n', '<leader>n', ':cnext<CR>', {})
vim.keymap.set('n', '<leader>N', ':cprev<CR>', {})

vim.keymap.set({'n', 'v'}, '<leader>y', '"*y', {})
vim.keymap.set({'n', 'v'}, '<leader>p', '"+p', {})
vim.keymap.set({'n', 'v'}, 'p', 'p==', {})

-- vim.keymap.set('n', '<leader>rr', [[:! for /F "TOKENS=1,2,*" \%a in ('tasklist /FI "IMAGENAME eq WpfApp2.exe"') do set MyPID=\%b<cr>]], {})

vim.keymap.set('n', '<leader>md', [[<cmd>wall<cr><cmd>compiler! msbuild<cr><cmd>Make ./DentalCad/DentalCADWithDentalBase.sln /target:DentalCADApp /p:Configuration=DebugNet6 /p:Platform=x64 /filelogger /fileloggerparameters:verbosity=normal && "DentalCAD\\DentalCADApp\\bin\\x64\\Debug\\net6.0-windows\\DentalCADApp.exe" /DebugShowConsole /DebugShowConsoleKeepTrace /maik++ <cr>]], {})
vim.keymap.set('n', '<leader>mr', [[<cmd>wall<cr><cmd>compiler! msbuild<cr><cmd>Make ./DentalCad/DentalCADWithDentalBase.sln /target:DentalCADApp /p:Configuration=ReleaseNet6 /p:Platform=x64 /filelogger /fileloggerparameters:verbosity=normal && "DentalCAD\\DentalCADApp\\bin\\x64\\Release\\net6.0-windows\\DentalCADApp.exe" /DebugShowConsole /DebugShowConsoleKeepTrace /maik++ <cr>]], {})


vim.keymap.set('n', '<leader>rd', ':Dispatch DentalCAD\\DentalCADApp\\bin\\x64\\Debug\\net6.0-windows\\DentalCADApp.exe /DebugShowConsole /DebugShowConsoleKeepTrace /maik++ /DuplicateDentureMode=true<cr>', {})
vim.keymap.set('n', '<leader>rr', ':Dispatch DentalCAD\\DentalCADApp\\bin\\x64\\Release\\net6.0-windows\\DentalCADApp.exe /DebugShowConsole /DebugShowConsoleKeepTrace /maik++ <cr>', {})

vim.keymap.set('n', '<leader>k', function () vim.diagnostic.open_float() end)

