--- Auto-start for modules.
-- This module monitors the presence of device files, and can start/stop associated modules (usually deviceloaders).
-- It depends on the inotify-tools being installed.
-- @module filedev
-- @alias device

local M = {}

local sched=require 'sched'
local toribio = require 'toribio'
local log = require 'log'

--- Initialize and starts the module.
-- This is called automatically by toribio if the _load_ attribute for the module in the configuration file is set to
-- true.
-- @param conf the configuration table (see @{conf}).
M.init = function( conf )
	local masks_to_watch = {}
	local deviceloadersconf = toribio.configuration.deviceloaders

	for modulename, devmask in pairs(conf.module or {}) do
		log('FILEDEV','INFO', 'watching path %s for module %s', tostring(devmask), tostring(modulename))
		masks_to_watch[devmask] = modulename
		masks_to_watch[#masks_to_watch+1] = devmask
	end

	sched.run(function()
		local inotifier_task = require 'catalog'.get_catalog('tasks'):waitfor(masks_to_watch)
		local waitd_fileevent = {emitter=inotifier_task, events={'*'}, buff_len=100}
		while true do
			local _, action, devfile, onmask = sched.wait(waitd_fileevent)
			if action==inotifier_task.events.file_add then
				local modulename = masks_to_watch[onmask]
				log('FILEDEV','INFO', 'starting module %s on %s', tostring(modulename), tostring(devfile))
				print('filedev module starting', devfile, modulename)
				deviceloadersconf[modulename] = deviceloadersconf[modulename] or {}
				deviceloadersconf[modulename].filename = devfile
				toribio.start('deviceloaders', modulename)
			elseif action==inotifier_task.events.file_del then
				toribio.remove_devices({filename=devfile})
			end
		end
	end)
	
	local inotifier = require 'tasks/inotifier'
	inotifier.init(masks_to_watch)
end

return M

--- Configuration Table.
-- This table is populated by toribio from the configuration file.  
-- @table conf
-- @field load whether toribio should start this module automatically at startup.
-- @field module a list of modulename - file pattern pairs. When a file matching a pattern appears, 
-- the correspondign module(s) will be sarted. The file will be provided to the module in the modules
-- configuration table, in the _filename_ field.  
-- For example, to start the mice module when a mouse device file is present, the following line can be added:  
-- _deviceloaders.filedev.module.mice = '/dev/input/mice'_  
-- To activate the dynamixel module when a usb-serial adapter is attached, the following line can be used:  
-- _deviceloaders.filedev.module.dynamixel = '/dev/ttyUSB*'_  
-- When the dynamixel module is started, the correct file (e.g. /dev/ttyUSB0) will be set in the filename attribute.
-- When a file disappears, all devices associated will be removed from toribio.