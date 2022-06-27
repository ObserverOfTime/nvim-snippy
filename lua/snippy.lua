local buf = require('snippy.buf')
local shared = require('snippy.shared')
local util = require('snippy.util')
local cache = require('snippy.cache')

local Builder = require('snippy.builder')

local api = vim.api
local fn = vim.fn
local t = util.t

local M = {}

-- Stop management

local function ensure_normal_mode()
    if fn.mode() ~= 'n' then
        api.nvim_feedkeys(t('<Esc>'), 'n', true)
    end
end

local function cursor_placed()
    -- The autocmds must be set up only after the cursor jumps to the tab stop
    api.nvim_feedkeys(t("<cmd>lua require('snippy.buf').setup_autocmds()<CR>"), 'n', true)
end

local function move_cursor_to(row, col)
    local line = fn.getline(row)
    col = math.max(fn.strchars(line:sub(1, col)) - 1, 0)
    api.nvim_feedkeys(t(string.format('%sG0%s', row, string.rep('<Right>', col))), 'n', true)
end

local function select_stop(from, to)
    api.nvim_win_set_cursor(0, { from[1] + 1, from[2] + 1 })
    ensure_normal_mode()
    move_cursor_to(from[1] + 1, from[2] + 1)
    api.nvim_feedkeys(t('v'), 'n', true)
    move_cursor_to(to[1] + 1, to[2])
    api.nvim_feedkeys(t('o<c-g>'), 'n', true)
    cursor_placed()
end

local function start_insert(row, col)
    if fn.pumvisible() == 1 then
        -- Close choice (completion) menu if open
        fn.complete(fn.col('.'), {})
    end
    api.nvim_win_set_cursor(0, { row, col })
    if fn.mode() ~= 'i' then
        if fn.mode() == 's' then
            api.nvim_feedkeys(t('<Esc>'), 'nx', true)
        end
        local line = api.nvim_get_current_line()
        if col >= #line then
            vim.cmd('startinsert!')
        else
            vim.cmd('startinsert')
        end
    end
    cursor_placed()
end

local function make_completion_choices(choices)
    local items = {}
    for _, value in ipairs(choices) do
        table.insert(items, {
            word = value,
            abbr = value,
            menu = '[Snippy]',
            kind = 'Choice',
        })
    end
    return items
end

local function present_choices(stop, startpos)
    vim.defer_fn(function()
        fn.complete(startpos[2] + 1, make_completion_choices(stop.spec.choices))
    end, shared.config.choice_delay)
end

local function add_empty_lines(text, n)
    local ln = api.nvim_win_get_cursor(0)[1]
    while n > 0 and fn.getline(ln + 1) ~= '' do
        text = text .. '\n'
        ln = ln + 1
        n = n - 1
    end
    return text
end

-- Snippet management

local function get_snippet_at_cursor()
    local lnum, col = unpack(api.nvim_win_get_cursor(0))

    local line_to_col = api.nvim_get_current_line():sub(1, col)
    local nows_line_to_col = line_to_col:gsub('^%s*', '')
    local word = line_to_col:match('(%S*)$')
    local default = fn.matchstr(line_to_col, '\\v%(^|\\s+)\\zs\\S+$')
    local word_bound = fn.matchstr(word, '\\k\\+$')
    local bol = word == line_to_col
    local bof = lnum == 1 and word == line_to_col
    local snippets = cache.snippets or cache.cache_snippets()

    while #word > 0 do
        for _, scope in ipairs(cache.get_scopes()) do
            if scope and snippets[scope] and snippets[scope][word] then
                local snippet = snippets[scope][word]
                if snippet.option.inword then
                    -- Match inside word
                    return word, snippet
                elseif snippet.option.bof then
                    -- Match if word is first on file
                    if bof then
                        return word, snippet
                    end
                elseif snippet.option.bol then
                    -- Match if word is first on line (absolute)
                    if bol and word == word_bound then
                        return word, snippet
                    end
                elseif snippet.option.beginning then
                    -- Match if word is first on line (trimmed)
                    if word == nows_line_to_col then
                        return word, snippet
                    end
                elseif snippet.option.word then
                    -- Match on word boundary, also with non-whitespace
                    if word_bound == word then
                        return word, snippet
                    end
                elseif default == word then
                    -- Match on word boundary, preceded by whitespace
                    return word, snippet
                end
            end
        end
        word = word:sub(2)
    end
    return nil, nil
