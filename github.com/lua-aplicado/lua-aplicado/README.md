Lua-Aplicado – A random collection of application level Lua libraries
=====================================================================

See the copyright information in the file named `COPYRIGHT`.

Dependencies
------------

### lua-nucleo

    sudo luarocks install lua-nucleo

### luafilesystem

    sudo luarocks install luafilesystem

### lbci

    sudo luarocks install lbci

### luasocket

    sudo luarocks install luasocket

Installation
------------

If you're in a require-friendly environment, you may install lua-aplicado
from luarocks (http://www.luarocks.org):

    luarocks install lua-aplicado

Or, if you want to get the most current code, use rocks-cvs version:

    luarocks install \
        lua-aplicado \
        --from=http://luarocks.org/repositories/rocks-cvs

Otherwise, copy lua-aplicado directory whereever is comfortable.
Make sure that dependencies are installed as well.

Initialization with require()
-----------------------------

To use lua-aplicado in require-friendly environment, do as follows:

    require 'lua-aplicado.module'

This assumes that lua-aplicado directory is somewhere in the `package.path`

Note that you may also want to enable the strict mode of the lua-nucleo
(aka the Global Environment Protection):

    require 'lua-nucleo.strict'

For all other lua-aplicado files, use `import()`.

Note that if you want to keep using `require()`,
you may replace in your code

    local foo, bar = import 'lua-aplicado/baz/quo.lua' { 'foo', 'bar' }

with

    local quo = require 'lua-aplicado.baz.quo'
    local foo, bar = quo.foo, quo.bar

Initialization without require()
--------------------------------

Copy or symlink `lua-nucleo/lua-nucleo` and `lua-aplicado/lua-aplicado`
directories to the same directory.

Set `CODE_ROOT` Lua variable to path to that directory.

    dofile(CODE_ROOT..'lua-nucleo/strict.lua')
    assert(loadfile(CODE_ROOT..'lua-nucleo/import.lua'))(CODE_ROOT)

After that use `import()`.

Documentation
-------------

Sorry, the documentation for the project is not available at this point.
Read the source and tests.

TODO
----

See file named `TODO`.

Support
-------

Post your questions to the Lua mailing list: http://www.lua.org/lua-l.html
