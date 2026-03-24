# Lars's Neovim Config

Personal Neovim configuration using [Lazy.nvim](https://github.com/folke/lazy.nvim).

**Leader key**: `Space`

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
- [Testing](#testing)
- [Neovide](#neovide)
- [Plugin List](#plugin-list)

---

## Installation

**Dependencies** (all must be on `PATH` unless noted):

| Dependency | Notes |
|------------|-------|
| [Neovim](https://neovim.io/) ≥ 0.9 | |
| [mingw64](https://winlibs.com/) | Required to build telescope-fzf-native |
| [zig](https://ziglang.org/) *(auto-installed)* | Required to compile treesitter parsers. Auto-installed via `winget` on first Lazy build if no C compiler is found — restart Neovim after, then run `:Lazy build nvim-treesitter` |
| [CMake](https://cmake.org/) | |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | **Do not use the winget version** — it is broken. Use an alternative installation method. |
| [Nerd Font: CaskaydiaCove NFM](https://www.nerdfonts.com/) | Required for icons in lualine and nvim-tree |
| Visual Studio Build Tools 2022 or Visual Studio 2022 | Add these to `PATH`: |
| | `msbuild.exe`: `C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin` |
| | `vstest.console.exe`: `C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\TestWindow` |
| [Neovide](https://neovide.dev/) *(optional)* | Launch with `--multigrid` for smooth scrolling |

**Setup:**

```sh
git clone <repo-url> ~/AppData/Local/nvim
```

Open Neovim — Lazy.nvim will bootstrap itself and install all plugins automatically.

---

## Editor

Global keymaps defined in `lua/lars/keymap.lua`.

| Key | Mode | Description |
|-----|------|-------------|
| `<C-d>` | n | Scroll down half-page, keep cursor centered |
| `<C-u>` | n | Scroll up half-page, keep cursor centered |
| `<leader>n` | n | Next quickfix item |
| `<leader>N` | n | Previous quickfix item |
| `<leader>y` | n/v | Yank to system clipboard |
| `<leader>p` | n/v | Paste from system clipboard |
| `p` | n/v | Paste and auto-indent |
| `<C-c>` | i | Leave insert mode and undo |
| `<leader>ml` | n/v | `dotnet Make \Lofwyr` (project-specific) |
| `<leader>jt` | n | Alternate: jump between test file and source file |
| `<leader>jv` | n | Alternate: jump between View/Page and ViewModel |

**Editor settings** (`lua/lars/options.lua`):
- Relative + absolute line numbers
- 4-space indentation (tabstop, softtabstop, shiftwidth)
- Smart indent, smart case search
- Persistent undo (survives closing and reopening files)
- `scrolloff = 8` (cursor stays 8 lines from top/bottom)
- Spell checking enabled
- Word-boundary line wrapping (`linebreak`) — no mid-word breaks
- Nerd Fonts required for icons

---

## Navigation

### Telescope — Fuzzy Finder

> `lua/plugins/navigation/telescope.lua`
> Uses ripgrep for file search, FZF native for fast sorting, smart case matching.

| Key | Description |
|-----|-------------|
| `<leader>ff` | Find files (all files, including hidden, excluding `.git`) |
| `<C-p>` | Find git-tracked files only |
| `<leader>fg` | Live grep (search string across project) |
| `<leader>fs` | Grep string under cursor |
| `<leader>fu` | List open buffers |
| `<leader>fh` | Search help tags |
| `<leader>fr` | Resume last search |
| `<leader>fl` | Git commit log |
| `<leader>fc` | Git commits for current buffer |
| `<leader>fb` | Git branches |
| `<leader>fk` | Search keymaps |

### Harpoon — File Bookmarks

> `lua/plugins/navigation/harpoon.lua`
> Pin frequently-used files and jump to them instantly.

| Key | Description |
|-----|-------------|
| `<leader>ha` | Add current file to harpoon |
| `<leader>hh` | Open harpoon quick menu |
| `<leader>1` – `<leader>9` | Jump to harpoon file 1–9 |
| `<leader>0` | Jump to harpoon file 0 |

### nvim-tree — File Tree

> `lua/plugins/navigation/nvim-tree.lua`

| Key | Description |
|-----|-------------|
| `<leader>te` | Toggle file tree |
| `<leader>ts` | Reveal current file in tree |
| `<leader>tc` | Collapse all folders |

### Oil — File Browser

> `lua/plugins/navigation/oil.lua`
> Editable file browser that replaces netrw. Edit files and directories like a buffer.

| Key | Description |
|-----|-------------|
| `<leader>fe` | Open oil in current file's directory |
| `<leader>ss` | Open config root (`nvim/`) in oil |
| `<leader>sp` | Open `lua/plugins/` in oil |
| `<leader>sl` | Open `lua/lars/` in oil |

**Inside an oil buffer:**

| Key | Description |
|-----|-------------|
| `<CR>` | Open file / enter directory |
| `-` | Go to parent directory |
| `_` | Open in current working directory |
| `` ` `` | `:cd` to this directory |
| `~` | `:tcd` to this directory |
| `<C-c>` | Close oil |
| `<C-l>` | Refresh |
| `g.` | Toggle hidden files |
| `g?` | Show help |
| `<leader>ev` | Open in vertical split |
| `<leader>eh` | Open in horizontal split |
| `<leader>et` | Open in new tab |
| `<leader>ep` | Preview file |

### Leap — Fast Motions

> `lua/plugins/navigation/leap.lua`
> Jump anywhere on screen with 2 keystrokes.

| Key | Description |
|-----|-------------|
| `s` | Leap: type 2 chars to jump to any visible location across all windows |

---

## LSP

> `lua/plugins/lspandcompletion/nvim-lsp-config.lua`
> Active for: `rust`, `c`, `cpp`, `toml`, `lua`
> C# uses Roslyn LSP via `roslyn.nvim` (separate plugin, auto-detects `.sln`/`.csproj`).

**Buffer-local keymaps (active when LSP is attached):**

| Key | Mode | Description |
|-----|------|-------------|
| `gd` | n | Go to definition |
| `gD` | n | Go to declaration |
| `gi` | n | Go to implementation |
| `gt` | n | Go to type definition |
| `gr` | n | List all references |
| `K` | n | Hover documentation |
| `<C-k>` | n | Signature help |
| `<F2>` | n | Rename symbol |
| `<C-.>` | n/v | Code actions |
| `<F3>` | n | Format file (async) |

> **Windows Terminal**: `<C-.>` requires a custom keybinding to send the correct
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

**Diagnostics (always active):**

| Key | Description |
|-----|-------------|
| `gl` | Open diagnostic float for current line |
| `dn` | Go to previous diagnostic |
| `dN` | Go to next diagnostic |
| `<leader>q` | Send diagnostics to location list |

---

## Completion

> `lua/plugins/lspandcompletion/completion.lua`
> Powered by nvim-cmp with LuaSnip snippets.
> Sources: LSP, Lua API, LuaSnip, ctags, buffer, path, cmdline.

| Key | Mode | Description |
|-----|------|-------------|
| `<Tab>` | i/s | Next item / expand or jump in snippet / trigger completion |
| `<S-Tab>` | i/s | Previous item / jump back in snippet |
| `<C-b>` | i | Scroll documentation up |
| `<C-f>` | i | Scroll documentation down |
| `<C-Space>` | i | Trigger completion manually |
| `<C-e>` | i | Abort / close completion menu |
| `<CR>` | i | Confirm selected item |

Cmdline completion is also active: `/` and `?` complete from buffer, `:` completes commands and paths.

---

## Debugger

> `lua/plugins/debug/nvim-dap.lua` + `nvim-dap-ui.lua`
> Adapters installed via Mason. Supports C# (netcoredbg), C/C++/Rust (codelldb).

**Session control:**

| Key | Description |
|-----|-------------|
| `<F5>` | Continue |
| `<F10>` | Step over |
| `<F11>` | Step into |
| `<F12>` | Step out |

**Breakpoints:**

| Key | Description |
|-----|-------------|
| `<leader>db` | Toggle breakpoint |
| `<leader>dB` | Set conditional breakpoint |
| `<leader>dlb` | Set log point (prints message without stopping) |

**Inspection:**

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>dh` | n/v | Hover: show value under cursor |
| `<leader>dp` | n/v | Preview: show value in float |
| `<leader>df` | n | Show call stack frames |
| `<leader>ds` | n | Show current scopes/variables |
| `<leader>dr` | n | Open debug REPL |
| `<leader>dl` | n | Re-run last debug session |
| `du` | n | Open DAP UI panel |

---

## Git

> `lua/plugins/sourcecontrol/fugitive.lua`
> Powered by vim-fugitive. `<leader>gb` shows commit messages inline in the blame view (via fugitive-blame-ext).
> For commit history and branch management, use Telescope (`<leader>fl`, `<leader>fb`).

| Key | Description |
|-----|-------------|
| `<leader>gs` | Git status (fullscreen) |
| `<leader>gb` | Git blame — hover over a line to see its commit message |
| `<leader>gd` | Git diff (fullscreen) |
| `<leader>gm` | Git diff split (side-by-side) |

---

## Text Editing

### Surround — vim-surround

> `lua/plugins/textedit/surround.lua`

| Key | Description |
|-----|-------------|
| `ys{motion}{char}` | Add surround — e.g. `ysiw"` wraps word in quotes |
| `cs{old}{new}` | Change surround — e.g. `cs'"` changes `'` to `"` |
| `ds{char}` | Delete surround — e.g. `ds"` removes surrounding quotes |

### Comment — Comment.nvim

> `lua/plugins/textedit/comment.lua`

| Key | Description |
|-----|-------------|
| `gcc` | Toggle line comment |
| `gc{motion}` | Toggle line comment over motion |
| `gbc` | Toggle block comment |
| `gb{motion}` | Toggle block comment over motion |

### Sideways — Move Arguments

> `lua/plugins/textedit/sideways.lua`
> Move function arguments / list items left or right.

| Key | Description |
|-----|-------------|
| `<C-h>` | Move argument left |
| `<C-l>` | Move argument right |

### CamelCaseMotion

> `lua/plugins/textedit/camelcasemotion.lua`
> Navigate inside `camelCase` and `PascalCase` words using leader-prefixed motions.

| Key | Description |
|-----|-------------|
| `<leader>w` | Next CamelCase word segment |
| `<leader>b` | Previous CamelCase word segment |
| `<leader>e` | End of CamelCase word segment |

### Treesitter — Incremental Selection

> `lua/plugins/lspandcompletion/treesiter.lua`
> Structurally expand/shrink the visual selection by syntax node.

| Key | Description |
|-----|-------------|
| `<C-space>` | Start selection / expand to next node |
| `<C-s>` | Expand to containing scope |
| `<M-space>` | Shrink selection |

---

## Wiki

> `lua/plugins/vimwiki.lua`
> Powered by kiwi.nvim. Wiki stored at `{data}/vimwiki` (symlink to change location).

| Key | Description |
|-----|-------------|
| `<leader>vw` | Open wiki index |
| `<leader>vd` | Open diary index |
| `<leader>vn` | New diary entry for today |
| `<leader>x` | Toggle todo checkbox |

---

## Build / Dispatch

> `lua/plugins/vimdispatch.lua`
> Async build system via vim-dispatch. Runs Make/shell commands without blocking.

| Key | Description |
|-----|-------------|
| `m<CR>` | Run `make` (dispatched) |
| `m<Space>` | Prepare a `make` command to edit before running |
| `` `<Space> `` | Prepare a shell command to edit before running |
| `<leader>ml` | Run `dotnet Make \Lofwyr` (project-specific) |

---

## AI / Claude Code

> `lua/plugins/ai/claudecode.lua`
> Powered by [claude-code.nvim](https://github.com/greggh/claude-code.nvim). Terminal-based Claude Code integration with auto-refresh when Claude modifies files.

| Key | Mode | Description |
|-----|------|-------------|
| `<C-,>` | n,t | Toggle Claude terminal |
| `<leader>ar` | n | Resume last session |
| `<leader>as` | v | Send visual selection to Claude |
| `<leader>ad` | n | View Claude diff |

---

## UI

### Dashboard — alpha-nvim

> `lua/plugins/ui/dashboard.lua`
> Replaces the default welcome screen. Shows interactive shortcuts and a keymap cheat sheet.
> Only appears when Neovim is opened without a file argument (`nvim`).

| Key | Description |
|-----|-------------|
| `f` | Find file |
| `g` | Live grep |
| `r` | Recent files |
| `k` | Browse keymaps |
| `q` | Quit |

---

## Testing

> `tests/` — Automated test suite using [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) busted runner.
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
| `keymap_spec.lua` | 20 | Global keymaps (keymap.lua + LSP diagnostics) |
| `plugin_keymap_spec.lua` | 53 | Plugin keymaps (Telescope, Harpoon, DAP, etc.) |
| `options_spec.lua` | 14 | Editor options (tabstop, scrolloff, etc.) |
| `alternate_spec.lua` | 7 | Test/source and View/Page/ViewModel navigation logic |
| `behavior_spec.lua` | 3 | Feedkeys behavioral tests (yank, quickfix, scroll) |
| `plugin_smoke_spec.lua` | 15 | Plugin load + API smoke tests |
| `dispatch_notify_spec.lua` | — | Dispatch/notify-based test coverage |

**LSP integration tests** (separate runner — needs event loop, ~60s per server):

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

| Key | Description |
|-----|-------------|
| `<C-=>` | Zoom in (scale × 1.25) |
| `<C-->` | Zoom out (scale ÷ 1.25) |

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
| [nightfox.nvim](https://github.com/EdenEast/nightfox.nvim) | Color scheme (active) |
| [tokyonight.nvim](https://github.com/folke/tokyonight.nvim) | Color scheme (available) |
| [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim) | Status line |
| [kiwi.nvim](https://github.com/serenevoid/kiwi.nvim) | Wiki / diary |
| [vim-dispatch](https://github.com/tpope/vim-dispatch) | Async build/run commands |
| [himalaya-vim](https://git.sr.ht/~soywod/himalaya-vim) | Email client (`:Himalaya`) |
| [VimBeGood](https://github.com/ThePrimeagen/vim-be-good) | Vim motion practice (`:VimBeGood`) |
| [claude-code.nvim](https://github.com/greggh/claude-code.nvim) | Claude Code IDE integration |
| [alpha-nvim](https://github.com/goolord/alpha-nvim) | Dashboard / start screen |
| [render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim) | Visual markdown rendering (headings, lists, tables, etc.) |
