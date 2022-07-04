" Vim filetype plugin for SnipMate snippets (.snippets and .snippet files)

if exists("b:did_ftplugin")
    finish
endif
let b:did_ftplugin = 1

let b:undo_ftplugin = "setl et< sts< cms< fdm< fde<"

setlocal commentstring=#\ %s
setlocal nospell

" Use hard tabs
setlocal noexpandtab softtabstop=0

setlocal foldmethod=expr foldexpr=v:lua.require'snippy.ftplugin'.fold_expr()

set foldtext=v:lua.require'snippy.ftplugin'.fold_text()

nnoremap <buffer> gf :call v:lua.require'snippy.ftplugin'.goto_file()<cr>
