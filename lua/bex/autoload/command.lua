--- `:command` support.
--
-- Provides special support for `bex.cmd.command`.
--
-- The last argument, the replacement text, may be a
-- callable instead of a string.  If so, it will be called with a table
-- corresponding to the escape sequences defined by Vim, e.g.:
--
--     {
--         args = "arg1 arg2 ...", -- arguments as a raw string
--         fargs = {"arg1", "arg2", ...}, -- arguments as a parsed list
--         bang = false, -- command invoked with !
--         count = 5, -- count argument
--         line1 = 22, -- first line of range
--         line2 = 45, -- second line of range
--         range = 2, -- arity of range (0, 1, 2)
--         mods = { -- enabled modifiers (verbose, topleft, etc.)
--             verbose = true
--         }
--     }
--
-- To use a function for custom completion, pass `"-complete=custom"` or
-- `"-complete=customlist"` followed by the callable as arguments.
-- It will be invoked with the usual `A`, `L`, `P` arguments specified in
-- the Vim documentation.  The following trivial example completes all arguments
-- as `foobar`:
--
--     bex.cmd.command(
--         '-complete=custom', function(a, l, p) return "foobar" end,
--         "MyCommand", ...)

local cmd = require('bex.cmd')
local param = require('bex.param')
local bridge = require('bex.bridge').command

local function add_haystack(haystack, cmds)
    for _, it in pairs(cmds) do
        -- neovim bug?!
        if type(it) == "table" then
            table.insert(haystack, it.definition)
            table.insert(haystack, it.complete_arg)
        end
    end
end

function bridge:reachable()
    local haystack = {}
    local bufs = vim.tbl_filter(vim.api.nvim_buf_is_loaded, vim.api.nvim_list_bufs())

    add_haystack(haystack, vim.api.nvim_get_commands({}))

    for _, buf in ipairs(bufs) do
        add_haystack(haystack, vim.api.nvim_buf_get_commands(buf, {}))
    end

    return function(id)
        for _, hay in ipairs(haystack) do
            if string.find(hay, id) then
                return true
            end
        end
    end
end

local cmddict = [[{"args": <q-args>, "fargs": [<f-args>], "line1": <q-line1>, "line2": <q-line2>, "count": <q-count>, "bang": <q-bang>, "mods": <q-mods>, "range": <q-range>, "reg": <q-reg>}]]

local function nilify(it)
    return it ~= "" and it or nil
end

local function numify(it)
    return it ~= "" and it + 0 or nil
end

local function tablify(it)
    local tbl = {}
    for el in vim.gsplit(it, " ") do
        if el ~= "" then
            tbl[el] = true
        end
    end
    return tbl
end

local function trampoline(f)
    return function(dict)
        local args = {}
        args.args = nilify(dict.args)
        args.fargs = dict.fargs
        args.line1 = numify(dict.line1)
        args.line2 = numify(dict.line2)
        args.count = numify(dict.count)
        args.bang = dict.bang ~= "" and true or false
        args.mods = tablify(dict.mods)
        args.range = numify(dict.range)
        args.reg = nilify(dict.reg)
        return f(args)
    end
end

function cmdcmd(ctx)
    local it = ctx:pop()
    if vim.is_callable(it) then
        ctx:raw("call v:lua." .. bridge[trampoline(it)] .. "(" .. cmddict .. ")")
    else
        ctx:push(it)
        while ctx:remaining() ~= 0 do
            ctx:raw(ctx:pop())
        end
    end
end

function cmdopt(ctx)
    local it = ctx:pop()
    if type(it) == "string" and vim.startswith(it, "-") then
        if it == "-complete=custom" or it == "-complete=customlist" then
            local f = ctx:pop()
            if not vim.is_callable(f) then
                error("Custom completion function is not callable: " .. vim.inspect(f))
            end
            ctx:raw(it .. "," .. bridge[f])
        else
            ctx:escape(it, " \\")
        end
        return true
    else
        ctx:push(it)
        return false
    end
end

cmd.command.params = {param.star(cmdopt), param.default, cmdcmd}
cmd.command.bang.params = cmd.command.params
