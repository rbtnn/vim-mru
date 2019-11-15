
if has('vimscript-3')
    scriptversion 3
else
    finish
endif

let g:loaded_mru = 1

command! -nargs=*   MRU     :call mru#exec(<q-args>)

augroup most-recently-used
    autocmd!
    autocmd BufEnter * :call mru#bufenter()
augroup END

