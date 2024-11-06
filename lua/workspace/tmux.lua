local M = {}

function M.manage_session(project_path, workspace, options)
	local project_name
	if project_path == "newProject" then
		project_name = vim.fn.input("Enter project name: ")
		if project_name and #project_name > 0 then
			project_path = vim.fn.fnamemodify(vim.fn.expand(workspace.path .. "/" .. project_name), ":p")
			os.execute("mkdir -p " .. project_path)
		end
	else
		project_name = project_path:match("./([^/]+)$")
	end

	local session_name = options.tmux_session_name_generator(project_name, workspace.name)

	if session_name == nil then
		session_name = string.upper(project_name)
	end
	session_name = session_name:gsub("[^%w_]", "_")

	local tmux_session_check = os.execute("tmux has-session -t=" .. session_name .. " 2> /dev/null")
	if tmux_session_check ~= 0 then
		os.execute("tmux new-session -ds " .. session_name .. " -c " .. project_path)
	end

	os.execute("tmux switch-client -t " .. session_name)
end

function M.attach(session_name)
	local tmux_session_check = os.execute("tmux has-session -t=" .. session_name .. " 2> /dev/null")
	if tmux_session_check == 0 then
		os.execute("tmux switch-client -t " .. session_name)
	end
end

function M.is_running()
	local tmux_running = os.execute("pgrep tmux > /dev/null")
	local in_tmux = vim.fn.exists("$TMUX") == 1
	if tmux_running == 0 and in_tmux then
		return true
	end
	return false
end

function M.delete_project(project_path, workspace)
	-- Ensure the path is valid
	if not project_path or project_path == "" then
		vim.api.nvim_err_writeln("Invalid project path.")
		return
	end

	-- Verify that the project is within the workspace path
	local workspace_path = vim.fn.expand(workspace.path)
	if not vim.startswith(project_path, workspace_path) then
		vim.api.nvim_err_writeln("Project path is outside the workspace.")
		return
	end

	-- Delete the project directory
	local escaped_path = vim.fn.shellescape(project_path)
	local cmd = "rm -rf " .. escaped_path
	local result = os.execute(cmd)
	if result == 0 then
		vim.api.nvim_out_write("Project deleted successfully.\n")
	else
		vim.api.nvim_err_writeln("Failed to delete the project.")
	end

	-- Also delete the tmux session associated with the project, if it exists
	local project_name = vim.fn.fnamemodify(project_path, ":t")
	local session_name = workspace.tmux_session_name_generator(project_name, workspace.name)
	session_name = session_name:gsub("[^%w_]", "_")
	M.kill_session(session_name)
end

function M.kill_session(session_name)
	if not session_name or session_name == "" then
		vim.api.nvim_err_writeln("Invalid session name.")
		return
	end

	local cmd = "tmux kill-session -t " .. vim.fn.shellescape(session_name)
	local result = os.execute(cmd)
	if result == 0 then
		vim.api.nvim_out_write("Tmux session '" .. session_name .. "' deleted successfully.\n")
	else
		vim.api.nvim_err_writeln("Failed to delete tmux session '" .. session_name .. "'.")
	end
end
return M
