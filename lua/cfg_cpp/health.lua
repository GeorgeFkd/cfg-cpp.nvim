local M = {}
function M.check()
	local config = require("cfg_cpp").config
	-- lua package.loaded['cfg_cpp.health'] = nil; vim.cmd('checkhealth cfg_cpp')
	local clang = config.clangexecpath or "clang"
	local dot = config.dotexecpath or "dot"
	local plugin_dir = require("lazy.core.config").plugins["cfg-cpp.nvim"].dir
	vim.health.ok("Plugin located at: " .. plugin_dir)
	local result = vim.fn.system({ clang, "--version" })
	if vim.v.shell_error == 0 then
		vim.health.ok("clang executable:" .. "\n" .. result)
	else
		vim.health.error("clang executable is not there,install it using your system's package manager.")
	end

	local result = vim.fn.system({ dot, "--version" })

	if vim.v.shell_error == 0 then
		vim.health.ok("dot executable:" .. "\n" .. result)
	else
		vim.health.error("dot executable is not installed, install it using your system's package manager.")
	end

	vim.health.ok("Output directory: " .. config.output_dir)
end

return M
