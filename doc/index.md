## Overview

*Luma* is a macro system for the Lua language that is heavily inspired by Scheme's 
[`define-syntax`/`syntax-rules` system][scheme]. The Scheme macro system
uses pattern matching to analyze the syntax of a macro, and template substitution to build
the code that the macro expands to. This is a powerful yet simple system that builds on top
of Scheme's structural regularity (the use of S-expressions for all code).

Luma also separates the expansion process in pattern matching and template substitution phases,
but as Lua source is unstructured text the pattern and template languages have to work with text.
Luma uses [*LPEG*][lpeg] for pattern matching and [*Cosmo*][cosmo] for templates.

## Status

This is the second public release of Luma, version 0.2. It just updates
Luma to work with the current version of LPEG, 0.10 (Luma 0.1 used LPEG
0.7).

## Download

Get Luma from [LuaRocks](http://luarocks.org) via the *luma* package, or from its [Github download page](http://github.com/mascarenhas/luma/downloads).

## History

### Luma 0.2

* Updates Luma to work with LPEG 0.10

### Luma 0.1

* First public release

## Contact Us

For more information please contact the author, [Fabio Mascarenhas](mailto:mascarenhas-NO-SPAM-THANKS@acm.org).
Comments are welcome!

[lpeg]: http://lpeg.luaforge.net "LPEG"

[scheme]: http://citeseer.ist.psu.edu/88826.html "Syntactic Abstraction in Scheme"

[cosmo]: http://cosmo.luaforge.net "Cosmo"
