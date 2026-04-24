if vim.g.loaded_async_nvim ~= nil then
	return
end
vim.g.loaded_async_nvim = true

if vim.fn.executable("rg") == 1 then
	vim.o.grepprg = "rg --vimgrep --smart-case"
end

vim.o.grepformat = "%f:%l:%c: %#%m,%f:%l: %#%m"

-- Grep for async grepprg; Grep! for vimgrep in all buffers.
vim.api.nvim_create_user_command("Grep", function(opts)
	if opts.bang then
		vim.fn.setqflist({}, " ")
		vim.cmd("silent bufdo! try | vimgrepadd " .. opts.args .. " % | catch /E480:/ | endtry")
	else
		require("sencer.makegrep").search(opts.args)
	end
end, { nargs = "+", bang = true })

vim.api.nvim_create_user_command("Make", function(opts)
	require("sencer.makegrep").make(opts.args, opts.bang)
end, { nargs = "*", bang = true })

vim.api.nvim_create_user_command("StopAsync", function(opts)
	local pid = tonumber(opts.args:match("^(%d+):"))
	if pid then
		if require("sencer.async").stop_job(pid) then
			print("Stopped job " .. pid)
		else
			print("Job " .. pid .. " not found")
		end
	else
		pid = tonumber(opts.args)
		if pid then
			if require("sencer.async").stop_job(pid) then
				print("Stopped job " .. pid)
			else
				print("Job " .. pid .. " not found")
			end
		else
			print("Usage: :StopAsync <pid> (or select from completion)")
		end
	end
end, {
	nargs = 1,
	complete = function(ArgLead, CmdLine, CursorPos)
		local jobs = require("sencer.async").get_running_jobs()
		local candidates = {}
		for pid, job in pairs(jobs) do
			local desc = tostring(pid) .. ": " .. job.desc
			table.insert(candidates, desc)
		end
		return vim.tbl_filter(function(c)
			return c:match("^" .. ArgLead)
		end, candidates)
	end,
})
-- Maps
vim.keymap.set("n", "gr<Space>", ":Grep ", { remap = false })
vim.keymap.set("n", "grr<Space>", ":Grep! ", { remap = false })
vim.keymap.set("n", "gr", function()
	return require("sencer.async").set_op(function(text)
		vim.cmd("Grep " .. text)
	end)
end, { expr = true, desc = "Grep operator" })
vim.keymap.set("x", "gr", function()
	return require("sencer.async").set_op(function(text)
		vim.cmd("Grep " .. text)
	end)
end, { expr = true, desc = "Grep operator" })
vim.keymap.set("n", "grr", function()
	return require("sencer.async").set_op(function(text)
		vim.cmd("Grep! " .. text)
	end)
end, { expr = true, desc = "Grep! operator" })
vim.keymap.set("x", "grr", function()
	return require("sencer.async").set_op(function(text)
		vim.cmd("Grep! " .. text)
	end)
end, { expr = true, desc = "Grep! operator" })
