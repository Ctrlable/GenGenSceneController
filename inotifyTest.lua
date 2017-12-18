local inotify = require 'inotify'
local bit = require 'bit'
local posix = require "posix"

function log(msg)
  luup.log("inotify test: " .. msg)
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

-- Enable logging of Z-Wave responses. This is necessary to read back ZWave responses
-- Version 0.7: if /etc/cmh/cmh.conf does not contain ^#?LogLevels .*,42 then copy it to /etc/cmh/cmh.conf.backup and add ,42 to the logLevels line
-- Version 0.8 and later: if either /etc/cmh/cmh.conf_flush or /etc/cmh/cmh.conf_noflush don't exist then
--                   copy /etc/cmh/cmh.conf to /etc/cmh/cmh.conf.backup if necessary
--                   copy /etc/cmh/cmh.conf.backup to  /etc/cmh/cmh.conf_noflush
--                   copy /etc/cmh/cmh.conf.backup to  /etc/cmh/cmh.conf_flush, modifying the LogLevels to add ,42 and change ImmediatelyFlushLog=1
--                   replace /etc/cmh/cmh.conf to a symbolic link of /etc/cmh/cmh.conf_noflush
-- SetFlushLogs switches /etc/cmh/cmh.conf to point to /etc/cmh/cmh.conf_flush or /etc/cmh/cmh.conf_noflush and then sends a self-signal SIGUSR2 to force the etc/cmh/cmh.conf file to be re-read
-- See the docs for pluto.conf which still lives in LinuxMCE, from which Vera's cmh.conf parsing was derived. (http://www.linuxmce.org/ - Pluto is no longer a project/planet)
--
CMH_CONF         = "/etc/cmh/cmh.conf"
CMH_CONF_BACKUP  = CMH_CONF .. ".backup"
CMH_CONF_FLUSH   = CMH_CONF .. "_flush"
CMH_CONF_NOFLUSH = CMH_CONF .. "_noflush"
SIGUSR2 = 17  -- Vera posix library does not define this - MIPS-specific value
function EnableZWaveReceiveLogging()
    -- Assume that everything is already done if both the _flush and _noflush files exist
    local f = io.open(CMH_CONF_BACKUP,"r")
    if f then
        f:close()
    else
        os.execute("cp " .. CMH_CONF .. " " .. CMH_CONF_BACKUP)
    end
    f = io.open(CMH_CONF_NOFLUSH,"r")
    if f then
        f:close()
    else
        os.execute("cp " .. CMH_CONF_BACKUP .. " " .. CMH_CONF_NOFLUSH)
    end
    f = io.open(CMH_CONF_FLUSH,"r")
    if f then
        f:close()
        flushLogs = nil;
    else
        local n = 1
        local confdata = {}
        f = io.open(CMH_CONF_BACKUP,"r")
        for line in f:lines() do
            if line:match("^ImmediatelyFlushLog") then
                line = "ImmediatelyFlushLog=1"
            elseif line:match("^#?LogLevels") then
                if not line:match(",42") then
                    line = line .. ",42"
                end
            end
            confdata[n] = line
            n = n + 1
        end
        f:close()
        f = io.open(CMH_CONF_FLUSH,"w")
        for lnum,line in ipairs(confdata) do
            f:write(line.."\n")
        end
        f:close()
        flushLogs = 0
    end
end

-- SetFlushLogs temporarily turns immediate log flushing on and off so that we can get
-- feedback from the controller while we are updating it
function SetFlushLogs(flush)
    if flushLogs == nil then
        if flush then
            flushLogs = 0
        else
            flushLogs = 1
        end
    end
    if flush then
        if flushLogs <= 0 then
            posix.unlink(CMH_CONF)
            posix.link(CMH_CONF_FLUSH,CMH_CONF,true) -- Symbolic link. Hard links don't work due to overlayfs bug
            posix.kill(posix.getpid("pid"),SIGUSR2) -- See rotate_logs() in /www/cgi-bin/cmn/log_level.sh
        end
        flushLogs = flushLogs + 1
    else
        if flushLogs > 0 then
            if flushLogs == 1 then
                posix.unlink(CMH_CONF)
                posix.link(CMH_CONF_NOFLUSH,CMH_CONF,true)
                posix.kill(posix.getpid("pid"),SIGUSR2)
            end
            flushLogs = flushLogs - 1
        end
    end
