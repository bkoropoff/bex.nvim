local util = {}

function util.bind(fn, ...)
    local args = {...}
    return function(...) return fn(unpack(args), ...) end
end

function util.method(obj, meth, ...)
    return util.bind(obj[meth], obj, ...)
end

return util
