
if has('vimscript-3')
    scriptversion 3
else
    finish
endif

function! s:fullpath(path) abort
    let path = a:path
    " resolve a path if the result is not UNC path.
    if resolve(path) !~# '^//'
        let path = resolve(path)
    endif
    return fnamemodify(resolve(a:path), ':p:gs?\\?/?')
endfunction

let s:mru_jsons = get(s:, 'mru_jsons', [])
let s:mru_limit = 300
let s:mru_delimiter = ' | '
let s:mru_title = 'mru'
let s:mru_cache_path_old = s:fullpath(expand('<sfile>:h:h') .. '/.most_recently_used')
let s:mru_cache_path = s:fullpath(expand('<sfile>:h:h') .. '/.mru')
let s:mru_defaultopt = {
    \   'title' : s:mru_title,
    \   'pos' : 'center',
    \   'padding' : [1,3,1,3],
    \ }

function! mru#exec(q_args) abort
    let jsons = deepcopy(s:mru_jsons)

    " remove the current file
    let path = s:fullpath(expand('%'))
    if filereadable(path)
        call filter(jsons, { i,x -> x['path'] != path })
    endif

    " filter matching q_args
    call filter(jsons, { i,x -> fnamemodify(x['path'], ':t') =~# a:q_args })

    let tstatus = term_getstatus(bufnr())
    if (tstatus != 'finished') && !empty(tstatus)
        call popup_notification('could not open on running terminal buffer', s:mru_defaultopt)
    elseif !empty(getcmdwintype())
        call popup_notification('could not open on command-line window', s:mru_defaultopt)
    elseif &modified
        call popup_notification('could not open on modified buffer', s:mru_defaultopt)
    elseif empty(jsons)
        call popup_notification('no most recently used', s:mru_defaultopt)
    else
        " make display-string for lnum
        for json in jsons
            if -1 == json['lnum']
                let json['lnum'] = ''
            else
                let json['lnum'] = printf('Line %d', json['lnum'])
            endif
        endfor

        " calcate the width of first column
        let fname_max = 0
        let lnum_max = 0
        for json in jsons
            let fname = fnamemodify(json['path'], ':t')
            if fname_max < strdisplaywidth(fname)
                let fname_max = strdisplaywidth(fname)
            endif
            let lnum = json['lnum']
            if lnum_max < strdisplaywidth(lnum)
                let lnum_max = strdisplaywidth(lnum)
            endif
        endfor

        " make lines
        let lines = []
        for json in jsons
            let fname = fnamemodify(json['path'], ':t')
            let lnum = json['lnum']
            let dir = fnamemodify(json['path'], ':h')
            let lines += [join([
                \ s:padding_right_space(fname, fname_max),
                \ s:padding_right_space(lnum, lnum_max),
                \ dir], s:mru_delimiter)]
        endfor

        let winid = popup_menu(lines, extend(deepcopy(s:mru_defaultopt), {
            \   'title' : printf('%s(%d)', s:mru_title, len(lines)),
            \   'close' : 'button',
            \   'maxwidth' : &columns * 2 / 3,
            \   'maxheight' : &lines * 2 / 3,
            \   'callback' : function('s:mru_callback'),
            \ }))
        call setwinvar(winid, 'jsons', jsons)
    endif
endfunction

function! mru#vimenter() abort
    if filereadable(s:mru_cache_path_old) && !filereadable(s:mru_cache_path)
        call rename(s:mru_cache_path_old, s:mru_cache_path)
    endif
    let jsons = []
    let added_paths = []
    if filereadable(s:mru_cache_path)
        for line in readfile(s:mru_cache_path)
            let json = {}
            if line =~# '^{'
                let json = json_decode(line)
            else
                let json = { 'path' : line, }
            endif
            if has_key(json, 'path')
                let json['path'] = s:fullpath(json['path'])
                if !has_key(json, 'lnum')
                    let json['lnum'] = -1
                endif
                " does not support UNC path.
                if json['path'] !~# '^//'
                    if filereadable(json['path']) && (-1 == index(added_paths, json['path']))
                        let added_paths += [json['path']]
                        let jsons += [json]
                    endif
                endif
            endif
        endfor
    endif
    let s:mru_jsons = jsons
endfunction

function! mru#vimleave() abort
    let lines = map(s:mru_jsons, { i,x -> json_encode(x) })
    call writefile(lines[:(s:mru_limit)], s:mru_cache_path)
endfunction

function! mru#bufleave() abort
    let path = s:fullpath(expand('%'))
    let lnum = line('.')
    if filereadable(path) && (&buftype != 'help') && (path != s:mru_cache_path)
        let jsons = [{ 'path' : path, 'lnum' : lnum, }]
        for json in s:mru_jsons
            if json['path'] != path
                let jsons += [json]
            endif
        endfor
        let s:mru_jsons = jsons
    endif
endfunction

function! s:mru_callback(id, key) abort
    if 0 < a:key
        let jsons = getwinvar(a:id, 'jsons', [])
        let path = jsons[(a:key - 1)]['path']
        let lnum = jsons[(a:key - 1)]['lnum']
        let lnum = matchstr(lnum, '^Line \zs\d\+$')
        if empty(lnum)
            let lnum = '1'
        endif
        let matches = filter(getbufinfo(), {i,x -> s:fullpath(x.name) == path })
        if !empty(matches)
            execute printf('%s +%s %d', 'buffer', lnum, matches[0]['bufnr'])
        else
            execute printf('%s +%s %s', 'edit', lnum, escape(path, ' \'))
        endif
    endif
endfunction

function! s:padding_right_space(text, width)
    return a:text .. repeat(' ', a:width - strdisplaywidth(a:text))
endfunction

