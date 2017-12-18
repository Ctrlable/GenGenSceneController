-- Test code for Z-Wave interceptor

nixio = require("nixio")
nixio2 = require("nixio2")

ZWN_SID            = "urn:micasaverde-com:serviceId:ZWaveNetwork1"
ZWI_SOCKET_PATH    = "\0ZwIntercept"

--
-- Debugging functions
--

local ANSI_RED     = "\027[31m"
local ANSI_GREEN   = "\027[32m"
local ANSI_YELLOW  = "\027[33m"
local ANSI_BLUE    = "\027[34m"
local ANSI_MAGENTA = "\027[35m"
local ANSI_CYAN    = "\027[36m"
local ANSI_WHITE   = "\027[37m"
local ANSI_RESET   = "\027[0m"

local VerboseLogging = 3

function GetDeviceName()
  local name = "ZwInteceptTest"
  return name
end

function ELog(msg)
  luup.log(ANSI_RED .. GetDeviceName() .." Error: " .. ANSI_RESET .. msg .. debug.traceback(ANSI_CYAN, 2) .. ANSI_RESET)
end

function log(msg)
  luup.log(GetDeviceName() ..": " .. msg)
end

function DLog(msg)
  if VerboseLogging > 0 then
    luup.log(GetDeviceName() .. " debug: " .. msg)
  end
end

function DTableToString(tab)
  if VerboseLogging > 0 then
    return tableToString(tab)
  else
    return ""
  end
end

function VLog(msg)
  if VerboseLogging > 2 then
    luup.log(GetDeviceName() .. " verbose: " .. msg)
  end
end

function VTableToString(tab)
  if VerboseLogging > 2 then
    return tableToString(tab)
  else
    return ""
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

local veraZWaveNode
local ZWaveNetworkDeviceId
function GetVeraIDs()
    if veraZWaveNode == nil then
        local zwave_device = 1
        local node_id = "1"
        for k,v in pairs(luup.devices) do
            if v.device_type == "urn:schemas-micasaverde-com:device:ZWaveNetwork:1" then
                local homeID = luup.variable_get(ZWN_SID, "HomeID", k)
                DLog("GetVeraIDs: Found Z-Wave network Vera device ID="..k.. " HomeID=" .. tostring(homeID))
                local homeNode = tostring(homeID):match("House: %x+ Node (%x+) Suc %x+")
                if homeNode then
                   zwave_device = k
                   node_id = tostring(tonumber(homeNode,16))
                   DLog("GetVeraIDs: Z-Wave node=0x"..homeNode.."="..node_id)
                   break
                end
            end
        end
        veraZWaveNode = tonumber(node_id)
        ZWaveNetworkDeviceId = zwave_device
    end
    return veraZWaveNode, ZWaveNetworkDeviceId
end

------------------------------------------------------

function InterceptZWaveData()
    local veraZWaveNode, ZWaveNetworkDeviceId = GetVeraIDs()
    local ComPort = luup.variable_get(ZWN_SID, "ComPort", ZWaveNetworkDeviceId)
    log("ComPort="..tableToString(ComPort))

    local fdlist = io.popen("ls -l /proc/self/fd")
    local comPortFdStr
    for line in fdlist:lines() do
        comPortFdStr = line:match(" (%d+) %-> " .. ComPort)
        if comPortFdStr then
            log("Found CommPort FD = ".. comPortFdStr);
            break
        end
    end
    fdlist:close()
    if not comPortFdStr then
        ELog("Could not find Comport file descriptor")
        return
    end

    local s1, errno, errstring = nixio2.socket("unix", "seqpacket")
    log("nixio2.socket s1="..tostring(s1).." errno="..tostring(errno).." errstring="..tostring(errstring))

    local s2, errno, errstring = nixio2.socket("unix", "seqpacket")
    log("nixio2.socket s2="..tostring(s2).." errno="..tostring(errno).." errstring="..tostring(errstring))

    local result, errno, errstring = nixio.fs.unlink(ZWI_SOCKET_PATH)
    log("nixio.fs.unlink: result="..tostring(result).." errno="..tostring(errno).." errstring="..tostring(errstring))

    local result, errno, errstring = s1:bind(ZWI_SOCKET_PATH)
    log("s1:bind: result="..tostring(result).." errno="..tostring(errno).." errstring="..tostring(errstring))

    local result, errno, errstring = s1:listen(2)
    log("s1:listen: result="..tostring(result).." errno="..tostring(errno).." errstring="..tostring(errstring))

    local result, errno, errstring = s2:connect(ZWI_SOCKET_PATH)
    log("s2:connect: result="..tostring(result).." errno="..tostring(errno).." errstring="..tostring(errstring))

    local s3, errno, errstring = s1:accept()
    log("s1:accept: s3="..tostring(s3).." errno="..tostring(errno).." errstring="..tostring(errstring))

    local s4 = nixio2.dup(s2, tonumber(comPortFdStr))
    log("nixio2.dup s4="..tostring(s4).." errno="..tostring(errno).." errstring="..tostring(errstring))

    local s5 = nixio.open(ComPort, "w+")
    log("nixio.open s5="..tostring(s5).." errno="..tostring(errno).." errstring="..tostring(errstring))

    log("s1="..tableToString(s1))
    log("s2="..tableToString(s2))
    log("s3="..tableToString(s3))
    log("s4="..tableToString(s4))
    log("s5="..tableToString(s5))

    local poll_flags = nixio.poll_flags("in", "err", "pri", "hup", "nval")
    log("poll_flags="..tostring(poll_flags))
    if s3 and s5 then

        local fds = {
            {fd=s3, events=poll_flags},
            {fd=s5, events=poll_flags}
        }

        while true do
            local nfds, newfds, ep = nixio.poll(fds, 1000)
            if nfds ~= nil then
                if nfds then
                    if newfds[1].revents == 1 then
                        local buffer = s3:recv(1000)
                        s5:write(buffer)
                        log("Host->Controller: "..nixio.bin.hexlify(buffer))
                    elseif newfds[1].revents ~= 0 then
                        log("Host error:"..tableToString(nfds[1]))
                    end
                    if newfds[2].revents == 1 then
                        local buffer = s5:read(1000)
                        s3:send(buffer)
                        log("Controller->host: "..nixio.bin.hexlify(buffer))
                    elseif newfds[2].revents ~= 0 then
                        log("Controller error:"..tableToString(newfds[1]))
                    end
                else
                    --log("poll timeout: nfds="..tableToString(nfds).." newfds="..tableToString(newfds).." ep="..tableToString(ep))
                end
            else
                log("poll error: nfds="..tableToString(nfds).." newfds="..tableToString(newfds).." ep="..tableToString(ep))
            end
        end
        s3:close()
    end
    s2:close()
    s1:close()
    nixio.fs.unlink(ZWI_SOCKET_PATH)
end

printTable(nixio2)
luup.call_delay("InterceptZWaveData",0,"")
--printTable(nixio)
--[[
    local fdlist = io.popen("ls -l /usr/lib/lua")
    local comPortFdStr
    for line in fdlist:lines() do
        log(line)
    end
--]]
--printTable(nixio)
--printTable(nixio2)
---
