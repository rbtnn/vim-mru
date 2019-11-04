
if has('vimscript-3')
    scriptversion 3
else
    finish
endif

let g:loaded_mru = 1

command! -bar -nargs=0   MRU     :call mru#exec()

augroup most-recently-used
    autocmd!
    autocmd BufEnter * :call mru#bufenter()
augroup END

