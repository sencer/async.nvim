local M = {}
local running_jobs = {} -- Track running jobs: { [pid] = { handle = ..., desc = ... } }

M.run_cmd = function(opts)
	-- Run a command via shell to handle quoting properly.
	return M.run_shell(opts)
end

M.run_shell = function(opts)
	-- Run a bash script, provided as string.
	local handle
	handle = vim.system({ vim.o.shell, "-c", opts.command }, {
		text = true,
		stdout = opts.on_stdout,
		stderr = opts.on_stderr,
	}, function(obj)
		-- on_exit callback
		if handle and handle.pid then
			running_jobs[handle.pid] = nil
		end
		if opts.on_exit then
			opts.on_exit(obj)
		end
	end)

	if handle and handle.pid then
		running_jobs[handle.pid] = { handle = handle, desc = opts.command }
	end
	return handle
end

M.get_running_jobs = function()
	return running_jobs
end

M.stop_job = function(pid)
	local job = running_jobs[pid]
	if job then
		job.handle:kill(15) -- SIGTERM
		running_jobs[pid] = nil
		return true
	end
	return false
end

M.qf = function(opts)
	vim.cmd.cclose()
	vim.fn.setqflist({}, " ", opts)

	local buffer = ""
	local lines_to_add = {}

	local function process_line(line)
		if line ~= "" then
			table.insert(lines_to_add, line)
		end
	end

	local output_watcher = function(err, data)
		if err then
			print("Error: " .. err)
			return
		end
		if data then
			buffer = buffer .. data
			local lines = vim.split(buffer, "\n", { plain = true })
			buffer = lines[#lines]
			for i = 1, #lines - 1 do
				process_line(lines[i])
			end
		end
	end

	local timer = vim.uv.new_timer()
	timer:start(0, 50, function()
		if #lines_to_add > 0 then
			local lines = lines_to_add
			lines_to_add = {}
			vim.schedule(function()
				vim.fn.setqflist({}, "a", { efm = opts.efm, lines = lines })
			end)
		end
	end)

	local job = M.run_shell({
		command = opts.command,
		on_stdout = output_watcher,
		on_stderr = function() end,
		on_exit = function(obj)
			if not timer:is_closing() then
				timer:stop()
				timer:close()
			end
			if buffer ~= "" then
				process_line(buffer)
			end
			if #lines_to_add > 0 then
				vim.schedule(function()
					vim.fn.setqflist({}, "a", { efm = opts.efm, lines = lines_to_add })
				end)
			end
			vim.schedule(function()
				vim.cmd("doautocmd QuickFixCmdPost cfile")
				if opts.on_finish then
					opts.on_finish()
				end
			end)
		end,
	})

	return job
end

local current_callback = nil

M.op_func = function(type)
	local start_mark = vim.api.nvim_buf_get_mark(0, "[")
	local end_mark = vim.api.nvim_buf_get_mark(0, "]")

	local start_row, start_col = start_mark[1] - 1, start_mark[2]
	local end_row, end_col = end_mark[1] - 1, end_mark[2]

	local target_line = (vim.api.nvim_buf_get_lines(0, end_row, end_row + 1, false)[1]) or ""
	if #target_line == 0 then
		end_col = 0
	else
		local valid_end_col = math.min(end_col, #target_line)
		local char_idx = vim.str_utfindex(target_line, valid_end_col)
		end_col = vim.str_byteindex(target_line, math.min(#target_line, char_idx + 1))
	end

	local lines = vim.api.nvim_buf_get_text(0, start_row, start_col, end_row, end_col, {})
	local text = table.concat(lines, "\n")

	if current_callback then
		current_callback(text)
	end
end

M.set_op = function(callback)
	current_callback = callback
	vim.o.operatorfunc = "v:lua.require'sencer.async'.op_func"
	return "g@"
end

return M
