" Copied and adapted from SnipMate
au BufRead,BufNewFile *.snippet,*.snippets setlocal filetype=snippets
au BufWritePost       *.snippet,*.snippets SnippyReload

au FileType snippets if expand('<afile>:e') =~# 'snippet$'
            \ | setlocal syntax=snippet
            \ | else
                \ | setlocal syntax=snippets
                \ | endif
