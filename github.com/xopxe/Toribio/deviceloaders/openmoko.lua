--- Library for managing a OpenMoko smartphone.
-- Uses the omhacks tool.
-- See http://manpages.ubuntu.com/manpages/precise/man1/om.1.html  
-- It is possible to provide default values applied automatically at startup. For this a configuration field
-- matching a method name  must exist. Examples:
--
-- deviceloaders.openmoko.usb\_charger\_mode = 'charge-battery'  
-- deviceloaders.openmoko.usb\_mode = 'host'  
-- deviceloaders.openmoko.gps\_power = {true, true}  
--
-- @usage local toribio = require 'toribio'
--local om = toribio.wait_for_device('openmoko')
--print (om.battery_energy())
-- @module openmoko
-- @alias device

local M = {}
local log = require 'log'

local run_shell = function(s)
	local f = io.popen(s) -- runs command
	local l = f:read("*a") -- read output of command
	f:close()
	return l
end

--- Initialize and starts the module.
-- This is called automatically by toribio if the _load_ attribute for the module in the configuration file is set to
-- true.
-- @param conf the configuration table (see @{conf}).
M.init = function(conf)
	local toribio = require 'toribio'
	conf = conf or {}
	local touchscreen_lock
	local device={
		--- Name of the device.
		-- In this case, "openmoko".
		name="openmoko",
		
		--- Module name.
		-- In this case, "openmoko".
		module="openmoko",
--[[
om sysfs name [name...]
-- om backlight brightness [0-100]
*om backlight
*om backlight get-max
*om backlight <brightness>
-- om touchscreen lock
-- om screen power [1/0]
om screen resolution [normal|qvga-normal]
-- om screen glamo-bus-timings [4-4-4|2-4-2]
-- om bt [--swap] power [1/0]
-- om gsm [--swap] power [1/0]
om gsm flowcontrol [1/0]
-- om gps [--swap] power [1/0]
-- om gps [--swap] keep-on-in-suspend [1/0]
om gps send-ubx <class> <type> [payload_byte0] [payload_byte1] ...
-- om wifi [--swap] power [1/0]
-- om wifi maxperf <iface> [1/0]
-- om wifi keep-bus-on-in-suspend [1/0]
om battery temperature
-- om battery energy
om battery consumption
-- om battery charger-limit [0-500]
om power
om power all-off
om resume-reason
om resume-reason contains <val>
* om  led <name>
* om  led <name> <brightness>
-- om  led <name> <brightness> timer <ontime> <offtime>
om uevent dump
-- om usb mode [device|host]
-- om usb charger-mode [charge-battery|power-usb]
-- om usb charger-limit [0|100|500]
--]]

		--- Set USB mode.
		-- In device mode the phone can  talk  to
		-- USB hosts (PCs or phones in host mode). In host mode the phone
		-- can talk to USB  devices. Also see usb.charge.mode
		-- @param mode Optional, either 'host' or 'device' changes the mode.
		-- @return The mode as set.
		usb_mode = function(mode)
			if mode then
				assert(mode=='host' or mode=='device', "Supported host mode are 'host' and 'device'")
				if mode=='host' then
					os.execute('ifconfig usb0 down')
				end
				run_shell('om usb mode '..mode)
				os.execute('lsusb') --https://docs.openmoko.org/trac/ticket/2166
				if mode=='device' then
					os.execute('ifconfig usb0 up')
				end
			end
			return run_shell('om usb mode')
		end,
			
		--- Set USB powering mode.
		-- Normally you want to charge
		-- the battery in device mode and power the USB bus  in  host  mode
		-- but  it is possible to for example use an external battery power
		-- the USB bus so that the phone can be  in  host  mode  and  still
		-- charge itself over USB. Also see usb.mode
		-- @param direction optional. Either 'charge-battery' or 'power-usb'
		-- @return The direction as set.
		usb_charger_mode = function(chargermode)
			if chargermode then
				assert(chargermode=='charge-battery' or chargermode=='power-usb', 
					"Supported powermodes are 'charge-battery' and 'power-usb'")
				run_shell('om usb charger-mode '..chargermode)
			end
			return run_shell('om usb charger-mode')
		end,
		
		--- Set the current limit on the USB port.
		-- Control the current that the  phone  will  draw
		-- from  the  USB  bus.  When  the phone is in device mode and some
		-- gadget driver is loaded it will negotiate  the  highest  allowed
		-- charging current automatically. However, if you are using a dumb
		-- external USB battery it might be necessary to force larger limit
		-- than the default of 100 mA. Do not set the limit to be too large
		-- if your charger can not handle it!
		-- When powered from an "dumb" device, the phone sets a 100mA limit by default.
		-- @param currlim Optional the current limit in mA. Supported values are 0, 100, 500 and 1000.
		-- @return The current limit as set.
		usb_charger_limit = function(currlim)
			if currlim then
				assert(currlim==0 or currlim==100 or currlim==500 or currlim==1000, 
					"Supported currlim values are 0, 100, 500 and 1000")
				run_shell('om usb charger-limit '..currlim)
			end
			return run_shell('om usb charger-limit ')
		end,
		
		--- Locks the touchsreen.
		-- This is useful  when  you want to keep the phone running in a pocket and
		-- don't want the backlight to turn on every time you  accidentally
		-- touch  the screen. Locking is done in a way that does not depend
		-- on X so if X server crashes and restarts your screen will  still
		-- stay locked.
		-- @param on True to lock false to unlock, nil to keep.
		-- @return The current lock mode as set.
		 touchscreen_lock = function (on)
			if on and not touchscreen_lock then 
				local out = run_shell('om touchscreen lock &')
				_, _, touchscreen_lock = out:find('%s(%d+)$')
			elseif on~=nil and touchscreen_lock then
				run_shell('kill '..touchscreen_lock)
				touchscreen_lock = nil
			end
			return touchscreen_lock ~= nil
		 end,
		
		--- Set the current limit on the battery charger.
		-- Usually is set equal to usb_charge_limit, but can be lower when powering from USB and only want to keep
		-- battery charged and leave enough power for the rest of the phone.
		-- @param currlim Optional the current limit in mA. Supported values are 0, 100, 500.
		-- @return The current limit as set.
		battery_charger_limit = function(currlim)
			if currlim then
				assert(currlim==0 or currlim==100 or currlim==500, 
					"Supported currlim values are 0, 100 and 500")
				run_shell('om battery charger-limit '..currlim)
			end
			return run_shell('om battery charger-limit')
		end,
		
		--- Return the battery charge level.
		-- @return a percentage of full charge.
		battery_energy = function ()
			return run_shell('om battery energy')
		end,
		
		--- Power the bluetooth module.
		-- @param power true to enable, false to disable, nil to keep.
		-- @return the mode as set
		bt_power = function(power)
			if power==true then
				run_shell('om bt power 1')
			elseif power==false then
				run_shell('om bt power 0')
			end
			return run_shell('om bt power')=="1"
		end,
	
		--- Power the gps module.
		-- @param power true to enable, false to disable, nil to keep.
		-- @param keep_on_in_suspend true to enable, false to disable, nil to keep
		-- @return the power as set, the suspend mode as set.
		gps_power = function(power, keep_on_in_suspend)
			if power==true then
				run_shell('om gps power 1')
			elseif power==false then
				run_shell('om gps power 0')
			end
			if keep_on_in_suspend==true then
				run_shell('om gps keep-on-in-suspend 1')
			elseif keep_on_in_suspend==false then
				run_shell('om gps keep-on-in-suspend 0')
			end
			return run_shell('om gps power')=="1", run_shell('om gps keep-on-in-suspend')=="1"
		end,

		--- Power the gsm module.
		-- @param power true to enable, false to disable, nil to keep.
		-- @return the mode as set
		gsm_power = function(power)
			if power==true then
				run_shell('om gsm power 1')
			elseif power==false then
				run_shell('om gsm power 0')
			end
			return run_shell('om gsm power')=="1"
		end,
	
		--- Power the wifi module.
		-- @param power true to enable, false to disable, nil to keep.
		-- @return the mode as set
		wifi_power = function(power)
			if power==true then
				run_shell('om wifi power 1')
			elseif power==false then
				run_shell('om wifi power 0')
			end
			return run_shell('om wifi power')=="1"
		end,
		
		--- Enable the maxperf mode for wifi.
		-- Enabling this  increases
		-- energy consumption but lowers latency.
		-- @param iface network interface (usually "eth1")
		-- @param on true to power on, false to power down, nil to keep as is.
		-- @return the mode as set
		wifi_maxperf = function(iface, on)
			if on==true then
				run_shell('om wifi maxperf '..iface..' 1')
			elseif on==false then
				run_shell('om wifi maxperf '..iface..' 0')
			end
			return run_shell('om wifi maxperf')=="1"
		end,
		
		--- Keep de wifi bus powered on suspend.
		-- Needed for wake on wlan.
		-- @param iface network interface (usually "eth1")
		-- @param on true to power on, false to power down, nil to keep as is.
		-- @return the mode as set
		wifi_keep_bus_on_in_suspend = function(on)
			if on==true then
				run_shell('om wifi keep-bus-on-in-suspend 1')
			elseif on==false then
				run_shell('om wifi keep-bus-on-in-suspend 0')
			end
			return run_shell('om wifi keep-bus-on-in-suspend')=="1"
		end,
		
		--- Power the screen.
		-- @param power true to enable, false to disable, nil to keep.
		-- @return the mode as set
		screen_power = function(power)
			if power==true then
				run_shell('om screen power 1')
			elseif power==false then
				run_shell('om screen power 0')
			end
			return run_shell('om screen power')=="1"
		end,
		
		--- Control the glamo timings.
		-- Reads  or sets the timings of the memory bus between the CPU and
		-- the glamo graphics chip. Numbers are SRAM interface  timings  of
		-- the CPU. According to http://lists.openmoko.org/pipermail/community/2010-July/062495.html
		-- using 2-4-2 is more appropriate, view that article and following
		-- discussion for more details.
		-- @param timing either '4-4-4' or '2-4-2', nil to keep.
		-- @return the timing as set
		screen_glamo_bus_timings = function(timing)
			if timing then
				assert(timing=='4-4-4' or timing=='2-4-2', 
					"Supported timing values are '4-4-4' and '2-4-2'")
				run_shell('om screen glamo-bus-timings '..timing)
			end
			return run_shell('om screen glamo-bus-timings')
		end,
		
		--- Control the backlight brigthness.
		-- Reports true brightness only if the screen
		-- has not been blanked with screen.power
		-- @param level the percentage of maxbrighness, nil to keep.
		-- @return the level as set.
		backlight_brightness = function (level)
			if level then
				run_shell('om backlight brightness '..level)
			end
			return run_shell('om backlight brightness')
		end,

		--- Control the vibrator power.
		-- @param level the vibrating power, in the 0..255 range
		-- @param ontime if provided with offtime, will blink at the indicated rate (milliseconds)
		-- @param offtime if provided with ontime, will blink at the indicated rate (milliseconds)
		-- @return the level as set.
		led_vibrator_power = function (level,ontime,offtime)
			if level then
				if ontime and offtime then
					run_shell('om led vibrator ' .. level .. 
						' timer ' .. ontime .. ' ' .. offtime)
				else
					run_shell('om led vibrator ' .. level)
				end
			end
			local ret = run_shell('om led vibrator')
			local reton, retontime, retofftime = ret:match('^(%d+)%D*(%d*)%D*(%d*)%c*$')
			return tonumber(reton), tonumber(retontime), tonumber(retofftime)
		end,
		
		--- Control the orange light of the power button.
		-- @param on true switches on, false off, nil keeps as is.
		-- @param ontime if provided with offtime, will blink at the indicated rate (milliseconds)
		-- @param offtime if provided with ontime, will blink at the indicated rate (milliseconds)
		-- @return the parameters as set.
		led_power_orange_power = function (on,ontime,offtime)
			local n
			if on then n=255 
			elseif n==false then n=0 end
			if n then
				if ontime and offtime then
					run_shell('om led power_orange ' .. n .. 
						' timer ' .. ontime .. ' ' .. offtime)
				else
					run_shell('om led power_orange ' .. n)
				end
			end
			local ret = run_shell('om led power_orange')
			local reton, retontime, retofftime = ret:match('^(%d+)%D*(%d*)%D*(%d*)%c*$')
			return tonumber(reton)>0, tonumber(retontime), tonumber(retofftime)
		end,
			
		--- Control the blue light of the power button.
		-- @param on true switches on, false off, nil keeps as is.
		-- @param ontime if provided with offtime, will blink at the indicated rate (milliseconds)
		-- @param offtime if provided with ontime, will blink at the indicated rate (milliseconds)
		-- @return the parameters as set.
		led_power_blue_power = function (on,ontime,offtime)
			local n
			if on then n=255 
			elseif n==false then n=0 end
			if n then
				if ontime and offtime then
					run_shell('om led power_blue ' .. n .. 
						' timer ' .. ontime .. ' ' .. offtime)
				else
					run_shell('om led power_blue ' .. n)
				end
			end
			local ret = run_shell('om led power_blue')
			local reton, retontime, retofftime = ret:match('^(%d+)%D*(%d*)%D*(%d*)$')
			return tonumber(reton)>0, tonumber(retontime), tonumber(retofftime)
		end,
		
		--- Control the red light of the aux button.
		-- @param on true switches on, false off, nil keeps as is.
		-- @param ontime if provided with offtime, will blink at the indicated rate (milliseconds)
		-- @param offtime if provided with ontime, will blink at the indicated rate (milliseconds)
		-- @return the parameters as set.
		led_aux_red_power = function (on,ontime,offtime)
			local n
			if on then n=255 
			elseif n==false then n=0 end
			if n then
				if ontime and offtime then
					run_shell('om led aux_red ' .. n .. 
						' timer ' .. ontime .. ' ' .. offtime)
				else
					run_shell('om led aux_red ' .. n)
				end
			end
			local ret = run_shell('om led aux_red')
			local reton, retontime, retofftime = ret:match('^(%d+)%D*(%d*)%D*(%d*)%c*%c*%c*%c*%c*$')
			return tonumber(reton)>0, tonumber(retontime), tonumber(retofftime)
		end,
	}
	
	
	for k, v in pairs (conf) do
		if device[k] then 
			if type(v)=='table' then
				--print('om from configuration', k, unpack(v))
				device[k](unpack(v))
			else
				--print('om from configuration', k, v)
				device[k](v)
			end

		end
	end
	
	log('OMOKO', 'INFO', 'Device %s created: %s', device.module, device.name)
	toribio.add_device(device)

end

return M

--- Configuration Table.
-- This table is populated by toribio from the configuration file. Can also be used to automatically
-- setup the openmoko calling the method with provided parameters. For example, to automatically 
-- start with a blinkig led, the following entrie could be added to the configuration file:
-- _deviceloaders.openmoko.led_aux_red_power = {true, 500, 500}_.
-- @table conf
-- @field load whether toribio should start this module automatically at startup.

