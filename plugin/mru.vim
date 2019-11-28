
if has('vimscript-3')
    scriptversion 3
else
    finish
endif

let g:loaded_mru = 1

command! -nargs=*   MRU     :call mru#exec(<q-args>)

augroup mru
    autocmd!
    autocmd BufLeave * :call mru#bufleave()
augroup END

