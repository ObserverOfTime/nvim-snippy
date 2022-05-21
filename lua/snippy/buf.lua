local shared = require('snippy.shared')
local util = require('snippy.util')

local Stop = require('snippy.stop')

local fn = vim.fn
local api = vim.api
local cmd = vim.cmd

local M = {}

M._state = {}

setmetatable(M, {
    __index = function(self, key)
        if key == 'current_stop' then
            return self.state().current_stop
        elseif key == 'stops' then
            return self.state().stops
        else
            return rawget(self, key)
        end
    end,
    __newindex = function(self, key, value)
        if key == 'current_stop' then
            self.state().current_stop = value
        elseif key == 'stops' then
            self.state().stops = value
        else
            return rawset(self, key, value)
        end
    end,
})

local function add_mark(id, startrow, startcol, endrow, endcol, right_gravity, end_right_gravity)
    local mark = api.nvim_buf_set_extmark(0, shared.namespace, startrow, startcol, {
        id = id,
        end_line = endrow,
        end_col = endcol,
        hl_group = shared.config.hl_group,
        right_gravity = right_gravity,
        end_right_gravity = end_right_gravity,
    })
    return mark
end

local function get_children(number)
    local value = M.state().stops[number]
    for n, stop in ipairs(M.state().stops) do
        if value.id == stop.spec.parent then
            return vim.list_extend({ n }, get_children(n))
        end
    end
    return {}
end

local function get_parents(number)
    local value = M.state().stops[number]
    if not value.spec.parent then
        return {}
    end
    for n, stop in ipairs(M.state().stops) do
        if stop.id == value.spec.parent and stop.spec.type == 'placeholder' then
            return vim.list_extend({ n }, get_parents(n))
        end
    end
    return {}
end

local function activate_parents(number)
    local parents = get_parents(number)
    for _, n in ipairs(parents) do
        local stop = M.state().stops[n]
        local from, to = stop:get_range()
        local mark_id = stop.mark
        local _ = add_mark(mark_id, from[1], from[2], to[1], to[2], false, true)
    end
end

local function deactivate_parents(number)
    local parents = get_parents(number)
    for _, n in ipairs(parents) do
        local stop = M.state().stops[n]
        local from, to = stop:get_range()
        local mark_id = stop.mark
        local _ = add_mark(mark_id, from[1], from[2], to[1], to[2], true, true)
    end
end

function M.clear_children(stop_num)
    local current_stop = M.stops[M.current_stop]
    local children = get_children(stop_num)
    table.sort(children)
    for i = #children, 1, -1 do
        table.remove(M.state().stops, children[i])
    end
    -- Reset current stop index
    for i, stop in ipairs(M.state().stops) do
        if stop.id == current_stop.id and #children > 0 then
            M.current_stop = i
            break
        end
    end
end

function M.state()
    local bufnr = api.nvim_buf_get_number(0)
    if not M._state[bufnr] then
        M._state[bufnr] = {
            stops = {},
            current_stop = 0,
        }
    end
    return M._state[bufnr]
end

function M.add_stop(spec, pos)
    local function is_traversable()
        for _, stop in ipairs(M.state().stops) do
            if stop.id == spec.id then
                return false
            end
        end
        return spec.type == 'tabstop' or spec.type == 'placeholder' or spec.type == 'choice'
    end
    local startrow = spec.startpos[1] - 1
    local startcol = spec.startpos[2]
    local endrow = spec.endpos[1] - 1
    local endcol = spec.endpos[2]
    local stops = M.state().stops
    local smark = add_mark(nil, startrow, startcol, endrow, endcol, true, true)
    table.insert(stops, pos, Stop.new({ id = spec.id, traversable = is_traversable(), mark = smark, spec = spec }))
    M.state().stops = stops
end

-- Change the extmarks to expand on change
function M.activate_stop(number)
    local value = M.state().stops[number]
    for n, stop in ipairs(M.state().stops) do
        if stop.id == value.id then
            local from, to = stop:get_range()
            local mark_id = stop.mark
            local _ = add_mark(mark_id, from[1], from[2], to[1], to[2], false, true)
            activate_parents(n)
        end
    end
    if value.spec.type == 'placeholder' then
        value.placeholder = value:get_text()
    end
    M.state().current_stop = number
    M.update_state()
end

-- Change the extmarks NOT to expand on change
function M.deactivate_stop(number)
    local value = M.state().stops[number]
    for n, stop in ipairs(M.state().stops) do
        if stop.id == value.id then
            local from, to = stop:get_range()
            local mark_id = stop.mark
            local _ = add_mark(mark_id, from[1], from[2], to[1], to[2], true, true)
            deactivate_parents(n)
        end
    end
end

function M.update_state()
    local current_stop = M.stops[M.current_stop]
    if not current_stop then
        return
    end
    local before = current_stop:get_before()
    M.state().before = before
end

