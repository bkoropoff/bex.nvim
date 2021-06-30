--- Ex command bridge.
--
--# Basic Usage
--
-- Exposes Ex commands as Lua functions.  To use a command as a function,
-- simply index this module, e.g:
--
--     local cmd = require('bex.cmd')
--     cmd.echo("Hello, world!")
--
-- Append `.bang` to a command to access its `!` variant:
--
--     cmd.normal.bang('gvGG')
--
-- This also works:
--
--     cmd['normal!']('gvGG')
--
-- You can capture output using the `.output` modifier:
--
--     local hello = cmd.echo.output("Hello, world!")
--
--# Controlling Behavior
--
--## Parameters Handling
-- How function arguments are formatted can be overridden by setting a list of
-- parameter handlers on a command function.  The `bex.param` module contains a
-- set of useful stock handlers.  For example, the `echo` command has its
-- parameters defined roughly as follows
--
--     local param = require('bex.param')
--
--     -- Double-quote all parameters
--     cmd.echo.params = {_ = param.quote}
--
-- The `Plug` command from the popular vim-plug package can be wrapped as
-- follows:
--
--     cmd.Plug.params = {param.squote, param.call(vim.fn.string)}
--     cmd.Plug.separator = ", "
--
-- You can write custom parameter handlers as functions that take a command
-- context object and make appropriate method calls to it.  A handler can pop
-- remaining function parameters off the stack and add tokens to the formatted
-- command as it sees fit.  There is no strict one-to-one correspondence between
-- input parameters and output tokens.  The `param.cmd` handler is a good example
-- of a sophisticated parameter handler:
--
--     function param.cmd(bridge_ns)
--         return function(ctx)
--             it = ctx:pop()
--             if bridge_ns and vim.is_callable(it) then
--                 it = "call v:lua." .. bridge_ns[it] .. "()"
--                 ctx:raw(it)
--             else
--                 ctx:push(it)
--                 while ctx:remaining() ~= 0 do
--                     ctx:raw(ctx:pop())
--                 end
--             end
--         end
--     end
--
-- Given a `bex.bridge` namespace, it returns a handler that can accept either a
-- Lua callable or a series of raw tokens forming the command.
--
-- Parameter handlers are invoked sequentially until all parameters have been
-- handled.  The `_` handler, if present, is invoked repeatedly to handle any
-- trailing parameters.  The final command is formed from all tokens
-- interspered with the `separator` field on the command function (default `" "`).
-- If fewer parameters were passed than handlers wished to consume, the command
-- is still executed with as many tokens were generated to that point.  This
-- allows many Ex commands that take variable arguments to "just work", e.g.:
--
--     -- Passing one argument works
--     cmd.augroup('foo')
--     cmd.augroup('END')
--     -- Passing none also works.  This scrapes all defined autocommand groups.
--     local dump = cmd.augroup.output()
--
--## Pre and Post Functions
--
-- You can further customize behavior of the command by overriding `pre` and `post`
-- functions.  The defaults for a given command look like:
--
--     -- Receives the command string to be executed, and may return
--     -- a modified version
--     function cmd.<cmd>.pre(ctx, cmdstr)
--         return cmdstr
--     end
--
--     -- Receives the result from executing the command (`nil` if not
--     -- capturing output) and mat return something different
--     function cmd.<cmd>.post(ctx, result)
--         return result
--     end
--
--# Autoloading
--
-- When a command function is first accessed, bex will attempt to load
-- `bex.autoload.<cmd>` (without any trailing `!`) as a Lua module if it
-- exists.  This module should set up any parameter handlers, etc.  Modules are
-- provided for several built-in Ex commands.
--
-- Bex does not presently understand abbreviations, so you should always use
-- the full name of a command to ensure overrides are loaded for it.

local param = require 'bex.param'

local cmd = {}

--- Command context.
--
-- Controls how function parameters are converted into a formatted Ex command.
-- A parameter handler pops function parameters off the context stack
-- and emits tokens by invoking methods on the context.
-- @type context

local nilpop = {} -- special indicator error

local ctx_mt = {}

--- Pop next argument.
--
-- Pops the next function argument for the command off the stack.
-- @return The argument
-- @function context:pop
function ctx_mt:pop()
    arg = table.remove(self._stack)
    if arg == nil then
        error(nilpop)
    end
    return arg
end

