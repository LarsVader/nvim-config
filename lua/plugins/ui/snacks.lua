return {
    {
        'folke/snacks.nvim',
        priority = 1000,
        lazy = false,
        opts = {
            image = { enabled = true },
        },
        keys = {
            {
                '<M-i>',
                function()
                    require('snacks.image.placement').clean()
                    local buf = vim.api.nvim_get_current_buf()
                    local name = vim.api.nvim_buf_get_name(buf):lower()
                    local ft = vim.bo[buf].filetype
                    if name:match('%.[pj][np]e?g$') or name:match('%.gif$')
                        or name:match('%.webp$') or name:match('%.bmp$')
                        or name:match('%.avif$') or name:match('%.tiff?$') then
                        require('snacks.image.buf').attach(buf)
                    elseif ft == 'markdown' or ft == 'norg' or ft == 'html'
                        or ft == 'css' or ft == 'typst' then
                        require('snacks.image.doc').attach(buf)
                    end
                end,
                mode = { 'n', 'i', 't' },
                desc = 'Image: refresh placements (clear stuck + re-attach current buffer)',
            },
        },
    },
}
