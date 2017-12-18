-- GenGeneric Scene Controller shared code Version 1.06
-- Copyright 2016-2017 Gustavo A Fernandez. All Rights Reserved
-- Supports Evolve LCD1, Cooper RFWC5 and Nexia One Touch Controller
 
--
-- Debugging functions
--

ANSI_RED     = "\027[31m"
ANSI_GREEN   = "\027[32m"
ANSI_YELLOW  = "\027[33m"
ANSI_BLUE    = "\027[34m"
ANSI_MAGENTA = "\027[35m"
ANSI_CYAN    = "\027[36m"
ANSI_WHITE   = "\027[37m"
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
		str = str .. tostring(name) .. "=" .. tableToString(value)
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

function ELog(...)
  luup.log(ANSI_RED .. GetDeviceName() .."   Error: " .. ANSI_RESET .. stackDepthIndent() .. logList(...) .. debug.traceback(ANSI_CYAN, 2) .. ANSI_RESET)
end

function log(...)
  luup.log(GetDeviceName() ..": " .. stackDepthIndent() .. logList(...))
end

function DLog(...)
  if VerboseLogging > 0 then
    luup.log(GetDeviceName() .. "   debug: " .. stackDepthIndent() .. logList(...))
  end
end

function DEntry(name)
  if VerboseLogging > 0 then
    luup.log(GetDeviceName() .. "   debug: " .. stackDepthIndent() .. getFunctionInfo(3,name))
  end
end

function VLog(...)
  if VerboseLogging > 2 then
    luup.log(GetDeviceName() .. " verbose: " .. stackDepthIndent() .. logList(...))
  end
end

function VEntry(name)
  if VerboseLogging > 2 then
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
-- Z-Wave Queue and job handling
--

zwint = require "zwint"

SID_ZWAVEMONITOR      = "urn:gengen_mcv-org:serviceId:ZWaveMonitor1"
SID_ZWN       	      = "urn:micasaverde-com:serviceId:ZWaveNetwork1"

GENGENINSTALLER_SID   = "urn:gengen_mcv-org:serviceId:SceneControllerInstaller1"
GENGENINSTALLER_DEVTYPE = "urn:schemas-gengen_mcv-org:device:SceneControllerInstaller:1"

local ZWaveQueue = {}
local ActiveZWaveJob = nil
local ZWaveQueueNext = nil
local ZWaveQueueNodes = 0
local TaskHandleList = {}

MonitorContextNum = 0
MonitorContextList = {}

local function EnqueueInternalActionOrMessage(queueNode)
	VEntry()
	local node_id = queueNode.node_id
	if not node_id then
		node_id = 0
	end
	if queueNode.pattern then
		-- Handle cases where callback was passed as nil.
		-- Also handles cases where a non-first-peer relays the response to
		-- the first peer to release the waitingForResponse flag.
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
		table.insert(newDev, queueNode) -- Normal case. Insert at end.
	end
	if queueNode.node_id == 0 and ZWaveQueueNext ~= newDev then
		-- Node 0 entries have priority. Bring them to the front of the queue.
		newDev.next.prev = newDev.prev
		newDev.prev.next = newDev.next
		newDev.next = ZWaveQueueNext
		newDev.prev = ZWaveQueueNext.prev
		ZWaveQueueNext.prev.next = newDev
		ZWaveQueueNext.prev = newDev
		ZWaveQueueNext = newDev
	end
end

