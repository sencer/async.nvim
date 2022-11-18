local async = require("sencer.async")

local M = {}

local function get_prg(typ, bufnr)
	local grepprg
	if #vim.bo[bufnr][typ] > 0 then
		grepprg = vim.bo[bufnr][typ]
	elseif #vim.o[typ] > 0 then
		grepprg = vim.o[typ]
	else
		print(typ .. " not set.")
		return
	end

	return grepprg
end

local function run(typ, text)
	local bufnr = vim.fn.bufnr()

	local prg = get_prg(typ, bufnr)

	if prg == nil then
		return
	end

	text = vim.trim(text)
	local command = #text > 0 and (prg .. " " .. vim.trim(text)) or prg

	local efm = typ == "grepprg" and vim.o.grepformat
		or (#vim.bo.errorformat > 0 and vim.bo.errorformat or vim.o.errorformat)

	local opts = {
		nr = "$",
		title = command,
		efm = efm,

		command = command,
	}

	local job = async.qf(opts)

	return job
end

M.search = function(text)
	return run("grepprg", text)
end

M.make = function(text)
	return run("makeprg", text)
end

return M
