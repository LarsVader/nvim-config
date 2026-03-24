# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal Neovim configuration using **Lazy.nvim** for plugin management. The config is structured as a Lua module named `lars`.

## Architecture

```
init.lua                  → requires "lars"
lua/lars/init.lua         → orchestrates core config (options, keymaps, autocommands, plugin-load)
lua/lars/plugin-load.lua  → bootstraps Lazy.nvim and calls lazy.setup("plugins")
lua/plugins/imports.lua   → imports all plugin category subdirectories
lua/plugins/<category>/   → each plugin has its own .lua file returning a Lazy spec table
```

Plugin categories: `navigation/`, `lspandcompletion/`, `debug/`, `textedit/`, `sourcecontrol/`, `ui/`

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

## Testing

After any config change, run the relevant spec files individually (do NOT use `run_all.sh` — it hangs on Windows):

```sh
nvim --headless -u tests/minimal_init.lua +"lua require('plenary.busted').run('tests/<spec>.lua')"
```

**LSP integration tests** are separate (need event loop, ~60s timeout per server):

```sh
cd ~/AppData/Local/nvim && bash tests/run_lsp.sh
```

Run LSP tests after changes to `lspandcompletion/` files, Mason packages, or .NET SDK updates.

## Notable Keymaps

See `lua/lars/keymap.lua` for global bindings and each plugin file's `keys` table for plugin-specific ones.

- `<leader>ff/fg/fs` - Telescope file/grep/word search
- `<leader>ha/hh/1-9` - Harpoon add/menu/jump
- `gd/K/gr/<F2>/<F3>` - LSP goto/hover/references/rename/format
- `<F5>/<F10>/<F11>/<F12>` - DAP continue/step-over/step-into/step-out
- `<leader>gs/gb/gd` - Fugitive status/blame/diff
