local fn = vim.fn
local list_dirs = require('snippy.directories').list_dirs
local cache = require('snippy.cache')

local M = {}

local exprs = {
    '%s.snippets',
    '%s_*.snippets',
    '%s/*.snippets',
    '%s/*.snippet',
    '%s/*/*.snippet',
}

-- Valid characters for snippet options.
local OPT_CHARS = 'wib#^_G'

-- Loading

local function parse_options(opt)
    return not opt and {} or {
        word = opt:find('w') and true,
        inword = opt:find('i') and true,
        beginning = opt:find('b') and true,
        bol = opt:find('%^') and true,
        bof = opt:find('%#') and true,
        empty_lines = opt:match('_') and opt:match('_+'):len(),
        no_generic = opt:find('G') and true,
    }
end

local function read_snippets_file(snippets_file, scope)
    local snips = {}
    local extends = {}
    local imports = {}
    local expressions = {}
    local file = io.open(snippets_file)
    local lines = vim.split(file:read('*a'), '\n')

    if scope and lines[1] == 'importable' then
        if not cache.importable[scope] then
            cache.importable[scope] = {}
        end
        local basename = vim.fn.fnamemodify(snippets_file, ':t:r')
        cache.importable[scope][basename] = snippets_file
        return {}, {}, {}, {}
    end

    if lines[#lines] == '' then
        table.remove(lines)
    end
    local i = 1

    local function _parse()
        local line = lines[i]
        local prefix = line:match('%s+(%S+)%s*')
        assert(prefix, 'prefix is nil: ' .. line .. ', file: ' .. snippets_file)
        local description = line:match('%s*"(.+)"%s*')
        local option = parse_options(line:match('%s+%S+%s+([' .. OPT_CHARS .. ']+)$'))
        local body = {}
        local indent = nil
        i = i + 1
        while i <= #lines do
            line = lines[i]
            if line:find('^%s+') then
                if not indent and line ~= '' then
                    indent = line:match('%s+')
                end
                line = line:sub(#indent + 1)
                line = line:gsub('^' .. indent .. '+', function(m)
                    return string.rep('\t', #m / #indent)
                end)
                table.insert(body, line)
                i = i + 1
            elseif line == '' then
                table.insert(body, line)
                i = i + 1
            else
                break
            end
        end
        -- ignore the last empty line after the snippet body
        if body[#body] == '' then
          table.remove(body)
        end
        snips[prefix] = {
            kind = 'snipmate',
            prefix = prefix,
            description = description,
            option = option,
            body = body,
        }
    end

    local function _parse_expression()
      local line = lines[i]
      local prefix = line:match('%s+(%S+)%s*')
      assert(prefix, 'prefix is nil: ' .. line .. ', file: ' .. snippets_file)
      i = i + 1
      if i <= #lines then
        line = lines[i]
        if line:find('^%s+') then
          expressions[prefix] = line:match("%S.*")
        end
        i = i + 1
      end
      -- read only the first line
      while not lines[i]:find('^%S') do
          i = i + 1
      end
    end

    while i <= #lines do
        local line = lines[i]
        if line:sub(1, 7) == 'snippet' then
            _parse()
        elseif line == 'importable' then
            i = i + 1
        elseif line:sub(1, 7) == 'extends' then
            local scopes = vim.split(vim.trim(line:sub(8)), '%s+')
            vim.list_extend(extends, scopes)
            i = i + 1
        elseif line:sub(1, 7) == 'imports' then
            table.insert(imports, line:sub(8):match('%S+'))
            i = i + 1
        elseif line:sub(1, 10) == 'expression' then
            _parse_expression()
        elseif line:sub(1, 1) == '#' or vim.trim(line) == '' then
            -- Skip empty lines or comments
            i = i + 1
        else
            error(string.format('Invalid line in snippets file %s: %s', snippets_file, line))
        end
    end
    return snips, expressions, extends, imports
end

local function read_single_snippet_file(snippet_file, scope)
    local description, prefix
    if snippet_file:match('/' .. scope .. '/.-/.*%.snippet$') then
        prefix = fn.fnamemodify(snippet_file, ':h:t')
        description = fn.fnamemodify(snippet_file, ':t:r')
    else
        prefix = fn.fnamemodify(snippet_file, ':t:r')
    end
    local file = io.open(snippet_file)
    local body = vim.split(file:read('*a'), '\n')
    if body[#body] == '' then
        body = vim.list_slice(body, 1, #body - 1)
    end
    return {
        [prefix] = {
            kind = 'snipmate',
            prefix = prefix,
            description = description,
            body = body,
        },
    }
end

local function list_files(ftype, dirs)
    local all = {}
    dirs = dirs or list_dirs()
    for _, expr in ipairs(exprs) do
        local e = expr:format(ftype)
        local paths = fn.globpath(dirs, e, 0, 1)
        all = vim.list_extend(all, paths)
    end
    return all
end

local function load_scope(scope, stack, files)
    local snips = {}
    local extends = {}
    local imports = {}
    local expressions = {}
    for _, file in ipairs(files or list_files(scope)) do
        local result = {}
        local extended
        if file:match('.snippets$') then
            result, expr, extended, imports = read_snippets_file(file, scope)
            extends = vim.list_extend(extends, extended)
        elseif file:match('.snippet$') then
            result = read_single_snippet_file(file, scope)
        end
        snips = vim.tbl_extend('force', snips, result)
        expressions = vim.tbl_extend('force', expressions, expr)
    end
    for _, import in ipairs(imports) do
        if cache.importable[scope][import] then
            local result, expr, extended = read_snippets_file(cache.importable[scope][import])
            extends = vim.list_extend(extends, extended)
            expressions = vim.tbl_extend('force', expressions, expr)
            snips = vim.tbl_extend('force', snips, result)
        end
    end
    for _, extended in ipairs(extends) do
        if vim.tbl_contains(stack, extended) then
            error(
                string.format(
                    'Recursive dependency found: %s',
                    table.concat(vim.tbl_flatten({ stack, extended }), ' -> ')
                )
            )
        end
        local result = load_scope(extended, vim.tbl_flatten({ stack, scope }))
        snips = vim.tbl_extend('keep', snips, result)
    end
    return snips, expressions
end

function M.list_existing_files()
    local files = {}
    for _, scope in ipairs(cache.get_scopes()) do
        local scope_files = list_files(scope)
        vim.list_extend(files, scope_files)
    end
    return files
end

function M.read_snippets()
    local snips, expressions = {}, {}
    local scopes = cache.get_scopes()
    for _, scope in ipairs(scopes) do
        if scope and scope ~= '' then
            if not cache.scopes[scope] then
                cache.scopes[scope], expressions[scope] = load_scope(scope, {})
            end
            snips[scope] = cache.scopes[scope]
        end
    end
    if fn.isdirectory('.snippets') == 1 then
      for _, scope in ipairs(scopes) do
        if scope and scope ~= '' then
            local s, e = load_scope(scope, {}, list_files(scope, '.snippets'))
            snips[scope] = vim.tbl_extend('force', snips[scope], s)
            expressions[scope] = vim.tbl_extend('force', expressions[scope] or {}, e)
        end
      end
    end
    return snips, expressions
end

return M
