local M = {}

local sched = require 'sched'
local log = require 'log'
local mutex = require 'mutex'
local selector = require 'tasks/selector'

local mx = mutex.new()


--local my_path = debug.getinfo(1, "S").source:match[[^@?(.*[\/])[^\/]-$]]

local NULL_CHAR = string.char(0x00)
local PACKET_START = string.char(0xFF,0xFF)

M.new_bus = function (conf)
	local filename = conf.filename or '/dev/ttyUSB0'
	log('AX', 'INFO', 'usb device file: %s', tostring(filename))

	local filehandler, erropen = selector.new_fd(filename, {'rdwr', 'nonblock'}, -1)
	
	local opencount=60
	while not filehandler and opencount>0 do
		print('retrying open...', opencount)
		sched.sleep(1)
		filehandler, erropen = selector.new_fd(filename, {'rdwr', 'nonblock'}, -1)
		opencount=opencount-1
	end
	if not filehandler then
		log('AX', 'ERROR', 'usb %s failed to open with %s', tostring(filename), tostring(erropen))
		return
	end
	log('AX', 'INFO', 'usb %s opened', tostring(filename))

	local tty_flags = conf.stty_flags or '-parenb -parodd cs8 hupcl -cstopb cread -clocal -crtscts -ignbrk -brkint '
	..'-ignpar -parmrk -inpck -istrip -inlcr -igncr -icrnl -ixon -ixoff -iuclc -ixany -imaxbel '
	..'-opost -olcuc -ocrnl -onlcr -onocr -onlret -ofill -ofdel nl0 cr0 tab0 bs0 vt0 ff0 -isig -icanon '
	..'-iexten -echo -echoe -echok -echonl -noflsh -xcase -tostop -echoprt -echoctl -echoke'
	local speed = conf.serialspeed or 1000000
	local init_tty_string ='stty -F ' .. filename .. ' ' .. speed .. ' ' .. tty_flags

	os.execute(init_tty_string)
	filehandler.fd:sync() --flush()
	
	local taskf_protocol = function()
		local waitd_traffic = sched.new_waitd({
			emitter=selector.task,
			events={filehandler.events.data},
			buff_len=-1
		})
		local packet=''
		local insync=false
		local packlen=nil -- -1

		local function parseAx12Packet(s)
			local function generate_checksum(data)
				local checksum = 0
				for i=1, #data do
					checksum = checksum + data:byte(i)
				end
				return 255 - (checksum%256)
			end
			--print('parseAx12Packet parsing', s:byte(1, #s))
			local id = s:sub(3,3)
			--local data_length = s:byte(4)
			local data = s:sub(5, -1)
			if generate_checksum(s:sub(3,-1))~=0 then return nil,'READ_CHECKSUM_ERROR' end
			local errinpacket= data:byte(1,1)
			local payload = data:sub(2,-2)
			--print('parseAx12Packet parsed', id:byte(1, #id),'$', errinpacket,':', payload:byte(1, #payload))
			return id, errinpacket, payload
		end

		while true do
			local _, _, fragment, err_read = sched.wait(waitd_traffic)
			
			if not fragment then
				--if err_read=='closed' then
				--	print('dynamixel file closed:', filename)
				--	return
				--end
				log('AX', 'ERROR', 'Read from dynamixel device file failed with %s', tostring(err_read))
				return
			end
			if fragment==NULL_CHAR  then
				error('No power on serial?')
			end

			packet=packet..fragment

			---[[
			while (not insync) and (#packet>2) and (packet:sub(1,2) ~= PACKET_START) do
				log('AX', 'DEBUG', 'resync on "%s"', packet:byte(1,10))
				packet=packet:sub(2, -1) --=packet:sub(packet:find(PACKET_START) or -1, -1)

			end
			--]]
			
			if not insync and #packet>=4 then
				insync = true
				packlen = packet:byte(4)
			end
			
			--print('++++++++++++++++', #packet, packlen)
			while packlen and #packet>=packlen+4 do --#packet >3 and packlen <= #packet - 3 do
				if #packet == packlen+4 then  --fast lane
					local id, errcode, payload=parseAx12Packet(packet)
					if id then
						--print('dynamixel message parsed (fast):',id:byte(), errcode,':', payload:byte(1,#payload))
						sched.signal(id, errcode, payload)
					end
					packet = ''
					packlen = nil
				else --slow lane
					local packet_pre = packet:sub( 1, packlen+4 )
					local id, errcode, payload=parseAx12Packet(packet_pre)
					--assert(handler, 'failed parsing (slow)'..packet:byte(1,#packet))
					if id then
						--print('dynamixel message parsed (slow):',id:byte(), errcode,':', payload:byte(1,#payload))
						sched.signal(id, errcode, payload)
					end

					local packet_remainder = packet:sub(packlen+5, -1 )
					packet = packet_remainder
					packlen =  packet:byte(4)
				end
				insync = false
			end
		end
	end
	local task_protocol = sched.run(taskf_protocol)
	local waitd_protocol = sched.new_waitd({
		emitter=task_protocol,
		events='*',
		timeout = conf.serialtimeout or 0.05,
		buff_len=1
	})
	
	local bus = {}
	
	bus.sendAX12packet = mx:synchronize(function (s, id, get_response)
		filehandler:send_sync(s)
		if get_response then
			local emitter, ev, err, data = sched.wait(waitd_protocol)
			if emitter then
				if id==ev then return err, data end
				log('AX', 'WARN', 'out of order messages in bus, increase serialtimeout')
			end
		end
	end)
	
	return bus
end

return M
