
if has('vimscript-3')
    scriptversion 3
else
    finish
endif

function! mru#exec(q_args) abort
    let jsons = s:mru_jsons()

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
        " calcate the width of first column
        let max = 0
        for json in jsons
            let fname = fnamemodify(json['path'], ':t')
            if max < strdisplaywidth(fname)
                let max = strdisplaywidth(fname)
            endif
        endfor

        " make lines
        let lines = []
        for json in jsons
            let fname = fnamemodify(json['path'], ':t')
            let dir = fnamemodify(json['path'], ':h')
            let lines += [join([
                \ s:padding_right_space(fname, max),
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

function! mru#bufenter() abort
    let path = s:fullpath(expand('%'))
    if filereadable(path) && (&buftype != 'help') && (path != s:mru_cache_path)
        let jsons = [{ 'path' : path, }]
        for json in s:mru_jsons()
            if json['path'] != path
                let jsons += [json]
            endif
        endfor
        call s:save_json(jsons)
    endif
endfunction

function! s:save_json(jsons) abort
    let lines = map(deepcopy(a:jsons), { i,x -> json_encode(x) })
    call writefile(lines[:(s:mru_limit)], s:mru_cache_path)
endfunction

function! s:fullpath(path) abort
    return fnamemodify(resolve(a:path), ':p:gs?\\?/?')
endfunction

function! s:mru_jsons() abort
    let jsons = []
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
                let jsons += [json]
            endif
        endfor
    endif
    return jsons
endfunction

function! s:mru_callback(id, key) abort
    if 0 < a:key
        let jsons = getwinvar(a:id, 'jsons', [])
        let path = jsons[(a:key - 1)]['path']
        let matches = filter(getbufinfo(), {i,x -> s:fullpath(x.name) == path })
        if !empty(matches)
            execute printf('%s %d', 'buffer', matches[0]['bufnr'])
        else
            execute printf('%s %s', 'edit', escape(path, ' \'))
        endif
    endif
endfunction

function! s:padding_right_space(text, width)
    return a:text .. repeat(' ', a:width - strdisplaywidth(a:text))
endfunction

let s:mru_cache_path = s:fullpath(expand('<sfile>:h:h') .. '/.most_recently_used')
let s:mru_limit = 300
let s:mru_delimiter = '|'
let s:mru_title = 'mru'
let s:mru_defaultopt = {
    \   'title' : s:mru_title,
    \   'pos' : 'center',
    \   'padding' : [1,3,1,3],
    \ }


