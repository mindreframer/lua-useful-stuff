## ldeb - a tool for packaging Lua scripts as Debian Packages

A common problem with dynamic languages is deploying your scripts so that other people may easily use them without having to reproduce your exact development set up.

Fortunately the Debian package manager provides a standard way to bundle a script together with its dependencies.  The Lua support in Debian/Ubuntu is particularly good, thanks to the work of Enrico Tassi.  The most common libraries for file systems, networking, etc are already present in the base repositories.  However, the package names are somewhat clumsy and sometimes non-obvious, so ldeb keeps a mapping of common Lua module names to Debian packages. So it knows that `lfs` corresponds to the package 'liblua5.1-filesystem0', and so on.

A version of Jay Carlson's [soar](http://lua-users.org/lists/lua-l/2012-02/msg00609.html) tool is included. This does two things - it will analyze a script's dependencies (either staticallly or dynamically) and optionally pack the script plus any _local_ dependencies into an executable self-contained archive. By local I mean here "anything not found in Debian".  For example, soar itself relies on [Microlight](https://github.com/stevedonovan/microlight) which is a module containing useful Lua utility functions. So applying soar to itself results in a Lua script which contains both `soar.lua` and `ml.lua` - it _inlines_ external modules.   `ldeb` can then pack this as a .deb, with a simple dependency on the 'Lua5.1' package.

## Installation

This is the usual two-liner:

    $ make
    $ sudo make install
  
This bootstraps ldeb and uses it to create a .deb file for itself, which is installed as usual.  ldeb has a number of commands; you can see all the supported modules:

    ~/lua$ ldeb show all
    cgilua	liblua5.1-cgi0
    socket	liblua5.1-socket2
    iconv	liblua5.1-iconv0
    bit	liblua5.1-bitop0
    copas	liblua5.1-copas0
    lpeg	liblua5.1-lpeg2
    ...
    leg	liblua5.1-leg0
    json	liblua5.1-json
    soap	liblua5.1-soap0
    
You can inquire whether a particular Lua module is already installed:

    ~/lua$ ldeb show lfs
    apt-cache show liblua5.1-filesystem0
    Package: liblua5.1-filesystem0
    ...
    Description: luafilesystem library for the Lua language version 5.1
     This package contains the luafilesystem library, a set of portable functions
     for directory creation, listing and deletion and for file locking.
    Homepage: http://www.luaforge.net/projects/luafilesystem
    Bugs: https://bugs.launchpad.net/ubuntu/+filebug
    Origin: Ubuntu

Nothing mysterious here - `ldeb` has resolved `lfs` to the correct package name and looked it up in the cache.

The `linstall` command (note the 'l') will install a Lua package:

    ~/lua$ sudo ldeb linstall sapi
    apt-get install liblua5.1-cgi0
    Reading package lists... Done
    ....
    Setting up liblua5.1-cgi0 (5.1.3-2) ...

Before you can start packing your own .debs, it's necessary to tell `ldeb` about your name and email address, so that it can list you as the maintainer.

    $ ldeb set name "Joe Jonson"
    $ ldeb set email "jj@jonson.org"

This information gets saved in the `~/.ldebrc` file, which is just a Lua table.  (If you did the explicit install step, then a name and email has already been set up, so that it could package `ldeb` itself, but unless you like using my name, please change it now ;))  (If you are a Git user and already told Git these things, then `ldeb guess` will ask Git for the information.)

Here is a basic little script, with a dependency on LuaFileSystem:

    ~/lua$ cat liner
    #!/usr/bin/env lua
    local lfs = require 'lfs'
    print(lfs.currentdir())
    
It's useful to run `ldeb` using the test flag, to see what it will do:

    ~/lua$ ldeb pack -t -d lfs -m "Liner is a two-liner script" liner
    mkdir -p liner1.0/DEBIAN
    mkdir -p liner1.0/usr/local/bin
    cp -p liner liner1.0/usr/local/bin
    Package: liner
    Version: 1.0
    Architecture: all
    Installed-Size: 4
    Maintainer: Steve Donovan <steve.j.donovan@gmail.com>
    Depends: lua5.1, liblua5.1-filesystem0
    Description: Liner is a two-liner script
    dpkg-deb --build liner1.0
    
