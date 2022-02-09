if exists('g:loaded_snippy') || !has('nvim')
    finish
endif
let g:loaded_snippy = 1

" Navigational mappings
inoremap <silent> <plug>(snippy)          <cmd>lua require 'snippy'.expand_or_advance()<cr>
inoremap <silent> <plug>(snippy-expand)   <cmd>lua require 'snippy'.expand()<cr>
inoremap <silent> <plug>(snippy-next)     <cmd>lua require 'snippy'.next()<cr>
inoremap <silent> <plug>(snippy-previous) <cmd>lua require 'snippy'.previous()<cr>

snoremap <silent> <plug>(snippy)          <cmd>lua require 'snippy'.expand_or_advance()<cr>
snoremap <silent> <plug>(snippy-next)     <cmd>lua require 'snippy'.next()<cr>
snoremap <silent> <plug>(snippy-previous) <cmd>lua require 'snippy'.previous()<cr>

" Selecting/cutting text
nnoremap <silent> <plug>(snippy-cut-text) <cmd>set operatorfunc=snippy#cut_text<cr>g@
xnoremap <silent> <plug>(snippy-cut-text) <cmd>call snippy#cut_text(mode(), v:true)<cr>

" Commands
command! -bang -nargs=? -complete=customlist,snippy#complete
            \ Snippets   call snippy#open(<q-args>, <bang>0)

command! SnippetsReload lua require 'snippy.cache'.clear_cache()
