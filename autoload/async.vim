function! async#OpFuncWrapper(Fn) abort

    function! OpFunc(type) abort closure
        let l:backup = @l
        if a:type ==# 'block' && line("'>") == line("'<")
            normal! `<v`>"ly
        elseif a:type ==# 'char'
            normal! `[v`]"ly
        else
            return
        endif

        call a:Fn(@l)
        let @l = l:backup
    endfunction

    set operatorfunc=OpFunc
    return 'g@'
endfunction
