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

M.exec = function(command, opts)
	opts = opts or {}
	return vim.async.await(3, function(cmd, opt, cb)
		local handle
		handle = vim.system(
			{ vim.o.shell, "-c", cmd },
			opt,
			vim.schedule_wrap(function(obj)
				if handle and handle.pid then
					running_jobs[handle.pid] = nil
				end
				cb(obj)
			end)
		)
		if handle and handle.pid then
			running_jobs[handle.pid] = { handle = handle, desc = cmd }
		end
		return {
			close = function(self, done)
				if handle and not handle:is_closing() then
					handle:kill(15)
				end
				if done then
					done()
				end
			end,
		}
	end, command, opts)
end

M.qf = function(opts)
	vim.cmd.cclose()
	vim.fn.setqflist({}, " ", opts)

	local buffer = ""
	local pending_lines = {}
	local total_added = 0
	local max_results = opts.max_rows or opts.max_results or vim.g.async_qf_max_rows or vim.g.async_qf_max_results or 2000
	local batch_size = opts.batch_size or 500
	local job_handle = nil
	local timer = vim.uv.new_timer()
	local process_exited = false
	local exit_obj = nil
	local stopped = false
	local notified = false

	local function stop_and_notify()
		if not stopped then
			stopped = true
			if job_handle and not job_handle:is_closing() then
				job_handle:kill(15)
			end
			if not notified then
				notified = true
				vim.schedule(function()
					vim.notify(string.format("Search reached %d rows limit; stopped.", max_results), vim.log.levels.WARN)
				end)
			end
		end
	end

	local function finish_job()
		if timer and not timer:is_closing() then
			timer:stop()
			timer:close()
		end
		vim.schedule(function()
			vim.cmd("doautocmd QuickFixCmdPost cfile")
			if opts.on_finish then
				opts.on_finish(exit_obj)
			end
		end)
	end

	local function flush()
		if #pending_lines == 0 then
			if process_exited then
				finish_job()
			end
			return
		end

		local cur_limit = batch_size
		if max_results > 0 then
			cur_limit = math.min(batch_size, max_results - total_added)
			if cur_limit <= 0 then
				pending_lines = {}
				finish_job()
				return
			end
		end

		local lines
		if #pending_lines > cur_limit then
			lines = {}
			for i = 1, cur_limit do
				lines[i] = pending_lines[i]
			end
			local remaining = {}
			for i = cur_limit + 1, #pending_lines do
				table.insert(remaining, pending_lines[i])
			end
			pending_lines = remaining
		else
			lines = pending_lines
			pending_lines = {}
		end

		total_added = total_added + #lines
		vim.fn.setqflist({}, "a", { efm = opts.efm, lines = lines })

		if max_results > 0 and total_added >= max_results then
			stop_and_notify()
			pending_lines = {}
			finish_job()
			return
		end

		if process_exited and #pending_lines == 0 then
			finish_job()
		end
	end

	local output_watcher = function(err, data)
		if err then
			print("Error: " .. err)
			return
		end
		if not stopped and data and data ~= "" then
			buffer = buffer .. data
			local lines = vim.split(buffer, "\n", { plain = true })
			buffer = table.remove(lines) or ""
			for _, line in ipairs(lines) do
				if line ~= "" then
					table.insert(pending_lines, line)
					if max_results > 0 and (total_added + #pending_lines) >= max_results then
						stop_and_notify()
						break
					end
				end
			end
		end
	end

	timer:start(0, 50, function()
		vim.schedule(flush)
	end)

	local job = M.run_shell({
		command = opts.command,
		on_stdout = output_watcher,
		on_stderr = function() end,
		on_exit = function(obj)
			process_exited = true
			exit_obj = obj
			if not stopped and buffer ~= "" then
				table.insert(pending_lines, buffer)
				buffer = ""
			end
			vim.schedule(flush)
		end,
	})

	job_handle = job
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
		if valid_end_col >= #target_line then
			end_col = #target_line
		else
			local char_idx = vim.str_utfindex(target_line, valid_end_col)
			end_col = vim.str_byteindex(target_line, char_idx + 1)
		end
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
