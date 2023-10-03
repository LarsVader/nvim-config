return {
	{
		-- motion to move inside camel case words (use leader key in front of normal motion)
		"bkad/CamelCaseMotion",
		init = function ()
			vim.g.camelcasemotion_key = "<leader>"
		end,
	},
}