-- Enqueue the last Z-Wave message in a group. 
-- This is used for the "no more information" message for battery devices. 
-- It may be deleted if other items are queued behind it.
function EnqueueFinalZWaveMessage(name, node_id, data)
  VEntry()
  EnqueueInternalActionOrMessage({
  	type=1,
  	name=name,
  	node_id=node_id,
  	data=data,
  	delay=0,
  	final=true})
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
--     by the "first peer" device which actually dispatches most Z-Wave commands
--   Unlike EnqueueZWaveMessageWithResponse, Callback must not be nil.
-- Oneshot is true if the intercept should be canceled as soon as it matches.
--   If OneShot is false and arm_regex is not nil, then the intercept is disarmed when it triggers.
-- Timeout and delay are in milliseconds.
--   If timeout is 0 then the monitor will be active until canceled with CancelZWaveMonitor
-- Returns a context which can be passed to CancelZWaveMonitor or nil if error.
function MonitorZWaveData(outgoing, peer_dev_num, arm_regex, intercept_regex, autoResponse, callback, owneshot, timeout, label)
	VEntry()
  	local context
	MonitorContextNum = MonitorContextNum + 1
	local prefix = "M_"
	if outgoing then
  		prefix = "I_"
	end
	context = prefix .. label .. "_" .. peer_dev_num.."_"..MonitorContextNum
	MonitorContextList[context] = {outgoing=outgoing, callback=callback, oneshot=oneshot}
  	local result, errcode, errmessage
  	if outgoing then
    	result, errcode, errmessage = zwint.intercept(peer_dev_num, context, intercept_regex, owneshot, timeout, arm_regex, autoResponse)
  	else
    	result, errcode, errmessage = zwint.monitor(peer_dev_num, context, intercept_regex, owneshot, timeout, arm_regex, autoResponse)
  	end
  	if not result then
		ELog("MonitorZWaveData: zwint failed. error code=", errcode, " error message=", errmessage)
		MonitorContextList[context] = nil;
		return nil;
  	end
  	return context;
end

local function RemoveHeadFromZWaveQueue(job)
	local queue = ZWaveQueueNext
	if job then
	   queue = ZWaveQueue[job.node_id]
	end
	if not queue then
		return false
	end
	table.remove(queue,1)
	if #queue == 0 then
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

-- Always run the Z-Wave queue in a delay task to avoid any deadlocks.
local function RunInternalZWaveQueue(fromWhere, delay_ms)
	DEntry()
	local delay_sec = math.floor(delay_ms / 1000)
	local sleep_ms = delay_ms - delay_sec*1000
	if sleep_ms > 0 then
		luup.sleep(sleem_ms)
	end
	if ZWaveQueueNext then
		luup.call_delay("SceneController_RunInternalZWaveQueue", delay_sec, fromWhere, true)
	end
end

function SceneController_RunZWaveQueue(device, settings)
	DEntry()
	for i = 1, tonumber(settings.NumEntries) do
		EnqueueInternalActionOrMessage(assert(loadstring("return "..settings["E"..i],"E"..i))())
	end
	RunInternalZWaveQueue("External", 0)
end

-- A UI5 substitutwe for the new luup.job_watch in UI7
local function CheckUI5ZWaveQueueHeadStatus(data)
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
		if j.node_id == 0 then
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

