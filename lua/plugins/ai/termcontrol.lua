-- termcontrol.nvim: generic terminal-interaction layer that used to live inline
-- in sidekick.lua: <M-,>, <M-1..9>, <M-G/j/k/d/u>, <M-n>. Defaults reproduce
-- the previous bindings exactly; sidekick integration activates only when
-- sidekick.nvim is loaded.
return {
    {
        "LarsVader/termcontrol.nvim",
        event = "VeryLazy",
        opts = {},
    },
}
