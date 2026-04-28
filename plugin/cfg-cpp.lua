vim.api.nvim_create_user_command("CfgCpp", function()
	require("cfg_cpp").run()
end, {})

vim.keymap.set("n", "<leader>cg", function()
	require("cfg_cpp").run()
end, { desc = "Generate call graph" })
