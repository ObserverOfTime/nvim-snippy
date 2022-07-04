local fn = vim.fn
local list_dirs = require("snippy.directories").list_dirs
local cache = require("snippy.cache")

local M = {}

function M.fold_text()
    local line = fn.getline(vim.v.foldstart)
    local trigger = line:match("^snippet%s+(%S+)") or line
    local desc = line:match('"(.*)"') or ""
    local opts = line:match('"%s+(%S+)$') or ""
    return string.format("%-15s%-40s%s", trigger, desc, opts)
end

function M.fold_expr()
    local line = function(n) return fn.getline(vim.v.lnum + n) end
    local curline = line(0)
    if curline:match("^[eivf]") then
        return 0
    elseif curline == "" and line(1):match("^#") ~= nil then
        return ">1"
    elseif curline == "" and line(-1):match("^#") ~= nil then
        return 0
    elseif not curline:match("^\t") and not curline:match("^$") then
        return ">1"
    else
        return 1
    end
end

local function goto_file(ft, name, import)
    for _, dir in ipairs(fn.split(list_dirs(), ",")) do
        if import then
            local path = dir .. ft .. "/" .. name .. ".snippets"
            if fn.filereadable(path) == 1 then
                return path
            end
        else
            local sdir = dir .. name
            local path = sdir .. ".snippets"
            if fn.filereadable(path) == 1 then
                return path
            elseif fn.isdirectory(sdir) == 1 then
                return sdir
            end
        end
    end
end

function M.goto_file()
    local line = fn.getline(".")
    local path = fn.expand("%:p")
    local ft = path:match("snippets%p(%w+).lua$") or path:match("snippets%p(%w+)%p")
    if line:match("^extends %S+$") then
        local fname = goto_file(ft, line:match("%S+$"))
        if fname then
            vim.cmd("edit " .. fname)
        end
    elseif line:match("^imports %S+$") then
        local fname = goto_file(ft, line:match("%S+$"), true)
        if fname then
            vim.cmd("edit " .. fname)
        end
    end
end


return M
