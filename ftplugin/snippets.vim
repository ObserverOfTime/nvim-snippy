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

setlocal foldmethod=expr foldexpr=getline(v:lnum)!~'^\\t\\\\|^$'?'>1':1

set foldtext=v:lua.SnippyFoldText()

lua << EOF
function SnippyFoldText()
    local line = vim.fn.getline(vim.v.foldstart)
    local trigger = line:match('^%S+%s+(%S+)')
    local desc = line:match('"(.*)"') or ''
    local opts = line:match('"%s+(%S+)$') or ''
    return string.format('%-15s%-40s%s', trigger, desc, opts)
end
EOF
