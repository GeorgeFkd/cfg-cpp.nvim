local M = {}
M.config = {
	keymap = "<leader>cg",
	desc = "Generate call graph",
	dotexecpath = "dot",
	clangexecpath = "clang",
	output_dir = "/tmp",
	debug = false,
	open_externally = false,
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

local function get_target_height(win)
	local win_height = vim.api.nvim_win_get_height(win)
	local screen_height = tonumber(vim.fn.system("xdpyinfo | grep dimensions | awk '{print $2}' | cut -dx -f2"))
	local lines = vim.o.lines
	local pixels_per_cell = math.floor(screen_height / lines)
	return (win_height - 4) * pixels_per_cell
end

--TODO: add debug mode
--TODO  add customisability(in the dot command,in the open command, in the keymap)
function M.run()
	local plugin_dir = require("lazy.core.config").plugins["cfg-cpp.nvim"].dir
	local binary = plugin_dir .. "/cpp/build/callgraphgen"
	local dot_output = M.config.output_dir .. "/callgraph.dot"
	local png_output = M.config.output_dir .. "/callgraph.png"
	local resized_output = M.config.output_dir .. "/resized-callgraph.png"
	local buf = vim.api.nvim_get_current_buf()
	local ft = vim.bo[buf].filetype

	if ft ~= "cpp" then
		vim.notify("cfg-cpp: not a cpp file", vim.log.levels.WARN)
		return
	end
	-- the calculation happens here as we cant do it in the callback of a system command
	local current_win = vim.api.nvim_get_current_win()
	local target_height = get_target_height(current_win)
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
	if M.config.debug then
		vim.notify("cfg-cpp: generating call graph...", vim.log.levels.INFO)
	end
	local exec_command = { binary, path, "-p", build_dir, "--", "-resource-dir", resource_dir }
	vim.system(exec_command, { text = true }, function(result)
		if result.code ~= 0 then
			vim.notify("cfg-cpp: tool failed\n" .. result.stderr, vim.log.levels.ERROR)
			return
		end
		local dot_file = io.open(dot_output, "w")
		if not dot_file then
			vim.notify("cfg-cpp: failed to write dot file", vim.log.levels.ERROR)
			return
		end
		dot_file:write(result.stdout)
		dot_file:close()

		local dot_command = { "dot", "-Tpng", "-Grankdir=LR", dot_output, "-o", png_output }
		vim.system(dot_command, { text = true }, function(dot_result)
			if dot_result.code ~= 0 then
				--TODO: should not be handled like this
				vim.notify("cfg-cpp: dot failed\n" .. dot_result.stderr, vim.log.levels.ERROR)
				return
			end
			if M.config.open_externally then
				vim.schedule(function()
					-- vim.notify("cfg-cpp: opening call graph", vim.log.levels.INFO)
					vim.fn.jobstart({ "xdg-open", png_output }, { detach = true })
				end)
				return
			end
			local magick_resize_command = { "magick", png_output, "-resize", "x" .. target_height, resized_output }
			vim.system(magick_resize_command, { text = true }, function(resize_result)
				if resize_result.code ~= 0 then
					vim.notify("cfg-cpp: magick resize failed\n" .. resize_result.stderr, vim.log.levels.ERROR)
					return
				end
				vim.schedule(function()
					local image = require("image").from_file(resized_output)
					if image == nil then
						print("Could not find image.nvim plugin to open the call graph with")
						return
					end
					vim.cmd("tabnew")
					local win = vim.api.nvim_get_current_win()
					local imgbuf = vim.api.nvim_get_current_buf()
					vim.api.nvim_win_set_width(win, 80)
					local image_tab = vim.api.nvim_get_current_tabpage()
					image:render({ window = win, buffer = imgbuf, x = 0, y = 0 })
					local leave_autocmd, enter_autocmd
					leave_autocmd = vim.api.nvim_create_autocmd("TabLeave", {
						callback = function()
							if vim.api.nvim_get_current_tabpage() == image_tab then
								image:clear()
							end
						end,
					})
					enter_autocmd = vim.api.nvim_create_autocmd("TabEnter", {
						callback = function()
							if vim.api.nvim_get_current_tabpage() == image_tab then
								image:render({ window = win, buffer = imgbuf, x = 0, y = 0 })
							end
						end,
					})
					vim.api.nvim_create_autocmd("TabClosed", {
						once = true,
						callback = function()
							if vim.api.nvim_get_current_tabpage() == image_tab then
								image:clear()
								vim.api.nvim_del_autocmd(leave_autocmd)
								vim.api.nvim_del_autocmd(enter_autocmd)
							end
						end,
					})
				end)
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
