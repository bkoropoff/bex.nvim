-- Load keymap so we can use its bridge
require('bex.keymap')

local cmd = require('bex.cmd')
local param = require('bex.param')
local bridge = require('bex.bridge').keymap

local map_cmds = {
    'map',
    'nmap',
    'vmap',
    'xmap',
    'smap',
    'omap',
    'map!',
    'imap',
    'lmap',
    'cmap',
    'tmap',
    'noremap',
    'nnoremap',
    'vnoremap',
    'xnoremap',
    'snoremap',
    'noremap!',
    'inoremap',
    'lnoremap',
    'tnoremap'
}

local unmap_cmds = {
    'unmap',
    'nunmap',
    'vunmap',
    'xunmap',
    'sunmap',
    'unmap!',
    'ounmap',
    'iunmap',
    'lunmap',
    'cunmap',
    'tunmap'
}

local clear_cmds = {
    'mapclear',
    'nmapclear',
    'vmapclear',
    'xmapclear',
    'smapclear',
    'omapclear',
    'mapclear!',
    'imapclear',
    'lmapclear',
    'cmapclear',
    'tmapclear'
}

local function opt(ctx)
    arg = vim.trim(ctx:pop())
    if vim.api.nvim_replace_termcodes(arg, true, true, true) == arg and
            vim.startswith(arg, '<') and vim.endswith(arg, '>') then
        ctx:raw(arg)
        if string.find(arg, '<expr>') then
            ctx.is_expr = true
        end
        return true
    end
    ctx:push(arg)
end

local function rhs(ctx)
    arg = ctx:pop()
    if vim.is_callable(arg) then
        ident = bridge[arg]
        if ctx.is_expr then
            ctx:raw('v:lua.' .. ident .. '()')
        else
            ctx:raw('<cmd>call v:lua.' .. ident .. '()<cr>')
        end
    else
        ctx:push(arg)
        while ctx:remaining() > 0 do
            ctx:raw(ctx:pop())
        end
    end
end

for _, name in ipairs(map_cmds) do
    local c = cmd[name]
    c.params = {param.star(opt), param.raw, rhs}
end

for _, name in ipairs(unmap_cmds) do
    local c = cmd[name]
    c.params = {param.star(opt), param.raw}
end

for _, name in ipairs(clear_cmds) do
    local c = cmd[name]
    c.params = {param.star(opt)}
end
