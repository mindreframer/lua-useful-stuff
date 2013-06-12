# Toribio Configuration.

Toribio's configuration file is toribio-go.conf. At run time, the content
is available in toribio.configuration table.

## File Format

The configuration file is actually a lua file, so usual lua syntax is valid.
For example "--" starts a comment, {} defines a table, etc. 

The main task of the configuration file is to give value to atributes. An 
attribute is just a index in a table structure.

There are two predefined main levels: 'tasks' and 'deviceloaders'. They specify
the tasks to start and what parameters provide to them.

For example:

    tasks.xy.load = true
    tasks.xy.motor_x = 'ax12:3'
    tasks.xy.motor_y = 'ax12:12'

Describes a task available in the tasks/ folder, called 'xy' (thus, there
is a tasks/xy.lua file). This task will be started automatically (the `true` 
value). When the task is started, it will be provided with a configuration
table as follows: `{motor_x='ax12:3', motor_y='ax12:12'}`

To quickly disable a task, set the load field to `false` or just comment that
line.

When creating an attribute, intermediate tables are generated automatically
as needed. For example:

    deviceloaders.filedev.load = true
    deviceloaders.filedev.module.mice = '/dev/input/mice'
    deviceloaders.filedev.module.dynamixel = '/dev/ttyUSB*'

creates a table named "module", which will have two fields, "mice" and 
"dynamixel".

## Interactive shell

Besides Toribio provided tasks, Lumen's task are also available. For example, 
there is an interactive shell, accesible trough telnet. To 
enable it, add the following:

    tasks.shell.load = true
    tasks.shell.ip = 127.0.0.1 --defaults to '*'
    tasks.shell.port = 2012 --defaults to 2012

## Log Level

Toribio uses Lumens logging infrastructure. It is possible to change the 
default log level, and set level per logging module. Available levels are
'NONE', 'ERROR', 'WARNING', 'INFO', 'DETAIL', 'DEBUG' and 'ALL'.

For example, to set a default level of INFO, while muting logging from 
the scheduler and showing all available messages from the dynamixel module, 
use:

    log.level.default = 'INFO'
    log.level.SCHED = 'NONE'
    log.level.AX = 'ALL'

## Parameters on the commandline

TODO


