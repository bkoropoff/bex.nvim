# Bex Manual

Bex provides a more convenient bridge between Lua and Ex in NeoVim.

## Call Ex Commands From Lua

The `bex.cmd` module lets you invoke Ex commands as functions, with
sophisticated conversion of parameters into the formatted command.
For example, `bex.cmd.autocmd` supports arbitrary Lua callables
as the action. `bex.cmd.augroup` supports executing a function
within the group instead of requiring an explicit `bex.cmd.augroup('END')`:

    local cmd = require('bex.cmd')
    cmd.augroup('my_group', function()
        cmd.autocmd.bang()
        cmd.autocmd('CursorHold', '*', function() print("CursorHold fired!") end)
    end)

See the `bex.cmd` module for details on how to override parameter handling
for arbitrary Ex commands.  Overrides are provided for several common
built-in commands.

The bridge back into Lua functions is provided by the `bex.bridge` module,
which you may find helpful in your own Lua code.

## Lua-friendly Keymap Setting

Although the `bex.cmd` module lets you use ordinary Ex command like `nnoremap`
to set keymaps, `bex.keymap` provides a more Lua-friendly alternative:

    -- Print "Hello, world!" when pressing key sequence in
    -- normal or visual mode in the current buffer
    keymap = require('bex.keymap')
    keymap.set {
        buffer = true,
        ["nx <Leader>zzz"] = function() print("Hello, world!") end
    }
