# async.nvim

Depends on nvim-lua/plenary.nvim. Provides `run_cmd` to run an external
command; `run_shell` to run a shell script, and `qf` to run a command/shell
script and populate quickfix with its stdout/stderr.

Create `:Make` command to run `makeprg` asynchronously.

Creates `:Grep` command to run `grepprg` asynchronously. Maps `gr` to run
`:Grep` on a textobject or visual selection. `gr<Space>` will open prompt for
`:Grep`.

As a convenience `:Grep!` runs `vimgrep` on all open buffers (synchronously);
and is mapped to `grr` and `grr<Space>`.

`async#OpFuncWrapper`, used for implementing `gr` and `grr` mappings can be
useful for other opfunc mappings. It receives a function as an argument, and
runs it with the pending textobject or visual selection.

`nnoremap <expr> gr async#OpFuncWrapper({x -> execute("Grep ".x)})` for example
is how `griw` greps the word under cursor.
