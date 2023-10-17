# nvim-config
my neovim configuration files

This is a personalized configuration with very specific changes that work for me when working on specific projects.
When using this config on other projects it might not work well. Currently my shortcut to make the project
for example is highly customized and only works inside exocad dentalcad solution
    
# installation

This config has the following dependencies, that need to be installed first:
* neovim in version > 0.9
* mingw64 for example from winlibs and add to path
* cmake
* nerdfont: "CaskayDiaCove NFM"
* ripgrep : note the winget version is broken. Use other installation method
* Visual Studio Build Tools 2022 (or  visual studio)
 * add msbuild.exe and vstest.console.exe to the path
  * msbuild.exe : C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin 
  * vstest.console.exe : C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\TestWindow
* optional: neovide and start with --multigrid parameter for smooth scrolling

After installing those dependencies just clone this repo into Windows: ~/AppData/Local/nvim 

# usage

Most important keyboard shortcuts:
* normal vim motions (do vimtutor or watch some youtube videos on vim motions e.g. from ThePrimeagen)
* fuzzy finder. All my fuzzy finder shortcuts start with <space>f except for find git files as I am used to a different mapping there.
 * <space>ff : find files
 * <space>fb : find git branches. Customized for dentalcad submodules.
 * <space>fu : find in open buffers
 * <space>fg : live grep
 * <space>fs : find string
 * <space>fr : reopen last fuzzy find
* <space>fe : opens the oil file explorer which let you modify files and folders like a vim buffer
* <space>te : open the nvim tree explorer onto the side
* <space>ts : open nvim tree but with the current file selected
* <space>gs : git status from fugitive plugin
* <space>gb : git blame (currently with one ignore-rev that only works in dentalcad. you can just type ":G blame" if somewhere else) 
* gc<motion> to comment out lines
* <space>mr : builds dentalcad in release net6 mode and runs it afterwards
* <space>md : builds dentalcad in debug net6 mode and runs it afterwards
* <space>rr : runs release net6 build
* <space>rd : runs debug net6 build
* gd : go to definition
* gi : go to implementation
* K : hover information e.g. api documentation
* <ctrl-.> : code actions
* <space>k : open diagnostic hover to show error message under cursor
* <space>n / <space>N : jump to next/previous item in quickfix list
* <space>p / <space>y : past/yank from system clipboard
* s : jump anywhere on the window by typing 2 letters and a third jump letter from leap plugin