Apart from maintainer information, `dpkg-deb` would _really_ like you to give a description, which is done using the '-m' (or '--description') flag.   If you don't provide a description, it will open an editor to allow you to type it.  This information is saved in the rc file, so subsequent repacks won't go through this step, unless you explicitly say '-m edit'.

We also have to specify the dependencies explicitly; if there's more than one, put them in quotes, separated by spaces.

So the incantation to pack and install a script is:

    $ ldeb pack -d "MODS" -m "DESCRIPT" script
    $ sudo ldeb install

## Using soar for dependency analyis

Our simple script has an obvious dependency on `lfs`, but generally tracking down dependencies manually is tedious.  The '-a' flag means 'analyze only', and the '-s' flag means 'analyze statically'.  (This is done by examining the output of the 'luac' compiler)

    ~/lua$ soar -a -s liner
    _main	liner
    ---- binary dependencies ---
    lfs	*BINARY*

`_main` is just the script itself, so no further packing is required.

`soar` generates a `soar.out` file containing any discovered dependencies, and `ldeb` will read this, if no explicit '-d' flag is used:

    ~/lua$ ldeb pack -t liner
    ...
    Maintainer: Steve Donovan <steve.j.donovan@gmail.com>
    Depends: lua5.1, liblua5.1-filesystem0
    Description: Liner is a one-liner script

Here's a slightly more involved example:

    ~/lua$ cat test1
    #!/usr/bin/env lua
    local ml = require 'ml'
    local lxp = require 'lxp'
    local socket = require 'socket'
    print 'doof'

    ~/lua$ soar -a -s test1
    socket	/usr/share/lua/5.1/socket.lua
    _main	test1
    ml	./ml.lua
    ---- binary dependencies ---
    socket.core	*BINARY*
    lxp	*BINARY*

That's not quite right - `soar` thinks that `socket.lua` is a local dependency. The '-d' (or '--debian' flag) implicitly excludes any Lua files in the standard Debian location:

    ~/lua$ soar -a -s -d test1
    ml	./ml.lua
    _main	test1
    ---- excluded dependencies --
    socket	true
    ---- binary dependencies ---
    lxp	*BINARY*

And then `ldeb` correctly recognizes that we want the Debian LuaSocket included as a dependency:

    ~/lua$ ldeb pack -t -m "test1 uses some modules" test1
    ...
    Depends: lua5.1, liblua5.1-expat0, liblua5.1-socket2
    Description: test1 uses some modules

In this case, `./ml.lua` must be packed first, so the soar/ldeb incantation should be this:

    ~/lua$ mkdir out
    ~/lua$ soar -o out/test1 -s -d test1
    ~/lua$ ldeb pack out/test1
    
For analyzing more complicated applications, that play with the Lua module path, it's better to switch to dynamic analysis (leave out the '-s'). Then `soar` will _run_ the script, until it returns normally or calls the overriden `os.exit`.  So, first ensure that the script is passed any necessary parameters (after the scriptname) so that it can do something non-triival, and second ensure that it _does_ terminate appropriately. (So if it's a web application there must be a code path which calls `os.exit`, for instance)
    
## Limitations

`ldeb` can ship multiple scripts (see the makefile for a good example) as a package, but it will always read the _last_ 'soar.out' generated, unless '-d' is explicit.

`soar` may correctly analyze and pack, but the external binary dependencies may be unknown to Debian (use 'ldeb show all' to see what's available).   There is not much we can do at this point, (apart from lobbying Enrico.)   

One solution is to allow `ldeb` to include binary Lua packages, but then we lose architecture-independence.  And in that case, [luabuild](https://github.com/stevedonovan/luabuild) may be a better solution anyway.
