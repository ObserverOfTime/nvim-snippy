" Syntax highlighting for .snippet files (used for snipMate.vim)
" Hopefully this should make snippets a bit nicer to write!

syn region snipPh matchgroup=Special start='\${\w\+:' end='}' contains=snipPhSel
syn match snipStop '\$\d\+\|___\|vvv'
syn match snipEscape '\\\\\|\\`'
syn match snipPhSel '.\{-}\ze}' contained
syn region snipEval start='`' end='\\\\`\|[^\\]`'
syn match snipVariable '$\v(VISUAL|TM_\w+)'

syn region snipChoice start='\${\d\+|' end='|}' contains=snipChoiceVal
syn match snipChoiceVal '[|,]\zs[^,|]\+[^}]\ze[|,]' contained

hi default link snipEscape    SpecialChar
hi default link snipChoice    Special
hi default link snipChoiceVal Keyword
hi default link snipTrans     Special
hi default link snipStop      Special
hi default link snipPhSel     String
hi default link snipEval      Special
hi default link snipVariable  PreProc
