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
	require("sencer.makegrep").make(opts.args)
end, { nargs = "*" })
-- Maps
vim.keymap.set("n", "gr<Space>", ":Grep ", { remap = false })
vim.keymap.set("n", "grr<Space>", ":Grep! ", { remap = false })
vim.keymap.set("n", "gr", 'async#OpFuncWrapper({x -> execute("Grep ".x)})', { expr = true })
vim.keymap.set("x", "gr", 'async#OpFuncWrapper({x -> execute("Grep ".x)})', { expr = true })
vim.keymap.set("n", "grr", 'async#OpFuncWrapper({x -> execute("Grep! ".x)})', { expr = true })
vim.keymap.set("x", "grr", 'async#OpFuncWrapper({x -> execute("Grep! ".x)})', { expr = true })
