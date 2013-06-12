# Tutorial.

Here we will build a few programs, step-by-step.


## Data logger

First we will do a data logger, that will save information read from an AX-12 motor to a file. We will call the task "axlogger".

We start by editing the configuration file. We must configure two things: enable the dynamixel device loader, and register the new task, adding the configuration parameters we might use. We do that by adding the following lines to miconf.conf:

    deviceloaders.dynamixel.load = true
    deviceloaders.dynamixel.filename = '/dev/ttyUSB0'
    tasks.axlogger.load=true
    tasks.axlogger.motorname='ax12:3'
    tasks.axlogger.interval=1
    tasks.axlogger.outfile='motor.log'

Then we place the task's code in the tasks/ folder. The tasks/axlogger.lua file:

    local M = {}
    local sched=require 'sched'
    local toribio = require 'toribio'

    M.init = function(conf)

    	local file = io.open(conf.outfile or 'data.log', 'w')
    	local motor = toribio.wait_for_device(conf.motorname)
    	while true do
    		local l = motor:get_load()
    		file:write(sched.get_time()..' '..l..'\n')
    		file:flush()
    		sched.sleep(conf.interval or 5)
    	end
    end

    return M

The log file will contain motor load readings. The process (the function provided to sched.run) starts opening a file for writing and getting the Device for the specified motor. 

The process will loop reading data from the motor and logging it, and then sleeping for the specified interval.

Notice how in the program we provide default values for configuration parameters in case they're missing (like a 5 second interval).

Finally, we run the program:

    lua toribio-go.lua -c miconf.conf

## Remote controlled robot

We will do a remote controlled robot. The idea is that we want to control a two-wheled differential robot using the mouse on another machine. We will see two methods: one using the Lumen's proxy service, and explicitly opening a socket.

### Remote control using a proxy

This is is the simplest method. The proxy task provided with Lumen allows a Toribio to receive events from another Toribio instance, trough a network. Thus the ""remote control"" Toribio only have to start the proxy task and load the mouse device, and the 'robot' Toribio can receive mouse events as if they were local.

There is no need to write code for the remote control, everything is achieved trough configuration:

    deviceloaders.mice.load = true
    tasks.proxy.load = true

The robot will have a task (named rcp_bot.lua) that will use the proxy service to receive the mouse events. For the moment, we will only show how to receive the mouse events without actually moving the motors. The configuration file will have the following:

    tasks.rcp_bot.load = true
    tasks.rcp_bot.rc_ip = "192.168.1.100"
    tasks.rcp_bot.rc_port = 1985 --default port for proxy

The rcp_bot.lua file to place in the tasks/ folder is the following:

    local M = {}
    local toribio = require 'toribio'
    local sched = require 'sched'
    local proxy = require 'tasks/proxy'
    
    M.init = function(conf)
    	local waitd = proxy.new_remote_waitd(conf.rc_ip, conf.rc_port, {
    		emitter = {'mice:/dev/input/mice'},
    		events = {'move', 'leftbutton'},
    	})
    	
    	local left, right = 0, 0
    	sched.sigrun(waitd, function(_, _, _, event, v1, v2) 
    		print (event, v1, v2)
    	end)
    end
    
    return M

The "robot" will print `'move', x, y` as the mouse is moved and `'leftbutton', 'true'` when the left button is clicked and `'leftbutton', 'false'` when released.

This method is very convenient, but does not adapt very well for a remote control: the robot is the one connecting to the control, which is somehow backwards. We will implement a more traditional remote control application next. In this implementation one instance of toribio will read inputs from the mouse (the task rc_control), and generate commands over a UDP link to a Toribio instance in a robot (task rc\_robot) which will receive and parse the commands.

### Remote Control

We will need the mice device, and a task to process mice input and generate commands. We begin with the rc_control.conf configuration file:

    deviceloaders.mice.load = true
    tasks.rc_control.load=true
    tasks.rc_control.ip='127.0.0.1' --change with the ip adress of the robot
    tasks.rc_control.port=9999

The remote control will behave as follows: it tracks mouse's movements, generates messages of the form "left, right" and sends them over udp. A message is sent at least each 0.5 seconds, so if we stop transmitting the robot can deduce it must stop. The skeleton for the tasks/rc_control.lua file is as follows:

    local M = {}
    local toribio = require 'toribio'
    local sched = require 'sched'
    
    M.init = function(conf)
    
    	local function generate_output(x, y)
    		--calculate velocities and send them over udp
    	end
    
    	local mice = toribio.wait_for_device('mice:/dev/input/mice')
    	local lastx, lasty = 0, 0
    	mice:register_callback('move', function (x, y)
    		if x then 
    			generate_output(x, y)
    			lastx, lasty = x, y
    		else
    			-- timeout with no mouse movements
    			generate_output(lastx, lasty)
    		end
    	end, 0.5)
    
    end
    
    return M

In this program we use the register\_callback method, instead of the explicit loop with a sched.wait inside as in the first program. This will start yet another process (the one listening for the signal), that will keep runing while the first process (the one started with sched.run) will finish immediatelly. The register\_callback method has a timeout parameter set (the 0.5 at the end). When the timeout runs out without signals, it will wake our function with `nil, 'timeout'` as parameters: that's why we check for x to see wether we have a new coordinate, or must use the last recorded set of coordinates.

