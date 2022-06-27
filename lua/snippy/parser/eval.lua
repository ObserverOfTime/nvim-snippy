local util = require('snippy.util')

local M = {}

local function eval(code, indent)
    local builder = require'snippy.builder'.new({ indent = indent, row = 1, col = 1 })
    local structure = {{ ['type'] = 'eval', children = { { raw = code } } }}
    builder:process_structure(structure)
    return builder.result
end

local function parse(text, from_pos)
    local escaped = false
    local code, pos, start = '', from_pos - 1, 0
    for ch in string.gmatch(text:sub(from_pos), ".") do
        pos = pos + 1
        if escaped then
            escaped = false
            code = code .. (ch == '`' and '' or '\\') .. ch
        elseif ch == '\\' then
            escaped = true
        elseif ch == '`' then
            if start == 0 then
                start = pos
            else
                local pre = text:sub(1, start - 1)
                local indent = pre:match('[ \t]*$')
                text = pre .. eval(code:gsub('[ \n]+', ' '), indent) .. text:sub(pos + 1)
                return parse(text, start + 1)
            end
        elseif start > 0 then
            code = code .. ch
        end
    end
    if start > 0 then
        util.print_error(string.format('Missing closing backtick: %s', text))
        return ''
    end
    return text
end

function M.resolve_interpolations(text)
    return parse(text, 1)
end

return M
