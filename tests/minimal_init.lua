-- Minimal init for plenary test runner
-- Bootstraps lazy.nvim + full config so all keymaps and plugins are available

-- Leader must be set before any keymaps are registered
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Add lazy.nvim to runtimepath
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
vim.opt.rtp:prepend(lazypath)

-- Add plenary to runtimepath so test harness is available immediately
local plenarypath = vim.fn.stdpath("data") .. "/lazy/plenary.nvim"
vim.opt.rtp:prepend(plenarypath)

-- Add the config dir to rtp (tests/ lives here as tests/)
local configpath = vim.fn.stdpath("config")
vim.opt.rtp:prepend(configpath)

-- Load the full config (options, keymaps, autocommands, plugin-load)
require("lars")

-- Ensure plenary plugin commands are registered (PlenaryBustedFile, etc.)
vim.cmd("runtime plugin/plenary.vim")
