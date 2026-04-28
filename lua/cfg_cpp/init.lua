local M = {}
M.config = {
	keymap = "<leader>cg",
	desc = "Generate call graph",
	dotexecpath = "dot",
	clangexecpath = "clang",
	output_dir = "/tmp",
	debug = true,
}
local function find_project_root(path)
	local dir = vim.fn.fnamemodify(path, ":h")
	while dir ~= "/" do
		local cmake = dir .. "/CMakeLists.txt"
		if vim.fn.filereadable(cmake) == 1 then
			local lines = vim.fn.readfile(cmake)
			for _, line in ipairs(lines) do
				if line:match("^%s*project%(") then
					return dir
				end
			end
		end
		dir = vim.fn.fnamemodify(dir, ":h")
	end
	return nil
end
local function find_compile_commands(project_root)
	local result = vim.fn.globpath(project_root, "**/compile_commands.json", false, true)
	if #result == 0 then
		return nil
	end
	return vim.fn.fnamemodify(result[1], ":h")
end

--TODO: add debug mode
--TODO  add customisability(in the dot command,in the open command, in the keymap)
function M.run()
	local plugin_dir = require("lazy.core.config").plugins["cfg-cpp.nvim"].dir
	local binary = plugin_dir .. "/cpp/build/callgraphgen"
	local dot_output = M.config.output_dir .. "/callgraph.dot"
	local svg_output = M.config.output_dir .. "/callgraph.svg"
	local buf = vim.api.nvim_get_current_buf()
	local ft = vim.bo[buf].filetype

	if ft ~= "cpp" then
		vim.notify("cfg-cpp: not a cpp file", vim.log.levels.WARN)
		return
	end
	local path = vim.api.nvim_buf_get_name(buf)
	local project_dir = find_project_root(path)
	local build_dir = find_compile_commands(project_dir)
	local resource_dir = vim.fn.system({ M.config.clangexecpath, "--print-resource-dir" }):gsub("\n", "")
	if M.config.debug then
		local msg = "Path: " .. path .. "\n"
		msg = msg .. "Project dir: " .. project_dir .. "\n"
		msg = msg .. "Build dir: " .. build_dir .. "\n"
		msg = msg .. "Clang Resource dir: " .. resource_dir .. "\n"
		vim.notify(msg)
	end
	if not build_dir then
		vim.notify("cfg-cpp: no compile_commands.json found", vim.log.levels.WARN)
		return
	end
	vim.notify("cfg-cpp: generating call graph...", vim.log.levels.INFO)
	local exec_command = { binary, path, "-p", build_dir, "--", "-resource-dir", resource_dir }
	vim.system(exec_command, { text = true }, function(result)
		if result.code ~= 0 then
			vim.notify("cfg-cpp: tool failed\n" .. result.stderr, vim.log.levels.ERROR)
			return
		end
		-- if M.config.debug then
		-- print("Stderr: " .. result.stderr)
		-- end
		-- write dot output
		local dot_file = io.open(dot_output, "w")
		if not dot_file then
			vim.notify("cfg-cpp: failed to write dot file", vim.log.levels.ERROR)
			return
		end
		dot_file:write(result.stdout)
		dot_file:close()

		local dot_command = { "dot", "-Tsvg", "-Grankdir=LR", dot_output, "-o", svg_output }
		vim.system(dot_command, { text = true }, function(dot_result)
			if dot_result.code ~= 0 then
				--TODO: should not be handled like this
				vim.notify("cfg-cpp: dot failed\n" .. dot_result.stderr, vim.log.levels.ERROR)
				return
			end

			vim.schedule(function()
				vim.notify("cfg-cpp: opening call graph", vim.log.levels.INFO)
				vim.fn.jobstart({ "xdg-open", svg_output }, { detach = true })
			end)
		end)
	end)
end

function M.setup(opts)
	opts = opts or {}
	M.config = vim.tbl_deep_extend("force", M.config, opts)

	vim.keymap.set("n", M.config.keymap, function()
		M.run()
	end, { desc = M.config.desc })
	vim.api.nvim_create_user_command("CfgCpp", M.run, {})
end

return M
