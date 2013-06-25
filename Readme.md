# Lua stuff

Lua is an obscure little language, but it has some really unique features and is gaining
popularity in the last time. It is intergrated into:

  - http://tylerneylon.com/a/learn-lua/
  - https://sites.google.com/site/marbux/home/where-lua-is-used
  - Redis (http://redis.io/commands/eval)
  - Nginx (https://github.com/chaoslawful/lua-nginx-module)
  - Postgresql (http://pllua.projects.pgfoundry.org/)
  - MySQL Proxy
  - allows scripting NetBSD kernel (http://www.phoronix.com/scan.php?page=news_item&px=MTMwMTU#n)
  - powers a low-level virtualized Ethernet switch for software defined networks: SnabbSwitch (https://github.com/SnabbCo/snabbswitch/wiki)
  - and powers many-many iOS games



Shortly: IT'S GETTING HOT! )))

--> many plugins/examples from WoW:

http://www.lua.org/wshop08/lua-whitehead.pdf
http://www.wowace.com/addons/?category=development-tools&site=+
http://www.wowace.com/addons/?category=libraries&site=+
http://www.wowace.com/addons/?category=data-export&site=+


In this repo I want to collect some interesting Lua projects, that I have found on Github. Since there is a slight possibility of them just disapearing, I have added them with `git subtree`command, that allows future updates and still retains the full sourcecode here.

see [00.pull.rb](https://github.com/mindreframer/lua-useful-stuff/blob/master/00.pull.rb)  for the code.


Projects added here:

  - the source listing for "Beginning Lua Programming"
  - https://github.com/slembcke/debugger.lua.git
  - https://github.com/badgerman/euler.git
  - https://github.com/kikito/inspect.lua.git
  - https://github.com/meric/l2l.git
  - https://github.com/lua-cookbook/lua-cookbook.git
  - https://github.com/lua-nucleo/lua-nucleo.git
  - https://github.com/trevrosen/lua-presentation.git
  - https://github.com/kikito/lua_missions.git
  - https://github.com/Fizzadar/Luawa.git
  - https://github.com/kikito/middleclass.git
  - https://github.com/Yonaba/Moses.git
  - https://github.com/winton/nginx-accelerator.git
  - https://github.com/kikito/stateful.lua.git
  - https://github.com/Fizzadar/yummymarks.git


<!-- PROJECTS_LIST_START -->
    agladysh/luamarca:
      Collection of silly Lua benchmarks
       22 commits, 3 stars, 0 forks

    badgerman/euler:
      Project Euler solutions, mostly in Lua
       3 commits, 1 stars, 0 forks

    catwell/luajit-msgpack-pure:
      MessagePack for LuaJIT (using FFI, no bindings)
       45 commits, 25 stars, 7 forks

    craigbarnes/ldiscount:
      Lua binding to Discount
       14 commits, 4 stars, 1 forks

    EmergingThreats/et-luajit-scripts:

       27 commits, 1 stars, 0 forks

    Fizzadar/Luawa:
      Lua Web Application (Framework)
       68 commits, 1 stars, 0 forks

    Fizzadar/yummymarks:

       1 commit, 1 stars, 0 forks

    geoffleyland/luatrace:
      A tool for tracing Lua script execution and analysing time profiles and coverage
       138 commits, 44 stars, 6 forks

    GloryFish/love2d-verlet-cloth:
      Verlet cloth simulation in Lua, for LÖVE
       4 commits, 1 stars, 0 forks

    hnakamur/luajit-examples:
      my example codes for LuaJIT
       24 commits, 7 stars, 0 forks

    justincormack/ljsyscall:
      LuaJIT Linux syscall FFI
       1000+ commits, 85 stars, 15 forks

    kikito/i18n.lua:
      A very complete i18n lib for Lua
       43 commits, 6 stars, 1 forks

    kikito/inspect.lua:
      Human-readable representation of Lua tables
       48 commits, 48 stars, 10 forks

    kikito/lua_missions:
      Lua Koans, minus the Zen stuff
       67 commits, 92 stars, 34 forks

    kikito/middleclass:
      Object-orientation for Lua
       119 commits, 207 stars, 25 forks

    kikito/stateful.lua:
      Stateful classes for Lua
       30 commits, 25 stars, 5 forks

    keplerproject/copas:
      Copas is a dispatcher based on coroutines that can be used by TCP/IP servers.
       122 commits, 29 stars, 6 forks

    keplerproject/coxpcall:
      Coxpcall encapsulates the protected calls with a coroutine based loop, so errors can be dealed without the usual pcall/xpcall issues with coroutines.
       42 commits, 7 stars, 3 forks

    keplerproject/luadoc:
      LuaDoc is a documentation tool for Lua source code.
       131 commits, 45 stars, 10 forks

    keplerproject/luarocks:
      LuaRocks is  a deployment and management system for Lua modules.
       529 commits, 130 stars, 38 forks

    keplerproject/orbit:
      Orbit is an MVC web framework for Lua.
       178 commits, 51 stars, 13 forks

    keplerproject/xavante:
      Xavante is a Lua HTTP 1.1 Web server that uses a modular architecture based on URI mapped handlers.
       361 commits, 55 stars, 18 forks

    leafo/lapis:
      a web framework written in MoonScript
       286 commits, 158 stars, 13 forks

    lipp/jet:
      Distributed applications with JSON-RPC
       158 commits, 4 stars, 0 forks

    lipp/lua-websockets:
      Websockets for Lua.
       313 commits, 38 stars, 6 forks

    lipp/zbus:
      A simple TCP/IP based message bus in Lua.
       105 commits, 6 stars, 0 forks

    logiceditor-com/codebase:
      Open-Source Lua codebase we use in our projects
       1000+ commits, 4 stars, 2 forks

    lua-aplicado/lua-aplicado:
      A random collection of application-level Lua libraries
       204 commits, 7 stars, 3 forks

    lua-cookbook/lua-cookbook:
      The Lua Cookbook
       31 commits, 54 stars, 14 forks

    lua-nucleo/lua-nucleo:
      A random collection of core and utility level Lua libraries
       747 commits, 35 stars, 11 forks

    LuaDist/srlua:
      A tool for building self-running Lua programs.
       17 commits, 6 stars, 3 forks

    luaforge/simulua:
      Simulua is a discrete-event simulation library for Lua. The simulation in Simulua is process-oriented, that is, the operation path of a simulated system is obtained from interactions of processes running in parallel and managed by an event list.

    This repository was converted from a CVS repository on luaforge.net on Jan. 20, 2010.
    If you are the maintainer, please fork and then email luaforge@gmail.com and ask us to reroot it to you.
    (Or you can ask us to delete the repository.)



        This repository was converted from a CVS repository on luaforge.net on Jan. 20, 2010.
    If you are the maintainer, please fork and then email luaforge@gmail.com and ask us to reroot it to you.
    (Or you can ask us to delete the repository.)
       4 commits, 1 stars, 0 forks

    martin-damien/babel:
      Babel is a module to enable internationalisation in Lua applications. It is designed to work with LÖVE 2D too.
       24 commits, 3 stars, 3 forks

    mascarenhas/luma:
      LPEG-based Lua macros
       56 commits, 8 stars, 0 forks

    meric/l2l:
      A lisp that compiles to and runs as fast as lua. Equipped with macroes and compile-time compiler manipulation. Comes with all built-in lua functions.
       50 commits, 47 stars, 5 forks

    mindreframer/leslie:
      a non-official git mirror for leslie - a Lua implementation for Django template language
       35 commits, 0 stars, 0 forks

    mindreframer/scilua:
      a non-official git mirror for http://www.scilua.org/
       8 commits, 0 stars, 0 forks

    mindreframer/ProFi.lua:
      a non-official git mirror for ProFi, a Lua profiler
       14 commits, 2 stars, 0 forks

    neomantra/lds:
      LuaJIT Data Structures - hold cdata in lists, trees, hash tables, and more
       9 commits, 12 stars, 1 forks

    neomantra/luajit-nanomsg:
      LuaJIT FFI binding to the nanomsg library
       20 commits, 4 stars, 1 forks

    Neopallium/lua-handlers:
      Provides a set of async. callback based handlers for working with raw TCP/UDP socket, ZeroMQ sockets, or HTTP client/server.
       127 commits, 61 stars, 5 forks

    norman/lua-postgres:
      A basic Postgres driver for Lua
       19 commits, 11 stars, 1 forks

    norman/telescope:
      A highly customizable test library for Lua that allows declarative tests with nested contexts.
       79 commits, 72 stars, 19 forks

    pkulchenko/serpent:
      Lua serializer and pretty printer
       46 commits, 31 stars, 8 forks

    pavouk/lgi:
      Dynamic Lua binding to GObject libraries using GObject-Introspection
       1000+ commits, 61 stars, 15 forks

    perky/FEZ:
      A lua library that helps you create component based projects inspired by Artemis.
       24 commits, 16 stars, 4 forks

    Olivine-Labs/luassert:
      Assertion library for Lua
       155 commits, 11 stars, 12 forks

    Olivine-Labs/lustache:
      Mustache templates for Lua
       48 commits, 25 stars, 5 forks

    rgieseke/locco:
      Locco is Docco in Lua.
       10 commits, 23 stars, 4 forks

    rrthomas/lua-stdlib:
      General Lua libraries
       706 commits, 50 stars, 4 forks

    seomoz/qless-core:
      Core Lua Scripts for qless
       120 commits, 33 stars, 4 forks

    silentbicycle/lunatest:
      xUnit-style + randomized unit testing framework for Lua (and C projects using Lua, etc.)
       77 commits, 30 stars, 12 forks

    silentbicycle/tamale:
      TAble MAtching Lua Extension - An Erlang-style pattern-matching library for Lua
       46 commits, 30 stars, 0 forks

    slembcke/debugger.lua:
      A simple, embedabble CLI debugger for Lua.
       13 commits, 20 stars, 2 forks

    SnabbCo/snabbswitch:
      The Snabb Switch Project
       303 commits, 86 stars, 11 forks

    sroccaserra/object-lua:
      A class-oriented OOP module for Lua
       35 commits, 26 stars, 1 forks

    statianzo/lua_euler:
      Working through Project Euler with Lua for some practice
       16 commits, 1 stars, 0 forks

    stevedonovan/Microlight:
      A little library of useful Lua functions, intended as the 'light' version of Penlight
       32 commits, 38 stars, 9 forks

    stevedonovan/ldeb:
      ldeb converts Lua scripts into Debian packages
       3 commits, 2 stars, 1 forks

    stevedonovan/luaish:
      A Lua REPL with global name tab-completion and a shell sub-mode
       5 commits, 21 stars, 4 forks

    stevedonovan/LuaMacro:
      An extended Lua macro preprocessor
       65 commits, 31 stars, 5 forks

    stevedonovan/Penlight:
      A set of pure Lua libraries focusing on input data handling (such as reading configuration files), functional programming (such as map, reduce, placeholder expressions,etc), and OS path management.  Much of the functionality is inspired by the Python standard libraries.
       348 commits, 142 stars, 29 forks

    stevedonovan/Orbiter:
      A personal Lua Web Application Server
       68 commits, 16 stars, 5 forks

    timn/roslua:
      ROS Client Library for Lua
       245 commits, 11 stars, 2 forks

    trevrosen/lua-presentation:
      A presentation on Lua originally created for Austin.rb
       23 commits, 3 stars, 0 forks

    webscriptio/lib:

       36 commits, 9 stars, 6 forks

    Wiladams/TINN:
      TINN Is Not Node
       60 commits, 8 stars, 0 forks

    Wiladams/TINNSnips:
      Snippets of code that work with the TINN tool
       40 commits, 3 stars, 0 forks

    Wiladams/LAPHLibs:
      Lua Application Programming Helper Libraries
       57 commits, 22 stars, 2 forks

    winton/nginx-accelerator:
      Drop-in page caching using nginx, lua, and memcached
       91 commits, 2 stars, 3 forks

    xopxe/Toribio:
      Embedded Robotics Platform.
       112 commits, 3 stars, 0 forks

    Yonaba/30log:
      30 lines library for object orientation in Lua
       66 commits, 16 stars, 6 forks

    Yonaba/Allen:
      An utility library to manipulate strings in Lua
       36 commits, 12 stars, 6 forks

    Yonaba/Lua-Class-System:
      Lua Class System (LCS) is a small library which offers a clean, minimalistic but powerful  API for (Pseudo) Object Oriented programming style using Lua.
       19 commits, 12 stars, 3 forks

    Yonaba/Moses:
      Utility library for functional programming  in Lua
       132 commits, 25 stars, 8 forks

    zdevito/terra:
      A low-level counterpart to Lua
       488 commits, 389 stars, 27 forks
<!-- PROJECTS_LIST_END -->
