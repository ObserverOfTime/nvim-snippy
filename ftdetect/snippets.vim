au BufRead,BufNewFile *.snippet  setlocal filetype=snippet
au BufRead,BufNewFile *.snippets setlocal filetype=snippets
au BufWritePost       *.snippet,*.snippets SnippetsReload