function M.fix_current_stop()
    local current_stop = M.stops[M.current_stop]
    if not current_stop then
        return
    end
    local new = current_stop:get_before()
    local old = M.state().before or new
    local current_line = api.nvim_get_current_line()
    if new ~= old and current_line:sub(1, #old) == old then
        local stop = M.stops[M.current_stop]
        local from, to = stop:get_range()
        add_mark(stop.mark, from[1], #old, to[1], to[2], false, true)
    end
end

-------------------------------------------------------------------------------
-- Place stops
-------------------------------------------------------------------------------

--- Create ids for id-less tabstops and named placeholders.
--- @param stops table
local function create_missing_ids(stops)
    local max_id = 0
    -- find the maximum numbered tabstop/placeholder
    -- numberless tabstops/placeholders will come after those
    for _, stop in ipairs(stops) do
        if stop.id then
            if max_id < stop.id then
                max_id = stop.id
            end
        end
    end
    -- create ids for yet id-less stops
    local ns = #stops
    local last_is_zero = stops[ns].id == 0
    for i, stop in ipairs(stops) do
        if not stop.id then
            if last_is_zero and i == ns - 1 then
                stop.id = 0
                table.remove(stops)
                break
            end
            max_id = max_id + 1
            if stop.name and stop.name ~= '_' then
                for _, st in ipairs(stops) do
                    if st.name == stop.name then
                        st.id = max_id
                    end
                end
            else
                if stop.name == '_' then stop.name = nil end
                stop.id = max_id
            end
        end
    end
end

--- Sort the tabstops. If id == 0, it comes last, if ids are different, lower
--- id comes first. If it's the same named placeholder, the one with a default
--- value comes first.
--- @param stops table: the unsorted tabstops
--- @return table: sorted tabstops
local function sort_stops(stops)
    table.sort(stops, function(s1, s2)
        if s1.id == 0 then
            return false
        elseif s2.id == 0 then
            return true
        elseif s1.name and s1.name == s2.name then
            return ( next(s1.children) and not next(s2.children) )
        elseif s2.name and s1.name == s2.name then
            return ( next(s2.children) and not next(s1.children) )
        elseif s1.id < s2.id then
            return true
        elseif s1.id > s2.id then
            return false
        end
        return util.is_before(s1.startpos, s2.startpos)
    end)
end

local function make_unique_ids(stops)
    local max_id = M.max_id or 0
    local id_map = {}
    for _, stop in ipairs(stops) do
        if id_map[stop.id] then
            stop.id = id_map[stop.id]
        else
            max_id = max_id + 1
            id_map[stop.id] = max_id
            stop.id = max_id
        end
    end
    for _, stop in ipairs(stops) do
        if stop.parent then
            stop.parent = id_map[stop.parent]
        end
    end
    M.max_id = max_id
end

function M.place_stops(stops)
    create_missing_ids(stops)
    sort_stops(stops)
    make_unique_ids(stops)
    local pos = M.current_stop + 1
    for _, spec in ipairs(stops) do
        M.add_stop(spec, pos)
        pos = pos + 1
    end
end

-------------------------------------------------------------------------------
-- Mirror stops
-------------------------------------------------------------------------------

function M.mirror_stop(number)
    local stops = M.stops
    if number < 1 or number > #stops then
        return
    end
    local value = stops[number]
    local text = value:get_text()
    for i, stop in ipairs(stops) do
        if i > number and stop.id == value.id then
            stop:set_text(text)
        end
    end
    if value.spec.type == 'placeholder' then
        if text ~= value.placeholder then
            M.clear_children(number)
        end
    end
end

-------------------------------------------------------------------------------
-- Autocommands
-------------------------------------------------------------------------------

local function did_undo()
    local ut = fn.undotree()
    return ut.seq_last ~= ut.seq_cur
end

-- Check if the cursor is inside any stop
local function check_position()
    local stops = M.stops
    local row, col = unpack(api.nvim_win_get_cursor(0))
    row = row - 1
    local max_row = vim.api.nvim_buf_line_count(0) - 1
    for _, stop in ipairs(stops) do
        local from, to = stop:get_range()
        local startrow, startcol = unpack(from)
        local endrow, endcol = unpack(to)
        if fn.mode() == 'n' then
            if startcol + 1 == fn.col('$') then
                startcol = startcol - 1
            end
            if endcol + 1 == fn.col('$') then
                endcol = endcol - 1
            end
        end

        if startrow > max_row or endrow > max_row then
            break
        end

        if
            (startrow < row or (startrow == row and startcol <= col))
            and (endrow > row or (endrow == row and endcol >= col))
        then
            return
        end
    end
    M.clear_state()
end

function M._TextChanged()
    if did_undo() then
        M.clear_state()
        return
    end
    M.fix_current_stop()
    M.update_state()
    if M.current_stop ~= 0 then
        M.mirror_stop(M.current_stop)
    end
end

function M._TextChangedP()
    M.fix_current_stop()
end

function M._CursorMoved()
    check_position()
end

function M._BufWritePost()
    check_position()
end

function M.setup_autocmds()
    local bufnr = api.nvim_buf_get_number(0)
    cmd(string.format(
        [[
            augroup snippy_local
            autocmd! * <buffer=%s>
            autocmd TextChanged,TextChangedI <buffer=%s> lua require 'snippy.buf'._TextChanged()
            autocmd TextChangedP <buffer=%s> lua require 'snippy.buf'._TextChangedP()
            autocmd CursorMoved,CursorMovedI <buffer=%s> lua require 'snippy.buf'._CursorMoved()
            autocmd BufWritePost <buffer=%s> lua require 'snippy.buf'._BufWritePost()
            autocmd OptionSet *runtimepath* lua require 'snippy.cache'.clear_cache()
            augroup END
        ]],
        bufnr,
        bufnr,
        bufnr,
        bufnr,
        bufnr
    ))
end

-------------------------------------------------------------------------------
-- State clearing
-------------------------------------------------------------------------------

function M.clear_state()
    for _, stop in pairs(M.state().stops) do
        api.nvim_buf_del_extmark(0, shared.namespace, stop.mark)
    end
    M.state().current_stop = 0
    M.state().stops = {}
    M.state().before = nil
    M.max_id = 0
    M.clear_autocmds()
end

function M.clear_autocmds()
    local bufnr = api.nvim_buf_get_number(0)
    cmd(string.format(
        [[
            augroup snippy_local
            autocmd! * <buffer=%s>
            augroup END
        ]],
        bufnr
    ))
end

return M
