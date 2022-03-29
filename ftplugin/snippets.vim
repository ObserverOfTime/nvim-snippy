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

setlocal foldmethod=expr foldexpr=v:lua.SnippyFoldExpr()

set foldtext=v:lua.SnippyFoldText()

lua << EOF
function SnippyFoldText()
    local line = vim.fn.getline(vim.v.foldstart)
    local trigger = line:match('^%S+%s+(%S+)') or line
    local desc = line:match('"(.*)"') or ''
    local opts = line:match('"%s+(%S+)$') or ''
    return string.format('%-15s%-40s%s', trigger, desc, opts)
end
function SnippyFoldExpr()
    local line = function(n) return vim.fn.getline(vim.v.lnum + n) end
    if line(0) == '' and line(1):match('^#') ~= nil then
        return '>1'
    elseif line(0) == '' and line(-1):match('^#') ~= nil then
        return 0
    elseif not line(0):match('^\t') and not line(0):match('^$') then
        return '>1'
    else
        return 1
    end
end
EOF
