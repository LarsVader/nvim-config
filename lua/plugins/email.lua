return {
	{
		'https://git.sr.ht/~soywod/himalaya-vim',
		dependencies = 'nvim-telescope/telescope.nvim',
		cmd = "Himalaya",
		config = function ()
			vim.api.nvim_create_autocmd({"BufEnter", "BufWinEnter"}, {
				pattern = {"himalaya emails*", "mail"},
				callback = function()
					vim.cmd([[
						nmap fl   <plug>(himalaya-folder-select)
						nmap <buffer> D <plug>(himalaya-email-delete)y<cr>
						vmap <buffer> D <plug>(himalaya-email-delete)y<cr>
					]])
				end
			})
		end
	}
}
