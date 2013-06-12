--- Library for accesing a mouse.
-- This library allows to read data from a mouse,
-- such as it's coordinates and button presses.
-- The device will be named "mice", module "mice". 
-- @module mice
-- @alias device

local M = {}

--- Initialize and starts the module.
-- This is called automatically by toribio if the _load_ attribute for the module in the configuration file is set to
-- true.
-- @param conf the configuration table (see @{conf}).
M.init = function(conf)
	local toribio = require 'toribio'
	local selector = require 'tasks/selector'
	local sched = require 'sched'
	local floor = math.floor

	local filename = conf.filename or '/dev/input/mice'
	local devicename='mice:'..filename

	local x, y = 0, 0
	local bl, bm, br = 0, 0, 0

	local leftbutton, rightbutton, middlebutton, move={}, {}, {}, {} --events
	
	local device={}
	
	local filehandler = assert(selector.new_fd(filename, {'rdonly', 'sync'}, 3, function(_, data)
		local s1,dx,dy = string.byte(data,1,3)
		if floor(s1/16)%2 == 1 then 
			dx = dx - 0x100
		end
		if floor(s1/32)%2==1 then 
			dy = dy - 0x100
		end
		local left = s1%2
		if bl ~= left then 
			bl=left
			sched.signal(leftbutton, left==1)
		end
		local right = floor(s1/2)%2
		if br ~= right then 
			br=right
			sched.signal(rightbutton, right==1)
		end
		local middle = floor(s1/4)%2
		if bm ~= middle then 
			bm=middle
			sched.signal(middlebutton, middle==1)
		end
		
		--print('DATA!!!', s1, '', dx,dy, left, middle, right)
		x, y = x+dx, y+dy
		
		if dx~=0 or dy~=0 then
			sched.signal(move, x, y, dx, dy)
		end
		return true
	end))
	
	--- Name of the device (in this case, 'mice').
	device.name=devicename

	--- Module name (in this case, 'mice').
	device.module='mice'

	--- Task that will emit signals associated to this device.
	device.task=selector.task

	--- Device file of the mouse.
	-- For example, '/dev/input/mice'
	device.filename=filename

	--- Events emitted by this device.
	-- Button presses have single parameter: true on press,
	-- false on release.
	-- @field leftbutton Left button click.
	-- @field rightbutton Right button click.
	-- @field middlebutton Middle button click.
	-- @field move Mouse moved, first parameter x, second parameter y coordinates.
	-- @table events
	device.events={
		leftbutton=leftbutton,
		rightbutton=rightbutton,
		middlebutton=middlebutton,
		move=move,
	}

	--- Get mouse position.
	-- @return a pair of x, y coordinates.
	device.get_pos=function()
		return x, y
	end

	--- Reset position.
	-- Fixes the coordinates associated to the current
	-- position.
	-- @param newx number to set as x coordinate of
	-- the cursos (defaults to 0)
	-- @param newy number to set as y coordinate of
	-- the cursos (defaults to 0)
	device.reset_pos=function(newx, newy)
		newx, newy = newx or 0, newy or 0
		x, y = newx, newy
	end

	--- Pause the event generation.
	-- While the device is paused, no events are generated, nor movements tracked.
	-- @param pause mode, true to pause, false to unpause
	device.set_pause = function ( pause )
		device.task:set_pause( pause )
	end
	
	toribio.add_device(device)
end

return M

--- Configuration Table.
-- When the start is done automatically (trough configuration), 
-- this table points to the modules section in the global configuration table loaded from the configuration file.
-- @table conf
-- @field load whether toribio should start this module automatically at startup.
-- @field filename the device file for themouse (defaults to ''/dev/input/mice'').
