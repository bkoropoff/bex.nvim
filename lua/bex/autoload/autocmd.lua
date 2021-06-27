local cmd = require 'bex.cmd'
local param = require 'bex.param'
local bridge = require 'bex.bridge'.autocmd

function autocmd_group(ctx)
    local group = ctx:pop()
    local groups = vim.api.nvim_exec("augroup", true)

    if string.find(groups, " " .. group .. " ") then
        -- That was a group
        ctx:escape(group, " \\")
    else
        -- An event, put it back
        ctx:push(group)
    end
end

function bridge:reachable()
    local autocmds = vim.api.nvim_exec("autocmd", true)
    return function(id)
        return string.find(autocmds, id)
    end
end

cmd.autocmd.params = {
    autocmd_group,
    param.default, -- event
    param.default, -- pat
    param.star(param.plusplusopt),
    param.cmd(bridge)
}

cmd.autocmd.bang.params = {
    autocmd_group,
    param.default, -- event
    param.default -- pat
}
