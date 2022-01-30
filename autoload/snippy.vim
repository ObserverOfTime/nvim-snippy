function! snippy#can_expand() abort
    return luaeval("require 'snippy'.can_expand()")
endfunction

function! snippy#can_expand_or_advance() abort
    return luaeval("require 'snippy'.can_expand_or_advance()")
endfunction

function! snippy#can_jump(direction) abort
    return luaeval("require 'snippy'.can_jump(_A)", a:direction)
endfunction

function! snippy#cut_text(...) abort
    return luaeval('require("snippy").cut_text(_A[1], _A[2])', a:000)
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" SnippyEdit
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! snippy#complete(...) abort
    return luaeval('require("snippy").complete_snippet_files(_A)', a:1)
endfunction

function! snippy#open(args, bang) abort
    if a:args != ''
        execute 'split' fnameescape(a:args)
    elseif a:bang
        execute 'split .snippets/' . &ft . '.snippets' 
    else
        let dir = stdpath('data') . '/site/snippets/'
        execute 'split' dir . &ft . '.snippets' 
    endif
endfunction
