# Toribio: a Embedded Robotics Library.

Toribio is a library for developing robotics applications. It is based on 
[Lumen](https://github.com/xopxe/Lumen) cooperative
scheduler, and allows to write coroutine, signal and callback based applications.
Toribio provides a mechanism for easily accessing hardware, and is geared towards
low end hardware, such as Single-Board Computers.

## Description

Using Toribio consists of writing Toribio tasks. These tasks are started automatically.
When writing these tasks, the programmer have easy access to available devices and to an 
asynchronous socket and file server. The tasks use Lumen as a cooperative scheduler, and 
thus can be synchronized exchanging signals. Signals also serve to exchange information 
between tasks. In any case, Lumen is a shared memory environment and all tasks live in 
the same VM, so tasks can declare global variables, etc.

Toribio provides the concept of Device. A Device is an object that represents, f.e. a motor,
the mouse or a distance sensor. Devices provide methods that allow to manipulate them. Also,
Devices can emit signals: for example, there could be a signal emitted when a button is 
pressed. These signals can be used trough callbacks: just register a function with Toribio 
to attend a signal from a Device.

## Dependencies

Toribio runs on Lua 5.1 or LuaJIT. Compatibility with Lua 5.2 is planned.
The only external dependency is the [nixio](https://github.com/Neopallium/nixio) library.
Additionally, for automatically managing devices on file creation and removal the 
`inotifywait` program must be installed.

## Tutorial

A tutorial is available [here](https://github.com/xopxe/Toribio/blob/master/docs/1-Tutorial.md)

## Contents

* toribio.lua

The main library. This is the library that will be require'd by tasks to get access 
to devices, etc.

* toribio-go.lua

The launch script. Uses toribio-go.conf to start tasks and provide them parameters.

* toribio-go.conf

Central configuration repository. Will be available to tasks trough toribio library. 
Also determines what tasks to start.

* /deviceloaders/*

Here go tasks that are able to discover new devices and instantiate new Device objects.
You may want to add tasks there to extend Toribio with support for new hardware

* /tasks/*

Here go user tasks, that implement the behaviour of the robot. A task can implement some
intelligence, or be a remote control server, or just be a data logger, etc.

* /docs/*

Full API reference and additional documentation.

* Lumen/

The Lumen scheduler.

## License

Same as Lua, see COPYRIGHT.

## Who?

Copyright (C) 2012 Jorge Visca, jvisca@fing.edu.uy

MINA Group, University of the Republic, Uruguay

