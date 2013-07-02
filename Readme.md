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
       22 commits, last change: 2012-12-23 11:16:43, 3 stars, 0 forks

    badgerman/euler:
      Project Euler solutions, mostly in Lua
       3 commits, last change: 2013-05-16 09:28:37, 1 stars, 0 forks

    catwell/luajit-msgpack-pure:
      MessagePack for LuaJIT (using FFI, no bindings)
       45 commits, last change: 2013-01-19 05:21:32, 25 stars, 7 forks

    craigbarnes/ldiscount:
      Lua bindings for the Discount Markdown library
       14 commits, last change: , 4 stars, 1 forks

    EmergingThreats/et-luajit-scripts:

       28 commits, last change: 2013-06-28 15:48:43, 1 stars, 0 forks

    Fizzadar/Luawa:
      Lua Web Application (Framework)
       68 commits, last change: 2013-06-14 07:05:57, 2 stars, 1 forks

    Fizzadar/yummymarks:

       1 commits, last change: , 2 stars, 1 forks

    geoffleyland/luatrace:
      A tool for tracing Lua script execution and analysing time profiles and coverage
       138 commits, last change: 2013-04-03 22:00:56, 44 stars, 6 forks

    GloryFish/love2d-verlet-cloth:
      Verlet cloth simulation in Lua, for LÖVE
       4 commits, last change: , 1 stars, 0 forks

    hnakamur/luajit-examples:
      my example codes for LuaJIT
       24 commits, last change: 2013-03-12 09:21:33, 8 stars, 0 forks

    justincormack/ljsyscall:
      LuaJIT Linux syscall FFI
       1000+ commits, last change: 2013-07-02 13:26:19, 86 stars, 15 forks

    keplerproject/copas:
      Copas is a dispatcher based on coroutines that can be used by TCP/IP servers.
       122 commits, last change: 2013-01-24 12:20:27, 29 stars, 7 forks

    keplerproject/coxpcall:
      Coxpcall encapsulates the protected calls with a coroutine based loop, so errors can be dealed without the usual pcall/xpcall issues with coroutines.
       42 commits, last change: 2013-06-10 09:00:44, 7 stars, 3 forks

    keplerproject/luadoc:
      LuaDoc is a documentation tool for Lua source code.
       131 commits, last change: 2011-10-01 11:54:12, 45 stars, 10 forks

    keplerproject/luarocks:
      LuaRocks is a deployment and management system for Lua modules.
       530 commits, last change: 2013-06-26 13:33:50, 133 stars, 40 forks

    keplerproject/orbit:
      Orbit is an MVC web framework for Lua.
       178 commits, last change: 2010-03-31 07:15:28, 51 stars, 14 forks

    keplerproject/xavante:
      Xavante is a Lua HTTP 1.1 Web server that uses a modular architecture based on URI mapped handlers.
       361 commits, last change: 2013-01-29 09:11:23, 55 stars, 18 forks

    kikito/i18n.lua:
      A very complete i18n lib for Lua
       43 commits, last change: 2012-11-01 09:52:19, 6 stars, 1 forks

    kikito/inspect.lua:
      Human-readable representation of Lua tables
       48 commits, last change: 2013-01-20 15:51:44, 49 stars, 11 forks

    kikito/lua_missions:
      Lua Koans, minus the Zen stuff
       67 commits, last change: 2013-04-08 08:26:51, 95 stars, 35 forks

    kikito/middleclass:
      Object-orientation for Lua
       119 commits, last change: 2013-01-01 16:57:39, 213 stars, 25 forks

    kikito/stateful.lua:
      Stateful classes for Lua
       30 commits, last change: 2013-03-01 15:41:32, 25 stars, 6 forks

    leafo/lapis:
      a web framework written in MoonScript
       286 commits, last change: 2013-06-17 10:06:03, 162 stars, 16 forks

    lipp/jet:
      Distributed applications with JSON-RPC
       158 commits, last change: 2013-05-21 10:50:18, 4 stars, 0 forks

    lipp/lua-websockets:
      Websockets for Lua.
       316 commits, last change: 2013-06-29 11:10:08, 38 stars, 7 forks

    lipp/zbus:
      A simple TCP/IP based message bus in Lua.
       105 commits, last change: , 6 stars, 0 forks

    logiceditor-com/codebase:
      Open-Source Lua codebase we use in our projects
       1000+ commits, last change: , 4 stars, 2 forks

    lua-aplicado/lua-aplicado:
      A random collection of application-level Lua libraries
       204 commits, last change: 2013-02-16 03:42:29, 7 stars, 3 forks

    lua-cookbook/lua-cookbook:
      The Lua Cookbook
       31 commits, last change: 2013-03-21 04:14:50, 56 stars, 14 forks

    lua-nucleo/lua-nucleo:
      A random collection of core and utility level Lua libraries
       750 commits, last change: 2013-06-29 23:39:56, 36 stars, 12 forks

    LuaDist/srlua:
      A tool for building self-running Lua programs.
       17 commits, last change: 2013-05-07 06:29:35, 6 stars, 3 forks

    luaforge/simulua:
      Simulua is a discrete-event simulation library for Lua. The simulation in Simulua is process-oriented, that is, the operation path of a simulated system is obtained from interactions of processes running in parallel and managed by an event list. This repository was converted from a CVS repository on luaforge.net on Jan. 20, 2010.
    If you are the …
       4 commits, last change: 2008-08-19 16:36:46, 1 stars, 0 forks

    martin-damien/babel:
      Babel is a module to enable internationalisation in Lua applications. It is designed to work with LÖVE 2D too.
       24 commits, last change: 2013-05-10 11:10:33, 3 stars, 3 forks

    mascarenhas/luma:
      LPEG-based Lua macros
       56 commits, last change: , 8 stars, 0 forks

    meric/l2l:
      A lisp that compiles to and runs as fast as lua. Equipped with macroes and compile-time compiler manipulation. Comes with all built-in lua functions.
       50 commits, last change: 2013-03-10 04:49:22, 46 stars, 5 forks

    mindreframer/leslie:
      a non-official git mirror for leslie - a Lua implementation for Django template language
       35 commits, last change: , 0 stars, 0 forks

    mindreframer/ProFi.lua:
      a non-official git mirror for ProFi, a Lua profiler
       14 commits, last change: 2013-04-05 09:35:12, 2 stars, 0 forks

    mindreframer/scilua:
      a non-official git mirror for http://www.scilua.org/
       8 commits, last change: 2013-04-04 13:00:13, 0 stars, 0 forks

    neomantra/lds:
      LuaJIT Data Structures - hold cdata in lists, trees, hash tables, and more
       9 commits, last change: 2012-10-15 11:28:38, 12 stars, 1 forks

    neomantra/luajit-nanomsg:
      LuaJIT FFI binding to the nanomsg library
       20 commits, last change: 2013-04-04 10:34:18, 4 stars, 1 forks

    Neopallium/lua-handlers:
      Provides a set of async. callback based handlers for working with raw TCP/UDP socket, ZeroMQ sockets, or HTTP client/server.
       127 commits, last change: 2013-05-27 04:35:59, 62 stars, 5 forks

    norman/lua-postgres:
      A basic Postgres driver for Lua
       19 commits, last change: , 11 stars, 1 forks

    norman/telescope:
      A highly customizable test library for Lua that allows declarative tests with nested contexts.
       79 commits, last change: 2013-02-21 05:17:01, 72 stars, 19 forks

    Olivine-Labs/luassert:
      Assertion library for Lua
       155 commits, last change: 2013-05-23 17:13:53, 11 stars, 12 forks

    Olivine-Labs/lustache:
      Mustache templates for Lua
       48 commits, last change: 2013-04-18 10:54:56, 25 stars, 5 forks

    pavouk/lgi:
      Dynamic Lua binding to GObject libraries using GObject-Introspection
       1000+ commits, last change: 2013-06-27 14:03:55, 62 stars, 15 forks

    perky/FEZ:
      A lua library that helps you create component based projects inspired by Artemis.
       24 commits, last change: 2012-08-12 05:51:16, 16 stars, 4 forks

    pkulchenko/serpent:
      Lua serializer and pretty printer
       46 commits, last change: 2013-06-12 11:06:02, 31 stars, 8 forks

    rgieseke/locco:
      Locco is Docco in Lua.
       10 commits, last change: 2013-01-19 08:48:37, 23 stars, 4 forks

    rrthomas/lua-stdlib:
      General Lua libraries
       716 commits, last change: 2013-06-02 07:07:58, 50 stars, 4 forks

    seomoz/qless-core:
      Core Lua Scripts for qless
       120 commits, last change: 2013-05-08 15:58:49, 33 stars, 5 forks

    silentbicycle/lunatest:
      xUnit-style + randomized unit testing framework for Lua (and C projects using Lua, etc.)
       77 commits, last change: 2013-01-20 17:03:11, 31 stars, 12 forks

    silentbicycle/tamale:
      TAble MAtching Lua Extension - An Erlang-style pattern-matching library for Lua
       46 commits, last change: 2012-01-20 07:39:14, 30 stars, 0 forks

    slembcke/debugger.lua:
      A simple, embedabble CLI debugger for Lua.
       13 commits, last change: 2012-10-02 13:12:37, 20 stars, 2 forks

    SnabbCo/snabbswitch:
      The Snabb Switch Project
       303 commits, last change: 2013-06-22 07:37:46, 87 stars, 11 forks

    sroccaserra/object-lua:
      A class-oriented OOP module for Lua
       35 commits, last change: 2010-03-04 05:20:33, 27 stars, 1 forks

    statianzo/lua_euler:
      Working through Project Euler with Lua for some practice
       16 commits, last change: , 1 stars, 0 forks

    stevedonovan/ldeb:
      ldeb converts Lua scripts into Debian packages
       3 commits, last change: , 2 stars, 1 forks

    stevedonovan/luaish:
      A Lua REPL with global name tab-completion and a shell sub-mode
       5 commits, last change: 2012-05-23 04:27:48, 21 stars, 4 forks

    stevedonovan/LuaMacro:
      An extended Lua macro preprocessor
       65 commits, last change: 2013-06-10 21:51:38, 31 stars, 5 forks

    stevedonovan/Microlight:
      A little library of useful Lua functions, intended as the 'light' version of Penlight
       32 commits, last change: 2012-12-29 01:39:19, 37 stars, 9 forks

    stevedonovan/Orbiter:
      A personal Lua Web Application Server
       68 commits, last change: 2013-01-24 03:14:22, 16 stars, 5 forks

    stevedonovan/Penlight:
      A set of pure Lua libraries focusing on input data handling (such as reading configuration files), functional programming (such as map, reduce, placeholder expressions,etc), and OS path management. Much of the functionality is inspired by the Python standard libraries.
       351 commits, last change: 2013-06-27 00:41:58, 145 stars, 30 forks

    timn/roslua:
      ROS Client Library for Lua
       245 commits, last change: 2013-01-29 05:46:53, 10 stars, 2 forks

    trevrosen/lua-presentation:
      A presentation on Lua originally created for Austin.rb
       23 commits, last change: , 3 stars, 0 forks

    webscriptio/lib:

       36 commits, last change: 2013-04-13 18:18:43, 9 stars, 6 forks

    Wiladams/LAPHLibs:
      Lua Application Programming Helper Libraries
       57 commits, last change: 2013-04-03 05:06:21, 22 stars, 2 forks

    Wiladams/TINN:
      TINN Is Not Node
       68 commits, last change: 2013-07-01 12:30:16, 8 stars, 0 forks

    Wiladams/TINNSnips:
      Snippets of code that work with the TINN tool
       42 commits, last change: 2013-06-30 23:30:18, 3 stars, 0 forks

    winton/nginx-accelerator:
      Drop-in page caching using nginx, lua, and memcached
       91 commits, last change: , 2 stars, 3 forks

    xopxe/Toribio:
      Embedded Robotics Platform.
       112 commits, last change: 2013-06-18 08:28:41, 3 stars, 0 forks

    Yonaba/30log:
      30 lines library for object orientation in Lua
       66 commits, last change: 2013-06-16 03:55:56, 16 stars, 6 forks

    Yonaba/Allen:
      An utility library to manipulate strings in Lua
       36 commits, last change: 2013-04-29 12:59:57, 12 stars, 6 forks

    Yonaba/Lua-Class-System:
      Lua Class System (LCS) is a small library which offers a clean, minimalistic but powerful API for (Pseudo) Object Oriented programming style using Lua.
       19 commits, last change: 2012-11-12 12:58:29, 12 stars, 3 forks

    Yonaba/Moses:
      Utility library for functional programming in Lua
       132 commits, last change: 2013-05-11 09:03:27, 25 stars, 8 forks

    zdevito/terra:
      A low-level counterpart to Lua
       491 commits, last change: 2013-06-28 15:17:10, 393 stars, 27 forks
<!-- PROJECTS_LIST_END -->