end

local function get_lsp_item(user_data)
    if user_data then
        if user_data.nvim and user_data.nvim.lsp then
            return user_data.nvim.lsp.completion_item
        elseif user_data.lspitem then
            local lspitem = user_data.lspitem
            return type(lspitem) == 'string' and vim.fn.json_decode(lspitem) or lspitem
        end
    end
end

-- Public functions

function M.complete()
    local col = api.nvim_win_get_cursor(0)[2]
    local current_line = api.nvim_get_current_line()
    local word = current_line:sub(1, col):match('(%S*)$')
    local items = M.get_completion_items()
    local choices = {}
    for _, item in ipairs(items) do
        if item.word:sub(1, #word) == word then
            item.menu = '[Snippy]'
            table.insert(choices, item)
        end
    end
    fn.complete(col - #word + 1, choices)
end

function M.complete_done()
    local completed_item = vim.v.completed_item
    if completed_item.user_data then
        local word = completed_item.word
        local user_data = completed_item.user_data
        local snippet
        if type(user_data) == 'table' then
            if user_data.snippy then
                snippet = user_data.snippy.snippet
            else
                local lsp_item = get_lsp_item(user_data) or {}
                if lsp_item.textEdit and type(lsp_item.textEdit) == 'table' then
                    snippet = lsp_item.textEdit.newText
                elseif lsp_item.insertTextFormat == 2 then
                    snippet = lsp_item.insertText
                end
            end
        end
        if snippet then
            M.expand_snippet(snippet, word)
        end
    end
end

function M.get_completion_items()
    local items = {}
    local snippets = cache.snippets or cache.cache_snippets()

    for _, scope in ipairs(cache.get_scopes()) do
        if scope and snippets[scope] then
            for _, snip in pairs(snippets[scope]) do
                table.insert(items, {
                    word = snip.prefix,
                    abbr = snip.prefix,
                    kind = 'Snippet',
                    dup = 1,
                    user_data = {
                        snippy = {
                            snippet = snip,
                        },
                    },
                })
            end
        end
    end

    return items
end

function M.cut_text(mode, visual)
    local tmpval, tmptype = fn.getreg('"'), fn.getregtype('"')
    local keys
    if visual then
        keys = 'gv'
        vim.cmd('normal! y')
    else
        if mode == 'line' then
            keys = "'[V']"
        elseif mode == 'char' then
            keys = '`[v`]'
        else
            return
        end
        vim.cmd('normal! ' .. keys .. 'y')
    end
    shared.set_selection(api.nvim_eval('@"'), mode)
    fn.setreg('"', tmpval, tmptype)
    api.nvim_feedkeys(t(keys .. '"_c'), 'n', true)
end

function M.previous()
    local stops = buf.stops
    local stop = (buf.current_stop or 0) - 1
    while stops[stop] and not stops[stop].traversable do
        stop = stop - 1
    end
    return M._jump(stop)
end

function M.next()
    local stops = buf.stops
    local stop = (buf.current_stop or 0) + 1
    while stops[stop] and not stops[stop].traversable do
        stop = stop + 1
    end
    return M._jump(stop)
end

function M._jump(stop)
    local stops = buf.stops
    if not stops or #stops == 0 then
        return false
    end
    if buf.current_stop ~= 0 then
        buf.mirror_stop(buf.current_stop)
        buf.deactivate_stop(buf.current_stop)
    end
    local should_finish = false
    if #stops >= stop and stop > 0 then
        -- Disable autocmds so we can move freely
        buf.clear_autocmds()
        buf.activate_stop(stop)
        buf.mirror_stop(stop)

        local value = stops[stop]
        local startpos, endpos = value:get_range()
        local empty = startpos[1] == endpos[1] and endpos[2] == startpos[2]
        if empty or value.spec.type == 'choice' then
            if stop == #stops then
                should_finish = true
            else
                start_insert(endpos[1] + 1, endpos[2])
            end
            if value.spec.type == 'choice' then
                present_choices(value, startpos)
            end
        else
            select_stop(startpos, endpos)
        end
    else
        should_finish = true
    end

    if should_finish then
        -- Start inserting at the end of the current stop
        local value = stops[buf.current_stop]
        local _, endpos = value:get_range()
        start_insert(endpos[1] + 1, endpos[2])
        buf.clear_state()
    end

    return true
end

function M.parse_snippet(snippet)
    local ok, parsed, pos
    local text
    local parser = require('snippy.parser')
    if type(snippet) == 'table' then
        -- Structured snippet
        text = table.concat(snippet.body, '\n')
        if snippet.option and snippet.option.empty_lines then
          text = add_empty_lines(text, snippet.option.empty_lines)
        end
        if snippet.kind == 'snipmate' then
            text = require'snippy.parser.eval'.resolve_interpolations(text)
            if shared.config.generic_tabstops then
                text = text:gsub('vvv', '$VISUAL')
                text = text:gsub('___', '${_}')
            end
            ok, parsed, pos = parser.parse_snipmate(text, 1)
        else
            ok, parsed, pos = parser.parse(text, 1)
        end
    else
        -- Text snippet
        text = snippet
        ok, parsed, pos = parser.parse(text, 1)
    end
    if not ok or pos <= #text then
        error("> Error while parsing snippet: didn't parse till the end")
        return ''
    end
    return parsed
end

function M.expand_snippet(snippet, word)
    vim.wo.foldenable = false
    local current_line = api.nvim_get_current_line()
    local row, col = unpack(api.nvim_win_get_cursor(0))
    if fn.mode() ~= 'i' then
        col = math.min(#current_line, col + 1)
    end
    if not word then
        word = ''
    end
    col = col - #word
    local indent = current_line:match('^(%s*)')
    local parsed = M.parse_snippet(snippet)
    local fixed_col = col -- fn.strchars(current_line:sub(1, col))
    local builder = Builder.new({ row = row, col = fixed_col, indent = indent, word = word })
    local content, stops = builder:build_snip(parsed)
    local lines = vim.split(content, '\n', true)
    api.nvim_set_option('undolevels', api.nvim_get_option('undolevels'))
    api.nvim_buf_set_text(0, row - 1, col, row - 1, col + #word, lines)
    buf.place_stops(stops)
    M.next()
    return ''
end

function M.get_repr(snippet)
    local parsed = M.parse_snippet(snippet)
    local builder = Builder.new({ row = 0, col = 0, indent = '', word = '' })
    local content, _ = builder:build_snip(parsed, true)
    return content
end

function M.expand_or_advance()
    return M.expand() or M.next()
end

function M.expand()
    local word, snippet = get_snippet_at_cursor()
    Snippy_last_char = nil
    if word and snippet then
        return M.expand_snippet(snippet, word)
    end
    return false
end

function M.can_expand()
    local word, snip = get_snippet_at_cursor()
    if word and snip then
        return true
    else
        return false
    end
end

function M.can_jump(dir)
    local stops = buf.state().stops
    if dir >= 0 then
        return #stops > 0 and buf.current_stop <= #stops
    else
        return #stops > 0 and buf.current_stop > 1
    end
end

function M.can_expand_or_advance()
    return M.can_expand() or M.can_jump(1)
end

function M.is_active()
    return buf.current_stop > 0 and not vim.tbl_isempty(buf.stops)
end

function M.complete_snippet_files(prefix)
    local files = {}
    for _, reader in ipairs(shared.readers) do
        vim.list_extend(files, reader.list_existing_files())
    end
    local results = {}
    for _, file in ipairs(files) do
        if file:find(prefix, 1, true) then
            table.insert(results, fn.fnamemodify(file, ':p'))
        end
    end
    return results
end

-------------------------------------------------------------------------------
-- Setup
-------------------------------------------------------------------------------

vim.cmd([[
    augroup snippy
    autocmd!
    autocmd FileType,BufReadPost,DirChanged * lua require 'snippy.cache'.cache_snippets()
    augroup END
]])

function M.setup(o)
    shared.set_config(o)
    table.insert(shared.readers, require('snippy.reader.snipmate'))
    require('snippy.mapping').init()
end

return M
