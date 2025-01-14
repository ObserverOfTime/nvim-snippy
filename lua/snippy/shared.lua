local M = {}

local default_config = {
    snippet_dirs = nil,
    hl_group = nil,
    scopes = {},
    mappings = {},
    choice_delay = 100,
    generic_tabstops = true,
}

M.namespace = vim.api.nvim_create_namespace('snippy')
M.config = vim.tbl_extend('force', {}, default_config)
M.readers = {}

function M.set_selection(value, mode)
    if mode == 'V' or mode == 'line' then
        value = value:sub(1, #value - 1)
        local lines = vim.split(value, '\n')
        local indent = ''
        for i, line in ipairs(lines) do
            if i == 1 then
                indent = line:match('^%s*')
            end
            lines[i] = line:gsub('^' .. indent, '')
        end
        value = table.concat(lines, '\n')
    end
    M.selected_text = value
end

function M.set_config(params)
    vim.validate({
        params = { params, 't' },
    })
    if params.snippet_dirs then
        local dirs = params.snippet_dirs
        local dir_list = type(dirs) == 'table' and dirs or vim.split(dirs, ',')
        for _, dir in ipairs(dir_list) do
            if vim.fn.isdirectory(vim.fn.expand(dir) .. '/snippets') == 1 then
                vim.api.nvim_echo({
                    {
                        'Snippy: folders in "snippet_dirs" should no longer contain a "snippets" subfolder',
                        'WarningMsg',
                    },
                }, true, {})
            end
        end
    end
    M.config = vim.tbl_extend('force', M.config, params)
end

return M
