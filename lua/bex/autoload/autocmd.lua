--- `:autocmd` support.
--
-- Defines overrides for the `autocmd` command.  The command to run
-- when triggered may be a Lua callable instead of raw text.  In this
-- case, it is invoked with no arguments.  Use `vim.v.event` to get
-- event parameters, e.g.:
--
--     cmd.autocmd(
--         'DirChanged', '*',
--         function() print("New dir: " .. vim.v.event.cwd) end)

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
