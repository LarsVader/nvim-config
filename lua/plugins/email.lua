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
						" nmap gp   <plug>(himalaya-folder-select-previous-page)
						" nmap gn   <plug>(himalaya-folder-select-next-page)
						" nmap <cr> <plug>(himalaya-email-read)
						" nmap gw   <plug>(himalaya-email-write)
						" nmap gr   <plug>(himalaya-email-reply)
						" nmap gR   <plug>(himalaya-email-reply-all)
						" nmap gf   <plug>(himalaya-email-forward)
						" nmap ga   <plug>(himalaya-email-download-attachments)
						" nmap gC   <plug>(himalaya-email-copy)
						" nmap gM   <plug>(himalaya-email-move)
						nmap <buffer> D <plug>(himalaya-email-delete)y<cr>
						vmap <buffer> D <plug>(himalaya-email-delete)y<cr>
					]])
					-- vim.keymap.set('n', 'r', function () print("buffer local mapping triggered") end, { buffer=ev.buf} )
					-- vim.keymap.set('n', 'dd', '<cmd>HimalayaDelete<cr>y<cr>', { buffer=ev.buf} )
					-- vim.keymap.set('v', 'd', 'himalaya#domain#email#delete', { buffer=ev.buf} )
					-- vim.keymap.set('v', 'x',
					-- 	function ()
					-- 		vim.fn['himalaya#domain#email#delete']()
					-- 	end, { buffer=ev.buf} )
				end
			})
		end
	}
}