function SceneController_RunInternalZWaveQueue(fromWhere)
	VEntry("SceneController_RunInternalZWaveQueue")
  	if not ZWaveQueueNext then
      VLog("SceneController_RunInternalZWaveQueue: fromWhere=", fromWhere, " queue is empty")
	  return
  	end

  	if ActiveZWaveJob then
	  VLog("SceneController_RunInternalZWaveQueue(", fromWhere, ") Job still active: job=", ActiveZWaveJob)
	  return
  	end

  	-- If the head of the queue is in a time delay or otherwise blocked.
  	-- look around the queue array for another queue who's first job we can perform now 
  	-- or else has the shortest delay.
   	local now =	socket.gettime()
    local nextTime = nil
    local nextQueue = nil
    local ZWaveQueueFirst = ZWaveQueueNext
  	while ZWaveQueueNext[1].waitUntil or ZWaveQueueNext[1].waitingForResponse or ZWaveQueueNext[1].batteryWait do
  		if not (ZWaveQueueNext[1].waitingForResponse or ZWaveQueueNext[1].batteryWait) then
  			if ZWaveQueueNext[1].waitUntil > now then
  				if not nextTime or nextTime > ZWaveQueueNext[1].waitUntil then
  		    		nextTime = ZWaveQueueNext[1].waitUntil
  		    		nextQueue = ZWaveQueueNext
  		  		end
  		  	else
				VLog("SceneController_RunInternalZWaveQueue: Removing time wait queu entry which timed out ", (now - ZWaveQueueNext[1].waitUntil), "seconds ago: ", ZWaveQueueNext[1])
  		  		if RemoveHeadFromZWaveQueue() then
  		  			RunInternalZWaveQueue(fromWhere.." after timeout", 0)
  		  		end
  		  		return
  		  	end
  		end
  		if ZWaveQueueNext.node_id ~= 0 and ZWaveQueueNext.next ~= ZWaveQueueFirst then
  		    ZWaveQueueNext = ZWaveQueueNext.next
  		else
  		  	if not nextQueue then
				VLog("SceneController_RunInternalZWaveQueue: No good candidates. quitting: ", ZWaveQueueNext)
  		  		return
  		  	end
  		    ZWaveQueueNext = nextQueue
  		    local waitTime = nextTime - now
  		    if waitTime >= 1 then
			  	VLog("SceneController_RunInternalZWaveQueue: Delaying for ", waitTime, " seconds using luup.call_delay.")
  			  	luup.call_delay("SceneController_RunInternalZWaveQueue", waitTime, fromWhere.." DelayFor ".. waitTime, true)
  		    else
			  	VLog("SceneController_RunInternalZWaveQueue: Delaying for ", waitTime, " seconds using luup.sleep.")
  			  	luup.sleep(waitTime*1000)
  		  		if RemoveHeadFromZWaveQueue() then
  		  			RunInternalZWaveQueue(fromWhere.." after sleep", 0)
  		  		end
  		  	end
  		    return
  		end
   	end

    -- At this pont, we know we have something to do.
    -- Dump the queue to the log in various ways.
  	if VerboseLogging >= 2 then
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
	elseif VerboseLogging > 0 then
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

	-- if j.HasBattery then
		-- If the device is battery operated turn on or off the no more information intercept
	--	ChangeBatteryNoMoreInformationMonitor(j.responseDevice, j.node_id, not j.final)
	-- end

    -- This is where we actually perform the action in a queue entry.
	ActiveZWaveJob = j
	if j.type == 1 then
		if j.node_id > 0 then
		  	VLog("SceneController_RunInternalZWaveQueue: type=ZWave, Node=Device name=", j.name, ": ", SID_ZWN, " SendData ", {Node = j.node_id, Data = j.data}, " ", ZWaveNetworkDeviceId);
		  	j.err_num, j.err_msg, j.job_num, j.arguments = luup.call_action(SID_ZWN, "SendData", {Node = j.node_id, Data = j.data}, ZWaveNetworkDeviceId)
		else
		  	VLog("SceneController_RunInternalZWaveQueue: type=ZWave, Node=Controller name=", j.name, ": ", SID_ZWN, " SendData ", {Data = j.data}, " ", ZWaveNetworkDeviceId);
		  	j.err_num, j.err_msg, j.job_num, j.arguments = luup.call_action(SID_ZWN, "SendData", {                  Data = j.data}, ZWaveNetworkDeviceId)
		end
	else
		VLog("SceneController_RunInternalZWaveQueue: type=LuaAction: name=", j.name)
		j.err_num, j.err_msg, j.job_num, j.arguments = luup.call_action(j.service, j.action, j.arguments, j.device)
	end

    -- Check for an immediate failure and retry in 5 seconds if so.
	VLog("SceneController_RunInternalZWaveQueue: call_action returned err_num=", j.err_num, " err_msg=", j.err_msg, " job_num=", j.job_num, " arguments=", j.arguments)
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
end

function SceneController_JobWatchCallBack(lul_job)
	VEntry()
	if not ZWaveQueueNext then
		VLog("SceneController_JobWatchCallBack: ZWaveQueue is empty.");
		return
	end
	local j = ActiveZWaveJob
	if not j then
		VLog("SceneController_JobWatchCallBack: No Active Z-Wave job.");
		return
	end
	local expectedJobType, expectedName
	if j.node_id == 0 then
		expectedJobType = "ZWJob_GenericSendFrame"
		expectedName = "send_code"
	else
		expectedJobType = "ZWJob_SendData"
		expectedName = "childcmd node "..j.node_id
	end
	if lul_job.type ~= expectedJobType then
		VLog("SceneController_JobWatchCallBack: Job type expected ", expectedJobType, " but got ", lul_job.type)
		return
	end
	if lul_job.name ~= expectedName then
		VLog("SceneController_JobWatchCallBack: Expected ", expectedName, " but got ", lul_job.name)
		return
	end
	if lul_job.status < 2 or lul_job.status > 4 then
		VLog("SceneController_JobWatchCallBack: status is still ", lul_job.status, ". notes:", lul_job.notes)
		return
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
	if lul_job.status == 3 and j.responseDevice and j.HasBattery and not j.final then
		j.batteryWait = true
		log(ANSI_YELLOW, j.description, " is now on battery wait", ANSI_RESET)
		local handle = TaskHandleList[j.responseDevice]
		if not handle then
			handle = -1
		end
		TaskHandleList[j.responseDevice] = luup.task("Waiting for device to wake up", 1, j.description, handle)
		RunInternalZWaveQueue("Battery wait", 0)
		return
	end
	if lul_job.status ~= 4 then
		ELog("SceneController_JobWatchCallBack: Job failed. Skipping to next job. Final status was ", lul_job.status, " notes:", lul_job.notes)
		j.delay = 0
		j.waitingForResponse = false
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
			-- A non-first-peer receives the response message first but then relays it
			-- to the first peer so that it can clear the WaitingForResponse flag
			-- and allow more messages to be sent for that device.
	  		luup.call_action(SID_ZWAVEMONITOR, "Monitor", response, GetFirstInstaller())
		end
	end
	if callback then
		if is_timeout then
			response = nil
		end
		callback(device, response)
	end
	RunZWaveQueue("ZWaveMonitorResponse", 0)
