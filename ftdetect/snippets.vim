au BufRead,BufNewFile *.snippet  setlocal filetype=snippet
au BufRead,BufNewFile *.snippets setlocal filetype=snippets
au BufWritePost       *.snippet,*.snippets lua require 'snippy.cache'.clear_cache()