--- Push argument back on stack.
--
-- Pushes an unwanted argument back on the stack so it can be consumed
-- by the next handler.
-- @function context:push
-- @param arg The argument
function ctx_mt:push(arg)
    table.insert(self._stack, arg)
end

--- Remaining arguments.
--
-- Get count of remaining arguments on the stack.
-- by the next handler.
-- @function context:remaining
-- @return The count.
function ctx_mt:remaining()
    return #(self._stack)
end

--- Emit raw token.
--
-- Adds a token to the formatted command with no escaping.
-- @function context:raw
-- @param arg The token.
function ctx_mt:raw(arg)
    table.insert(self._tokens, tostring(arg))
end

--- Emit escaped token.
--
-- Adds a token to the formatted command with the specified characters
-- escaped with backslashes.
-- @function context:escape
-- @param arg The token.
-- @param chars A string containing characters to escape.
function ctx_mt:escape(arg, chars)
    table.insert(self._tokens, vim.fn.escape(tostring(arg), chars))
end

--- Emit filename token.
--
-- Adds a token to the formatted command escaped using the `fnameescape`
-- Vim function.
-- @function context:fname
-- @param arg The token.
function ctx_mt:fname(arg)
    table.insert(self._tokens, vim.fn.fnameescape(tostring(arg)))
end

--- Emit single-quoted token.
--
-- Adds a token to the formatted command enclosed in single quotes.
-- It is an error for the argument to contain any single quote
-- character itself.
-- @function context:squote
-- @param arg The token.
function ctx_mt:squote(arg)
    arg = tostring(arg)
    if string.find(arg, "'") then
        error("Can't single-quote argument with single quote character: " .. arg)
    end
    table.insert(self._tokens, "'" .. arg .. "'")
end

--- Emit double-quoted token.
--
-- Adds a token to the formatted command enclosed in double quotes,
-- with any double quotes or backslashes within the token escaped with
-- backslashes.
-- @function context:quote
-- @param arg The token.
function ctx_mt:quote(arg)
    table.insert(self._tokens, '"' .. vim.fn.escape(tostring(arg), '"\\') .. '"')
end

function ctx_mt:__index(i)
    return ctx_mt[i]
end

local function ctx_new(co, args)
    local ctx = {
        co = co,
        _tokens = {},
        _stack = {}
    }

    for i, v in ipairs(args) do
        ctx._stack[#args - i + 1] = v
    end

    setmetatable(ctx, ctx_mt)

    return ctx
end

local function ctx_format(ctx)
    local co = ctx.co
    local status, err = pcall(function()
        for _, fn in ipairs(co.params) do
            fn(ctx)
        end

        if #(ctx._stack) ~= 0 then
            local fn = co.params._
            if fn == nil then
                error("Too many arguments to " .. co.name)
            end
            while #(ctx._stack) ~= 0 do
                fn(ctx)
            end
        end
    end)

    if not status and err ~= nilpop then
        error(err)
    end

    return co.name .. " " .. table.concat(ctx._tokens, co.separator)
end

-- co (command object): proxy object for ex commands

local function co_run(co, args, output)
    local ctx = ctx_new(co, args)
    local cmdstr = co.pre(ctx, ctx_format(ctx))
    return co.post(ctx, vim.api.nvim_exec(cmdstr, output))
end

local co_mt = {}

function co_mt.__call(co, ...)
    return co_run(co, {...}, false)
end

function co_mt.bang(co)
    return cmd[co.name .. "!"]
end

function co_mt.output(co)
    return function(...)
        return co_run(co, {...}, true)
    end
end

function co_mt.__index(co, arg)
    local fn = co_mt[arg]
    if fn then
        return fn(co)
    end
end

local function co_new(name)
    co = {
        name = name,
        pre = function(ctx, cmdstr) return cmdstr end,
        post = function(ctx, output) return output end,
        params = {
            _ = param.default
        },
        separator = " "
    }
    setmetatable(co, co_mt)
    return co
end

-- cmd: lazily instantiate command objects

local cmd_mt = {}

local autoloading = {}

local function try_autoload(name)
    if vim.endswith(name, '!') then
        name = string.sub(name, 1, -2)
    end
    if autoloading[name] then
        return
    end
    autoloading[name] = true
    pcall(function() require('bex.autoload.' .. name) end)
    autoloading[name] = nil
end

function cmd_mt.__index(mod, idx)
    local co = co_new(idx)
    mod[idx] = co
    try_autoload(idx)
    return co
end

setmetatable(cmd, cmd_mt)

return cmd
