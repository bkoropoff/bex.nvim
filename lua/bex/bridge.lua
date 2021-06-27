--- Lua-to-VIM function bridge.
--
-- Exposes Lua functions in the `v:lua` table and as global Vim functions.
-- Create a namespace for your module by indexing this module, e.g.:
--
--     local bridge = require('bex.bridge').my_module
--
-- You can then get an identifier for your function by simply indexing
-- your namespace:
--
--     local ident = bridge[function(...) ... end]
--
-- This identifier can then be used in Vim functions, Ex commands, etc.:
--
--     -- An example, use `bex.cmd` for this instead
--     vim.cmd("autocmd mygroup FileType * call " .. ident .. "()")
--
-- To prevent registrations from growing without bound if you
-- bridge functions dynamically, you can define a `reachable` method on your
-- namespace.  The method should return a function which tests
-- whether a given identifier is in use any longer.  For example, the
-- built-in autocmd support defines it as follows:
--
--    function bridge:reachable()
--        local autocmds = vim.api.nvim_exec("autocmd", true)
--        return function(id)
--            return string.find(autocmds, id)
--        end
--    end
--
-- Garbage collection will be attempted every `bridge.gc_interval` function
-- registrations, which defaults to `20`.
local bridge = {}

local bridge_ns_mt = {}

local next_id = 0

--- Namespace table.
--
-- The type of table obtained by indexing this module.
-- @type namespace

local functempl = [[
function! __name__(...)
    return call(g:Lua__name__, a:000)
endfun
]]

function bridge_ns_mt.__index(ns, idx)
    if vim.is_callable(idx) then
        id = "__bex_bridge_" .. next_id .. "__"
        next_id = next_id + 1
        _G[id] = idx
        vim.g["Lua" .. id] = idx
        ns[idx] = id
        vim.cmd(string.gsub(functempl, "__name__", id))
        ns._gc_tick = ns._gc_tick + 1
        if ns.reachable and ns._gc_tick >= ns.gc_interval then
            bridge_ns_mt.gc(ns)
            ns._gc_tick = 0
        end
        return id
    else
        return bridge_ns_mt[idx]
    end
end

--- Garbage collect namespace.
--
-- Explicitly garbage collects the namespace.
-- @function namespace:gc
function bridge_ns_mt.gc(ns)
    if not ns.reachable then
        error("No reachability predicate generator method set on bridge: " .. ns.name)
    end
    pred = ns:reachable()
    for func, id in pairs(ns) do
        if type(func) ~= 'string' and not pred(id) then
            ns[func] = nil
            _G[id] = nil
            vim.g["Lua" .. id] = nil
            vim.cmd("delfunction! " .. id)
        end
    end
end

function bridge_ns_new(name)
    ns = {name = name, _gc_tick = 0, gc_interval = 20}
    setmetatable(ns, bridge_ns_mt)
    return ns
end

local bridge_mt = {}

function bridge_mt.__index(tb, idx)
    b = bridge_ns_new(idx)
    tb[idx] = b
    return b
end

setmetatable(bridge, bridge_mt)

return bridge
