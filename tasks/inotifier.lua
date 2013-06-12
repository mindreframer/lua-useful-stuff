local M = {}

local sched=require 'sched'
local selector = require "tasks/selector"
local nixio = require 'nixio'

--executes s on the console and returns the output
local run_shell = function (s)
	local f = io.popen(s) -- runs command
	local l = f:read("*a") -- read output of command
	f:close()
	return l
end

M.init = function(masks_to_watch)
	M.events = {
		file_add = {},
		file_del = {},
	}
	M.task = sched.run(function()
		require 'catalog'.get_catalog('tasks'):register(masks_to_watch, sched.running_task)

		if #run_shell('which inotifywait')==0 then
			error('inotifywait not available')
		end
		local paths_to_watch = {}
		for _, mask in ipairs(masks_to_watch) do
			--print('DDDDDDDDDDDDD+', mask)
			--string.match(mask, '^(.*%/)[^%/]*$')
			local dir = nixio.fs.dirname(mask) 
			paths_to_watch[dir..'/']=true 
			--print('DDDDDDDDDDDDD-', dir)
		end
		
		local command = 'inotifywait -q -c -m -e create,delete'
		for path, _ in pairs(paths_to_watch) do
			command = command..' '..path
		end
		--print('+++++++++INOTIFY:', command)
		local watcherfd=selector.grab_stdout (command, 'line', nil)

		local waitd_inotify={emitter=selector.task, events={watcherfd.events.data}, buff_len=100}
		
		--generate events for already existing files
		for _, devmask in ipairs(masks_to_watch) do
			for devfile in nixio.fs.glob(devmask) do
				print('existing file', devfile)
				sched.signal('FILE+', devfile, devmask)
			end
		end

		--monitor files
		while true do
			local _, _,line=sched.wait(waitd_inotify)
			if line then 
				local path, action, file = string.match(line, '^([^,]+),(.+),([^,]+)$')
				local fullpath=path..file
				--print('INOTIFY', action, fullpath)
				if action=='CREATE' then
					for _, mask in ipairs(masks_to_watch) do
						for devfile in nixio.fs.glob(mask) do
							if devfile==fullpath then
								print('FILE+', fullpath, mask)
								sched.signal(M.events.file_add, fullpath, mask)
							end
							--print('confline starting', devfile, modulename)
							--local devmodule = require ('../drivers/filedev/'..modulename)
							--devmodule.init(devfile)
						end
					end
				elseif action=='DELETE' then
					print('FILE-', fullpath)
					sched.signal(M.events.file_del, fullpath)
				end
			end
		end
	end)
end

return M