The only part missing is the generate\_output function. We will use nixio to create a UDP socket and use it to send the messages.

    local nixio = require 'nixio'
    local udp = assert(nixio.bind('*', 0, 'inet', 'dgram'))
    udp:connect(conf.ip, conf.port)
    local function generate_output(x, y)
    	local left = (y + x)/2
    	local right = (y - x)/2
    	udp:send(left..','..right)
    end

This program can be easily improved adding a callback that would react to mouse clicks. For example adding the following callback allows to stop the robot clicking the left button.

    mice:register_callback('leftbutton', function (is_pressed)
    	if is_pressed then 
    		generate_output(0, 0)
    		mice.reset_pos(0, 0)
    		lastx, lasty = 0, 0
    	end
    end)

### Controlled bot

The bot listens for UDP packets, parses them and set motor velocities. As allways, the configuration in rc_bot.conf:

    deviceloaders.dynamixel.load = true
    deviceloaders.dynamixel.filename = '/dev/ttyUSB0'
    tasks.rc_bot.load = true
    tasks.rc_bot.ip = '127.0.0.1' --change with the ip adress of the robot
    tasks.rc_bot.motor_left='ax12:3'
    tasks.rc_bot.motor_right='ax12:12'
    tasks.rc_bot.port = 9999

And the tasks/rc\_bot.lua skeleton:

    local M = {}
    local toribio = require 'toribio'
    local sched = require 'sched'
    
    M.init = function(conf)
    

    	--initialize motors
    	local motor_left = toribio.wait_for_device(conf.motor_left)
    	local motor_right = toribio.wait_for_device(conf.motor_right)
    	motor_left.init_mode_wheel()
    	motor_right.init_mode_wheel()

    	--initialize socket
    	local nixio = require 'nixio'
    	local udp = assert(nixio.bind(conf.ip, conf.port, 'inet', 'dgram'))
    	local selector = require 'tasks/selector'
    	local udp = selector.new_udp(conf.ip, conf.port, 1480)
    
    	--listen for messages
    	sched.sigrun({emitter=udp.task, events={udp.events.data}, timeout=1}, 
    		function(_, _, msg) 
    			local left, right = 0, 0
    			if msg then
    				left, right = msg:match('^([^,]+),([^,]+)$')
    			end
    			motor_left.set_speed(left)
    			motor_right.set_speed(right)
    		end
    	)

    end
    
    return M

Notice how we use the selector service to create a udp socket object, that will emit signals when data arrives. Then we listen for these signals with a function (registered in the sched.sigrun call). The timeout is set so if we do not receive a command within a second, the robot will stop.

Now we run toribio with rc\_control task enabled on one machine, connected to a second machine with rc\_bot enabled.

    lua toribio-go.lua -c rc_control.conf

and

    lua toribio-go.lua -c rc_bot.conf


Notice that rc\_control might have to be run as sudo, if your distribution request such thing for accesing /dev/input/mice.

## Reactive robotics

In this example, we will use a usb4butia IO board. Our task will be called bootia, and we will use the deviceloader/bobot task to access the hardware. Thus, our configuration file will have the following:

    deviceloaders.bobot.load = true
    deviceloaders.bobot.path = '../bobot' --path to bobot library
    deviceloaders.bobot.comms = {"usb"}
    deviceloaders.bobot.timeout_refresh = 10
    tasks.bootia.load=true

The code for the tasks/bootia.lua might be as follows:

    local M = {}
    local sched = require 'sched'
    local toribio = require 'toribio'
    
    M.init = function()
    	sched.run(function()
    		local button = toribio.wait_for_device({module='bb-button'})
    		local pressed = false
    		while true do
    			local now = ( button.getValue()==1 )
    			if pressed and not now then 
    				print ("pressed!")
    				pressed=now
    			elseif not pressed and now then
    				print ("released!")
    				pressed=now
    			end
    			sched.sleep(0.1)
    		end
    	end)
    end
    
    return M

This process polls a button connected to the usb4butia board (any button will do), and prints "pressed!" or "released!" when the button changes state. You can change the polling rate in the sched.sleep() call. The absolutely minimum you can expect to work is at least call sched.yield() from time to time, to give opportunity to other processes to do their stuff.

Now suppose you have a usb4butia powered robot that only goes forward and backwards, changind the direction with a button press. You could put the direction changind code right in the previous process, but we will do it using a more flexible method: signalling. 

The idea is that there will be a signal that requests a direction change, and a separate process that will wait for these signals and apply them. The previous process will be modified to emit a signal as follows:

    			if pressed and not now then 
    				sched.signal('change direction!')
    				pressed=now
    			elseif not pressed and now then
    				pressed=now
    			end

Now that button process fires events, we can start another process that will listen for them and change the 
motor direction (the motors will start moving at the first button press):

    	sched.run(function()
    		local motors = toribio.wait_for_device('bb-motors')
    		local direction = 1
    		sched.sigrun({emitter='*', events={'change direction!'}}, function()
    			motors.setvel2mtr(direction, 500, direction, 500)
    			direction=1-direction
    		end)
    	end)


Because our wait descriptor for changing direction accepts events from anyone (the `emitter='*'` field), we can have more processes that fire it. Suppose that we want to add the behavior that the robot will change direction randomly, anywhere between 10 to 20 seconds. We can have it simply adding another process:

    	sched.run(function()
    		while true do
    			sched.sleep(10 + 10*math.random())
    			sched.signal('change direction!')
    		end
    	end)