end

function SceneController_ZWaveMonitorError(device, errorCode, errorMessage)
	ELog("SceneController_ZWaveMonitorError: errorCode=", errorCode, " errorMessage=", errorMessage)
end


local NoMoreInformationContexts = {}
function ChangeBatteryNoMoreInformationMonitor(peer_dev_num, zwave_node, enable)

	local BatteryNoMoreInformationCallback = function(installer, captures)
		VEntry("BatteryNoMoreInformationCallback")
		local node_id = tonumber(captures.C2, 16)
		local list = ZWaveQueue[node_id]
		if list and list[1] and list[1].batteryWait then
			list[1].batteryWait = false
			local device = luup.devices[peer_dev_num]
			log(ANSI_YELLOW, "Battery wait released for ", device.description, ANSI_RESET)
			local handle = TaskHandleList[peer_dev_num]
			if not handle then
				handle = -1
			end
			TaskHandleList[peer_dev_num] = luup.task("", 4, device.description, handle)
		end
	    EnqueueFinalZWaveMessage("BatteryNoMoreInformation", node_id, "0x84 0x8");
	end

	if enable then
		if not NoMoreInformationContexts[peer_dev_num] then
			NoMoreInformationContexts[peer_dev_num] = MonitorZWaveData( 
				true, -- outgoing
				luup.device, -- peer_dev_num
--[==[
42      12/04/16 20:05:26.449   0x1 0x8 0x0 0x4 0x4 0x9 0x2 0x84 0x7 0x7f (##########)
           SOF - Start Of Frame --+   ¦   ¦   ¦   ¦   ¦   ¦    ¦   ¦    ¦
                     length = 8 ------+   ¦   ¦   ¦   ¦   ¦    ¦   ¦    ¦
                        Request ----------+   ¦   ¦   ¦   ¦    ¦   ¦    ¦
FUNC_ID_APPLICATION_COMMAND_HANDLER ----------+   ¦   ¦   ¦    ¦   ¦    ¦
           Receive Status BROAD ------------------+   ¦   ¦    ¦   ¦    ¦
Device 12=Nexia One Touch Scene Controller Z-Wave ----+   ¦    ¦   ¦    ¦
                Data length = 2 --------------------------+    ¦   ¦    ¦
          COMMAND_CLASS_WAKE_UP -------------------------------+   ¦    ¦
           WAKE_UP_NOTIFICATION -----------------------------------+    ¦
                    Checksum OK ----------------------------------------+
--]==]
				"^01 .. 00 04 .. " .. string.format("%02X", zwave_node) .. " .. 84 07",
--[==[
                                              C1  C2                                   C3
41      12/04/16 20:05:27.515   0x1 0xd 0x0 0x19 0x9 0x2 0x84 0x8 0x5 0x0 0x0 0x0 0x0 0x4 0x6d (#\r############m)
           SOF - Start Of Frame --+   ¦   ¦    ¦   ¦   ¦    ¦   ¦   ¦ +-------------+   ¦    ¦
                    length = 13 ------+   ¦    ¦   ¦   ¦    ¦   ¦   ¦        ¦          ¦    ¦
                        Request ----------+    ¦   ¦   ¦    ¦   ¦   ¦        ¦          ¦    ¦
   FUNC_ID_ZW_SEND_DATA_GENERIC ---------------+   ¦   ¦    ¦   ¦   ¦        ¦          ¦    ¦
Device 12=Nexia One Touch Scene Controller Z-Wave -+   ¦    ¦   ¦   ¦        ¦          ¦    ¦
                Data length = 2 -----------------------+    ¦   ¦   ¦        ¦          ¦    ¦
          COMMAND_CLASS_WAKE_UP ----------------------------+   ¦   ¦        ¦          ¦    ¦
    WAKE_UP_NO_MORE_INFORMATION --------------------------------+   ¦        ¦          ¦    ¦
Xmit options = ACK | AUTO_ROUTE ------------------------------------+        ¦          ¦    ¦
           Routing data ignored ---------------------------------------------+          ¦    ¦
                   Callback = 4 --------------------------------------------------------+    ¦
                    Checksum OK -------------------------------------------------------------+
--]==]
				"^01 .. 00 (..) (" .. string.format("%02X", zwave_node) .. ") .. 84 08 .+ (..) ..$",
--[==[
42      12/04/16 20:05:27.538   0x6 0x1 0x4 0x1 0x19 0x1 0xe2 (#######)
              ACK - Acknowledge --+   ¦   ¦   ¦    ¦   ¦    ¦
           SOF - Start Of Frame ------+   ¦   ¦    ¦   ¦    ¦
                     length = 4 ----------+   ¦    ¦   ¦    ¦
                       Response --------------+    ¦   ¦    ¦
   FUNC_ID_ZW_SEND_DATA_GENERIC -------------------+   ¦    ¦
                     RetVal: OK -----------------------+    ¦
                    Checksum OK ----------------------------+
42      12/04/16 20:05:27.539   got expected ACK -- removed

        ACK: 0x6 (#)

42      12/04/16 20:05:27.778   0x1 0x5 0x0 0x19 0x4 0x0 0xe7 (#######)
           SOF - Start Of Frame --+   ¦   ¦    ¦   ¦   ¦    ¦
                     length = 5 ------+   ¦    ¦   ¦   ¦    ¦
                        Request ----------+    ¦   ¦   ¦    ¦
   FUNC_ID_ZW_SEND_DATA_GENERIC ---------------+   ¦   ¦    ¦
                   Callback = 4 -------------------+   ¦    ¦
           TRANSMIT_COMPLETE_OK -----------------------+    ¦
                    Checksum OK ----------------------------+
41      12/04/16 20:05:27.779   ACK: 0x6 (#) -- removed
--]==]
				"06 01 04 01 \\1 01 XX 01 05 00 \\1 \\3 00 XX",
				BatteryNoMoreInformationCallback, 
				false, -- not oneShot
				0, -- no timeout
				"BatteryNoMoreInfo")
		end
	else
		local context = NoMoreInformationContexts[peer_dev_num]
		if context then 
			zwint.cancel(peer_dev_num, context)
			MonitorContextList[context] = nil
			NoMoreInformationContexts[peer_dev_num] = nil
		end -- if context
	end -- else not enable
end -- function ChangeBatteryNoMoreInformationMonitor

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
function RunZWaveQueue(fromWhere, delay_ms)
	DEntry()
	if ZWaveQueueNext then
		RunInternalZWaveQueue(fromWhere, delay_ms)
		delay_ms = 0
	end
	if #ExternalZWaveQueue > 0 then
		local delay_sec = math.floor(delay_ms / 1000)
		local sleep_ms = delay_ms - delay_sec*1000
		if sleep_ms > 0 then
			luup.sleep(sleem_ms)
		end
		luup.call_delay("SceneController_RunExternalZWaveQueue", delay_sec, fromWhere, true)
	end
end

function SceneController_RunExternalZWaveQueue(fromWhere)
	VEntry()
	if #ExternalZWaveQueue > 0 then
		local data = {}
		for i,v in ipairs(ExternalZWaveQueue) do
			data["E"..i] = tableToString(v);
		end
		data.NumEntries = #ExternalZWaveQueue
		ExternalZWaveQueue = {}
	  	luup.call_action(GENGENINSTALLER_SID, "RunZWaveQueue", data, GetFirstInstaller())
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

