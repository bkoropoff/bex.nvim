--- `:augroup` support.
--
-- Provides overrides that allow you to specify a callable
-- as the second parameter to `bex.cmd.augroup`.  It will
-- be invoked after entering the augroup and generate
-- an `:augroup END` automatically afterwards.  This allows
-- usage like:
--
--     local cmd = require('bex.cmd')
--
--     cmd.augroup('my_augroup', function()
--         cmd.autocmd.bang()
--         cmd.autocmd(...)
--         ...
--     end)

local cmd = require('bex.cmd')
local param = require('bex.param')

local function body(ctx)
    ctx.augroup_body = ctx:pop()
end

cmd.augroup.params = {param.default, body}

function cmd.augroup.post(ctx, result)
    if ctx.augroup_body then
        local status, ret = pcall(ctx.augroup_body)
        vim.cmd("augroup END")
        if not status then
            error(ret)
        end
    end
    return result
end
