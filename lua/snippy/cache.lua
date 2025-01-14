local cfg = require'snippy.shared'.config

local M = {}

M.directories = nil
M.snippets = nil
M.expressions = nil
M.scopes = {}
M.importable = {}

function M.get_scopes()
    local ft = vim.bo.filetype

    local scopes = vim.tbl_flatten({ '_', vim.split(ft, '.', true) })

    if cfg.scopes[ft] then
        local fts = cfg.scopes[ft]
        scopes = type(fts) == 'table' and fts or fts(scopes)
    end

    return scopes
end

function M.cache_snippets()
    for _, reader in ipairs(require'snippy.shared'.readers) do
        local s, e = reader.read_snippets()
        M.snippets = vim.tbl_extend('force', M.snippets or {}, s)
        M.expressions = vim.tbl_deep_extend('force', M.expressions or {}, e)
    end
    return M.snippets
end

function M.cache_expressions(expressions)
    if not M.expressions then
        M.cache_snippets()
    end
    return M.expressions
end

function M.clear_cache()
    M.directories = require'snippy.directories'.list_dirs()
    M.snippets = nil
    M.expressions = nil
    M.scopes = {}
end

return M
