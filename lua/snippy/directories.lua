local fn = vim.fn
local shared = require('snippy.shared')
local cache = require('snippy.cache')

local M = {}

--- Find all directories with snippets.
--- @param dirs any
--- @return string: comma-separated list of directories
local function snip_dirs(dirs)
    local ret = type(dirs) == 'string' and dirs or table.concat(dirs, ',')
    return table.concat(fn.globpath(ret, 'snippets/', 0, 1), ',')
end

--- Directives in runtime path, but put snippets from packages/plugins before
--- user snippets, so that the latter have higher priority.
--- @return table: directories in runtime path
local function rtp_dirs()
    local user, after, new = {}, {}, {}
    local rtp = vim.api.nvim_list_runtime_paths()
    local add = table.insert
    for _, v in ipairs(rtp) do
        if v:match('%Wafter%W') then
            add(after, v)
        elseif v:match('%Wpack%W') or v:match('%Wplugged%W') then
            add(new, v)
        else
            add(user, v)
        end
    end
    for _, v in ipairs(user) do
        add(new, v)
    end
    for _, v in ipairs(after) do
        add(new, v)
    end
    return new
end

--- Comma-separated list of directories with snippets, later directories will
--- have higher priority. Priorities are, from lower to higher:
---
--- 1. snippets in runtime path, except in 'site/snippets'
--- 2. snippets in 'site/snippets' (eg. ~/.local/share/nvim/site/snippets)
--- 3. snippets in 'after' directories
--- 4. snippets in directories from settings
--- 5. project-local snippets (handled in read_snippets)
--- @return string: comma-separated list of directories
function M.list_dirs()
    if cache.directories then
        return cache.directories
    end
    local dirs = snip_dirs(rtp_dirs())
    if shared.config.snippet_dirs then
        local udirs = shared.config.snippet_dirs
        if type(udirs) == 'table' then
          udirs = table.concat(udirs, ',')
        end
        if udirs ~= '' then
            dirs = dirs .. ',' .. udirs
        end
    end
    cache.directories = dirs
    return dirs
end

return M
