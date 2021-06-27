--- Stock parameter handlers
--
-- This module contains parameter handlers or factories for
-- use when setting up commands in `bex.cmd`

local param = {}

--- Default parameter handler.
--
-- One parameter in, one token out.  Escapes only spaces and backslash.
function param.default(ctx)
    ctx:escape(ctx:pop(), "\\ ")
end

--- Filename parameter handler.
--
-- One parameter in, one token out.  Escapes as a filename.
function param.fname(ctx)
    ctx:fname(ctx:pop())
end

--- Single quote parameter handler.
--
-- One parameter in, one token out.  Surrounds with single quotes.
function param.quote(ctx)
    ctx:quote(ctx:pop())
end

--- Double quote parameter handler.
--
-- One paramter in, one token out.  Surrounds with double quotes, escaping contents.
function param.squote(ctx)
    ctx:squote(ctx:pop())
end

--- Raw parameter handler.
--
-- One paramter in, one token out.  Performs no escaping.
function param.raw(ctx)
    ctx:raw(ctx:pop())
end

--- Command parameter handler (factory).
--
-- Returns a parameter handler that formats an Ex command,
-- e.g. for autocmd and similar that take a trailing command
-- as a parameter.
--
-- If `bridge_ns` is provided, a callable as a parameter will
-- result in a command that calls it with no arguments.
-- Otherwise, all remaining parameters are emited as
-- raw tokens.
--
-- @param bridge_ns An optional namespace for bridging Lua functions.
--   See `bex.bridge`.
-- @return A new handler.
function param.cmd(bridge_ns)
    return function(ctx)
        it = ctx:pop()
        if bridge_ns and vim.is_callable(it) then
            it = "call v:lua." .. bridge_ns[it] .. "()"
            ctx:raw(it)
        else
            ctx:push(it)
            while ctx:remaining() ~= 0 do
                ctx:raw(ctx:pop())
            end
        end
    end
end

--- ++opt parameter handler.
--
-- Emits a `++opt` style parameter verbatim if it matches, and
-- does nothing otherwise.  Suitable for use with `bex.param.star`.
function param.plusplusopt(ctx)
    arg = ctx:pop()
    if type(arg) == "string" and string.sub(arg, 1, 2) == "++" then
        ctx:raw(arg)
        return true
    else
        ctx:push(arg)
        return false
    end
end

--- +opt parameter handler.
--
-- Emits a `+opt` style parameter verbatim if it matches, and
-- does nothing otherwise.  Suitable for use with `bex.param.star`.
function param.plusopt(ctx)
    arg = ctx:pop()
    if type(arg) == "string" and string.sub(arg, 1, 1) == "+" then
        ctx:raw(arg)
        return true
    else
        ctx:push(arg)
        return false
    end
end

--- -opt parameter handler.
--
-- Emits a -opt style parameter verbatim if it matches, and
-- does nothing otherwise.  Suitable for use with `bex.param.star`.
function param.minusopt(ctx)
    arg = ctx:pop()
    if type(arg) == "string" and vim.startswith(arg, "-") then
        ctx:raw(arg)
        return true
    else
        ctx:push(arg)
        return false
    end
end

--- Kleene-star like parameter handler factory.
--
-- Runs another handler until it returns falsity.
-- Useful with `bex.param.plusplusopt`, etc.
--
-- @param inner The inner parameter handler
-- @return A new handler.
function param.star(inner)
    return function(ctx)
        while inner(ctx) do end
    end
end

--- Call simple function (factory).
--
-- Handles a single parameter by passing it to a function and
-- emiting the result as a raw token.
--
-- @param func The function.
-- @return A new handler.
function param.call(func)
    return function(ctx)
        ctx:raw(func(ctx:pop()))
    end
end

return param
