
if has('vimscript-3')
    scriptversion 3
else
    finish
endif

function! mru#exec() abort
    let paths = s:mru_paths()
    let path = s:fullpath(expand('%'))
    if 0 <= index(paths, path)
        call remove(paths, path)
    endif
    let tstatus = term_getstatus(bufnr())
    if (tstatus != 'finished') && !empty(tstatus)
        call popup_notification('running terminal', {
            \   'title' : 'Most Recently Used',
            \   'pos' : 'center',
            \   'padding' : [1,3,1,3],
            \ })
    elseif &modified
        call popup_notification('current buffer is modified', {
            \   'title' : 'Most Recently Used',
            \   'pos' : 'center',
            \   'padding' : [1,3,1,3],
            \ })
    elseif empty(paths)
        call popup_notification('no most recently used', {
            \   'title' : 'Most Recently Used',
            \   'pos' : 'center',
            \   'padding' : [1,3,1,3],
            \ })
    else
        " calcate the width of first column
        let max = 0
        for i in range(0, len(paths) - 1)
            let fname = fnamemodify(paths[i], ':t')
            if max < strdisplaywidth(fname)
                let max = strdisplaywidth(fname)
            endif
        endfor

        " make lines
        for i in range(0, len(paths) - 1)
            let fname = fnamemodify(paths[i], ':t')
            let dir = fnamemodify(paths[i], ':h')
            let paths[i] = printf('%s | %s', s:padding_right_space(fname, max), dir)
        endfor

        call popup_menu(paths, {
            \   'title' : 'Most Recently Used',
            \   'pos' : 'center',
            \   'padding' : [1,3,1,3],
            \   'close' : 'button',
            \   'maxwidth' : &columns * 2 / 3,
            \   'maxheight' : &lines * 2 / 3,
            \   'callback' : function('s:mru_callback'),
            \ })
    endif
endfunction

function! mru#bufenter() abort
    let path = s:fullpath(expand('%'))
    if filereadable(path) && (&buftype != 'help') && (path != s:mru_cache_path)
        let paths = [path]
        for x in s:mru_paths()
            let x = s:fullpath(x)
            if -1 == index(paths, x)
                let paths += [x]
            endif
        endfor
        call writefile(uniq(paths)[:(s:mru_limit)], s:mru_cache_path)
    endif
endfunction

function! s:fullpath(path) abort
    return fnamemodify(a:path, ':p:gs?\\?/?')
endfunction

function! s:mru_paths() abort
    let paths = []
    if filereadable(s:mru_cache_path)
        let paths = filter(readfile(s:mru_cache_path), { i, x -> filereadable(x) })
    endif
    return paths
endfunction

function! s:mru_callback(id, key) abort
    if 0 <= a:key
        let xs = split(getbufline(winbufnr(a:id), a:key)[0], '|')
        let path = s:fullpath(trim(xs[1]) .. '/' .. trim(xs[0]))
        let matches = filter(getbufinfo(), {i,x -> s:fullpath(x.name) == path })
        execute printf('%s %s', (!empty(matches) ? 'buffer' : 'edit'), escape(path, ' \'))
    endif
endfunction

function! s:padding_right_space(text, width)
    return a:text .. repeat(' ', a:width - strdisplaywidth(a:text))
endfunction

let s:mru_cache_path = s:fullpath(expand('<sfile>:h:h') .. '/.most_recently_used')
let s:mru_limit = 30