end

local logStartPos = -1;

function LuaUPnPLogModified()
    local file, openError = io.open("/var/log/cmh/LuaUPnP.log")
    if not file then
        log("Could not open log file: " .. tostring(openError))
        return
    end

    local fileSize, sizeError = file:seek("end",0)
    if not fileSize then
        file:close()
        log("Could not determine log file size: ".. tostring(sizeError))
        return
    end
    if logStartPos < 0 then
        -- negative logStartPos means start logStartPos+1 bytes from the end of the file. In particular logStartPos=-1 should always return a empty log on the first try but start logging from there.
        logStartPos = fileSize + 1 + logStartPos
        if logStartPos < 0 then -- Backed too far
            logStartPos = 0
        end
    else
        if logStartPos > fileSize then
            log("Warning: Log file was truncated: Perhaps logs were rotated")
            logStartPos = 0
        end
    end

    local pos, seekError = file:seek("set", logStartPos)
    if not pos then
        file:close()
        log("Could not seek to position" .. tostring(logStartPos) .. ": ".. tostring(sizeError))
        return
    end
    local chunkSize = fileSize - pos
    chunk = file:read(chunkSize)
    file:close()
    if not chunk then
        chunk = ""
    end
    local oldChunkSize = chunkSize
    chunkSize = chunk:len()
    fileSize = fileSize - oldChunkSize + chunkSize

    -- Trim off the last line if it does not end with a \n. We will pick it up next time
    if chunkSize > 0 then
        if chunk:byte(chunkSize) ~= 10 then
            local ix1, ix2 = chunk:find("\n[^\n]+$")
            if ix1 then
                chunk = chunk:sub(1,ix1)
                chunkSize = ix1
            end
        end
    end
    logStartPos = pos + chunkSize

    if chunk:byte(1) ~= 10 then
        chunk = "\n" .. chunk
    end

    -- find lines like "42      11/12/16 0:59:06.578    0x1 0x5 0x0 0x13 0xd 0x0 0xe4 (####\r##)""
    for zwave in chunk:gmatch("\n42%s+[%d/]+%s[%d:%.]+%s+([x%x%s]+%x)%s+%(") do
        log("found Z-Wave response: '" .. tostring(zwave) .. "'")
    end
end

function DoINotifyEvent(data)
    local events = inotify_handle:read()

    for n, ev in ipairs(events) do
        if bit.band(ev.mask, inotify.IN_MODIFY) ~= 0 then
            LuaUPnPLogModified()
        else
            printTable(ev, "Special inotify")
        end
    end

    if inotify_running then
        luup.call_delay("DoINotifyEvent", 0, "", true)
    else
        log("inotify stopped")
        SetFlushLogs(false);
        -- Done automatically on close, I think, but kept to be thorough
        inotify_handle:rmwatch(inotify_wd)

        inotify_handle:close()
    end
end

printTable(inotify)

inotify_running = false;

inotify_handle, e1, e2 = inotify.init()
if not inotify_handle then
  luup.log("inotify_handle is nil")
  printTable(e1)
  printTable(e2)
  return
end

inotify_running = true;
EnableZWaveReceiveLogging()
SetFlushLogs(true);

-- Watch for new files and renames
inotify_wd = inotify_handle:addwatch('/var/log/cmh/LuaUPnP.log', bit.band(inotify.IN_ALL_EVENTS, bit.bnot(
        bit.bor(inotify.IN_ACCESS,inotify.IN_OPEN,inotify.IN_CLOSE))))

luup.call_delay("DoINotifyEvent", 0, "", true)

function StopInotify(data)
    log("StopInotify: Setting inotify_running to false")
    inotify_running = false
end

local r1 = luup.call_delay("StopInotify", 60, "", true)
log("call_delay StopInotify result="..tostring(r1))

--
