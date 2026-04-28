local M = {}
vim.notify("My plugin is being loaded")
local plugin_dir = require("lazy.core.config").plugins["cfg-cpp.nvim"].dir
local binary = plugin_dir .. "/cpp/build/callgraphgen"
local dot_output = "/tmp/callgraph.dot"
local svg_output = "/tmp/callgraph.svg"
vim.notify("Hello from the exec part")
function M.run()
	local buf = vim.api.nvim_get_current_buf()
	local ft = vim.bo[buf].filetype

	if ft ~= "cpp" then
		vim.notify("cfg-cpp: not a cpp file", vim.log.levels.WARN)
		return
	end

	local path = vim.api.nvim_buf_get_name(buf)
	local project_dir = vim.fn.fnamemodify(path, ":h")

	vim.notify("cfg-cpp: generating call graph...", vim.log.levels.INFO)

	vim.system({ binary, path, "-p", project_dir }, { text = true }, function(result)
		if result.code ~= 0 then
			vim.notify("cfg-cpp: tool failed\n" .. result.stderr, vim.log.levels.ERROR)
			return
		end

		-- write dot output
		local dot_file = io.open(dot_output, "w")
		if not dot_file then
			vim.notify("cfg-cpp: failed to write dot file", vim.log.levels.ERROR)
			return
		end
		dot_file:write(result.stdout)
		dot_file:close()

		-- render with dot
		vim.system(
			{ "dot", "-Tsvg", "-Grankdir=LR", dot_output, "-o", svg_output },
			{ text = true },
			function(dot_result)
				if dot_result.code ~= 0 then
					vim.notify("cfg-cpp: dot failed\n" .. dot_result.stderr, vim.log.levels.ERROR)
					return
				end

				vim.schedule(function()
					vim.notify("cfg-cpp: opening call graph", vim.log.levels.INFO)
					vim.fn.jobstart({ "xdg-open", svg_output }, { detach = true })
				end)
			end
		)
	end)
end

vim.api.nvim_create_user_command("CfgCpp", M.run, {})
vim.keymap.set("n", "<leader>cg", M.run, { desc = "Generate call graph" })

return M
