# Lars's Neovim Config

Personal Neovim configuration using [Lazy.nvim](https://github.com/folke/lazy.nvim).

**Leader key**: `Space`

**All keymaps are searchable**: press `<Space>fk` to open the keymap finder (Telescope picker). Every keymap -- including fold commands, LSP actions, debug controls, and plugin shortcuts -- is discoverable there.

## Table of Contents

- [Installation](#installation)
- [Editor](#editor)
- [Navigation](#navigation)
- [LSP](#lsp)
- [Completion](#completion)
- [Debugger](#debugger)
- [Git](#git)
- [Text Editing](#text-editing)
- [Wiki](#wiki)
- [Build / Dispatch](#build--dispatch)
- [AI / Claude Code](#ai--claude-code)
- [Testing / Coverage](#testing--coverage)
- [Automated Tests](#automated-tests)
- [Neovide](#neovide)
- [Plugin List](#plugin-list)

---

## Installation

**Dependencies** (all must be on `PATH` unless noted):

| Dependency | Notes |
|------------|-------|
| [Neovim](https://neovim.io/) >= 0.9 | |
| [mingw64](https://winlibs.com/) | Required to build telescope-fzf-native |
| [zig](https://ziglang.org/) *(auto-installed)* | Required to compile treesitter parsers. Auto-installed via `winget` on first Lazy build if no C compiler is found -- restart Neovim after, then run `:Lazy build nvim-treesitter` |
| [CMake](https://cmake.org/) | |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | **Do not use the winget version** -- it is broken. Use an alternative installation method. |
| [Nerd Font: CaskaydiaCove NFM](https://www.nerdfonts.com/) | Required for icons in lualine and nvim-tree |
| Visual Studio Build Tools 2022 or Visual Studio 2022 | Add these to `PATH`: |
| | `msbuild.exe`: `C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin` |
| | `vstest.console.exe`: `C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\TestWindow` |
| [Neovide](https://neovide.dev/) *(optional)* | Launch with `--multigrid` for smooth scrolling |

**Setup:**

```sh
git clone <repo-url> ~/AppData/Local/nvim
```

Open Neovim -- Lazy.nvim will bootstrap itself and install all plugins automatically.

---

## Editor

> `lua/lars/keymap.lua` -- global keymaps
> `lua/lars/options.lua` -- editor settings

**Editor settings:**
- Relative + absolute line numbers
- 4-space indentation (tabstop, softtabstop, shiftwidth)
- Smart indent, smart case search
- Persistent undo (survives closing and reopening files)
- `scrolloff = 8` (cursor stays 8 lines from top/bottom)
- Spell checking enabled
- Word-boundary line wrapping (`linebreak`) -- no mid-word breaks
- Nerd Fonts required for icons

---

## Navigation

### Telescope -- Fuzzy Finder

> `lua/plugins/navigation/telescope.lua`
> Uses ripgrep for file search, FZF native for fast sorting, smart case matching.

### Harpoon -- File Bookmarks

> `lua/plugins/navigation/harpoon.lua`
> Pin frequently-used files and jump to them instantly.

### nvim-tree -- File Tree

> `lua/plugins/navigation/nvim-tree.lua`

### Oil -- File Browser

> `lua/plugins/navigation/oil.lua`
> Editable file browser that replaces netrw. Edit files and directories like a buffer.

### Leap -- Fast Motions

> `lua/plugins/navigation/leap.lua`
> Jump anywhere on screen with 2 keystrokes.

---

## LSP

> `lua/plugins/lspandcompletion/nvim-lsp-config.lua`
> Active for: `rust`, `c`, `cpp`, `toml`, `lua`
> C# uses Roslyn LSP via `roslyn.nvim` (separate plugin, auto-detects `.sln`/`.csproj`).

> **Windows Terminal**: `<C-.>` (code actions) requires a custom keybinding to send the correct
> escape sequence. Add the following to Windows Terminal's `settings.json`
> (`Ctrl+Shift+,` to open):
>
> In `"actions"`:
> ```json
> { "command": { "action": "sendInput", "input": "\u001b[46;5u" }, "id": "User.sendInput.ctrlDot" }
> ```
> In `"keybindings"`:
> ```json
> { "id": "User.sendInput.ctrlDot", "keys": "ctrl+." }
> ```

---

## Completion

> `lua/plugins/lspandcompletion/completion.lua`
> Powered by nvim-cmp with LuaSnip snippets.
> Sources: LSP, Lua API, LuaSnip, ctags, buffer, path, cmdline.

Cmdline completion is also active: `/` and `?` complete from buffer, `:` completes commands and paths.

---

## Debugger

> `lua/plugins/debug/nvim-dap.lua` + `nvim-dap-ui.lua`
> Adapters installed via Mason. Supports C# (netcoredbg), C/C++/Rust (codelldb).

---

## Git

> `lua/plugins/sourcecontrol/fugitive.lua`
> Powered by vim-fugitive. `<leader>gb` shows commit messages inline in the blame view (via fugitive-blame-ext).
> For commit history and branch management, use Telescope (`<leader>fl`, `<leader>fb`).

---

## Text Editing

### Surround -- vim-surround

> `lua/plugins/textedit/surround.lua`

### Comment -- Comment.nvim

> `lua/plugins/textedit/comment.lua`

### Sideways -- Move Arguments

> `lua/plugins/textedit/sideways.lua`
> Move function arguments / list items left or right.

### CamelCaseMotion

> `lua/plugins/textedit/camelcasemotion.lua`
> Navigate inside `camelCase` and `PascalCase` words using leader-prefixed motions.

### Treesitter -- Incremental Selection

> `lua/plugins/lspandcompletion/treesiter.lua`
> Structurally expand/shrink the visual selection by syntax node.

---

## Wiki

> `lua/plugins/vimwiki.lua`
> Powered by kiwi.nvim. Wiki stored at `{data}/vimwiki` (symlink to change location).

---

## Build / Dispatch

> `lua/plugins/vimdispatch.lua`
> Async build system via vim-dispatch. Runs Make/shell commands without blocking.

---

## AI / Claude Code

> `lua/plugins/ai/claudecode.lua`
> Powered by [claude-code.nvim](https://github.com/greggh/claude-code.nvim). Terminal-based Claude Code integration.
> Launched with `/LOW` priority and CPU affinity `0xE` (logical procs 1-3) via a `cmd /c start` wrapper, so Claude and all its child processes (builds, tests) leave one logical processor free for the rest of the system.
> File-refresh polling is custom: every 5s via a libuv timer, plus on `BufEnter`/`FocusGained`, but only while the Claude terminal is NOT the currently focused window. This avoids a `:terminal` viewport-follows-cursor interaction that caused scroll-through-transcript jank on long conversations.

---

## UI

### Dashboard -- alpha-nvim

> `lua/plugins/ui/dashboard.lua`
> Replaces the default welcome screen. Shows interactive shortcuts and a keymap cheat sheet.
> Only appears when Neovim is opened without a file argument (`nvim`).

---

## Testing / Coverage

### Neotest -- Test Explorer

> `lua/plugins/testing/neotest.lua`
> Test runner and explorer with tree-view panel. Uses neotest-dotnet adapter for C#/xUnit.

### nvim-coverage -- Code Coverage

> `lua/plugins/testing/nvim-coverage.lua`
> Displays code coverage as gutter signs. Reads Cobertura XML from `dotnet test --collect:"XPlat Code Coverage"`.

---

## Automated Tests

> `tests/` -- Automated test suite using [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) busted runner.
> Catches keymap regressions, plugin API breakage, and config drift.

**Run all tests:**

```sh
cd ~/AppData/Local/nvim
bash tests/run_all.sh
```

**Run a single spec file:**

```sh
nvim --headless -u tests/minimal_init.lua +"lua require('plenary.busted').run('tests/keymap_spec.lua')"
```

| Spec file | Tests | What it verifies |
|-----------|-------|-----------------|
| `keymap_spec.lua` | 27 | Global keymaps (keymap.lua + LSP diagnostics + fold commands) |
| `plugin_keymap_spec.lua` | 62 | Plugin keymaps (Telescope, Harpoon, DAP, etc.) |
| `options_spec.lua` | 14 | Editor options (tabstop, scrolloff, etc.) |
| `alternate_spec.lua` | 7 | Test/source and View/Page/ViewModel navigation logic |
| `behavior_spec.lua` | 3 | Feedkeys behavioral tests (yank, quickfix, scroll) |
| `plugin_smoke_spec.lua` | 24 | Plugin load + API smoke tests |
| `dispatch_notify_spec.lua` | -- | Dispatch/notify-based test coverage |

**LSP integration tests** (separate runner -- needs event loop, ~60s per server):

```sh
cd ~/AppData/Local/nvim
bash tests/run_lsp.sh
```

Tests that each configured LSP server starts, attaches to a fixture file, and initialises.
Run after changes to `lspandcompletion/` files, Mason packages, or SDK updates.

| Server | Fixture | Timeout |
|--------|---------|---------|
| roslyn | `tests/fixtures/cs/Test.cs` | 60s |

---

## Neovide

> Settings in `lua/lars/options.lua`. Only active when running inside Neovide.
> Default scale factor: `0.8`.

---

## Plugin List

| Plugin | Purpose |
|--------|---------|
| [lazy.nvim](https://github.com/folke/lazy.nvim) | Plugin manager |
| [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) | Fuzzy finder |
| [telescope-fzf-native](https://github.com/nvim-telescope/telescope-fzf-native.nvim) | FZF sorter for telescope |
| [harpoon](https://github.com/ThePrimeagen/harpoon) | File bookmarks |
| [nvim-tree](https://github.com/nvim-tree/nvim-tree.lua) | File tree explorer |
| [oil.nvim](https://github.com/stevearc/oil.nvim) | Editable file browser |
| [leap.nvim](https://github.com/ggandor/leap.nvim) | Fast 2-char jump motions |
| [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) | LSP client configuration |
| [mason.nvim](https://github.com/williamboman/mason.nvim) | LSP/DAP/formatter installer |
| [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) | Completion engine |
| [LuaSnip](https://github.com/L3MON4D3/LuaSnip) | Snippet engine |
| [neodev.nvim](https://github.com/folke/neodev.nvim) | Neovim Lua API completion |
| [crates.nvim](https://github.com/saecki/crates.nvim) | Cargo.toml dependency completion |
| [roslyn.nvim](https://github.com/seblyng/roslyn.nvim) | C# Roslyn LSP (replaces OmniSharp) |
| [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) | Syntax parsing and highlighting |
| [nvim-treesitter-context](https://github.com/nvim-treesitter/nvim-treesitter-context) | Show current scope at top of window |
| [nvim-dap](https://github.com/mfussenegger/nvim-dap) | Debug adapter protocol |
| [nvim-dap-ui](https://github.com/rcarriga/nvim-dap-ui) | Debug UI |
| [mason-nvim-dap](https://github.com/jay-babu/mason-nvim-dap.nvim) | DAP adapter installer |
| [vim-fugitive](https://github.com/tpope/vim-fugitive) | Git integration |
| [vim-rhubarb](https://github.com/tpope/vim-rhubarb) | GitHub integration for fugitive |
| [vim-fugitive-blame-ext](https://github.com/tommcdo/vim-fugitive-blame-ext) | Commit messages in blame view |
| [vim-surround](https://github.com/tpope/vim-surround) | Surround text objects |
| [Comment.nvim](https://github.com/numToStr/Comment.nvim) | Comment/uncomment operators |
| [sideways.vim](https://github.com/AndrewRadev/sideways.vim) | Move function arguments |
| [CamelCaseMotion](https://github.com/bkad/CamelCaseMotion) | Navigate camelCase words |
| [autopairs](https://github.com/windwp/nvim-autopairs) | Auto-close brackets/quotes |
| [neoformat](https://github.com/sbdchd/neoformat) | Code formatter |
| [themery.nvim](https://github.com/zaldih/themery.nvim) | Theme switcher with persistence (`<Space>ut`) |
| [nightfox.nvim](https://github.com/EdenEast/nightfox.nvim) | Color scheme (default: carbonfox) |
| [tokyonight.nvim](https://github.com/folke/tokyonight.nvim) | Color scheme |
| [catppuccin](https://github.com/catppuccin/nvim) | Color scheme |
| [rose-pine](https://github.com/rose-pine/neovim) | Color scheme |
| [kanagawa.nvim](https://github.com/rebelot/kanagawa.nvim) | Color scheme |
| [everforest](https://github.com/sainnhe/everforest) | Color scheme |
| [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim) | Status line |
| [kiwi.nvim](https://github.com/serenevoid/kiwi.nvim) | Wiki / diary |
| [vim-dispatch](https://github.com/tpope/vim-dispatch) | Async build/run commands |
| [VimBeGood](https://github.com/ThePrimeagen/vim-be-good) | Vim motion practice (`:VimBeGood`) |
| [claude-code.nvim](https://github.com/greggh/claude-code.nvim) | Claude Code IDE integration |
| [neotest](https://github.com/nvim-neotest/neotest) | Test runner and explorer |
| [neotest-dotnet](https://github.com/Issafalcon/neotest-dotnet) | .NET/xUnit adapter for neotest |
| [nvim-coverage](https://github.com/andythigpen/nvim-coverage) | Code coverage gutter signs |
| [alpha-nvim](https://github.com/goolord/alpha-nvim) | Dashboard / start screen |
| [render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim) | Visual markdown rendering (headings, lists, tables, etc.) |
