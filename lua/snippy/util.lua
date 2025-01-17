-- Util

local api = vim.api
local cmd = vim.cmd

local M = {}

function M.print_error(...)
    api.nvim_err_writeln(table.concat(vim.tbl_flatten({ ... }), ' '))
    cmd('redraw')
end

function M.is_after(pos1, pos2)
    return pos1[1] > pos2[1] or (pos1[1] == pos2[1] and pos1[2] > pos2[2])
end

function M.is_before(pos1, pos2)
    return pos1[1] < pos2[1] or (pos1[1] == pos2[1] and pos1[2] < pos2[2])
end

function M.t(input)
    return api.nvim_replace_termcodes(input, true, false, true)
end

function M.parse_comment_string()
    local defaults = {
        ['start'] = '/*',
        ['end'] = '*/',
        ['line'] = '//',
    }
    local commentstr = vim.bo.commentstring
    local parts = vim.split(commentstr, '%s-%%s%s-')
    if not parts then
        return defaults
    elseif parts[2] == '' then
        defaults['line'] = parts[1]
    else
        defaults['start'] = parts[1]
        defaults['end'] = parts[2]
    end
    return defaults
end

return M
