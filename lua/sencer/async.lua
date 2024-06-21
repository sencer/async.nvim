local joblib = require("plenary.job")
local M = {}

M.run_cmd = function(opts)
	-- Run a command.
	local cmd = vim.split(opts.command, " ")
	return joblib:new(
		vim.tbl_extend("force", opts, { interactive = false, command = cmd[1], args = vim.list_slice(cmd, 2) })
	)
end

M.run_shell = function(opts)
	-- Run a bash script, provided as string.
	return joblib:new(
		vim.tbl_extend("force", opts, { interactive = false, command = vim.o.shell, args = { "-c", opts.command } })
	)
end

M.qf = function(opts)
	-- Run a command or bash script; use its stdout or stderr to populate quickfix.
	vim.cmd.cclose()
	-- Create a new qflist
	vim.fn.setqflist({}, " ", opts)

	local fn = opts.run_shell and M.run_shell or M.run_cmd

	local output_watcher = vim.schedule_wrap(function(err, line)
		if err ~= nil then
			print("Error adding to qf : " .. err)
			return
		end

		vim.fn.setqflist({}, "a", { efm = opts.efm, lines = { line } })
	end)

	local job = fn({
		command = opts.command,
		on_stdout = output_watcher,
		on_stderr = output_watcher,
		on_exit = vim.schedule_wrap(function()
			vim.cmd("doautocmd QuickFixCmdPost cfile")
		end),
	})

	job:start()
	return job
end

return M
