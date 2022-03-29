" Syntax highlighting for .snippets files (used for snipMate.vim)
" Hopefully this should make snippets a bit nicer to write!

runtime syntax/snippet.vim

syn match snipComment '^#.*'

syn match snipDirective '^[^s \t]\+.*' contains=snipKeyword,snipExtra
syn keyword snipKeyword extends imports importable version nextgroup=snipExtra contained
syn match snipExtra     '\s\+.*' contained

syn match snipLine      '^snippet.*' contains=snipTrigger,snipDesc,snipOptions
syn match snipTrigger   '\s\+\S\+' contained nextgroup=snipDesc,snipOptions
syn match snipDesc      '\s\+".*"' nextgroup=snipOptions contained
syn match snipOptions   '\s\+[wib#s^_]\+$' contained
syn match snipError     "^[^#vsei\t ].*$"

hi default link snipLine      Identifier
hi default link snipComment   Comment
hi default link snipTrigger   Constant
hi default link snipKeyword   Keyword
hi default link snipError     Error
hi default link snipDesc      String
hi default link snipExtra     String
hi default link snipOptions   Special
