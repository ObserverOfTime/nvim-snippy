" Syntax highlighting for .snippets files (used for snipMate.vim)
" Hopefully this should make snippets a bit nicer to write!

runtime syntax/snippet.vim

syn match snipComment '^#.*'
syn match snipLine '^snippet.*' contains=snipTrigger,snipKeyword,snipDesc,snipOptions
syn match snipLine '^extends.*' contains=snipKeyword
syn match snipLine '^version.*' contains=snipKeyword
syn match snipTrigger '\s\+\S\+' contained nextgroup=snipDesc,snipOptions
syn match snipKeyword '^(snippet|extends|version)'me=s+8 contained
syn match snipDesc '\s\+".*"' nextgroup=snipOptions contained
syn match snipOptions '\s\+[wib#s^_]\+$' contained
syn match snipError "^[^#vse\t ].*$"

hi default link snipLine      Identifier
hi default link snipComment   Comment
hi default link snipTrigger   Constant
hi default link snipKeyword   Keyword
hi default link snipError     Error
hi default link snipDesc      String
hi default link snipOptions   Special
