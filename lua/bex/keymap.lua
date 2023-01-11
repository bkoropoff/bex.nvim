--- Lua keymap API.
--
-- This module provides a more convenient API for manipulating keymaps
-- than using Ex commands (which is also supported) or raw NVIM
-- API calls.
--
-- Use `bex.keymap.set` to set keymap entries, and `bex.keymap.delete` to
-- remove them.

local bridge = require('bex.bridge').keymap
local util = require('bex.util')

local keymap = {}

local mode_list = {'n', 'v', 'x', 'i', 'o', 't', 'c', 's', '!', 'l'}
local mode_tab = {}
local option_tab = {
    buffer = 'boolean',
    expr = 'boolean',
    noremap = 'boolean',
    nowait = 'boolean',
    script = 'boolean',
    silent = 'boolean',
    unique = 'boolean',
    replace_keycodes = 'boolean',
}

for _, m in ipairs(mode_list) do
    mode_tab[m] = m
end

function bridge:reachable()
    local keymaps = {}
    local bufs = vim.tbl_filter(vim.api.nvim_buf_is_loaded, vim.api.nvim_list_bufs())

    for _, m in ipairs(mode_list) do
        table.insert(keymaps, vim.api.nvim_get_keymap(m))
        for _, bufnr in ipairs(bufs) do
            table.insert(keymaps, vim.api.nvim_buf_get_keymap(bufnr, m))
        end
    end

    return function(ident)
        for _, km in ipairs(keymaps) do
            for _, m in ipairs(km) do
                if string.find(m.rhs, ident) then
                    return true
                end
            end
        end
        return false
    end
end

local function set_option(opts, k, v)
    local ty = option_tab[k]
    if ty then
        if type(v) ~= ty then
            error("Option '" .. k .. "' value " .. vim.inspect(v) .. " is not a " .. ty)
        end
        opts[k] = v
        if k == 'expr' and v and opts.replace_keycodes == nil then
            opts.replace_keycodes = true
        end
        return true
    end
end

local function parse_lhs(lhs)
    if type(lhs) ~= 'string' then
        error("LHS is not a string: " .. vim.inspect(lhs))
    end
    modestr = vim.split(lhs, ' ')[1]
    if not modestr or modestr == '' then
        error("Can't identify modes in LHS: " .. lhs)
    end

    modes = {}
    for mode in string.gmatch(modestr, ".") do
        if not mode_tab[mode] then
            error("Invalid mode in LHS: " .. mode)
        end
        table.insert(modes, mode)
    end
    lhs = vim.trim(string.sub(lhs, #modestr + 1))
    return modes, lhs
end

local function wrap_keycodes(rhs)
    return function()
        return vim.api.nvim_replace_termcodes(rhs(), true, true, true)
    end
end

--- Set keymap entries.
--
-- Sets all entries in `tbl`, which should conform to the following format:
--     {
--         <option>: <value>,
--         ...,
--         ["<modes> <lhs>"] = <rhs>,
--         ...
--     }
--
-- Each `option` may be a valid keymap option, all of which take boolean values:
--
-- - buffer
-- - expr
-- - noremap
-- - nowait
-- - script
-- - silent
-- - unique
--
-- In each map entry, `<modes>` should be one or more of the usual map modes, e.g.
-- `xo` for both `x` and `o` mappings.
--
-- `<lhs>` should be the usual sequence of key presses as you would use with the
-- standard Ex commands.
--
-- `<rhs>` may be a string, in which case it behaves as the `<rhs>` in the standard
-- Ex commands.  It may instead be a callable object, in which case the mapping
-- will call it with no parameters.
--
-- If `<rhs>` is a table, its first entry (index `1`) is treated as above, with additional
-- option keys in the table overriding those from the outer table.
--
-- @usage
--
-- -- Print "Hello, world!" when pressing key sequence in
-- -- normal or visual mode in the current buffer
-- keymap = require('bex.keymap')
-- keymap.set {
--     buffer = true,
--     ["nx <Leader>zzz"] = function() print("Hello, world!") end
-- }
--
-- @param tbl The binding table as described above.
-- @param bufnr Which buffer to apply mappings to.  Implies the `buffer = true` option.
function keymap.set(tbl, bufnr)
    local defaults = {}

    for k, v in pairs(tbl) do
        set_option(defaults, k, v)
    end

    if bufnr == nil then
        bufnr = 0
    else
        defaults.buffer = true
    end

    for lhs, rhs in pairs(tbl) do
        if type(lhs) ~= 'string' then
            error("LHS is not a string: " .. vim.inspect(lhs))
        end
        if not option_tab[lhs] then
            modes, lhs = parse_lhs(lhs)
            opts = vim.tbl_extend("keep", {}, defaults)
            if type(rhs) ~= 'table' then
                rhs = {rhs}
            end
            for k, v in pairs(rhs) do
                if not set_option(opts, k, v) and k ~= 1 then
                    error("Unknown key in RHS: " .. vim.inspect(k))
                end
            end
            rhs = rhs[1]
            if not rhs then
                error("No RHS specified for mapping: " .. lhs)
            end
            if vim.is_callable(rhs) then
                if not vim.fn.has('nvim-0.8') then
                    if opts.replace_keycodes then
                        rhs = wrap_keycodes(rhs)
                    end
                    opts.replace_keycodes = nil
                end
                if vim.fn.has('nvim-0.7') then
                    opts.callback = rhs
                    rhs = ''
                else
                    ident = bridge[rhs]
                    if opts.expr then
                        rhs = 'v:lua.' .. ident .. '()'
                    else
                        rhs = '<cmd>call v:lua.' .. ident .. '<cr>'
                    end
                end
            elseif type(rhs) ~= 'string' then
                error("Invalid RHS for '" .. lhs .. "': " .. vim.inspect(rhs)) 
            end

            buf = opts.buffer
            opts.buffer = nil

            for _, mode in ipairs(modes) do
                if buf then
                    vim.api.nvim_buf_set_keymap(bufnr, mode, lhs, rhs, opts)
                else
                    vim.api.nvim_set_keymap(mode, lhs, rhs, opts)
                end
            end
        end
    end
end

--- Delete keymap entry.
--
-- Deletes the given keymap entry.
--
-- @param entry The entry to unmap, which is the same format used
--   in `bex.keymap.set`: `"<modes> <lhs>"`
-- @param bufnr If `nil`, delete from the global keymap.  Otherwise, delete
--   from the keymap for that buffer.  `0` specifies the current buffer.
function keymap.delete(entry, bufnr)
    modes, lhs = parse_lhs(entry)
    for _, mode in ipairs(modes) do
        if bufnr then
            vim.api.nvim_buf_del_keymap(bufnr, mode, lhs)
        else
            vim.api.nvim_del_keymap(mode, lhs)
        end
    end
end

return keymap
