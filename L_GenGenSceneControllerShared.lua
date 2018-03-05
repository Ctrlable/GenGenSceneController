-- GenGeneric Scene Controller shared code Version 1.23d
-- Supports Evolve LCD1, Cooper RFWC5 and Nexia One Touch Controllers
--
-- Copyright (C) 2017, 2018  Gustavo A Fernandez
-- Thanks to Ron Luna and Ctrlable for contributing for RFWC5 support
--
-- This program is free software; you can redistribute it and/or
-- modify it under the terms of the GNU General Public License
-- as published by the Free Software Foundation; either version 2
-- of the License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You can access the terms of this license at
-- https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html
--
bit = require "bit"
nixio = require "nixio"
nixFs = require "nixio.fs"

--
-- Debugging functions
--

ANSI_BLACK          = "\027[30m"
ANSI_RED            = "\027[31m"
ANSI_GREEN          = "\027[32m"
ANSI_YELLOW         = "\027[33m"
ANSI_BLUE           = "\027[34m"
ANSI_MAGENTA        = "\027[35m"
ANSI_CYAN           = "\027[36m"
ANSI_WHITE          = "\027[37m"
ANSI_BRIGHT_BLACK   = "\027[1;30m"
ANSI_BRIGHT_RED     = "\027[1;31m"
ANSI_BRIGHT_GREEN   = "\027[1;32m"
ANSI_BRIGHT_YELLOW  = "\027[1;33m"
ANSI_BRIGHT_BLUE    = "\027[1;34m"
ANSI_BRIGHT_MAGENTA = "\027[1;35m"
ANSI_BRIGHT_CYAN    = "\027[1;36m"
ANSI_BRIGHT_WHITE   = "\027[1;37m"
ANSI_RESET   = "\027[0m"

local function stackDepthIndent()
	local str = ""
	local level = 4
	while debug.getinfo (level, "n") do
		str = str .. "  "
		level = level + 1
	end
	return str
end

local function getFunctionInfo(level,name)
    local info = debug.getinfo(level, "n")
	if not name then
		if info and info.name then
			name = info.name
		else
			info = debug.getinfo(level)
			if info then
			    name = "unknown [line " .. tostring(info.currentline-1).."]"
				local s2 = string.gsub(info.source,"[^\n]*\n", "", info.currentline-2)
				if s2 then
					local s3 = string.match(s2, "[^\n]*")
					if s3 then
						local s4 = string.match(s3, "function%s*([%w_]+)")
						if s4 then
							name = s4
						else
							name = s3
						end
					end
				end
			else
				name = "unknown"
			end
		end
	end
	local str = name.."("
	local ix = 1
	while true do
		local name, value = debug.getlocal(level, ix)
		if not name then
			break
		end
		if ix > 1 then
			str = str .. ", "
		end
		local v = "..."
		if name ~= "SCObj" then	-- Hack. SCObj is big and useless in DEntry/VEntry
			v = tableToString(value)
		end
		str = str .. tostring(name) .. "=" .. v
		ix = ix + 1
	end
	str = str .. ")"
	return str
end 

local function logList(...)
  local s = ""
  for i = 1, select ("#", ...) do
  	local x = select(i, ...)
    if type(x) == "string" then
	  s = s .. x
	else
	  s = s .. tableToString(x)
	end
  end 
  return s
end

function luup_device_message(device, error, message, timeout, source)
	VEntry()
	if luup.device_message then
		luup.device_message(device, error, message, timeout, source)
	end
end

function ELog(...)
  if VerboseLogging > 0 then
  	luup.log(ANSI_BRIGHT_RED .. GetDeviceName() .."   Error: " .. ANSI_RESET .. stackDepthIndent() .. logList(...) .. debug.traceback(ANSI_CYAN, 2) .. ANSI_RESET)
  else
  	luup.log(ANSI_BRIGHT_RED .. GetDeviceName() .."   Error: " .. ANSI_RESET .. stackDepthIndent() .. logList(...))
  end
  luup_device_message(luup.device, 
				      2, -- job_Error
				      logList(...), -- message
				      0, -- No timeout
				      GetDeviceName()) -- source    
end

function log(...)
  luup.log(GetDeviceName() ..": " .. stackDepthIndent() .. logList(...))
end

function ILog(...)
  if VerboseLogging >= 1 then
    luup.log(ANSI_BRIGHT_YELLOW .. GetDeviceName() .. "    info: " .. stackDepthIndent() .. logList(...) .. ANSI_RESET)
  end
end

function DLog(...)
  if VerboseLogging >= 2 then
    luup.log(GetDeviceName() .. "   debug: " .. stackDepthIndent() .. logList(...))
  end
end

function DEntry(name)
  if VerboseLogging >= 2 then
    luup.log(GetDeviceName() .. "   debug: " .. stackDepthIndent() .. getFunctionInfo(3,name))
  end
end

-- VerboseLogging == 3 shows extended Z-Wave queue but not VLog/VEntry

function VLog(...)
  if VerboseLogging >= 4 then
    luup.log(GetDeviceName() .. " verbose: " .. stackDepthIndent() .. logList(...))
  end
end

function VEntry(name)
  if VerboseLogging >= 4 then
    luup.log(GetDeviceName() .. " verbose: " .. stackDepthIndent() .. getFunctionInfo(3,name))
  end
end

