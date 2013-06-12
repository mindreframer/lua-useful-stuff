#!/usr/bin/env moon

module "things", package.seeall
export Person

class Thing
  name: "unknown"

class Person extends Thing
  say_name: => print "Hello, I am " .. @name

with Person!
  .name = "MoonScript"
  \say_name!

