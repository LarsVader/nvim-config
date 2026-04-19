# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal Neovim configuration using **Lazy.nvim** for plugin management. The config is structured as a Lua module named `lars`.

## Architecture

```
init.lua                  → requires "lars"
lua/lars/init.lua         → orchestrates core config (options, keymaps, autocommands, plugin-load)
lua/lars/plugin-load.lua  → bootstraps Lazy.nvim and calls lazy.setup("plugins")
lua/lars/options.lua      → editor options (indentation, GUI/Neovide settings)
lua/lars/keymap.lua       → global keymaps (leader = Space)
lua/lars/autocommands.lua → autocommands (transparency, etc.)
lua/lars/alternate.lua    → alternate file navigation
lua/plugins/imports.lua   → imports all plugin category subdirectories
lua/plugins/<category>/   → each plugin has its own .lua file returning a Lazy spec table
```

Plugin categories: `ai/`, `debug/`, `lspandcompletion/`, `navigation/`, `sourcecontrol/`, `textedit/`, `ui/`

## Plugin Conventions

Each plugin file returns a Lua table in [Lazy.nvim spec format](https://lazy.folke.io/spec):

```lua
return {
  {
    'owner/plugin-name',
    dependencies = { ... },
    lazy = true,
    keys = { { "<leader>xx", "<cmd>...<cr>", desc = "Description" } },
    config = function() require('plugin').setup({ ... }) end,
  },
}
```

- Keymaps belong in the plugin's `keys` table (for lazy loading) or `config`/`init` function
- Global/non-plugin keymaps go in `lua/lars/keymap.lua`
- New plugin categories: add a directory under `lua/plugins/`, create individual plugin files, add an `import` entry in `lua/plugins/imports.lua`

## Key Settings

- **Leader key**: Space
- **Indentation**: 4 spaces (tabstop, softtabstop, shiftwidth all = 4)
- **GUI**: Neovide-specific settings in `lua/lars/options.lua` (scale factor, zoom keymaps)
- **Transparency**: `lua/lars/autocommands.lua` removes background from Normal/NormalFloat on ColorScheme

## Language Support

- **Rust**: rust-tools, crates.nvim
- **C#**: roslyn.nvim (Roslyn LSP via Mason), netcoredbg debug adapter
- **C/C++**: codelldb debug adapter
- **Lua**: neodev.nvim (for Neovim API completion)
- **XAML**: axsg-lsp (XamlToCSharpGenerator, dotnet tool, stdio transport)

## Testing (MANDATORY)

After ANY config change, you MUST:

### 1. Update the relevant test spec

- New/changed global keymaps → update `tests/keymap_spec.lua`
- New/changed plugin keymaps → update `tests/plugin_keymap_spec.lua`
- New plugin added → add smoke test to `tests/plugin_smoke_spec.lua` AND keymap entries to `tests/plugin_keymap_spec.lua`
- Changed options → update `tests/options_spec.lua`
- Changed alternate.lua → update `tests/alternate_spec.lua`

### 2. Run tests for each changed spec file individually

```sh
nvim --headless -u tests/minimal_init.lua +"lua require('plenary.busted').run('tests/<name>_spec.lua')" 2>&1
```

**WARNING**: Do NOT use `bash tests/run_all.sh` from Claude Code — it hangs on Windows because nvim inside `$(...)` bash subshells never exits. Always run individual spec files directly.

### 3. All tests must pass before reporting the task as done

Exit code 127 from headless nvim is normal — check for `Failed : 0` in the output.

### Test conventions

- Spec files use `dofile(vim.fn.stdpath("config") .. "/tests/helpers.lua")` for helpers (NOT `require`)
- `helpers.lua` provides: `find_keymap(mode, lhs)`, `has_keymap(mode, lhs)`, `feed(keys)`, `force_load_plugin(name)`, `get_buf_lines()`, `set_buf_lines(lines)`
- `find_keymap` auto-normalizes `<leader>` and uppercases `<C-x>` modifier letters

### LSP integration tests

Separate from unit tests (need event loop, ~60s timeout per server):

```sh
cd ~/AppData/Local/nvim && bash tests/run_lsp.sh
```

Run LSP tests after changes to `lspandcompletion/` files, Mason packages, or .NET SDK updates.

## Before Making Changes

1. Read relevant existing files before modifying them
2. Check `lua/plugins/imports.lua` if adding a new plugin category

## After Making Changes

1. Verify config loads: `nvim --headless +q 2>&1`
2. Run changed spec files individually (see Testing above)
3. Check if `README.md` needs updating (new keymaps, dependencies, behaviours)

## Notable Keymaps

See `lua/lars/keymap.lua` for global bindings and each plugin file's `keys` table for plugin-specific ones.

- `<leader>ff/fg/fs` - Telescope file/grep/word search
- `<leader>ha/hh/1-9` - Harpoon add/menu/jump
- `gd/K/gr/<F2>/<F3>` - LSP goto/hover/references/rename/format
- `<F5>/<F10>/<F11>/<F12>` - DAP continue/step-over/step-into/step-out
- `<leader>gs/gb/gd` - Fugitive status/blame/diff