function printTable(tab,prefix,hash)
	local k,v,s,i, top, pref, p, q, r
	if prefix == nil then
		prefix = ""
	end
	if hash == nil then
	    top = true
		hash = {}
	else
	    top = false
	end
	if hash[tab] ~= nil then
		log(prefix .. "recursive " .. hash[tab])
		return
	end
	if type(tab) == "string" then
	  	log(prefix .. " (" .. type(tab) .. ") = " .. string.format("%q", tab))
	elseif type(tab) ~= "table" then
	  	log(prefix .. " (" .. type(tab) .. ") = " .. tostring(tab))
	else
		hash[tab] = prefix
		r = {}
		if top then
			log(prefix .. "{")
			pref = prefix
			prefix = prefix .. "  "
		end
		for k,v in pairs(tab) do
			table.insert(r,{k=k, v=v})
		end
		table.sort(r,function(x,y) return tostring(x.k):lower() < tostring(y.k):lower(); end)
		for p,q in ipairs(r) do
		 	k = q.k;
		 	v = q.v;
		 	if type(k) == "table" then
		    	log(prefix .. "key-{")
		     	printTable(k,prefix .. "       ", hash);
				s = "    }: "
			else
		    	s = tostring(k) .. ": "
			end
			if type(v) == "table" then
				log(prefix .. s .. "{")
				printTable(v,prefix .. string.rep(" ",#s) .. "  ", hash)
				log(prefix .. string.rep(" ",#s) .. "}")
			elseif type(v) == "string" then
		   		log(prefix .. s .. "(" .. type(v) .. ") " .. string.format("%q",v))
			else
		   		log(prefix .. s .. "(" .. type(v) .. ") " .. tostring(v))
			end
		end
		if top then
			log(pref .. "}")
		end
		hash[tab] = nil;
	end
end

function tableToString(tab, hash)
	if type(tab) == "string" then
		return string.format("%q",tab)
	elseif type(tab) ~= "table" then
		return tostring(tab)
	end
	if hash == nil then
		hash = {}
	elseif hash[tab] then
		return "recursive"
	end
	hash[tab] = true
	local k,v,s
	s = "{"
  	for k,v in pairs(tab) do
		if s ~= "{" then
	    	s = s .. ", "
	  	end
      	if type(k) == "table" then
	    	s = s .. tableToString(k, hash)
	  	elseif type(k) == "number" then
			s = s .. "[" .. k .. "]"
	  	else
	    	s = s .. tostring(k)
	  	end
	  	s = s .. "="
	  	if type(v) == "string" then
			s = s .. string.format("%q",v)
      	elseif type(v) == "table" then
	    	s = s .. tableToString(v, hash)
	  	else
	    	s = s .. tostring(v)
	  	end
	end
	s = s .. "}"
	hash[tab] = nil
	return s
end

--
-- Global lock
--
local global_lock_name = "/tmp/gengen_lock"
-- creat and excl flags are crucial here. open will fail if the file already exists.
local global_lock_flags = nixio.open_flags("creat", "excl")
function take_global_lock()
	local lockFile = nixio.open(global_lock_name, global_lock_flags, 666)
	if lockFile then
		lockFile:close()
		ILog("Global lock taken")
		return true
	end
	ILog("Waiting for global lock")
	return false
end

function give_global_lock()
    nixFs.unlink(global_lock_name)	
	ILog("Global lock given")
end

--
-- Z-Wave Queue and job handling
--

zwint = require "zwint"

SID_ZWAVEMONITOR      = "urn:gengen_mcv-org:serviceId:ZWaveMonitor1"
SID_ZWN       	      = "urn:micasaverde-com:serviceId:ZWaveNetwork1"
SID_SCENECONTROLLER   = "urn:gengen_mcv-org:serviceId:SceneController1"

GENGENINSTALLER_SID   = "urn:gengen_mcv-org:serviceId:SceneControllerInstaller1"
GENGENINSTALLER_DEVTYPE = "urn:schemas-gengen_mcv-org:device:SceneControllerInstaller:1"

local ZWaveQueue = {}
local ActiveZWaveJob = nil
local DelayingJob = false
local ZWaveQueueNext = nil
local ZWaveQueueNodes = 0
local TaskHandleList = {}
local OtherJobPending = false
local ZWaveQueuePendingTime = 0
local MinOtherJobDelay = 400
local ZQ_MaxQueueDepth = 3 -- Actually only 2 pending. at least 1 slot always unused.

MonitorContextNum = 0
MonitorContextList = {}
local DeviceAwakeList = {}
local DeviceAwakeStates = {}
local DeviceAwakeNextState = 1
local NoMoreInformationContexts = {}

local function EnqueueActionOrMessage(SCObj, queueNode)
  VEntry()
  local peer_dev_num = GetPeerDevNum(luup.device)
  local description = ""
  if peer_dev_num then
	description = queueNode.description or luup.devices[peer_dev_num].description
	if not queueNode.responseDevice then
		queueNode.responseDevice = peer_dev_num
	end
	if queueNode.hasBattery == nil then
		queueNode.hasBattery = SCObj.HasBattery
	end
  end
  queueNode.description = description
  VLog("EnqueueActionOrMessage-External: ", queueNode)
  table.insert(ExternalZWaveQueue, queueNode)
end

-- Enqueue a local Z-Wave controller message.
function EnqueueZWaveControllerMessage(SCObj, name, node_id, data, dev_num, delay)
  VEntry()
  EnqueueActionOrMessage(SCObj, {
  	type=0,
  	name=name,
	description=luup.devices[dev_num].description,
	device=dev_num,
  	node_id=node_id,
  	data=data,
  	delay=delay})
end

-- Enqueue a Z-Wave message. No response is expected. Wait <delay> milliseconds
-- before sending a Z-Wave command to the same device
function EnqueueZWaveMessage(SCObj, name, node_id, data, dev_num, delay)
  VEntry()
  EnqueueActionOrMessage(SCObj, {
  	type=1,
  	name=name,
	description=luup.devices[dev_num].description,
	device=dev_num,
  	node_id=node_id,
  	data=data,
  	delay=delay})
end

-- Enqueue a Z-Wave message to a target device. 
-- No response is expected. Wait <delay> milliseconds
-- before sending a Z-Wave command to the same device
function EnqueueTargetZWaveMessage(SCObj, name, node_id, data, dev_num, delay)
  VEntry()
  EnqueueActionOrMessage(SCObj, {
  	type=1,
  	name=name,
	description=luup.devices[dev_num].description,
	device=dev_num,
  	node_id=node_id,
  	data=data,
  	delay=delay,
  	hasBattery=false})
end

-- Enqueue a Lua action within the Z-Wave queue
-- Name must be the name of the job as returned by the job watch callback. e.g. ZWJob_PollNode
-- Parameters 2-5 are the same as luup_action.
function EnqueueLuupAction(SCObj, name, node_id, service, action, arguments, device, delay)
  VEntry()
  EnqueueActionOrMessage(SCObj, {
  	type=2,
  	name=name,
  	device=device,
  	node_id=node_id,
  	service=service,
	description=service..": "..action,
  	action=action,
  	arguments=arguments,
	hasBattery=false,
  	delay=delay})
end

-- Enqueue a Z-Wave message, expecting a response.
-- name, node_id, data, delay - as in EnqueueZWaveMessage
-- controller: true if a message to the local controller, false if a message to a remote device
-- pattern is a Linux externed refular expression which will be matched against the hexified incoming Z-Wave data.
-- Callback is a function which is passed the peer device number and any captures from the regex. 
--    The capture array is nil if a timeout occurred.
--    If callback is nil, then this can be used to wait until the response is receviced, without regard to its value,
--    before sending any other commands to that specific device.
-- Oneshot is true if the monitor should be canceled as soon as it matches.
-- Timeout and delay are in milliseconds.
--   If timeeout is 0 or nil then the monitor will be active until canceled with CancelZWaveMonitor
-- If armPattern is not nil then the given pattern must be sent first to arm the monitor.
-- If autoResponse is not nil then the received data is not received by LuaUPnP and the given autoResponse is sent to the device instead.
-- Delay is applied after the response is received but ignored in case of a timeout.
-- Returns a context which can be passed to CancelZWaveMonitor if callback is not nil.
function EnqueueZWaveMessageWithResponse(SCObj, name, node_id, data, delay, controller, pattern, callback, oneshot, dev_num, timeout, armPattern, autoResponse)
 VEntry()
  local context
  if callback then
    MonitorContextNum = MonitorContextNum + 1
  	context = "R_" .. name .. "_" .. node_id .. "_" .. MonitorContextNum
  	MonitorContextList[context] = {incoming=true, callback=callback, oneshot=oneshot, releaseNodeId=node_id}
  end
  local messageType = 1
  if controller then
	messageType = 0
  end 
  EnqueueActionOrMessage(SCObj, {
  	type=messageType,
  	name=name,
	description=luup.devices[dev_num].description,
  	node_id=node_id,
	device=dev_num,
  	data=data,
  	delay=delay,
  	pattern=pattern,
  	context=context,
	oneshot=oneshot,
  	timeout=timeout,
  	armPattern=armPattern,
  	autoResponse=autoResponse})
  return context
end

local function EnqueueInternalActionOrMessage(queueNode)
	VEntry()
	local node_id = queueNode.node_id
	if not node_id then
		node_id = 0
	end
	if queueNode.type == 4 then
		InitWakeUpNotificationMonitor(queueNode.responseDevice, queueNode.node_id, true)
		return
	end
	if queueNode.pattern then
		-- Handle cases where callback was passed as nil.
		-- Also handles cases where a non-first-peer relays the response to
		-- the installert to release the waitingForResponse flag.
		if not queueNode.context then
	  		MonitorContextNum = MonitorContextNum + 1
		  		queueNode.context = "W" .. queueNode.node_id .. "_" .. MonitorContextNum
		end
		if not MonitorContextList[queueNode.context] then
	  		MonitorContextList[queueNode.context] = {incoming=true, oneshot=queueNode.oneshot, releaseNodeId=queueNode.node_id}
		end 
	end
	local newDev = ZWaveQueue[node_id]
	if not newDev then
	  if queueNode.type == 1 then
		luup_device_message(queueNode.device, 
					        0, -- job_WaitingToStart
					        "Waiting to configure", -- message
					        5, -- Timeout
					        GetDeviceName()) -- source    
	  end
	  newDev = {node_id=node_id}
	  ZWaveQueue[node_id] = newDev
	  ZWaveQueueNodes = ZWaveQueueNodes + 1
	  if not ZWaveQueueNext then
		newDev.next = newDev
		newDev.prev = newDev
		ZWaveQueueNext = newDev
	  else
		newDev.next = ZWaveQueueNext
		newDev.prev = ZWaveQueueNext.prev
		ZWaveQueueNext.prev.next = newDev
		ZWaveQueueNext.prev = newDev
	  end
	end
	if #newDev > 0 and newDev[#newDev].final then
		if not queueNode.final then -- Ignore final over final
			table.insert(newDev, #newDev, queueNode) -- Insert non-final before existing final
		end
	else
	    -- Here we apply the "*" hack which indicates that a command can replace another command further ahead in the queue.
		-- This is useful when an "all on" or "all off"-type scene can change the indicator several times.
		if string.sub(queueNode.name,1,1) == "*" then
			queueNode.matchString = string.match(queueNode.name, "[^(]+", 2) -- Skip the initial *. Ignore anything after (
			if queueNode.matchString then
				for i, v in ipairs(newDev) do
					if ZWaveQueueNext ~= v and v.matchString == queueNode.matchString and v.node_id == queueNode.node_id then
						newDev[i] = queueNode
						return
					end
				end
			end
		end
		table.insert(newDev, queueNode) -- Normal case. Insert at end.
		if queueNode.hasBattery then
			InitWakeUpNotificationMonitor(queueNode.responseDevice, queueNode.node_id, false)
			if #newDev == 1 and DeviceAwakeList[queueNode.node_id] ~= 1 then
				log(ANSI_YELLOW, queueNode.description, " is now on battery wait", ANSI_RESET)
				local handle = TaskHandleList[queueNode.responseDevice]
				if not handle then
					handle = -1
				end
				TaskHandleList[queueNode.responseDevice] = luup.task("Waiting for device to wake up", 1, queueNode.description, handle)
				if queueNode.type == 1 then
					luup_device_message(queueNode.device, 
								        5, -- job_WaitingForCallback
								        "Waiting for device to wake up", -- message
								        0, -- No timeout
								        GetDeviceName()) -- source    
				end
			end
		end
	end
end

-- Enqueues a special message called as part of the "configured" trigger.
-- which initializes the wake-up monitor in "already awake" state if it
-- has not already been initialized
function EnqueueInitWakeupMonitorMessage(name, node_id, peer_dev_num)
 VEntry("EnqueueInitWakeupMonitorMessage")
  local queueNode = {
  	type=4,
  	name=name,
  	node_id=node_id,
	responseDevice = peer_dev_num,
	description = luup.devices[peer_dev_num].description,
	hasBattery = true}
  table.insert(ExternalZWaveQueue, queueNode)
end

-- Enqueue the last Z-Wave message in a group. 
-- This is used for the "no more information" message for battery devices. 
-- It may be deleted if other items are queued behind it.
local function EnqueueFinalZWaveMessage(name, node_id, data, peer_dev_num)
 VEntry("EnqueueFinalZWaveMessage")
  local queueNode = {
  	type=1,
  	name=name,
  	node_id=node_id,
  	data=data,
  	delay=0,
	responseDevice = peer_dev_num,
	description = luup.devices[peer_dev_num].description,
	hasBattery = true,
  	final=true}
  EnqueueInternalActionOrMessage(queueNode)
end


-- Monitors a Z-Wave message sent by the controller or intercpets a message sent by LuaUPnP
--   and optionally removes the message and sends an expected autoResponse back to to the sender
-- Outgoing is false for monitoring incoming data or true for intercepting outgoing data.
-- Arm_regex is an optional Linux extended regular expression which will be matched
--   against the hexified data in the opposite direction. A match will arm the monitor/intercept.
--   If arm_pattern is nil then the monitor/intercept is always armed.
-- Main_regex is a Linux extended regular expression which will be matched
--   against the hexified outgoing Z-Wave data from LuaUPnP (intercept) or incoming data
--   from the controller (monitor). A match will trigger the monitor/incercept if it is armed.
-- Response (if not nil) is a hex string which will be returned to the sender (after converting into
--   binary) when monitor/intercept is triggered. The data that caused the trigger is not passed through.
--   If autoResponse is nil then the data is passed through.
--   The autoResponse string can also include \1 ... \9 captures from the intercept regex (but not the
--   arm regex) and can also include XX to calculate the Z-Wave checksum.
-- Callback is a function which is passed the peer device number and any captures from
--   the main regex. The capture array is nil if a timeout occurred.
--   Callback can also be a string as a function name in which case the callback will be executed
--     by the installer device which actually dispatches most Z-Wave commands
--   Callback can be nil if not needed.
-- Oneshot is true if the intercept should be canceled as soon as it matches.
--   If OneShot is false and arm_regex is not nil, then the intercept is disarmed when it triggers.
-- Timeout and delay are in milliseconds.
--   If timeout is 0 then the monitor will be active until canceled with CancelZWaveMonitor
-- Label - A label used in creating the unique key for this monitor. Should be descriptive and helps with debugging.
-- Forward is true if the response should be forwarded to the opposite party rather than returned back to the sender.
--   Only used if AutoResponse is non-nil 
-- Returns a context which can be passed to CancelZWaveMonitor or nil if error.
function MonitorZWaveData(outgoing, peer_dev_num, arm_regex, intercept_regex, autoResponse, callback, owneshot, timeout, label, forward)
	VEntry()
	if not zwint or not zwint.monitor then
		DLog("MonitorZWaveData returning nil because zwint is not yet installer")
		return nil
	end
  	local context
	MonitorContextNum = MonitorContextNum + 1
	local prefix = "M_"
	if outgoing then
  		prefix = "I_"
	end
	if not forward then
		forward = false
	end
	context = prefix .. label .. "_" .. peer_dev_num.."_"..MonitorContextNum
	if not callback then
		context = "*" .. context
	end
	MonitorContextList[context] = {outgoing=outgoing, callback=callback, oneshot=oneshot}
  	local result, errcode, errmessage
  	if outgoing then
    	result, errcode, errmessage = zwint.intercept(peer_dev_num, context, intercept_regex, owneshot, timeout, arm_regex, autoResponse, forward)
  	else
    	result, errcode, errmessage = zwint.monitor(peer_dev_num, context, intercept_regex, owneshot, timeout, arm_regex, autoResponse, forward)
  	end
  	if not result then
		ELog("MonitorZWaveData: zwint failed. error code=", errcode, " error message=", errmessage)
		MonitorContextList[context] = nil;
		return nil;
  	end
  	return context;
end

-- Remove the current job from the Z-Wave queue.
-- Return true if there are more jobs in the queue
local function RemoveHeadFromZWaveQueue(job)
	VEntry()
	local queue = ZWaveQueueNext
	if job then
	   queue = ZWaveQueue[job.node_id]
		if not queue then
			ELog("Job not in queue:", ZWaveQueue)
			return false
		end
	end
	if not queue then
		return false
	end
	local removed = queue[1]
	table.remove(queue,1)
	if #queue == 0 then
		if removed and removed.type == 1 then
			luup_device_message(removed.device, 
						        4, -- job_Completed
						        "Done", -- message
						        1, -- Timeout
						        GetDeviceName()) -- source    
		end
		ZWaveQueue[queue.node_id] = nil
		ZWaveQueueNodes = ZWaveQueueNodes - 1
		if queue.next == queue then
			ZWaveQueueNext = nil
			return false
		else
			queue.next.prev = queue.prev
			queue.prev.next = queue.next
			if queue == ZWaveQueueNext then
				ZWaveQueueNext = queue.next
			end
		end
	end
	return true;
end

-- Remove the current job and and other jobs for that node (if it is non-zero)
-- from the queue. Return true if there are jobs remaining in the queue for
-- other nodes.
local function RemoveNodeFromZWaveQueue(job)
	if job.node_id == 0 then
		return RemoveHeadFromZWaveQueue(job)
	end
	local result = true
	local queue = ZWaveQueueNext
	if job then
	   queue = ZWaveQueue[job.node_id]
	end
	if not queue then
		return false
	end
	ZWaveQueue[queue.node_id] = nil
	ZWaveQueueNodes = ZWaveQueueNodes - 1
	if queue.next == queue then
		ZWaveQueueNext = nil
		result = false
	else
		queue.next.prev = queue.prev
		queue.prev.next = queue.next
		if queue == ZWaveQueueNext then
			ZWaveQueueNext = queue.next
		end
	end
	while #queue > 0 do
		local j2 = table.remove(queue, 1)
		if j2 ~= job and j2.responseDevice and j2.responseDevice > 0 and j2.timeout and j2.timeout > 0 then
			VLog("RemoveNodeFromZWaveQueue: sending fake timeout for job which was never started due to previously failed job:", j2)
			while not take_global_lock() do
				luup.sleep(100)	 -- Will this work and not cause LuaUPnP crashes? Using luup.call_delay here is difficult
			end
			luup.call_action(SID_ZWAVEMONITOR, "Timeout", {key=j2.context}, j2.responseDevice)
			give_global_lock()
		end
	end
	return result;
end

function SceneController_InitWakeupMonitor(device, settings)
	DEntry()
	InitWakeUpNotificationMonitor(settings.Peer_Dev_Num, settings.ZWave_Node)
end

function CheckUI5ZWaveQueueHeadStatus2(data)
  	local j = ActiveZWaveJob
	if not j then
		return
	end
	j.err_num, j.err_msg = luup.job.status(j.job_num, 1)
  	if not j.err_msg then
		j.err_msg = ""
  	end
  	if j.err_num == 0 then
    	j.err_msg = j.err_msg .. "Waiting to start"
  	end
  	if j.err_num ~= j.last_err_num or j.err_msg ~= j.last_err_msg then
  		j.last_err_num = j.err_num
  		j.last_err_msg = j.err_msg
		local lul_job = {}
		if j.type == 0 then
			lul_job.type = "ZWJob_GenericSendFrame"
			lul_job.name = "send_code"
		else
			lul_job.type = "ZWJob_SendData"
			lul_job.name = "childcmd node "..j.node_id
		end
		lul_job.status = j.err_num
		lul_job.notes = j.err_msg
		SceneController_JobWatchCallBack(lul_job)
		if j.err_num >= 2 and j.err_num  <= 4 then
			return
		end
	end
	CheckUI5ZWaveQueueHeadStatus("")
end

local function ChangeBatteryNoMoreInformationMonitor(peer_dev_num, zwave_node, enable)
	VEntry("ChangeBatteryNoMoreInformationMonitor")
	local BatteryNoMoreInformationCallback = function(installer, captures)
		local deviceAwakeCount = DeviceAwakeList[zwave_node]
		VEntry("BatteryNoMoreInformationCallback")
		if not deviceAwakeCount == nil or deviceAwakeCount == 0 then
			ELog("Received a No More Information message for device ", peer_dev_num, " Z-Wave node ", zwave_node, " without a corresponing wake-up event.")
			return 
		end
		deviceAwakeCount = deviceAwakeCount - 1;
		DeviceAwakeList[zwave_node] = deviceAwakeCount;
		if deviceAwakeCount == 1 then
			local list = ZWaveQueue[zwave_node]
			if list and list[1] then
				local device = luup.devices[peer_dev_num]
				log(ANSI_YELLOW, "Battery wait released for ", device.description, ANSI_RESET)
				local handle = TaskHandleList[peer_dev_num]
				if not handle then
					handle = -1
				end
				TaskHandleList[peer_dev_num] = luup.task("", 4, device.description, handle)
			end
		    EnqueueFinalZWaveMessage("BatteryNoMoreInformation", zwave_node, "0x84 0x8", peer_dev_num);
		else
			VLog("BatteryNoMoreInformationCallback: Battery wait not released because deviceAwakeCount=",deviceAwakeCount)
		end
	end

	if enable then
		if not NoMoreInformationContexts[peer_dev_num] then
			NoMoreInformationContexts[peer_dev_num] = MonitorZWaveData( 
				true, -- outgoing
				luup.device, -- peer_dev_num
				nil, -- armRegEx
--[==[
                                              C1  C2                                   C3
41      12/04/16 20:05:27.515   0x1 0xd 0x0 0x19 0x9 0x2 0x84 0x8 0x5 0x0 0x0 0x0 0x0 0x4 0x6d (#\r############m)
           SOF - Start Of Frame --+   �   �    �   �   �    �   �   � +-------------+   �    �
                    length = 13 ------+   �    �   �   �    �   �   �        �          �    �
                        Request ----------+    �   �   �    �   �   �        �          �    �
   FUNC_ID_ZW_SEND_DATA_GENERIC ---------------+   �   �    �   �   �        �          �    �
Device 12=Nexia One Touch Scene Controller Z-Wave -+   �    �   �   �        �          �    �
                Data length = 2 -----------------------+    �   �   �        �          �    �
          COMMAND_CLASS_WAKE_UP ----------------------------+   �   �        �          �    �
    WAKE_UP_NO_MORE_INFORMATION --------------------------------+   �        �          �    �
Xmit options = ACK | AUTO_ROUTE ------------------------------------+        �          �    �
           Routing data ignored ---------------------------------------------+          �    �
                   Callback = 4 --------------------------------------------------------+    �
                    Checksum OK -------------------------------------------------------------+
--]==]
				"^01 .. 00 (..) (" .. string.format("%02X", zwave_node) .. ") .. 84 08 .+ (..) ..$",
--[==[
42      12/04/16 20:05:27.538   0x6 0x1 0x4 0x1 0x19 0x1 0xe2 (#######)
              ACK - Acknowledge --+   �   �   �    �   �    �
           SOF - Start Of Frame ------+   �   �    �   �    �
                     length = 4 ----------+   �    �   �    �
                       Response --------------+    �   �    �
   FUNC_ID_ZW_SEND_DATA_GENERIC -------------------+   �    �
                     RetVal: OK -----------------------+    �
                    Checksum OK ----------------------------+
42      12/04/16 20:05:27.539   got expected ACK -- removed

        ACK: 0x6 (#)

42      12/04/16 20:05:27.778   0x1 0x5 0x0 0x19 0x4 0x0 0xe7 (#######)
           SOF - Start Of Frame --+   �   �    �   �   �    �
                     length = 5 ------+   �    �   �   �    �
                        Request ----------+    �   �   �    �
   FUNC_ID_ZW_SEND_DATA_GENERIC ---------------+   �   �    �
                   Callback = 4 -------------------+   �    �
           TRANSMIT_COMPLETE_OK -----------------------+    �
                    Checksum OK ----------------------------+
41      12/04/16 20:05:27.779   ACK: 0x6 (#) -- removed
--]==]
				"06 01 04 01 \\1 01 XX 01 05 00 \\1 \\3 00 XX",
				BatteryNoMoreInformationCallback, 
				false, -- oneShot
				0, -- no timeout
				"BatteryNoMoreInfo")
		end
		VLog("  Created no more information context: ", NoMoreInformationContexts[peer_dev_num]) 
	else
		local context = NoMoreInformationContexts[peer_dev_num]
		if context then 
			VLog(" Deleting no more information context: ", context) 
			zwint.cancel(luup.device, context)
			MonitorContextList[context] = nil
			NoMoreInformationContexts[peer_dev_num] = nil
		end -- if context
	end -- else not enable
end -- function ChangeBatteryNoMoreInformationMonitor

function InitWakeUpNotificationMonitor(peer_dev_num, zwave_node, alreadyAwake)
	VEntry()
	if DeviceAwakeList[zwave_node] ~= nil then
		return
	end
	DeviceAwakeList[zwave_node] = 0
	local WakeUpNotificationCallback = function(installer, captures)
		local deviceAwake = DeviceAwakeList[zwave_node]
		VEntry("WakeUpNotificationCallback")
		if deviceAwake > 0 then
			DeviceAwakeList[zwave_node] = deviceAwake + 1
		else
			DeviceAwakeList[zwave_node] = 2
		end
		if DeviceAwakeList[zwave_node] == 2 then
			ChangeBatteryNoMoreInformationMonitor(peer_dev_num, zwave_node, true)
		end
		DeviceAwakeStates[zwave_node] = DeviceAwakeNextState
		luup.call_delay("SceneController_NoMoreInformationTimeout", 10, peer_dev_num .. "_" .. zwave_node .. "_" .. DeviceAwakeNextState, true)
		DeviceAwakeNextState = DeviceAwakeNextState+1
	end 	
	MonitorZWaveData( 
				false, -- outgoing
				luup.device, -- peer_dev_num
				nil, -- arm_regex
--[==[
42      12/04/16 20:05:26.449   0x1 0x8 0x0 0x4 0x4 0x9 0x2 0x84 0x7 0x7f (##########)
           SOF - Start Of Frame --+   �   �   �   �   �   �    �   �    �
                     length = 8 ------+   �   �   �   �   �    �   �    �
                        Request ----------+   �   �   �   �    �   �    �
FUNC_ID_APPLICATION_COMMAND_HANDLER ----------+   �   �   �    �   �    �
           Receive Status BROAD ------------------+   �   �    �   �    �
Device 12=Nexia One Touch Scene Controller Z-Wave ----+   �    �   �    �
                Data length = 2 --------------------------+    �   �    �
          COMMAND_CLASS_WAKE_UP -------------------------------+   �    �
           WAKE_UP_NOTIFICATION -----------------------------------+    �
                    Checksum OK ----------------------------------------+
--]==]
				"^01 .. 00 04 .. " .. string.format("%02X", zwave_node) .. " .. 84 07",
				nil, -- autoResponse
				WakeUpNotificationCallback, 
				false, -- not oneShot
				0, -- no timeout
				"WakeUpNotification")
	if alreadyAwake then
		WakeUpNotificationCallback(nil, nil)
	end
end

-- Always run the Z-Wave queue in a delay task to avoid any deadlocks.
function RunInternalZWaveQueue(fromWhere, delay_ms)
	DEntry()
	local t1 = socket.gettime()
	local delayTime = t1 + delay_ms/1000
	if delayTime > ZWaveQueuePendingTime then
	   ZWaveQueuePendingTime = delayTime
	end
	if OtherJobPending then
		DLog("OtherJobPending. Quitting")
		return
	end
	if ActiveZWaveJob then
		DLog("ActiveZWaveJob. Quitting")
		return
	end
	if DelayingJob then
		DLog("DelayingJob. Quitting")
		return
	end
	if not ZWaveQueueNext then
		DLog("Not ZWaveQueueNext. Quitting")
		return
	end
	DelayingJob = true;
	delay_ms = (ZWaveQueuePendingTime - t1) * 1000
	local delay_sec
	if delay_ms <= 0 then
		delay_sec = 0
	else		 
		delay_sec = math.floor(delay_ms / 1000)
		local sleep_ms = math.floor(delay_ms - delay_sec*1000)
		if sleep_ms > 0 then
			VLog("RunInternalZWaveQueue: luup.sleep for ",delay_sec," seconds and ", sleep_ms," ms"); 
			luup.sleep(sleem_ms)
			local t2 = socket.gettime()
			if (t2 - t1) * 1000 < sleep_ms then
				delay_sec = delay_sec + 1
				VLog("luup.sleep too short. Delaying by an extra second: ", delay_sec)
			else
				VLog("luup.sleep done")
			end
		end
	end
	luup.call_delay("SceneController_RunInternalZWaveQueue", delay_sec, fromWhere, true)
end

function SceneController_RunInternalZWaveQueue(fromWhere)
	VEntry("SceneController_RunInternalZWaveQueue")
	DelayingJob = false

	if OtherJobPending then
		VLog("SceneController_RunInternalZWaveQueue(", fromWhere, ") An outside job is still active")
	  	return
	end
  	
  	if not ZWaveQueueNext then
		VLog("SceneController_RunInternalZWaveQueue(", fromWhere, ") queue is empty")
	  	return
  	end

  	if ActiveZWaveJob then
	VLog("SceneController_RunInternalZWaveQueue(", fromWhere, ") Job still active: job=", ActiveZWaveJob)
	  	return
  	end

   	local now =	socket.gettime()
	local delay = math.floor((ZWaveQueuePendingTime - now) * 1000)
	if delay > 0 then
	VLog("SceneController_RunInternalZWaveQueue(", fromWhere, ") called too soon. Delaying ", delay, "ms")
		RunInternalZWaveQueue("ZWaveQueuePendingDelay", delay)
		return
	end

  	-- If the head of the queue is in a time delay or otherwise blocked.
  	-- look around the queue array for another queue who's first job we can perform now 
  	-- or else has the shortest delay.
    local nextTime = nil
    local nextQueue = nil
	local biggestDelay = -1
	local longestQueue = 0
	local bestCandidate = nil
    local candidate = ZWaveQueueNext
	repeat
		if candidate[1].waitingForResponse then
			if candidate[1].type == 0 then
				VLog("SceneController_RunInternalZWaveQueue(", fromWhere, ") Stopping seach because waitingForResponse from local controller:", candidate[1])
				bestCandidate = nil
				nextQueue = nil
				break;
			else
				VLog("SceneController_RunInternalZWaveQueue(", fromWhere, ") Skipping candidate due to waitingForResponse:", candidate[1])
			end
		elseif candidate[1].hasBattery and DeviceAwakeList[candidate[1].node_id] ~= 1 then
			VLog("SceneController_RunInternalZWaveQueue(", fromWhere, ") Skipping candidate due to batteryWait:", candidate[1])
  		else
  			if candidate[1].waitUntil then
  				if candidate[1].waitUntil > now then
					VLog("SceneController_RunInternalZWaveQueue(", fromWhere, ") time wait queue entry still waiting for ", (candidate[1].waitUntil - now), " seconds from now: ", candidate[1])
  					if not nextTime or nextTime > candidate[1].waitUntil then
  		    			nextTime = candidate[1].waitUntil
  		    			nextQueue = candidate
						if candidate.type == 0 then -- We cannot start jobs for other nodes until any local job has had time to complete.
							bestCandidate = nil
							break;
						end
  		  			end
  		  		else
					VLog("SceneController_RunInternalZWaveQueue(", fromWhere, ") Removing time wait queue entry which already passed ", (now - candidate[1].waitUntil), " seconds ago: ", candidate[1])
					ZWaveQueueNext = candidate
	  		  		if RemoveHeadFromZWaveQueue() then
	  		  			RunInternalZWaveQueue(fromWhere.." after timeout", 0)
	  		  		end
  		  			return
  		  		end
			elseif candidate.type == 0 then -- local Z-Wave controller commands always have priority
				VLog("SceneController_RunInternalZWaveQueue(", fromWhere, ") Found a local job and stopping search.", candidate[1])
				bestCandidate = candidate
				break
			elseif candidate[1].delay > biggestDelay then -- If several devices are in the queue, give priority to the one with the biggest delay to get it started first.
				if biggestDelay > -1 then
					VLog("SceneController_RunInternalZWaveQueue(", fromWhere, ") Found a bigger delay job. ", candidate[1].delay, " > ", biggestDelay, ": ",  candidate[1])
			   	else
					VLog("SceneController_RunInternalZWaveQueue(", fromWhere, ") Found viable job with delay= ", candidate[1].delay, " ms.: ",  candidate[1])
				end
			   	bestCandidate = candidate
				biggestDelay = candidate[1].delay
				longestQueue = #candidate
			elseif candidate[1].delay == biggestDelay and #candidate > longestQueue then -- If delays are the same (typically 0) then choose the device with the most jobs to do.
				VLog("SceneController_RunInternalZWaveQueue(", fromWhere, ") Found a bigger queue length job. ",  #candidate, " > ", longestQueue, ": ",  candidate[1])
				bestCandidate = candidate
				longestQueue = #candidate
  			end
		end
		candidate = candidate.next
	until candidate == ZWaveQueueNext

	if bestCandidate then
		if not take_global_lock() then
			RunInternalZWaveQueue(fromWhere .. " spinlock", 1000)
            return
		end

		VLog("SceneController_RunInternalZWaveQueue(", fromWhere, ") running next job: ",  candidate[1])
	    ZWaveQueueNext = bestCandidate
	    -- At this pont, we know we have something to do.
	    -- Dump the queue to the log in various ways.
	  	if VerboseLogging >= 3 then
	      local curDev = ZWaveQueueNext
		  local count = 1;
		  repeat
			DLog  ("SceneController_RunInternalZWaveQueue(", fromWhere, ")   Node_id: ", curDev.node_id, "  Next: ", curDev.next.node_id, "  Prev: ", curDev.prev.node_id)
		    for i = 1, #curDev do
				DLog("SceneController_RunInternalZWaveQueue(", fromWhere, ")     Entry ", count, ": ", curDev[i])
			  	count = count + 1;
		    end
		    curDev = curDev.next
		  until curDev == ZWaveQueueNext
		elseif VerboseLogging >= 2 then
	  	  local count = 0
	  	  local curDev = ZWaveQueueNext
		  local nodelist = ""
		  repeat
		  	nodelist = nodelist .. curDev.node_id .. "("..#curDev..") "
			curDev = curDev.next;
			count = count + 1
		  until curDev == ZWaveQueueNext or count > 10
		  DLog("SceneController_RunInternalZWaveQueue(", fromWhere, "): Nodes: ", ZWaveQueueNodes, " ( ", nodelist, ")")
		end

		local veraZWaveNode, ZWaveNetworkDeviceId = GetVeraIDs()
	    local j = ZWaveQueueNext[1];

		if j.pattern then
			DLog("SceneController_RunInternalZWaveQueue(", fromWhere, "): Calling zwint.monitor: ", j)
			zwint.monitor(j.responseDevice,j.context,j.pattern,j.oneshot,j.timeout, j.armPattern, j.autoResponse);
			j.waitingForResponse = true
		end

		if j.hasBattery and j.final then
			-- If the device is battery operated and this is the final "no more information" message, 
			-- then turn off the no more information intercept to let it go through.
			ChangeBatteryNoMoreInformationMonitor(j.responseDevice, j.node_id, false)
			DeviceAwakeList[j.node_id] = 0
		end

	    -- This is where we actually perform the action in a queue entry.
		ActiveZWaveJob = j
		if j.type == 0 then
			VLog("SceneController_RunInternalZWaveQueue(", fromWhere, ") type=ZWave, Node=Controller name=", j.name, ": ", SID_ZWN, " SendData ", {Data = j.data}, " ", ZWaveNetworkDeviceId);
		  	j.err_num, j.err_msg, j.job_num, j.arguments = luup.call_action(SID_ZWN, "SendData", {                  Data = j.data}, ZWaveNetworkDeviceId)
		elseif j.type == 1 then
			local message = "Working..."
			if VerboseLogging > 0 then
				message = "Executing " .. j.name
			end
			luup_device_message(j.device, 
						        1, -- job_InProgress
						        message,
						        5, -- Timeout
						        GetDeviceName()) -- source    
			VLog("SceneController_RunInternalZWaveQueue(", fromWhere, ") type=ZWave, Node=Device name=", j.name, ": ", SID_ZWN, " SendData ", {Node = j.node_id, Data = j.data}, " ", ZWaveNetworkDeviceId);
			j.err_num, j.err_msg, j.job_num, j.arguments = luup.call_action(SID_ZWN, "SendData", {Node = j.node_id, Data = j.data}, ZWaveNetworkDeviceId)
		elseif j.type == 2 then
			VLog("SceneController_RunInternalZWaveQueue(", fromWhere, ") type=LuaAction: name=", j.name)
			j.err_num, j.err_msg, j.job_num, j.arguments = luup.call_action(j.service, j.action, j.arguments, j.device)
		else
			ELog("SceneController_RunInternalZWaveQueue(", fromWhere, ") Invalid job type: ", j)
		end

		give_global_lock()

	    -- Check for an immediate failure and retry in 5 seconds if so.
		VLog("SceneController_RunInternalZWaveQueue(", fromWhere, ") call_action returned err_num=", j.err_num, " err_msg=", j.err_msg, " job_num=", j.job_num, " arguments=", j.arguments)

		if j.err_num ~= 0 or j.job_num == 0 then
		    log("SceneController_RunInternalZWaveQueue(", fromWhere, "): call_action failed, retrying in 5 seconds. ", j);
			ActiveZWaveJob = nil
		    if j.pattern then
				j.waitingForResponse = false
		    	zwint.cancel(j.responseDevice, j.context)
		    end
		    RunInternalZWaveQueue(fromWhere.." retry", 5000)
		    return
		end

		if luup.job_watch then
			return
		end

		-- From here down is for UI5 only
		j.startTime = socket.gettime()
	    CheckUI5ZWaveQueueHeadStatus("")

	elseif nextQueue then
		VLog("SceneController_RunInternalZWaveQueue(", fromWhere, ") waiting for  next job: ",  nextQueue[1])
		-- No entries are ready to run, so wait until the one that will be ready sooonest
	    ZWaveQueueNext = nextQueue
	    local waitTime = nextTime - now
	    if waitTime < 1 then
			local waitms = math.floor(waitTime*1000)
			VLog("SceneController_RunInternalZWaveQueue(", fromWhere, ") Delaying for ", waitms, " ms using luup.sleep.")
		  	luup.sleep(waitms)
			local t2 = socket.gettime()
			if t2 - now >= waitms then
				waitTime = 0
		  		if RemoveHeadFromZWaveQueue() then
		  			RunInternalZWaveQueue(fromWhere.." after sleep", 0)
		  		end
			else
				VLog("SceneController_RunInternalZWaveQueue(", fromWhere, ") luup.sleep too short.")
				waitTime = waitTime + 1;
			end
		end
		if waitTime >= 1 then
			local waitSec = math.floor(waitTime)
			VLog("SceneController_RunInternalZWaveQueue(", fromWhere, ") Delaying for ", waitSec, " seconds using luup.call_delay.")
		  	luup.call_delay("SceneController_RunInternalZWaveQueue", waitSec, fromWhere.." DelayFor ".. waitTime, true)
	  	end
	else
		VLog("SceneController_RunInternalZWaveQueue(", fromWhere, ") Nothing to do")	
	end
end

function RegisterClientDevice(backoff)
	DEntry()
	backoff = tonumber(backoff)
	if not backoff then
		backoff = 1
	end
	luup.variable_set(SID_SCENECONTROLLER, "ZQ_WritePtr", "0", luup.device)

	-- Clear out old variables. Replace them with temporary files. 
	-- TODO: This code should be deleted after the next release.
	for i = 0, (ZQ_MaxQueueDepth-1) do
		local data = luup.variable_get(SID_SCENECONTROLLER, "ZQ_Data"..i, luup.device)
		if data and data ~= "" then
			luup.variable_set(SID_SCENECONTROLLER, "ZQ_Data"..i, "", luup.device)
		end
	end	

	-- luup.variable_set(SID_SCENECONTROLLER, "ZQ_ReadPtr", "0", luup.device)
	local err_num, err_msg, job_num, arguments = luup.call_action(GENGENINSTALLER_SID, "RegisterClientDevice", {DeviceNumber=luup.device}, GetFirstInstaller())
	if err_num ~= 0 then
		DLog("RegisterClientDevice: call_action returnd ", err_num, ": ", err_msg,". Trying again.") 
		local tryAgainSeconds = 3
		luup.call_delay("RegisterClientDevice", tryAgainSeconds, tostring(backoff+2), true)
	end
end

ZQReadPtrs = {}

function SceneController_RegisterClientDevice(device, target)
	DEntry()
	ZQReadPtrs[target] = 0
	VariableWatch("SceneController_ZQWritePtrChanged", SID_SCENECONTROLLER, "ZQ_WritePtr", target, tostring(target))
end

function SceneController_ZQWritePtrChanged(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new, context)
	VEntry()
	local target = tonumber(context)
	local writePtr = tonumber(lul_value_new)
	--local readPtr = luup.variable_get(SID_SCENECONTROLLER, "ZQ_ReadPtr", target)
	local readPtr = ZQReadPtrs[target]
	readPtr = tonumber(readPtr)
	while readPtr ~= writePtr do
		local data = nixio.fs.readfile("/tmp/ZQ_Data_" ..readPtr .. "_" .. target);
		-- local data = luup.variable_get(SID_SCENECONTROLLER, "ZQ_Data"..readPtr, target)
		-- luup.variable_set(SID_SCENECONTROLLER, "ZQ_Data"..readPtr, "", target)
		local settings = assert(loadstring("return " .. data))()
		for i,v in ipairs(settings) do
			EnqueueInternalActionOrMessage(v)
		end
		readPtr = (readPtr + 1) % ZQ_MaxQueueDepth
	end
	-- VLog("About to Set ZQ_ReadPtr to", readPtr) 
	-- luup.variable_set(SID_SCENECONTROLLER, "ZQ_ReadPtr", tostring(readPtr), target)
	ZQReadPtrs[target] = readPtr
	VLog("Set ZQ_ReadPtr to", readPtr," About to call RunInternalZWaveQueue") 
	RunInternalZWaveQueue("External ZQ", 0)
end


function SceneController_RunZWaveQueue(device, settings)
	DEntry()
	for i = 1, tonumber(settings.NumEntries) do
		EnqueueInternalActionOrMessage(assert(loadstring("return "..settings["E"..i],"E"..i))())
	end
	RunInternalZWaveQueue("External", 0)
end

function SceneController_NoMoreInformationTimeout(data)
	local peer_dev_num, zwave_node, state = string.match(data,"(%d+)_(%d+)_(%d+)")
	peer_dev_num = tonumber(peer_dev_num)
	zwave_node = tonumber(zwave_node)
	state = tonumber(state)
	VEntry("SceneController_NoMoreInformationTimeout")
	if DeviceAwakeStates[zwave_node] == state then
	   	if  DeviceAwakeList[zwave_node] > 1 then
	   		DeviceAwakeList[zwave_node] = 0
			ChangeBatteryNoMoreInformationMonitor(peer_dev_num, zwave_node, false)
		elseif  DeviceAwakeList[zwave_node] == 1 then
			VLog("Ignoring No More Information timeout because we are currently activing commnicating with the devoce. DeviceAwakeList[",zwave_node,"]=",DeviceAwakeList[zwave_node]) 
		else
			VLog("Ignoring No More Information timeout because it is no longer active. DeviceAwakeList[",zwave_node,"]=",DeviceAwakeList[zwave_node]) 		 	
		end
	else
		VLog("Ignoring stale No More Information timeout. callback state=",state, "DeviceAwakeStates[",zwave_node,"]=",DeviceAwakeStates[zwave_node])  	
	end
	RunInternalZWaveQueue("NoMoreInformationTimeout", 0) 
end

-- A UI5 substitutwe for the new luup.job_watch in UI7
function CheckUI5ZWaveQueueHeadStatus(data)
  	local j = ActiveZWaveJob
	if not j then
		return
	end
	local slept = socket.gettime() - j.startTime
	local delay
	if slept < 0.1 then
		delay = 0.1
 	elseif slept < 0.6	then
		delay = 0.2
  	elseif slept < 60 then
		delay = slept / 3
	else
		ELog("CheckUI5ZWaveQueueHeadStatus: Giving up after 1 minute: job=", j)
		ActiveZWaveJob = nil
  		if RemoveHeadFromZWaveQueue(j) then
  		  	RunInternalZWaveQueue("1 minute timeout", 0)
  		end
  		return
    end
    if delay < 1 then
    	luup.sleep(delay * 1000)
    	CheckUI5ZWaveQueueHeadStatus2()
    else
    	luup.call_delay("CheckUI5ZWaveQueueHeadStatus2", delay, "", true)
    end
end


-- We need to monitor other jobs that are not aurs in order to avoid the dreaded cannot get lock crash
-- We either wait indefinitely or wait for a given timeout depending on the job status
local function HandleOtherJob(lul_job)
	VEntry("HandleOtherJob")
	local status = lul_job.status
	if status == 1 or status >= 5 then
		OtherJobPending = true;
	else
		local wasPending = OtherJobPending
		OtherJobPending = false;
		local delay = 0
		if 	lul_job.status ~= 4 then -- ~= success
			ZWaveQueuePendingTime = socket.gettime() + MinOtherJobDelay/1000
			delay = MinOtherJobDelay
		end
		if wasPending and ZWaveQueueNext then
			RunInternalZWaveQueue("Other job finished", delay)
		end
	end 
end

-- This is the job watch callback which monitors all jobs whether or not they belong to us.
function SceneController_JobWatchCallBack(lul_job)
	VEntry("SceneController_JobWatchCallBack")
	if not ZWaveQueueNext then
		VLog("SceneController_JobWatchCallBack: ZWaveQueue is empty.");
		HandleOtherJob(lul_job)
		return
	end
	local j = ActiveZWaveJob
	if not j then
		VLog("SceneController_JobWatchCallBack: No Active Z-Wave job.");
		HandleOtherJob(lul_job)
		return
	end
	local expectedJobType, expectedName
	if j.type == 0 then
		expectedJobType = "ZWJob_GenericSendFrame"
		expectedName = "send_code"
	elseif j.type == 1 then
		expectedJobType = "ZWJob_SendData"
		expectedName = "childcmd node "..j.node_id
	elseif j.type == 2 then
		expectedJobType = j.name
	end
	if lul_job.type ~= expectedJobType then
		VLog("SceneController_JobWatchCallBack: Job type expected ", expectedJobType, " but got ", lul_job.type)
		HandleOtherJob(lul_job)
		return
	end
	if j.type ~= 2 then
		if lul_job.name ~= expectedName then
			VLog("SceneController_JobWatchCallBack: Expected ", expectedName, " but got ", lul_job.name)
			HandleOtherJob(lul_job)
			return
		end
		if lul_job.status < 2 or lul_job.status > 4 then
			VLog("SceneController_JobWatchCallBack: status is still ", lul_job.status, ". notes:", lul_job.notes)
			return
		end
	end
	ActiveZWaveJob = nil
	if lul_job.status == 2 then -- error
		if not j.retry then
			j.retry = 1
		else
			j.retry = j.retry + 1
		end
		ELog("SceneController_JobWatchCallBack: Job failed. retry=", j.retry)
		if j.retry <= 3 then
			RunInternalZWaveQueue("Retry_Job", 0)
			return
		end
	end
	if lul_job.status == 3 and j.responseDevice and j.hasBattery and not j.final then
		DeviceAwakeList[j.node_id] = 0
		log(ANSI_YELLOW, j.description, " went to sleep unexpectedly", ANSI_RESET)
		local handle = TaskHandleList[j.responseDevice]
		if not handle then
			handle = -1
		end
		TaskHandleList[j.responseDevice] = luup.task("Device went to sleep unexpectedly", 1, j.description, handle)
		if j.type == 1 then
			luup_device_message(j.device, 
						        5, -- job_WaitingForCallback
						        "Device went to sleep unexpectedly", -- message
						        0, -- No timeout
						        GetDeviceName()) -- source    
		end
		RunInternalZWaveQueue("Battery wait", 0)
		return
	end
	if lul_job.status ~= 4 and j.type ~= 2 then
		ELog("SceneController_JobWatchCallBack: Job ",j.name," for ",j.description," failed. Give up and go to next node. Final status was ", lul_job.status, " notes:", lul_job.notes)
		if j.type == 1 then
			luup_device_message(j.device, 
						        2, -- job_Error
						        "Device did not respond. Giving up.", -- message
						        0, -- No timeout
						        GetDeviceName()) -- source    
		end
		if RemoveNodeFromZWaveQueue(j) then
			RunInternalZWaveQueue("Failed_Job", 0)
		end
		return
	end
	if j.waitingForResponse then
		return
	end
	if j.delay > 0 then
		local now = socket.gettime()
		j.waitUntil = now + j.delay / 1000
		RunInternalZWaveQueue("Delay_Job", 0)
	elseif RemoveHeadFromZWaveQueue(j) then
		RunInternalZWaveQueue("Next_Job", 0)
	end
end

function SceneController_ZWaveMonitorResponse(device, response, is_intercept, is_timeout)
	DEntry("SceneController_ZWaveMonitorResponse")
	local now = socket.gettime()
	local context = response.key
	local releaseNodeId
	local callback
	if context then
		local obj = MonitorContextList[context]
		if obj then
			if obj.oneshot then
				MonitorContextList[context] = nil;
			end
			callback = obj.callback
			releaseNodeId = obj.releaseNodeId
		else
			ELog("SceneController_ZWaveMonitorResponse: Response context ", context, " not found in context list: ", MonitorContextList)
		end
	end
	if releaseNodeId then
		if device == GetFirstInstaller() then
			if ZWaveQueue[releaseNodeId] then
				local j = ZWaveQueue[releaseNodeId][1]
				if j.waitingForResponse then
					j.waitingForResponse = false
					if j ~= ActiveZWaveJob then
						if j.delay > 0 then
							j.waitUntil = socket.gettime() + j.delay / 1000
							RunInternalZWaveQueue("Delay_Job_after_response", 0)
						elseif RemoveHeadFromZWaveQueue(j) then
							RunInternalZWaveQueue("Next_Job_after_response", 0)
						end
					end
				end
			end
		else
			if response.time then -- The Fake timeout is passed from installer to device and does not have the time keyword.
				-- A device receives the response message first but then relays it
				-- to the installer so that it can clear the WaitingForResponse flag
				-- and allow more messages to be sent for that device.
				while not take_global_lock() do
					luup.sleep(100)	 -- Will this work and not cause LuaUPnP crashes? Using luup.call_delay here is difficult
				end
		  		luup.call_action(SID_ZWAVEMONITOR, response.action, response, GetFirstInstaller())
				give_global_lock()
			end
		end
	end
	if callback then
		if is_timeout then
			response = nil
		end
		callback(device, response)
	end
	RunZWaveQueue("ZWaveMonitorResponse")
end

function SceneController_ZWaveMonitorError(device, errorCode, errorMessage)
	ELog("SceneController_ZWaveMonitorError: errorCode=", errorCode, " errorMessage=", errorMessage)
end

local veraZWaveNode
local ZWaveNetworkDeviceId
function GetVeraIDs()
	if veraZWaveNode == nil then
		local zwave_device = 1
		local node_id = "1"
		for k,v in pairs(luup.devices) do
			if v.device_type == DEVTYPE_ZWN then
				local homeID = luup.variable_get(SID_ZWN, "HomeID", k)
				DLog("GetVeraIDs: Found Z-Wave network Vera device ID=", k, " HomeID=", homeID)
				local homeNode = tostring(homeID):match("House: %x+ Node (%x+) Suc %x+")
				if homeNode then
					zwave_device = k
					node_id = tostring(tonumber(homeNode,16))
					DLog("GetVeraIDs: Z-Wave node=0x", homeNode, "=", node_id)
					break
				end
			end
		end
		veraZWaveNode = tonumber(node_id)
		ZWaveNetworkDeviceId = zwave_device
	end
	return veraZWaveNode, ZWaveNetworkDeviceId
end

--
-- Z-Wave Queue
--
ExternalZWaveQueue = {}

-- Always run the Z-Wave queue in a delay task to avoid any deadlocks.
function RunZWaveQueue(fromWhere)
	DEntry()
	if ZWaveQueueNext then
		RunInternalZWaveQueue(fromWhere, 0)
	end
	if #ExternalZWaveQueue > 0 then
		-- local readPtr = luup.variable_get(SID_SCENECONTROLLER, "ZQ_ReadPtr", luup.device)
		-- readPtr = tonumber(readPtr)
		local writePtr = luup.variable_get(SID_SCENECONTROLLER, "ZQ_WritePtr", luup.device)
		writePtr = tonumber(writePtr)
		local nextWritePtr = (writePtr + 1) % ZQ_MaxQueueDepth
		-- if nextWritePtr == readPtr then
			-- ELog("ZWave Queue full")
		-- else
			nixio.fs.writefile("/tmp/ZQ_Data_" ..writePtr .. "_" .. luup.device, tableToString(ExternalZWaveQueue));
			--luup.variable_set(SID_SCENECONTROLLER, "ZQ_Data"..writePtr, tableToString(ExternalZWaveQueue), luup.device)
			ExternalZWaveQueue = {}
			luup.variable_set(SID_SCENECONTROLLER, "ZQ_WritePtr", tostring(nextWritePtr), luup.device)
		-- end
	end
end

local firstInstaller = nil
function GetFirstInstaller()
	if not firstInstaller then
		local min
		for dev_num, v in pairs(luup.devices) do
			if v.device_type == GENGENINSTALLER_DEVTYPE then
				if not firstInstaller or firstInstaller > dev_num then
					firstInstaller = dev_num
				end
			end
		end
	end
	return firstInstaller
end

---
--- Enhanced variable watch support
---
-- Sanitize a string converting all non [a-zA-Z0-9_] characters to _
-- This May return a string beginning with a digit
local function toidentifier(anything)
  return  string.gsub(tostring(anything),"[^%w_]","_")
end

function WatchedVarHandler(xfunction_name, ufunction_name, context, device, service, variable, value_old, value_new)
  VEntry()
  if WatchedVariables[xfunction_name] then
    if UnwatchedVariables[ufunction_name] then
	  local temp = UnwatchedVariables[ufunction_name] - 1
 	  VLog("Skipping Unwatched variable: ", ufunction_name, ". Unwatch count now ", UnwatchedVariables[ufunction_name])
	  if temp <= 0 then
	    temp = nil
	  end
	  UnwatchedVariables[ufunction_name] = temp
	  return false -- Temp unwatch
	end
    return true -- Normal case
  end
  VLog(xfunction_name, " no longer being watched")
  return false -- Variable no longer watched
end

WatchedVariables = {}
UnwatchedVariables = {}
-- An extended version of luup.variable_watch which takes an extra context (string) parameter
-- function_name is passed  lul_device, lul_service, lul_variable, lul_value_old, lul_value_new, context
-- Returns an object which can be passed to CancelVariableWatch
-- Watches created here can also be temporarily unwatched (once) using TempVariableUnwatch
function VariableWatch(function_name, service, variable, device, context)
  VEntry()
  local xfunction_name = "VarWatch_" .. function_name .. toidentifier(context) .. "___" .. toidentifier(service) .. variable .. tostring(device)
  local ufunction_name = "VarUnwatch_" .. toidentifier(service) .. variable .. tostring(device)
  if WatchedVariables[xfunction_name] then
    -- Already being watched with the given context.
	WatchedVariables[xfunction_name] = WatchedVariables[xfunction_name] + 1
	return
  end
  WatchedVariables[xfunction_name] = 1;
  if WatchedVariables[ufunction_name] then
	WatchedVariables[ufunction_name] = WatchedVariables[ufunction_name] + 1
  else
	WatchedVariables[ufunction_name] = 1
  end
  local qContext = string.format('%q', context)
  local funcBody="function " .. xfunction_name .. "(device, service, variable, value_old, value_new)\n" ..
                 "  if WatchedVarHandler ('"..xfunction_name.."', '" .. ufunction_name .. "', '" .. qContext .. "', device, service, variable, value_old, value_new) then\n" ..
                 "    " .. function_name .. "(device, service, variable, value_old, value_new, " .. qContext .. ")\n" ..
			     "  end\n" ..
			     "end\n"
  assert(loadstring(funcBody))()
  luup.variable_watch(xfunction_name, service, variable, device)
  return xfunction_name;
end

-- Temporarily "unwatch" a variable which is expected to trigger
function TempVariableUnwatch(service, variable, device)
  VEntry()
  local ufunction_name = "VarUnwatch_" .. toidentifier(service) .. variable .. tostring(device)
  local numWatched = WatchedVariables[ufunction_name]
  if numWatched then
	if UnwatchedVariables[ufunction_name] then
	  UnwatchedVariables[ufunction_name] = UnwatchedVariables[ufunction_name] + numWatched
	else
	  UnwatchedVariables[ufunction_name] = numWatched
	end
  end
end

function CancelVariableWatch(xfunction_name)
	VEntry()
	assert(WatchedVariables[xfunction_name] > 0)
	WatchedVariables[xfunction_name] = WatchedVariables[xfunction_name] - 1

	ufunction_name = "VarUnwatch_" .. xfunction_name:match("___(.*)$")
	assert(WatchedVariables[ufunction_name] > 0)
	WatchedVariables[ufunction_name] = WatchedVariables[ufunction_name] - 1
end

---
--- Other shared functions
---

-- Given the Z-Wave node ID, NodeIdToDeviceNumbers returns the Z-Wave device number
function NodeIdToDeviceNumber(node_id)
  	local veraZWaveNode, ZWaveNetworkDeviceId = GetVeraIDs()
	for k, v in pairs(luup.devices) do
		if v.device_num_parent == ZWaveNetworkDeviceId and tonumber(v.id) == node_id then
			return k
		end
	end
	return nil
end

local DupData = {}
local RECEIVE_STATUS_TYPE_MASK = 0x0C
local RECEIVE_STATUS_TYPE_SINGLE = 0x00
local RECEIVE_STATUS_TYPE_BROAD = 0x04
local RECEIVE_STATUS_TYPE_MULTI = 0x08
local RECEIVE_STATUS_TYPE_EXPLORE = 0x10
local MAX_DUP_TIME = 0.250 -- seconds
local MAX_EXPLORE_DUP_TIME = 0.400 -- seconds
function CheckDups(peer_dev_num, result, data)
	DEntry()
	local oldTable = DupData[peer_dev_num]
	local time = tonumber(result.time)
	local receiveStatus = tonumber(result.C1, 16)
	receiveStatus = bit.band(receiveStatus, RECEIVE_STATUS_TYPE_MASK);
	local result = true
	if oldTable and oldTable.data == data and 
	    ((time-oldTable.time < MAX_DUP_TIME and
		 (oldTable.receiveStatus == receiveStatus or
		 (oldTable.receiveStatus > RECEIVE_STATUS_TYPE_SINGLE and receiveStatus == RECEIVE_STATUS_TYPE_SINGLE))) or
		(time-oldTable.time < MAX_EXPLORE_DUP_TIME and receiveStatus >= RECEIVE_STATUS_TYPE_EXPLORE))  then
		oldTable.time = time
		log(ANSI_YELLOW, "peer_dev_num=", peer_dev_num, " data=", data, " timestamp=", time, " is a dup", ANSI_RESET)
		result = false
	end
	DupData[peer_dev_num] = {time=time, receiveStatus=receiveStatus, data=data}
	return result
end
