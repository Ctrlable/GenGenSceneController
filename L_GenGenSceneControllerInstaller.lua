-- Installer for GenGeneric Scene Controller Version 1.17
-- Copyright 2016-2017 Gustavo A Fernandez. All Rights Reserved
--
-- Includes installation files for
--   Evolve LCD1
--   Cooper RFWC5
--   Nexia One Touch NX1000
-- This installs zwave_products_user.xml for UI5 and modifies KitDevice.json for UI7.
-- It also installs the custom icon in the appropriate places for UI5 or UI7

-- VerboseLogging == 0: important logs and errors:    ELog, log
-- VerboseLogging == 1: Includes Info  logs:          ELog, log, ILog,
-- VerboseLogging == 2: Includes debug logs:          ELog, log, ILog, DLog, DEntry
-- VerboseLogging == 3: Include extended ZWave Queue  ELog, log, ILog, DLog, DEntry
-- VerboseLogging == 4:	Includes verbose logs:        ELog, log, ILog, DLog, DEntry, VLog, VEntry
VerboseLogging = 0

-- Set UseDebugZWaveInterceptor to true to enable zwint log messages to log.LuaUPnP (Do not confuse with LuaUPnP.log)
local UseDebugZWaveInterceptor = true

local GenGenInstaller_Version = 116 -- Update this each time we update the installer.

local bit = require 'bit'
local nixio = require "nixio"
local socket = require "socket"
require "L_GenGenSceneControllerShared"

local HAG_SID                 = "urn:micasaverde-com:serviceId:HomeAutomationGateway1"
local ZWN_SID       	      = "urn:micasaverde-com:serviceId:ZWaveNetwork1"

local GENGENINSTALLER_SID     = "urn:gengen_mcv-org:serviceId:SceneControllerInstaller1"
local GENGENINSTALLER_DEVTYPE = "urn:schemas-gengen_mcv-org:device:SceneControllerInstaller:1"

local SID_SCENECONTROLLER     = "urn:gengen_mcv-org:serviceId:SceneController1"

-- Make sure tha all of the log functions work before even the SCObj global is set.
function GetDeviceName()
  return "GenGeneric Scene Controller"
end

local reload_needed = false

-- Update file with the given content if the previous version does not exist or is different.
function UpdateFileWithContent(filename, content, permissions, version, force)
	local update = false
	local backup = false
	local oldVersion
	if not content then
		ELog("Missing content for ", filename)
		return false
	end
	local stat = nixio.fs.stat(filename)
	local oldName = filename .. ".old"
	local backupName = filename .. ".save"
	oldversion = luup.variable_get(GENGENINSTALLER_SID, filename .. "_version", lul_device) 
	if oldversion then
		oldversion = tonumber(oldversion)
	else
		oldversion = 0
	end
	if not version then
		version = 0
	end
	if stat then
		if version > oldversion or (version == oldversion and stat.size ~= #content) or force then
			log("Backing up ", filename, " to ", backupName, " and replacing with new version.")
			VLog("Old ", filename, " size was ", stat.size, " bytes. new size is ", #content, " bytes.")
			nixio.fs.rename(backupName, oldName)
			local result, errno, errmsg =  nixio.fs.rename(filename, backupName)
			if result then
				update = true
				backup = true
			else
				ELog("could not rename ", filename, " to", backupName, ": ", errmsg)
			end
		else
			if oldversion > version then
				VLog("Not updating ", filename, " because the old version is ", oldversion, " and the new version is ", version)
			else
				VLog("Not updating ", filename, " because the new content is ", #content, " bytes and the old is ", stat.size, " bytes.")
			end
		end
	else
		VLog("updating ", filename, " because a previous version does not exist")
		update = true
	end
	if update then
		local f, errno, errmsg = nixio.open(filename, "w", permissions)
		if f then
			local result, errno, errmsg, bytesWritten = f:write(content)
			if result then
				f:close()
				if backup then
					nixio.fs.remove(oldName)
				end
				VLog("Wrote ", filename, " successfully (", #content, " bytes)")
				if version > 0 then
					luup.variable_set(GENGENINSTALLER_SID, filename .. "_version", tostring(version), lul_device)
				end
				reload_needed = filename
				return true
			else
				ELog("could not write ", #content, " bytes into ", filename, ". only ", bytesWritten, " bytes written: ", errmsg)
				f:close()
				if backup then
					nixio.fs.rename(backupName, filename)
					nixio.fs.rename(oldName, backupName)
				end
			end
		else
			ELog("could not open ", filename, " for writing: ", errmsg)
			if backup then
				nixio.fs.rename(backupName, filename)
				nixio.fs.rename(oldName, backupName)
			end
		end
	end
	return false
end

-- Prepares a file to be updated.
-- Returns nixio read and write file handles if update is needed.
-- Returns nil if no update required or error occurred. (base not modified)
-- <base.old - previous base.modified (for error handling)
-- <base>.save - previous base
-- <base>.modified - new file
-- <base> - Symlink to <base>.modified
function PrepFileForUpdate(base, force)
	local base_modified = base .. ".modified"
	local base_save = base .. ".save"
	local base_old = base .. ".old"
	local base_temp = base .. ".temp"
	local base_lstat, errno, errmsg = nixio.fs.lstat(base)
	local why = nil
	if not base_lstat then
		ELog("could not lstat ", base, ": ", errmsg)
		return nil
	end
	local base_save_stat = nixio.fs.stat(base_save)
	if base_save_stat and base_lstat.type == "lnk" then
		local base_linkname, errno, errmsg = nixio.fs.readlink(base)
		if not base_linkname then
			ELog("Could not readlink ", base": ", errmsg)
			return nil
		end
		if base_linkname ~= base_save then
			why = base .. " now symlinks to " .. base_linkname .. " instead of " .. base_save .. ". Perhaps the Vera software has been updated. Removing old " .. base_save
			nixio.fs.remove(base_save)
			base_save_stat = nil
		end
	end
	local base_modified_stat = nixio.fs.stat(base_modified)
	if not why then
		if force then
			why = "Installer has been updated"
		elseif not base_modified_stat then
			why = "the file has never been modified by the installer"
		end
	end
	if why then
		if base_modified_stat then
			nixio.fs.rename(base_modified, base_old)
		end
		if not base_save_stat then
			local result, errno, errmsg = nixio.fs.rename(base, base_save)
			if not result then
				ELog("could not rename ", base, " to", base_save, ": ", errmsg)
				if base_modified_stat then
					nixio.fs.rename(base_old, base_modified)
				end
				return nil
			end
		end
		local read_file, errmsg, errno = io.open(base_save, "r")
		if not read_file then
			ELog("could not open ", base_save, " for reading: ", errmsg)
			if not base_save_stat then
		    	nixio.fs.rename(base_save, base)
			end
			if base_modified_stat then
				nixio.fs.rename(base_old, base_modified)
			end
			return nil
		end
		local write_file, errmsg, errno = io.open(base_modified, "w", 644)
		if not write_file then
			ELog("could not open ", base_modified, " for writing: ", errmsg)
			read_file:close()
			if not base_save_stat then
		    	nixio.fs.rename(base_save, base)
			end
			if base_modified_stat then
				nixio.fs.rename(base_old, base_modified)
			end
			return nil
		end
		if base_save_stat then
			local result, errno, errmsg = nixio.fs.remove(base)
			if not result then
				ELog("could not delete old symlink ", base, ": ", errmsg)
				write_file:close()
				read_file:close()
				nixio.fs.remove(base_modified)
				if base_modified_stat then
					nixio.fs.rename(base_old, base_modified)
				end
				return nil
			end
		end
		local result, errno, errmsg = nixio.fs.symlink(base_modified, base)
		if not result then
			ELog("could not symlink ", base_modified, " to", base, ": ", errmsg)
			write_file:close()
			read_file:close()
			if not base_save_stat then
		    	nixio.fs.rename(base_save, base)
			end
			nixio.fs.remove(base_modified)
			if base_modified_stat then
				nixio.fs.rename(base_old, base_modified)
			end
			return nil
		end
		nixio.fs.remove(base_old)
		return read_file, write_file, why
	end
	return nil
end

function updateJson(filename, update_func, updated)
	read_file, write_file, why = PrepFileForUpdate(filename, updated)
	if read_file then
		log("Updating ", filename, " because ", why)
		local str = read_file:read("*a")
		read_file:close()
		local obj=json.decode(str);
		update_func(obj)
		local state = { indent = true }
		local str2 = json.encode (obj, state)
		write_file:write(str2)
		write_file:close()
		reload_needed = filename
	else
		VLog("Not updating ", filename)
	end
end

ScannedDeviceList = {}

function ScanForNewDevices()
	DEntry()

	local function AdoptEvolveLCD1(device_num)
		DEntry()
		luup.attr_set("device_type", "urn:schemas-gengen_mcv-org:device:SceneControllerEvolveLCD:1", device_num)
		luup.attr_set("device_file", "D_EvolveLCD1.xml", device_num)
		luup.attr_set("impl_file", "I_GenGenSceneController.xml", device_num)
		luup.attr_set("name", "Evolve LCD1 Z-Wave", device_num)
		luup.attr_set("manufacturer", "Evolve Guest Controls", device_num)
		luup.attr_set("device_json", "D_EvolveLCD1.json", device_num)
		luup.attr_set("category_num", "14", device_num)
		luup.attr_set("subcategory_num", "0", device_num)
		luup.attr_set("model", "EVLCD1", device_num)
		luup.attr_set("invisible", "1", device_num)
		luup.variable_set("urn:micasaverde-com:serviceId:SceneController1", "NumButtons", "5", device_num)
		luup.variable_set("urn:micasaverde-com:serviceId:SceneController1", "FiresOffEvents", "1", device_num)
		luup.variable_set("urn:micasaverde-com:serviceId:SceneController1", "ActivationMethod", "0", device_num)
		luup.variable_set("urn:micasaverde-com:serviceId:ZWaveDevice1", "VariablesSet", "20-Display Timeout (seconds),m,,"..
		                                                                                "21-Backlight ON level (1-20),m,,"..
		                                                                                "22-Backlight OFF level (0-20),m,,"..
		                                                                                "23-Button ON level (1-20),m,,"..
		                                                                                "24-Button OFF level (0-20),m,,"..
		                                                                                "25-LCD Contrast (5-20),m,,"..
		                                                                                "26-Orientation(1=rotate 180 0=normal),m,,"..
		                                                                                "27-Network Update (seconds),m,,"..
		                                                                                "29-backlight level (0-100),m,,"..
		                                                                                "32-Backlight Demo mode (0-1),m,", device_num)
		luup.variable_set("urn:micasaverde-com:serviceId:HaDevice1", "Documentation", "http://code.mios.com/trac/mios_evolve-lcd1", device_num)
		luup.variable_set("urn:micasaverde-com:serviceId:ZWaveDevice1", "Documentation", "http://code.mios.com/trac/mios_evolve-lcd1", device_num)
	end

	local function AdoptCooperRFWC5(device_num)
		DEntry()
		luup.attr_set("device_type", "urn:schemas-gengen_mcv-org:device:SceneControllerCooperRFWC5:1", device_num)
		luup.attr_set("device_file", "D_CooperRFWC5.xml", device_num)
		luup.attr_set("impl_file", "I_GenGenSceneController.xml", device_num)
		luup.attr_set("manufacturer", "Cooper Industries", device_num)
		luup.attr_set("name", "Cooper RFWC5 Z-Wave", device_num)
		luup.attr_set("dev ice_json", "D_CooperRFWC5.json", device_num)
		luup.attr_set("category_num", "14", device_num)
		luup.attr_set("subcategory_num", "0", device_num)
		luup.attr_set("model", "RFWC5", device_num)
		luup.attr_set("invisible", "1", device_num)
		luup.variable_set("urn:micasaverde-com:serviceId:SceneController1", "NumButtons", "5", device_num)
		luup.variable_set("urn:micasaverde-com:serviceId:SceneController1", "FiresOffEvents", "1", device_num)
		luup.variable_set("urn:micasaverde-com:serviceId:SceneController1", "ActivationMethod", "0", device_num)
	end

	local function AdoptNexiaOneTouch(device_num)
		DEntry()
		luup.attr_set("device_type", "urn:schemas-gengen_mcv-org:device:SceneControllerNexiaOneTouch:1", device_num)
		luup.attr_set("device_file", "D_NexiaOneTouch.xml", device_num)
		luup.attr_set("impl_file", "I_GenGenSceneController.xml", device_num)
		luup.attr_set("manufacturer", "Ingersoll Rand", device_num)
		luup.attr_set("name", "Nexia One Touch Z-Wave", device_num)
		luup.attr_set("device_json", "D_NexiaOneTouch.json", device_num)
		luup.attr_set("category_num", "14", device_num)
		luup.attr_set("subcategory_num", "0", device_num)
		luup.attr_set("model", "NX1000", device_num)
		luup.attr_set("invisible", "1", device_num)
		luup.variable_set("urn:micasaverde-com:serviceId:SceneController1", "NumButtons", "5", device_num)
		luup.variable_set("urn:micasaverde-com:serviceId:SceneController1", "FiresOffEvents", "1", device_num)
		luup.variable_set("urn:micasaverde-com:serviceId:SceneController1", "ActivationMethod", "0", device_num)
		luup.variable_set("urn:micasaverde-com:serviceId:ZWaveDevice1", "VariablesSet", "20-Touch Calibration (1-10),m,,"..
		                                                                                "21-Screen Contrast (1-10),m,,"..
		                                                                                "23-Button LED Level (1-10),m,,"..
		                                                                                "24-Backlight Level (1-10),m,,"..
		                                                                                "25-Scene Button Press Backlight Timeout (10-15),m,,"..
		                                                                                "26-Page Button Press Backlight Timeout (5-15),m,,"..
		                                                                                "28-Screen Timeout (1-240),m,,"..
		                                                                                "29-Screen Timeout Primary Page (0-3),m,,"..
		                                                                                "30-Battery Stat Shutdown Threshold % (0-20),m,,"..
		                                                                                "31-Battery Radio Cutoff Threshold % (0-40),m,,"..
																					    "32-Battery LOWBATT Indicator Threshold % (5-50),m,,"..
																					    "33-Battery Threshold Value for Midlevel % (30-80),m,",device_num)
		luup.variable_set("urn:micasaverde-com:serviceId:HaDevice1", "Documentation", "http://products.z-wavealliance.org/products/1344", device_num)
		luup.variable_set("urn:micasaverde-com:serviceId:ZWaveDevice1", "Documentation", "http://products.z-wavealliance.org/products/1344", device_num)
	end

	-- This is a hack for UI7 1.7.2608 getting confused by inconsistent node info reports from the Kichler 12387 undercabinet light controller.
	-- Vera also does not like devices that don't support COMMAND_CLASS_VERSION so we add it to the command class list and intercept the expected
	-- version and command class version queries.
	local function ApplyKichler12387Hack(device_num, node_id)
		DEntry()

		local function Kichler12387NodeInfoCallback(peer_dev_num, result)
			DLog("Kichler 12387 node info intercept: device num=".. device_num.." node_id="..node_id.. "result=".. tableToString(result));
		end

		local function Kichler12387VersionCallback(peer_dev_num, result)
			DLog("Kichler 12387 Version intercept: device num=".. device_num.." node_id="..node_id.. "result=".. tableToString(result));
		end

		local function Kichler12387CommandClassVersionCallback(peer_dev_num, result)
			DLog("Kichler 12387 Version intercept: device num=".. device_num.." node_id="..node_id.. "result=".. tableToString(result));
		end

		MonitorZWaveData(true, -- outgoing,
						 luup.device, -- peer_dev_num
		                 nil, -- No arm_regex
--[==[
41      04/02/17 23:01:39.675       0x1 0x4 0x0 0x60 0x60 0xfb (###``#) 
               SOF - Start Of Frame --+   ¦   ¦    ¦    ¦    ¦
                         length = 4 ------+   ¦    ¦    ¦    ¦
                            Request ----------+    ¦    ¦    ¦
       FUNC_ID_ZW_REQUEST_NODE_INFO ---------------+    ¦    ¦
Node: 96 Device 204=UD17F Breakfast undercabinet lights +    ¦
                        Checksum OK -------------------------+--]==]
		                 "^01 04 00 60 " .. string.format("%02X", node_id) .. " ..", -- Main RegEx
--[==[
42      04/02/17 23:01:39.700   0x6 0x1 0x4 0x1 0x60 0x1 0x9b (####`##) 
              ACK - Acknowledge --+   ¦   ¦   ¦    ¦   ¦    ¦
           SOF - Start Of Frame ------+   ¦   ¦    ¦   ¦    ¦
                     length = 4 ----------+   ¦    ¦   ¦    ¦
                       Response --------------+    ¦   ¦    ¦
   FUNC_ID_ZW_REQUEST_NODE_INFO -------------------+   ¦    ¦
               Result = Success -----------------------+    ¦
                    Checksum OK ----------------------------+
42      04/02/17 23:01:39.700   got expected ACK 
41      04/02/17 23:01:39.700   ACK: 0x6 (#) 

42      04/02/17 23:01:39.737     0x1 0xc 0x0 0x49 0x84 0x60 0x7 0x2 0x11 0x0 0x72 0x85 0x26 0x86 0x99 (###I#`####r#&#) 
             SOF - Start Of Frame --+   ¦   ¦    ¦    ¦    ¦   ¦   ¦    ¦   ¦    ¦    ¦    ¦    ¦    ¦
                      length = 12 ------+   ¦    ¦    ¦    ¦   ¦   ¦    ¦   ¦    ¦    ¦    ¦    ¦    ¦
                          Request ----------+    ¦    ¦    ¦   ¦   ¦    ¦   ¦    ¦    ¦    ¦    ¦    ¦
    FUNC_ID_ZW_APPLICATION_UPDATE ---------------+    ¦    ¦   ¦   ¦    ¦   ¦    ¦    ¦    ¦    ¦    ¦
Update state = Node Info received --------------------+    ¦   ¦   ¦    ¦   ¦    ¦    ¦    ¦    ¦    ¦
Node ID: 96 Device 204=UD17F Breakfast undercabinet lights +   ¦   ¦    ¦   ¦    ¦    ¦    ¦    ¦    ¦
             Node info length = 6 -----------------------------+   ¦    ¦   ¦    ¦    ¦    ¦    ¦    ¦
   Basic type = Static Controller ---------------------------------+    ¦   ¦    ¦    ¦    ¦    ¦    ¦
 Generic type = switch multilevel --------------------------------------+   ¦    ¦    ¦    ¦    ¦    ¦
         Specific type = Not used ------------------------------------------+    ¦    ¦    ¦    ¦    ¦
Can receive command class[1] = COMMAND_CLASS_MANUFACTURER_SPECIFIC --------------+    ¦    ¦    ¦    ¦
Can receive command class[2] = COMMAND_CLASS_ASSOCIATION -----------------------------+    ¦    ¦    ¦
Can receive command class[3] = COMMAND_CLASS_SWITCH_MULTILEVEL ----------------------------+    ¦    ¦
Can receive command class[3] = COMMAND_CLASS_VERSION (fake) ------------------------------------+    ¦   
                      Checksum OK -------------------------------------------------------------------+
--]==]
		                 "06 01 04 01 60 01 XX 01 0C 00 49 84 " .. string.format("%02X", node_id) .. " 07 02 11 00 72 85 26 86 XX", -- Autoresponse,
		                 Kichler12387NodeInfoCallback,
		                 false, -- Not OneShot
		                 0, -- no timeout
						 "Kichler12387NodeInfo", -- label
						 false) -- no forward

		MonitorZWaveData(true, -- outgoing,
						 luup.device, -- peer_dev_num
		                 nil, -- No arm_regex
--[==[
41      07/17/17 7:52:58.995    0x1 0x9 0x0 0x13 0x40 0x2 0x86 0x11 0x25 0x5 0x10 (####@###%##) 
           SOF - Start Of Frame --+   ¦   ¦    ¦    ¦   ¦    ¦    ¦    ¦   ¦    ¦
                     length = 9 ------+   ¦    ¦    ¦   ¦    ¦    ¦    ¦   ¦    ¦
                        Request ----------+    ¦    ¦   ¦    ¦    ¦    ¦   ¦    ¦
           FUNC_ID_ZW_SEND_DATA ---------------+    ¦   ¦    ¦    ¦    ¦   ¦    ¦
Device 175=SD17-2 Breakfast workspace light --------+   ¦    ¦    ¦    ¦   ¦    ¦
                Data length = 2 ------------------------+    ¦    ¦    ¦   ¦    ¦
          COMMAND_CLASS_VERSION -----------------------------+    ¦    ¦   ¦    ¦
                    VERSION_GET ----------------------------------+    ¦   ¦    ¦
Xmit options = ACK | AUTO_ROUTE | Reserved bits : 0x20 ----------------+   ¦    ¦
                   Callback = 5 -------------------------------------------+    ¦
                    Checksum OK ------------------------------------------------+
--]==]
		                 "^01 09 00 13 " .. string.format("%02X", node_id) .. " 02 86 11 .. (..)", -- Main RegEx

--[==[
42      07/17/17 7:52:59.027    0x6 0x1 0x4 0x1 0x13 0x1 0xe8 (#######) 
              ACK - Acknowledge --+   ¦   ¦   ¦    ¦   ¦    ¦
           SOF - Start Of Frame ------+   ¦   ¦    ¦   ¦    ¦
                     length = 4 ----------+   ¦    ¦   ¦    ¦
                       Response --------------+    ¦   ¦    ¦
           FUNC_ID_ZW_SEND_DATA -------------------+   ¦    ¦
                     RetVal: OK -----------------------+    ¦
                    Checksum OK ----------------------------+
42      07/17/17 23:51:36.201   0x1 0x5 0x0 0x13 0x05 0x0 0x9d (####t##) 
           SOF - Start Of Frame --+   ¦   ¦    ¦    ¦   ¦    ¦
                     length = 5 ------+   ¦    ¦    ¦   ¦    ¦
                        Request ----------+    ¦    ¦   ¦    ¦
           FUNC_ID_ZW_SEND_DATA ---------------+    ¦   ¦    ¦
                   Callback = 5 --------------------+   ¦    ¦
           TRANSMIT_COMPLETE_OK ------------------------+    ¦
                    Checksum OK -----------------------------+
41      07/17/17 23:51:36.201   ACK: 0x6 (#) 
42      07/17/17 7:52:59.060    0x1 0xd 0x0 0x4 0x0 0x40 0x7 0x86 0x12 0x6 0x3 0x2a 0x5 0x29 0x26 (#\r###@#####*#)&) 
           SOF - Start Of Frame --+   ¦   ¦   ¦   ¦    ¦   ¦    ¦    ¦   ¦   ¦    ¦   ¦    ¦    ¦
                    length = 13 ------+   ¦   ¦   ¦    ¦   ¦    ¦    ¦   ¦   ¦    ¦   ¦    ¦    ¦
                        Request ----------+   ¦   ¦    ¦   ¦    ¦    ¦   ¦   ¦    ¦   ¦    ¦    ¦
FUNC_ID_APPLICATION_COMMAND_HANDLER ----------+   ¦    ¦   ¦    ¦    ¦   ¦   ¦    ¦   ¦    ¦    ¦
          Receive Status SINGLE ------------------+    ¦   ¦    ¦    ¦   ¦   ¦    ¦   ¦    ¦    ¦
Device 175=SD17-2 Breakfast workspace light -----------+   ¦    ¦    ¦   ¦   ¦    ¦   ¦    ¦    ¦
                Data length = 7 ---------------------------+    ¦    ¦   ¦   ¦    ¦   ¦    ¦    ¦
          COMMAND_CLASS_VERSION --------------------------------+    ¦   ¦   ¦    ¦   ¦    ¦    ¦
                 VERSION_REPORT -------------------------------------+   ¦   ¦    ¦   ¦    ¦    ¦
Z-Wave Library Type = SLAVE_ROUTING -------------------------------------+   ¦    ¦   ¦    ¦    ¦
Z-Wave Protocol Version = 3 -------------------------------------------------+    ¦   ¦    ¦    ¦
Z-Wave Protocol Sub-Version = 42 -------------------------------------------------+   ¦    ¦    ¦
        Application Version = 5 ------------------------------------------------------+    ¦    ¦
   Application Sub-Version = 41 -----------------------------------------------------------+    ¦
                    Checksum OK ----------------------------------------------------------------+
41      07/17/17 7:52:59.061    ACK: 0x6 (#) 
--]==]
		                 "06 01 04 01 13 01 XX 01 04 00 13 \\1 00 XX 01 0D 00 04 00 " .. string.format("%02X", node_id) .. " 07 86 12 06 03 2A 99 99 XX", -- Autoresponse,
		                 Kichler12387VersionCallback,
		                 false, -- Not OneShot
		                 0, -- no timeout
						 "Kichler12387Version", -- label
						 false) -- no forward

		MonitorZWaveData(true, -- outgoing,
						 luup.device, -- peer_dev_num
		                 nil, -- No arm_regex
--[==[
41      07/17/17 7:52:59.260    0x1 0xa 0x0 0x13 0x40 0x3 0x86 0x13 0x26 0x5 0x6 0x15 (#\n##@###&###) 
           SOF - Start Of Frame --+   ¦   ¦    ¦    ¦   ¦    ¦    ¦    ¦   ¦   ¦    ¦
                    length = 10 ------+   ¦    ¦    ¦   ¦    ¦    ¦    ¦   ¦   ¦    ¦
                        Request ----------+    ¦    ¦   ¦    ¦    ¦    ¦   ¦   ¦    ¦
           FUNC_ID_ZW_SEND_DATA ---------------+    ¦   ¦    ¦    ¦    ¦   ¦   ¦    ¦
Device 175=SD17-2 Breakfast workspace light --------+   ¦    ¦    ¦    ¦   ¦   ¦    ¦
                Data length = 3 ------------------------+    ¦    ¦    ¦   ¦   ¦    ¦
          COMMAND_CLASS_VERSION -----------------------------+    ¦    ¦   ¦   ¦    ¦
      VERSION_COMMAND_CLASS_GET ----------------------------------+    ¦   ¦   ¦    ¦
Requested Command Class = COMMAND_CLASS_SWITCH_MULTILEVEL -------------+   ¦   ¦    ¦
Xmit options = ACK | AUTO_ROUTE -------------------------------------------+   ¦    ¦
                   Callback = 6 -----------------------------------------------+    ¦
                    Checksum OK ----------------------------------------------------+
--]==]
		                 "^01 0A 00 13 " .. string.format("%02X", node_id) .. " 03 86 13 (..) .. (..) ..", -- Main RegEx
--[==[

42      07/17/17 7:52:59.306    0x6 0x1 0x4 0x1 0x13 0x1 0xe8 (#######) 
              ACK - Acknowledge --+   ¦   ¦   ¦    ¦   ¦    ¦
           SOF - Start Of Frame ------+   ¦   ¦    ¦   ¦    ¦
                     length = 4 ----------+   ¦    ¦   ¦    ¦
                       Response --------------+    ¦   ¦    ¦
           FUNC_ID_ZW_SEND_DATA -------------------+   ¦    ¦
                     RetVal: OK -----------------------+    ¦
                    Checksum OK ----------------------------+
41      07/17/17 7:52:59.307    ACK: 0x6 (#) 
42      07/17/17 23:51:36.660   0x1 0x5 0x0 0x13 0x06 0x0 0x9c (####u##) 
           SOF - Start Of Frame --+   ¦   ¦    ¦    ¦   ¦    ¦
                     length = 5 ------+   ¦    ¦    ¦   ¦    ¦
                        Request ----------+    ¦    ¦   ¦    ¦
           FUNC_ID_ZW_SEND_DATA ---------------+    ¦   ¦    ¦
                   Callback = 6 --------------------+   ¦    ¦
           TRANSMIT_COMPLETE_OK ------------------------+    ¦
                    Checksum OK -----------------------------+
41      07/17/17 23:51:36.660   ACK: 0x6 (#) 42      
        07/17/17 7:52:59.339    0x1 0xa 0x0 0x4 0x0 0x40 0x4 0x86 0x14 0x26 0x1 0x0 (#\n###@###&##) 
           SOF - Start Of Frame --+   ¦   ¦   ¦   ¦    ¦   ¦    ¦    ¦    ¦   ¦   ¦
                    length = 10 ------+   ¦   ¦   ¦    ¦   ¦    ¦    ¦    ¦   ¦   ¦
                        Request ----------+   ¦   ¦    ¦   ¦    ¦    ¦    ¦   ¦   ¦
FUNC_ID_APPLICATION_COMMAND_HANDLER ----------+   ¦    ¦   ¦    ¦    ¦    ¦   ¦   ¦
          Receive Status SINGLE ------------------+    ¦   ¦    ¦    ¦    ¦   ¦   ¦
Device 175=SD17-2 Breakfast workspace light -----------+   ¦    ¦    ¦    ¦   ¦   ¦
                Data length = 4 ---------------------------+    ¦    ¦    ¦   ¦   ¦
          COMMAND_CLASS_VERSION --------------------------------+    ¦    ¦   ¦   ¦
   VERSION_COMMAND_CLASS_REPORT -------------------------------------+    ¦   ¦   ¦
Requested Command Class = COMMAND_CLASS_SWITCH_MULTILEVEL ----------------+   ¦   ¦
      Command CLass Version = 1 ----------------------------------------------+   ¦
                    Checksum OK --------------------------------------------------+
41      07/17/17 7:52:59.340    ACK: 0x6 (#) 
--]==]
		                 "06 01 04 01 13 01 XX 01 05 00 13 \\2 00 XX 01 0A 00 04 00 " .. string.format("%02X", node_id) .. " 04 86 14 \\1 01 XX", -- Autoresponse,
		                 Kichler12387CommandClassVersionCallback,
		                 false, -- Not OneShot
		                 0, -- no timeout
						 "Kichler12387CommandClassVersion", -- label
						 false) -- no forward

	end

	-- This is a hack for UI7 1.7.2608 mishandling of the Shlage BE469 lock. It is incorrectly sending a Command Cleass Version, Version Command Class Get in non-secure mode.
	local function ApplySchageLockHack(device_num, node_id)
		DEntry()

		local function ShlageLockVersionCallback(peer_dev_num, result)
			log("Shlage lock version intercept: device num=".. device_num.." node_id="..node_id.. "result=".. tableToString(result));
		end

		MonitorZWaveData(true, -- outgoing,
						 luup.device, -- peer_dev_num
		                 nil, -- No arm_regex
--[==[
                                              C1                               C2
41      04/02/17 15:21:37.647   0x1 0xa 0x0 0x13 0xba 0x3 0x86 0x13 0x71 0x5 0xc7 0x79 (#\n######q##y) 
           SOF - Start Of Frame --+   ¦   ¦    ¦    ¦   ¦    ¦    ¦    ¦   ¦    ¦    ¦
                    length = 10 ------+   ¦    ¦    ¦   ¦    ¦    ¦    ¦   ¦    ¦    ¦
                        Request ----------+    ¦    ¦   ¦    ¦    ¦    ¦   ¦    ¦    ¦
           FUNC_ID_ZW_SEND_DATA ---------------+    ¦   ¦    ¦    ¦    ¦   ¦    ¦    ¦
     Device 548=Front Door Lock --------------------+   ¦    ¦    ¦    ¦   ¦    ¦    ¦
                Data length = 3 ------------------------+    ¦    ¦    ¦   ¦    ¦    ¦
          COMMAND_CLASS_VERSION -----------------------------+    ¦    ¦   ¦    ¦    ¦
      VERSION_COMMAND_CLASS_GET ----------------------------------+    ¦   ¦    ¦    ¦
Requested Command Class = COMMAND_CLASS_ALARM -------------------------+   ¦    ¦    ¦
Xmit options = ACK | AUTO_ROUTE -------------------------------------------+    ¦    ¦
                 Callback = 199 ------------------------------------------------+    ¦
                    Checksum OK -----------------------------------------------------+
--]==]
		                 "^01 .. 00 (..) " .. string.format("%02X", node_id) .. " 03 86 13 71 .. (..) ..", -- Main RegEx
--[==[
42      04/02/17 15:21:37.331   0x6 0x1 0x4 0x1 0x13 0x1 0xe8 (#######) 
              ACK - Acknowledge --+   ¦   ¦   ¦    ¦   ¦    ¦
           SOF - Start Of Frame ------+   ¦   ¦    ¦   ¦    ¦
                     length = 4 ----------+   ¦    ¦   ¦    ¦
                       Response --------------+    ¦   ¦    ¦
           FUNC_ID_ZW_SEND_DATA -------------------+   ¦    ¦
                     RetVal: OK -----------------------+    ¦
                    Checksum OK ----------------------------+
42      04/02/17 15:21:37.331   got expected ACK 
41      04/02/17 15:21:37.332   ACK: 0x6 (#) 

42      04/02/17 15:21:37.409   0x1 0x5 0x0 0x13 0xc6 0x0 0x2f (######/) 
           SOF - Start Of Frame --+   ¦   ¦    ¦    ¦   ¦    ¦
                     length = 5 ------+   ¦    ¦    ¦   ¦    ¦
                        Request ----------+    ¦    ¦   ¦    ¦
           FUNC_ID_ZW_SEND_DATA ---------------+    ¦   ¦    ¦
                 Callback = 198 --------------------+   ¦    ¦
           TRANSMIT_COMPLETE_OK ------------------------+    ¦
                    Checksum OK -----------------------------+
41      04/02/17 15:21:37.410   ACK: 0x6 (#) 
42      04/02/17 15:21:37.631   0x1 0xa 0x0 0x4 0x0 0xba 0x4 0x86 0x14 0x71 0x1 0xbd 
           SOF - Start Of Frame --+   ¦   ¦   ¦   ¦    ¦   ¦    ¦    ¦   ¦    ¦    ¦
                    length = 10 ------+   ¦   ¦   ¦    ¦   ¦    ¦    ¦   ¦    ¦    ¦
                        Request ----------+   ¦   ¦    ¦   ¦    ¦    ¦   ¦    ¦    ¦
FUNC_ID_APPLICATION_COMMAND_HANDLER ----------+   ¦    ¦   ¦    ¦    ¦   ¦    ¦    ¦
          Receive Status SINGLE ------------------+    ¦   ¦    ¦    ¦   ¦    ¦    ¦
     Device 548=Front Door Lock -----------------------+   ¦    ¦    ¦   ¦    ¦    ¦
                Data length = 4 ---------------------------+    ¦    ¦   ¦    ¦    ¦
          COMMAND_CLASS_VERSION --------------------------------+    ¦   ¦    ¦    ¦
   VERSION_COMMAND_CLASS_REPORT -------------------------------------+   ¦    ¦    ¦
Requested Command Class = COMMAND_CLASS_ALARM ---------------------------+    ¦    ¦
                    Version = 1 ----------------------------------------------+    ¦
                    Checksum OK ---------------------------------------------------+
--]==]
		                 "06 01 04 01 \\1 01 XX 01 05 00 \\1 \\2 00 XX 01 0A 00 04 00 " .. string.format("%02X", node_id) .. " 04 86 14 71 01 XX", -- Autoresponse,
		                 ShlageLockVersionCallback,
		                 false, -- Not OneShot
		                 0, -- no timeout
						 "ShlageLockVersion", -- label
						 false) -- no forward
	end

	local function ApplyLuaUPnPAutoRouteNoACKFix()
		local function AutoRoutNoAckCallback(peer_dev_num, result)
			log("AutoRouteNoAckk Callback: peer_dev_num=".. peer_dev_num.." result=".. tableToString(result));
		end
		MonitorZWaveData(true, -- outgoing,
						 luup.device, -- peer_dev_num
		                 nil, -- No arm_regex
--[==[
41      11/24/17 21:25:33.043   0x1 0xa 0x0 0x13 0xc 0x3 0x25 0x1 0x0 0x4 0x37 0xfe (#\n####%###7#) 
           SOF - Start Of Frame --+   ¦   ¦    ¦   ¦   ¦    ¦   ¦   ¦   ¦    ¦    ¦
                    length = 10 ------+   ¦    ¦   ¦   ¦    ¦   ¦   ¦   ¦    ¦    ¦
                        Request ----------+    ¦   ¦   ¦    ¦   ¦   ¦   ¦    ¦    ¦
           FUNC_ID_ZW_SEND_DATA ---------------+   ¦   ¦    ¦   ¦   ¦   ¦    ¦    ¦
  Device 5=Leviton Combo Switch -------------------+   ¦    ¦   ¦   ¦   ¦    ¦    ¦
                Data length = 3 -----------------------+    ¦   ¦   ¦   ¦    ¦    ¦
    COMMAND_CLASS_SWITCH_BINARY ----------------------------+   ¦   ¦   ¦    ¦    ¦
              SWITCH_BINARY_SET --------------------------------+   ¦   ¦    ¦    ¦
                    Value = OFF ------------------------------------+   ¦    ¦    ¦
      Xmit options = AUTO_ROUTE ----------------------------------------+    ¦    ¦
                  Callback = 55 ---------------------------------------------+    ¦
                    Checksum OK --------------------------------------------------+
--]==]
		                 "^01 .. 00 13 .+ 04 (..) ..$", -- Main RegEx
--[==[
42      11/24/17 21:25:33.086   0x6 0x1 0x4 0x1 0x13 0x1 0xe8 (#######) 
              ACK - Acknowledge --+   ¦   ¦   ¦    ¦   ¦    ¦
           SOF - Start Of Frame ------+   ¦   ¦    ¦   ¦    ¦
                     length = 4 ----------+   ¦    ¦   ¦    ¦
                       Response --------------+    ¦   ¦    ¦
           FUNC_ID_ZW_SEND_DATA -------------------+   ¦    ¦
                     RetVal: OK -----------------------+    ¦
                    Checksum OK ----------------------------+
42      11/24/17 21:25:33.087   got expected ACK 
41      11/24/17 21:25:33.087   ACK: 0x6 (#) 

42      11/24/17 21:25:33.127   0x1 0x7 0x0 0x13 0x37 0x0 0x0 0x1 0xdd (####7####) 
           SOF - Start Of Frame --+   ¦   ¦    ¦    ¦   ¦ +-----+    ¦
                     length = 7 ------+   ¦    ¦    ¦   ¦    ¦       ¦
                        Request ----------+    ¦    ¦   ¦    ¦       ¦
           FUNC_ID_ZW_SEND_DATA ---------------+    ¦   ¦    ¦       ¦
                  Callback = 55 --------------------+   ¦    ¦       ¦
           TRANSMIT_COMPLETE_OK ------------------------+    ¦       ¦
                 Tx Time = 1 ms -----------------------------+       ¦
                    Checksum OK -------------------------------------+
41      11/24/17 21:25:33.128   ACK: 0x6 (#) 

--]==]
		                 "06 01 04 01 13 01 XX 01 07 00 13 \\1 00 00 00 XX", -- Autoresponse,
		                 nil, -- AutoRoutNoAckCallback,
		                 false, -- Not OneShot
		                 0, -- no timeout
						 "AutoRouteNoAck", -- label
						 false) -- no forward
	end

	for device_num, device in pairs(luup.devices) do
		if device.device_type == "urn:schemas-gengen_mcv-org:device:SceneControllerEvolveLCD:1" then
			local impl = luup.attr_get("impl_file", device_num)  
			if impl == "I_EvolveLCD1.xml" then
			  	reload_needed = "I_EvolveLCD1.xml"
			  	log("Updating the implementation file of the existing Evolve LCD1 peer device: ", device_num)
			  	luup.attr_set("impl_file", "I_GenGenSceneController.xml", device_num);
			end
		elseif device.device_type == "urn:schemas-gengen_mcv-org:device:SceneControllerCooperRFWC5:1" then
			local impl = luup.attr_get("impl_file", device_num) 
			if impl == "I_CooperRFWC5.xml" then
				reload_needed = "I_CooperRFWC5.xml"
			  	log("Updating the implementation file of the existing Cooper RFWC5 peer device: ", device_num)
			  	luup.attr_set("impl_file", "I_GenGenSceneController.xml", device_num);
			end
		elseif device.device_num_parent and
			luup.devices[device.device_num_parent] and
			luup.devices[device.device_num_parent].device_type == "urn:schemas-micasaverde-com:device:ZWaveNetwork:1" then
	  		local manufacturer_info = luup.variable_get("urn:micasaverde-com:serviceId:ZWaveDevice1", "ManufacturerInfo", device_num)
			local capabilities = luup.variable_get("urn:micasaverde-com:serviceId:ZWaveDevice1", "Capabilities", device_num)
			DLog("device_num=",device_num," name=",device.description," manufacturer_info=",manufacturer_info," capabilities=",capabilities);
		  	if manufacturer_info == "275,17750,19506" then
	        	if device.device_type ~= 'urn:schemas-gengen_mcv-org:device:SceneControllerEvolveLCD:1' then
					AdoptEvolveLCD1(device_num)
			  		reload_needed = "Evolve LCD1 adopted"
				end
			elseif manufacturer_info == "26,22349,0" then
				if device.device_type ~= "urn:schemas-gengen_mcv-org:device:SceneControllerCooperRFWC5:1" then
					AdoptCooperRFWC5(device_num)
		 			reload_needed = "Cooper RFWC5 adopted"
				end 
			elseif manufacturer_info == "376,21315,18229" then
				if device.device_type ~="urn:schemas-gengen_mcv-org:device:SceneControllerNexiaOneTouch:1" then
					AdoptNexiaOneTouch(device_num)
					reload_needed = "Nexia One Touch adopted"
	  			end
			elseif manufacturer_info == "59,25409,20548" or capabilities == "83,220,0,4,64,3,R,B,RS,W1,|32S,34,93S,98S,99S,112S,113S,114,122,128S,133S,134,152," then
				ApplySchageLockHack(device_num, device.id)
			elseif capabilities == "146,150,0,2,17,0,L,B,|38,114,133," then
				ApplyKichler12387Hack(device_num, device.id)
			end
		end
	end	-- for device_num

	local function NexiaManufacturerCallback(peer_dev_num, result)
		DEntry()

		local time = tonumber(result.time)
		local receiveStatus = tonumber(result.C1, 16)
		local node_id = tonumber(result.C2, 16)
		local device_num = NodeIdToDeviceNumber(node_id)
		DEntry("NexiaManufacturerCallback")
		if device_num and CheckDups(device_num, time, receiveStatus, "72050178534347359e"..result.C2) then
			local device = luup.devices[device_num]
			if device and device.device_type ~= "urn:schemas-gengen_mcv-org:device:SceneControllerNexiaOneTouch:1" then
				AdoptNexiaOneTouch(device_num)
				log("Nexia One Touch adopted. Reloading LuaUPnP.")
				luup.call_action(HAG_SID, "Reload", {}, 0)
			end
		end
	end

	-- The Nexia One Touch may show up as a "Generic IO" device if it was included before the plug-in was installed
	-- because UI7 gets confused by the devices's response to the COMMAND_CLASS_ASSOCIATION_GRP_INFO/ASSOCIATION_GROUP_INFO_GET command  
--[==[
                                                 C1  C2
42      02/25/17 15:55:45.857   0x1 0xe 0x0 0x4 0x0 0xf 0x8 0x72 0x5 0x1 0x78 0x53 0x43 0x47 0x35 0x9e (#######r##xSCG5#) 
           SOF - Start Of Frame --+   ¦   ¦   ¦   ¦   ¦   ¦    ¦   ¦ +------+ +-------+ +-------+    ¦
                    length = 14 ------+   ¦   ¦   ¦   ¦   ¦    ¦   ¦    ¦         ¦         ¦        ¦
                        Request ----------+   ¦   ¦   ¦   ¦    ¦   ¦    ¦         ¦         ¦        ¦
FUNC_ID_APPLICATION_COMMAND_HANDLER ----------+   ¦   ¦   ¦    ¦   ¦    ¦         ¦         ¦        ¦
          Receive Status SINGLE ------------------+   ¦   ¦    ¦   ¦    ¦         ¦         ¦        ¦
          Device 10=_Generic IO ----------------------+   ¦    ¦   ¦    ¦         ¦         ¦        ¦
                Data length = 8 --------------------------+    ¦   ¦    ¦         ¦         ¦        ¦
COMMAND_CLASS_MANUFACTURER_SPECIFIC ---------------------------+   ¦    ¦         ¦         ¦        ¦
   MANUFACTURER_SPECIFIC_REPORT -----------------------------------+    ¦         ¦         ¦        ¦
  Manufacturer Id = Nexia (376) ----------------------------------------+         ¦         ¦        ¦
       Product Type Id = 0x5343 --------------------------------------------------+         ¦        ¦
            Procuct Id = 0x4735 ------------------------------------------------------------+        ¦
                    Checksum OK ---------------------------------------------------------------------+
--]==]
	MonitorZWaveData(false, -- incoming,
					 luup.device, -- peer_dev_num
	                 nil, -- No arm_regex
	                 "^01 .. 00 04 (..) (..) .. 72 05 01 78 53 43 47 35", -- Main RegEx
	                 nil, -- no response,
	                 NexiaManufacturerCallback,
	                 false, -- Not OneShot
	                 0, -- no timeout
					 "NexiaManufacturer", -- label
					 false ) -- not forward

	if luup.version_major < 7 then -- UI5 only.
    -- In response to a Version Get command, the Nexisa One-Touch returns a Z-Wave protocol version 4, sub-version 32
    -- which is not even in the official Z-Wave version list and certainly confuses UI5. We create a forwarding monitor
    -- which returns a (false) version which at least UI5 can handle.
--[==[								  C1		  C2  C3  C4				     C5  C6  C7
42      03/04/17 14:19:17.494   0x1 0x11 0x0 0x4 0x0 0xf 0xb 0x86 0x12 0x6 0x4 0x20 0x1 0x0 0x1 0x1 0x1 0x1a 0x42 (########### ######B) 
           SOF - Start Of Frame --+    ¦   ¦   ¦   ¦   ¦   ¦    ¦    ¦   ¦   ¦    ¦   ¦   ¦ +--------------+    ¦
                    length = 17 -------+   ¦   ¦   ¦   ¦   ¦    ¦    ¦   ¦   ¦    ¦   ¦   ¦        ¦            ¦
                        Request -----------+   ¦   ¦   ¦   ¦    ¦    ¦   ¦   ¦    ¦   ¦   ¦        ¦            ¦
FUNC_ID_APPLICATION_COMMAND_HANDLER -----------+   ¦   ¦   ¦    ¦    ¦   ¦   ¦    ¦   ¦   ¦        ¦            ¦
          Receive Status SINGLE -------------------+   ¦   ¦    ¦    ¦   ¦   ¦    ¦   ¦   ¦        ¦            ¦
          Device 49=_Generic IO -----------------------+   ¦    ¦    ¦   ¦   ¦    ¦   ¦   ¦        ¦            ¦
               Data length = 11 ---------------------------+    ¦    ¦   ¦   ¦    ¦   ¦   ¦        ¦            ¦
          COMMAND_CLASS_VERSION --------------------------------+    ¦   ¦   ¦    ¦   ¦   ¦        ¦            ¦
                 VERSION_REPORT -------------------------------------+   ¦   ¦    ¦   ¦   ¦        ¦            ¦
Z-Wave Library Type = SLAVE_ROUTING -------------------------------------+   ¦    ¦   ¦   ¦        ¦            ¦
Z-Wave Protocol Version = 4 -------------------------------------------------+    ¦   ¦   ¦        ¦            ¦
Z-Wave Protocol Sub-Version = 32 -------------------------------------------------+   ¦   ¦        ¦            ¦
        Application Version = 1 ------------------------------------------------------+   ¦        ¦            ¦
    Application Sub-Version = 0 ----------------------------------------------------------+        ¦            ¦
                         ?data? -------------------------------------------------------------------+            ¦
                    Checksum OK --------------------------------------------------------------------------------+
	convert version 4, subversion 32 to version 3, subversion 28 (Z-Wave 5.03.00)
--]==]
		local function NexiaVersionCallback(peer_dev_num, result)
			DEntry("NexiaVersionCallback")
		end

		MonitorZWaveData(false, -- incoming,
						 luup.device, -- peer_dev_num
		                 nil, -- No arm_regex
		                 "^01 (..) 00 04 (..) (..) (..) 86 12 06 04 (..) (..) (..)", -- Main RegEx
		                 "01 0D 00 04 \\2 \\3 07 86 12 06 03 1C \\6 \\7 XX", -- Forwarded response,
		                 NexiaVersionCallback,
		                 false, -- Not OneShot
		                 0, -- no timeout
						 "NexiaVersion", -- label
						 true) -- forward
	end

	-- UI7 sometimes sends Z-Wave commands twice with xmit option AUTO_ROUTE and then again with ACK | AURO_ROUTE
	-- Only the second of these is valid.
	ApplyLuaUPnPAutoRouteNoACKFix()
end

-- returns first, updated
-- First is true if we are the lowest device number installer
-- updated is true if the installer has been updated since the last execution.
function IsFirstAndLatestInstallerVersion(our_dev_num, our_version)
	DEntry()
	local version = 0;
	local count = 0;
	local our_index = 0;
	local sorted = {}
	local ourVerStr = luup.variable_get(GENGENINSTALLER_SID, "Version", our_dev_num)
	local updated = not ourVerStr or tonumber(ourVerStr) ~= our_version
	if updated then
		luup.variable_set(GENGENINSTALLER_SID, "Version", our_version, our_dev_num)
	end
	for dev_num, v in pairs(luup.devices) do
		table.insert(sorted,dev_num)
	end
	table.sort(sorted)
	for i = 1, #sorted do
		local dev_num = sorted[i];
		if dev_num == our_dev_num then
			our_index = i
		end
		if luup.devices[dev_num].device_type == GENGENINSTALLER_DEVTYPE then
			local verStr = luup.variable_get(GENGENINSTALLER_SID, "Version", dev_num)
			local ver = tonumber(verStr)
			if ver then
				if our_index == 0 then
					return false, false -- We found another installer device before we found us.
				end
			end
		end
	end
	return true, updated
end

function DeleteOldInstallers(our_dev_num)
	DEntry()
	for dev_num, v in pairs(luup.devices) do
		if dev_num ~= our_dev_num and
		   (v.device_type == "urn:schemas-gengen_mcv-org:device:SceneControllerEvolveLCD1Installer:1" or
		    v.device_type == "urn:schemas-gengen_mcv-org:device:SceneControllerEvolveLCDFinder:1" or
		    v.device_type == "urn:schemas-gengen_mcv-org:device:SceneControllerCooperRFWC5Installer:1") then
			log("Removing older installer: device ID ", dev_num)
			luup.call_action(HAG_SID,"DeleteDevice", {DeviceNum = dev_num}, 0);
			-- Delete only one at a time. We will reload the luup engine for more.
			return true
		end
	end
	return false
end

local nixio = require("nixio")

function SceneControllerInstaller_Init(lul_device)
  -- First, delete any stale global lock. Note that there may be a race condition
  -- here if another device just took it but we will live with that.
  give_global_lock()

  -- Now, make sure that we are the latest version of this installer
  -- And if there is more than one of us, that we are the lowest numbered device.
  -- Otherwise delete ourselves.
  local first, updated = IsFirstAndLatestInstallerVersion(lul_device, GenGenInstaller_Version)
  if not first then
	log("Removing superfluous installer: device ID ", lul_device)
	luup.call_action(HAG_SID,"DeleteDevice", {DeviceNum = lul_device}, 0);
	return
  end

  -- Now look for older installers with different names and delete them one at a time
  if DeleteOldInstallers(lul_device) then
	log("Older installer deleted. Reloading LuaUPnP.")
	luup.call_action(HAG_SID, "Reload", {}, 0)
	return
  end

  luup.attr_set("invisible","1",lul_device)

  if luup.job_watch then
	luup.job_watch("SceneController_JobWatchCallBack") -- Watch jobs on all devices.
  else
	DLog("luup.job_watch does not exist")
  end

  function b642bin(str)
  	return nixio.bin.b64decode(string.gsub(str, "%s+", ""))
  end

  -- The custom icons gets written to different places depending on UI5 or UI7
  local EvolveLCD1Icon = b642bin([[
	iVBORw0KGgoAAAANSUhEUgAAADMAAAAzCAYAAAA6oTAqAAAAAXNSR0IArs4c6QAAAARnQU1BAACx
	jwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAsBJREFU
	aEPtmr9LG2EYx+MQcBSyZnB0lC6uDgr+DV20i3Mnl4LGQQKCZGnToUOGzmKhUB3EBAKJBSFOPapD
	CA5XqBDokKhp+PZ9bAPXu/d673vvj7ymeeEhkNy993zueZ7v8957mclwRjabxerqSmZp6Rnv57F+
	53lXmcPDD5nBYDAj5Mj6+nOcnLyG71dwe/vRGfP99zg7e4PNzRcQAqGDSqV99HqfAPxk5tbo9U5B
	/knBPDx8dYvijzfk1xTGxdBMIzOtGQt5qSXNhsMhut2ustE8KkMLTKfTQf28jsZlI7XR+TSPytAC
	0263cf79Ghf4kdqa376A5lEZ2mA+d28YCFIb3YwITL8PrK2BtfS/bWeHy2wEplAoPEIlfQbhuTDV
	KrC8HHWc4DjDCIwIyAh0BOQsTFJEwiAExIVhConFxWialUp2IyNbP1wYSTUwlmbaYHwfoNoJGgmD
	jZoRTTGhmiEQSjMSgaCRwpmGkQUJAjkpALJAqdRsfv4JRoZc3tiIqtnRkXkY2aJPbJoTp2atFkDL
	l6BR/zEtAME7nVQ74ShyBYAWnqRmYRj6zibMv5Y0vHR0Us1GjmqJTLP5OzLhpmlDzcJ3PA5IODKU
	SsVitGkSnO00k1G3/2NtVqlEI0MKZzMySTUjtDYjp3k1MzdnD0YWJPZ5ZqKeND0PWFiI9plxqJkW
	AaDohJtmzC6O+w9nEuszIzDaaiauzxwf2xMAbbszcSuA2Vl7MNoiM1FqRoVOyhXeAxjHqlmLmhFQ
	eKFp+nmmfsneArTZW4CURuc7sXHeZ/tY5Iiq0TwqQ4s0qzig89wpzES+oK3Vao9ZEvepM4VE5lJO
	M5eAlGFE7pitY1LB3N01bPkndZ37+5bcH4G2tl7C896yi5wyk+nxpo+tsj73Dru7r8T/opXL5bC3
	t41yueycHRwUkc/nuTC/AJpOW5HRBwJ9AAAAAElFTkSuQmCC
  ]])

  local CooperRFWC5Icon = b642bin([[
	iVBORw0KGgoAAAANSUhEUgAAADMAAAAzCAIAAAC1w6d9AAAAAXNSR0IArs4c
	6QAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUw
	AADqYAAAOpgAABdwnLpRPAAAA0ZJREFUWEfNmU1PGlEUhu3GH4D8ja6aELf+
	ADfuunHZxDUJanTXNSQmFGsHW7EjDFId0Fqd8v1hIxYC2EZrCLY2MV1oTNqm
	0TYm01ennVjRK1wO5Z5MWDBzh4dzzz3nvPfe0XW962b7fmGMB7hvdXd3W61W
	1nCQ3WRbW1t2u91ms91tg42NjWmaxvj1LsY9SZIsFouqqklqi0ajbrd7eHiY
	k8zhcPT29jIGc98ql8sej2dwcFA4MkUJSNITArKfv3S7R//4hdtH/ww8PDz0
	++Xn8oxwZKlUMpV9RUNG46uLtxwfH/sDcvVTQSyys7Oz+VCw9C5T+1xslay/
	v/+gAdvZ2dlswCKRcCz5Elitko2MjIyPj0casEQicStYPB4PKLKB1SoZYT47
	PT0NKP73u2+EI1PVxUIpZWKJ4rN8fiMa/xNe9D47OOJMHfv7+wuLwcveooyz
	bz/0ew/0ZIkHDoXISBNXrlazhlnRC7s6alSztre3p4bn67E6HGfIq3Nz8uX1
	KMoKqFar4aUX1zqswz5bW1td33htkMFzyBrFSppmbaLndDqdaPH4bGrqMSo3
	ULTYsm/Wh5QWCs0rytyHWr6TPjOnEt4Clrl0stlsIr3SSTKUUS0WAQEmEd4y
	yczvybJGs/kiFotl1tdEJFtaiuQL8baToTShBmibTTgOwW6sxLbPJrBQoxo3
	s7loO1njTMaT4saZIZD+x2w26zMog+WVBZAh2hBz9FmDrVAYwiSXyz19Nv23
	FZtFgjWEgs83Q6CdUJ1GR0cZAoUtTLxeabu6ATh8Iu8j8eKqbOcoO8dmp9J4
	PpvNJNLnoSZcf2bsX4hIBrfd1GpTVnQ+hdL2brsVhVKvNIlXAJ9CwYQi2pSg
	32ghRdEB5oqu1WpqOCQiGRDL5dKqdt5I0ugAwh0XwGUy6WRmlYYMu1QTExN8
	8uTaUd5pSYgaUF85zK1QynzGV6DqRxUKbyHyRCQzCwONdjr6qt9/qCOlkZhR
	GGjIsAvkDJKdVODvQVlNTk4SnFSQuOryS6DgWzp3crlcPT09Jycn5GTYwHI/
	cg8NDTHezDpFxNnhwMAAjki5j1cZA/v6+mRZ5iTDP6tUKrdu9PM9UCwWsRXP
	IPsNKYKZWIf5r+wAAAAASUVORK5CYII=
  ]])

  local NexiaOneTouchIcon = b642bin([[
	iVBORw0KGgoAAAANSUhEUgAAADMAAAAzCAYAAAA6oTAqAAAAAXNSR0IArs4c
	6QAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUw
	AADqYAAAOpgAABdwnLpRPAAAAAlwSFlzAAAHsAAAB7AB1IKDYgAAA7xJREFU
	aEPtms9LG0EUx+PBv8Crf0U9iDcP9ejJk71IL96EnrwUigpSKQShrRbREtGm
	Na1pQwJBMSa2iUkqsaapNKSFBhEbISGBUPPDKN/u21ZIdicms7tZV3TgkWVn
	dvM+8+Z9Z3Z220yM0t7ejr6+u6bu7jus6is9F4//MNntDlOlUmlrypGhoXtY
	W3uOVMqCTMZlGEulluH1zmB4+D6aAqFG09NPUCi4AZwJZqxSKHhA/nHBnJ4m
	jEXx3xvy6xbGiKG5jcxtzugwLjUZZufn58jlcqqN7qOmaAJzcHAAf9iPYDSo
	2Oh6uo+aoglMMplEOP0TEeQVW+j4O+g+aopmMJ9zhwIIFBt1hhSmXC5jZGQE
	XV1dNTY3N8dkbinM2NiYCFfvtxqeBROJRIS11rDMcYJjlZbB8IAQlKFhLovI
	BWijyOTzeQwODsqGmdVq1TcyvPnDigyvGLRsmGkFk8lkQLlTbSQMuuaMFjAE
	QsOMRKDaSOF0h+ERAUMLAA8Ir5r19/dfv8iQx9Qp0knT5/PpD8OTNzdCzRKJ
	BGj5Um00/+giAI1ypV49KzJHR0eimklh6FzLYZSC8AqAbmszpUCsyMRiMTEy
	0knzStRMCwGwWCyySZPgWj7MeJyXtr0RauZ0OmWRIYXTNTLN5s5FhFiRIadZ
	OdPb26sfTLMg1c8113ptJn1AY8HQnsDAwIBsnrm2akbKJZ00aTLVNWd4lc1w
	asabK9Xt68Gw5pnt7W19IqMUiGcF0NPT03oYpSB0naHVbKdSwcbhv11ObyqF
	ULEIOrcuKBQrn+qtmkm5pHsAuqyaq52ct9sxPjEBq9eLyakpPFtcxCuPRzxe
	8ftlQPVyhpRLutBs+fOMPyq8BUgKbwH+26pnFeanZni+Cm+AZ6bhDDix+W1T
	PF7fXa9pS9fQ9YbYOC8KQ4gcUWt0HzVFk03AbDYLsnolnU5fWl8qlVBvIuSB
	Uw0TCoVhtb4WjfWc4fcH8GbFJtZHo1GZbwRqsSzC/v4DbDYbzs6UfyyhGoaW
	Gr8zf0STvjchxxYWXop1vw7TWFpalsFsbX1EcGcPx9ki3GsbiMfjPMGoaasa
	xuFwwPcpKJrL5ZI5Qr0dCO3CuxWA202fqdQWct729h2+xBJi9C4bro0oVcOc
	nJyAepeMxr60XNSHw2FmPbXf398XQdXmjWqYRr2lZ70imFIpqKePTf9XubzH
	9yHQ6OgDIUlfCH/gEYx3od/K9j5hnpvH+PjD5j/R6ujowOTkI8zOzhrOzObH
	6OzsZML8BfhiHhlJtrqcAAAAAElFTkSuQmCC
  ]])

  -- Install Z-Wave interceptor (zwint)
  local zwint_so_version = 1.05
  local zwint_so
  if UseDebugZWaveInterceptor then
    -- zwint debug version
    zwint_so = b642bin([[
    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
    AABIAgAAQDcAAAAAAAASAAAAcAEAADA3AAAAAAAAEgAAAEACAAAgNwAAAAAAABIAAAAmAgAAEDcA
    AAAAAAASAAAA9wEAAAA3AAAAAAAAEgAAAPQAAADwNgAAAAAAABIAAAAIAgAA4DYAAAAAAAASAAAA
    MwIAANA2AAAAAAAAEgAAADsCAADANgAAAAAAABIAAABQAAAAsDYAAAAAAAASAAAA1QEAAKA2AAAA
    AAAAEgAAAEsBAACQNgAAAAAAABIAAADrAAAAgDYAAAAAAAASAAAAWwEAAHA2AAAAAAAAEgAAAIoB
    AABgNgAAAAAAABIAAAC8AAAAUDYAAAAAAAASAAAAkQEAAEA2AAAAAAAAEgAAAJYAAAAwNgAAAAAA
    ABIAAACLAgAAIDYAAAAAAAASAAAA8AEAABA2AAAAAAAAEgAAAHwCAAAANgAAAAAAABIAAABGAQAA
    8DUAAAAAAAASAAAAJgAAAAAAAAAAAAAAIgAAAIEBAADgNQAAAAAAABIAAAAQAQAA0DUAAAAAAAAS
    AAAA4AAAAMA1AAAAAAAAEgAAAHgBAACwNQAAAAAAABIAAADIAAAAoDUAAAAAAAASAAAAqQEAAJA1
    AAAAAAAAEgAAAK4AAACANQAAAAAAABIAAAAUAgAAcDUAAAAAAAASAAAAyAEAAGA1AAAAAAAAEgAA
    AKIBAABQNQAAAAAAABIAAABoAAAAQDUAAAAAAAASAAAAAF9HTE9CQUxfT0ZGU0VUX1RBQkxFXwBf
    Z3BfZGlzcABfZmluaQBfX2N4YV9maW5hbGl6ZQBfSnZfUmVnaXN0ZXJDbGFzc2VzAHN0ZGVycgBm
    cHJpbnRmAGx1YV9wdXNoaW50ZWdlcgBjbG9ja19nZXR0aW1lAGZ0aW1lAGxvY2FsdGltZV9yAHJl
    Z2ZyZWUAZnB1dHMAc29ja2V0AF9fZXJybm9fbG9jYXRpb24AY29ubmVjdABjbG9zZQBsdWFfcHVz
    aG5pbABzdHJlcnJvcgBsdWFfcHVzaHN0cmluZwBsdWFfZ2V0dG9wAGx1YV90eXBlAGx1YV9pc2lu
    dGVnZXIAbHVhTF9hcmdlcnJvcgBsdWFfdG9pbnRlZ2VyAHB0aHJlYWRfbXV0ZXhfbG9jawBwdGhy
    ZWFkX211dGV4X3VubG9jawBkdXAyAGx1YV9wdXNoYm9vbGVhbgBsdWFfdG9sc3RyaW5nAHN0cmNt
    cABvcGVuZGlyAHNucHJpbnRmAHJlYWRsaW5rAHN0cnRvbAByZWFkZGlyAGNsb3NlZGlyAHN0cmNw
    eQBwdGhyZWFkX2NyZWF0ZQBzb2NrZXRwYWlyAG9wZW4AbHVhX2lzbnVtYmVyAHdyaXRlAGx1YV90
    b2Jvb2xlYW4Ac3RybGVuAG1hbGxvYwByZWdjb21wAHJlZ2Vycm9yAF9fZmxvYXRzaWRmAF9fZGl2
    ZGYzAF9fYWRkZGYzAGdldHRpbWVvZmRheQBzdHJuY3B5AHJlYWQAcmVnZXhlYwBwb2xsAGx1YW9w
    ZW5fendpbnQAcHRocmVhZF9tdXRleF9pbml0AGx1YUxfcmVnaXN0ZXIAbHVhX3B1c2hudW1iZXIA
    bHVhX3NldGZpZWxkAGxpYmdjY19zLnNvLjEAbGlicHRocmVhZC5zby4wAGxpYmMuc28uMABfZnRl
    eHQAX2ZkYXRhAF9ncABfZWRhdGEAX19ic3Nfc3RhcnQAX2Zic3MAX2VuZABHQ0NfMy4wAAAAAAAB
    AAEAAAABAAEAAQABAAEAAQABAAEAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAACAAAAAAAAAAEAAQCYAgAAEAAAAAAAAABQJnkLAAACAPACAAAAAAAA
    AAAAAAAAAADITwEAAwAAAMxPAQADAAAA0E8BAAMAAADUTwEAAwAAANhPAQADAAAA3E8BAAMAAADg
    TwEAAwAAAORPAQADAAAA6E8BAAMAAADsTwEAAwAAAPBPAQADAAAA9E8BAAMAAAAcUQEAAwAAAAIA
    HDwYw5wnIeCZA+D/vScQALyvHAC/rxgAvK8BABEEAAAAAAIAHDz0wpwnIeCfAySAmY8cDjknPgAR
    BAAAAAAQALyPAQARBAAAAAACABw8zMKcJyHgnwMkgJmP4DQ5J+UJEQQAAAAAEAC8jxwAv48IAOAD
    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
    EICZjyF44AMJ+CADRAAYJBCAmY8heOADCfggA0MAGCQQgJmPIXjgAwn4IANCABgkEICZjyF44AMJ
    +CADQQAYJBCAmY8heOADCfggA0AAGCQQgJmPIXjgAwn4IAM/ABgkEICZjyF44AMJ+CADPgAYJBCA
    mY8heOADCfggAz0AGCQQgJmPIXjgAwn4IAM7ABgkEICZjyF44AMJ+CADOgAYJBCAmY8heOADCfgg
    AzkAGCQQgJmPIXjgAwn4IAM4ABgkEICZjyF44AMJ+CADNwAYJBCAmY8heOADCfggAzYAGCQQgJmP
    IXjgAwn4IAM1ABgkEICZjyF44AMJ+CADNAAYJBCAmY8heOADCfggAzMAGCQQgJmPIXjgAwn4IAMy
    ABgkEICZjyF44AMJ+CADMQAYJBCAmY8heOADCfggAzAAGCQQgJmPIXjgAwn4IAMvABgkEICZjyF4
    4AMJ+CADLgAYJBCAmY8heOADCfggAy0AGCQQgJmPIXjgAwn4IAMsABgkEICZjyF44AMJ+CADKwAY
    JBCAmY8heOADCfggAyoAGCQQgJmPIXjgAwn4IAMpABgkEICZjyF44AMJ+CADKAAYJBCAmY8heOAD
    CfggAycAGCQQgJmPIXjgAwn4IAMmABgkEICZjyF44AMJ+CADJQAYJBCAmY8heOADCfggAyQAGCQQ
    gJmPIXjgAwn4IAMjABgkEICZjyF44AMJ+CADIgAYJBCAmY8heOADCfggAyEAGCQQgJmPIXjgAwn4
    IAMfABgkEICZjyF44AMJ+CADHgAYJBCAmY8heOADCfggAx0AGCQQgJmPIXjgAwn4IAMcABgkEICZ
    jyF44AMJ+CADGwAYJBCAmY8heOADCfggAxoAGCQQgJmPIXjgAwn4IAMZABgkEICZjyF44AMJ+CAD
    GAAYJBCAmY8heOADCfggAxcAGCQQgJmPIXjgAwn4IAMWABgkEICZjyF44AMJ+CADFQAYJBCAmY8h
    eOADCfggAxQAGCQQgJmPIXjgAwn4IAMTABgkEICZjyF44AMJ+CADEgAYJBCAmY8heOADCfggAxAA
    GCQQgJmPIXjgAwn4IAMPABgkEICZjyF44AMJ+CADDgAYJAAAAAAAAAAAAAAAAAAAAAACABw8QJec
    JyHgmQPg/70nEAC8rxwAv68YALyvAQARBAAAAAACABw8HJecJyHgnwMkgJmPYA05Jxn1EQQAAAAA
    EAC8jxwAv48IAOADIAC9J3p3aW50IHRocmVhZCBlcnJvcjogJXMgJWQKAAA3NyAgICAgICUwMmQv
    JTAyZC8lMDJkICVkOiUwMmQ6JTAyZC4lMDNkICAgIAAAAABkZWxldGUgJXMgLT4gJXMgLT4gJXMg
    LT4gJXMKAAAAAHJlcG9wZW5faHR0cF9mZCgpCgAAcmVwb3Blbl9odHRwX2ZkAENhbm5vdCBjb25u
    ZWN0IHRvIHNlcnZlcgAAAAAgIGh0dHBfZmQoKT0lZAoARGV2aWNlIG51bWJlciBub3QgYW4gaW50
    ZWdlcgAAAABOb3QgcmVnaXN0ZXJlZAAAQmFkIGRldmljZV9wYXRoAERldmljZV9wYXRoIGRvZXMg
    bm90IG1hdGNoIGFscmVhZHkgcmVnaXN0ZXJlZCBuYW1lAAAvcHJvYy9zZWxmL2ZkLwAAJXMlcwAA
    AABvcmlnaW5hbF9jb21tcG9ydF9mZD0lZAoAAAAARGV2aWNlX3BhdGggbm90IGZvdW5kIGluIG9w
    ZW4gZmlsZSBsaXN0AENyZWF0ZWQgc29ja2V0IHBhaXIuIGZkcyAlZCBhbmQgJWQKAER1cDIuIG9s
    ZF9mZD0lZCwgbmV3X2ZkPSVkLCByZXN1bHQ9JWQKAABDbG9zaW5nIGZkICVkIGFmdGVyIGR1cDIK
    AAAATmV3IGNvbW1wb3J0IGZkPSVkCgBEZXZpY2VfbnVtIG5vdCBhIG51bWJlcgBLZXkgbm90IGEg
    c3RyaW5nAAAAAERlcXVldWVIVFRQRGF0YTogbmV4dFJlcXVlc3RAJXAgaHR0cF9hY3RpdmU9JWQg
    aHR0cF9ob2xkb2ZmPSVkCgAgICBTZW5kaW5nIGh0dHA6ICglZCBieXRlcykgJXMKACAgIFdyb3Rl
    ICVkIGJ5dGVzIHRvIEhUVFAgc2VydmVyCgAAACAgIHJldHJ5OiBXcm90ZSAlZCBieXRlcyB0byBI
    VFRQIHNlcnZlcgoAAAAAaW50ZXJjZXB0AAAAbW9uaXRvcgBQYXR0ZXJuIG5vdCBhIHN0cmluZwAA
    AAB0aW1lb3V0IG5vdCBhIG51bWJlcgAAAABSZXNwb25zZSBub3QgYSBzdHJpbmcAAABGb3J3YXJk
    IG5vdCBib29sZWFuAEx1YSAlczoga2V5PSVzIGFybV9wYXR0ZXJuPSVzIHBhdHRlcm49JXMgcmVz
    cG9uc2U9JXMgb25lc2hvdD0lZCB0aW1lb3V0PSVkIGZvcndhcmQ9JWQKAABpbnNlcnQgJXMgLT4g
    JXMgLT4gJXMgLT4gJXMKAAAAAEdFVCAvZGF0YV9yZXF1ZXN0P2lkPWFjdGlvbiZEZXZpY2VOdW09
    JWQmc2VydmljZUlkPXVybjpnZW5nZW5fbWN2LW9yZzpzZXJ2aWNlSWQ6WldhdmVNb25pdG9yMSZh
    Y3Rpb249JXMma2V5PSVzJnRpbWU9JWYAACZDJWQ9AAAAJkVycm9yTWVzc2FnZT0AACBIVFRQLzEu
    MQ0KSG9zdDogMTI3LjAuMC4xDQoNCgAAc2VuZF9odHRwOiBodHRwX2FjdGl2ZT0lZCBodHRwX2hv
    bGRvZmY9JWQKAABRdWV1ZWluZyBuZXh0IGh0dHAgcmVxdWVzdEAlcC4gbGFzdFJlcXVlc3RAJXAg
    aHR0cF9hY3RpdmU9JWQgaHR0cF9ob2xkb2ZmPSVkIHJlcXVlc3Q9JXMKAAAAAFF1ZXVlaW5nIGZp
    cnN0IGFuZCBsYXN0IGh0dHAgcmVxdWVzdEAlcC4gaHR0cF9hY3RpdmU9JWQgaHR0cF9ob2xkb2Zm
    PSVkIHJlcXVlc3Q9JXMKAEVycm9yAAAAUmVzcG9uc2UgdG9vIGxvbmcAAABob3N0LT5jb250cm9s
    bGVyAAAAAGNvbnRyb2xsZXItPmhvc3QAAAAAcwAAAGZvcndhcmQAcmVzcG9uc2UAAAAARm9yd2Fy
    ZCB3cml0ZQAAAFJlc3BvbnNlIHdyaXRlAABJbnRlcmNlcHQAAABNb25pdG9yACVzIEdvdCAlZCBi
    eXRlJXMgb2YgZGF0YSBmcm9tIGZkICVkCgAAAAAgICBzLT5zdGF0ZT0lZCBjPTB4JTAyWAoAAAAA
    ICAgU3dhbGxvd2luZyBhY2sgJWQgb2YgJWQKACAgIFdyaXRpbmcgcGFydCAlZCBvZiByZXNwb25z
    ZTogJWQgYnl0ZXMKAAAASW50ZXJjZXB0IHdyaXRlACAgIGNoZWNrc3VtPTB4JTAyWAoAMDEyMzQ1
    Njc4OUFCQ0RFRgAAAAAgICBoZXhidWZmPSVzCgAAICAgVHJ5aW5nIG1vbml0b3I6ICVzCgAAICAg
    TW9uaXRvcjogJXMgcGFzc2VkCgAAICAgTW9uaXRvciAlcyBpcyBub3cgYXJtZWQKACAgICAgICVz
    IGM9JWMgcnN0YXRlPSVkIGJ5dGU9MHglMDJYCgAAAAAgICAgICBSZXNwb25zZSBzeW50YXggZXJy
    b3IKAAAAAFJlc3BvbnNlIHN5bnRheCBlcnJvcgAAAFVubWF0Y2hlZCByZXBsYWNlbWVudAAAACAg
    IE1vbml0b3IgJXMgaXMgbm93IHVuYXJtZWQKAAAAICAgRGVsZXRpbmcgb25lc2hvdDogJXMKAAAA
    AFBhc3N0aHJvdWdoIHdyaXRlAAAAICAgTm90IGludGVyY2VwdGVkLiBQYXNzIHRocm91Z2ggJWQg
    Ynl0ZSVzIHRvIGZkICVkLiByZXN1bHQ9JWQKAEJhZCBjaGVja3VtIHdyaXRlAAAAICAgQmFkIGNo
    ZWNrc3VtLiBQYXNzIHRocm91Z2ggJWQgYnl0ZSVzIHRvIGZkICVkLiByZXN1bHQ9JWQKAAAAAFRh
    aWwgd3JpdGUAACAgIFdyaXRpbmcgJWQgdHJhaWxpbmcgb3V0cHV0IGJ5dGUlcyB0byBmZCAlZC4g
    UmVzdWx0PSVkCgAAAFN0YXJ0IHp3aW50IHRocmVhZAoAQ2FsbGluZyBwb2xsLiB0aW1lb3V0PSVk
    CgAAAFBvbGwgcmV0dXJuZWQgJWQKAAAAVGltaW5nIG91dCBtb25pdG9yIHdpdGgga2V5OiAlcwoA
    AAAAVGltZW91dABob3N0X2ZkICVkIHJldmVudHMgPSAlZAoAAAAAY29udHJvbGxlcl9mZCAlZCBy
    ZXZlbnRzID0gJWQKAABodHRwX2ZkICVkIHJldmVudHMgPSAlZAoAAAAAUmVjZWl2ZWQgJWQgYnl0
    ZXMgKHRvdGFsICVkIGJ5dGVzKSBmcm9tIGh0dHAgc2VydmVyOiAlcwoAAAAAaHR0cF9mZCBjbG9z
    ZWQKAENsb3NpbmcgaHR0cF9mZCAlZAoAb3V0cHV0AABTdGFydCBsdWFvcGVuX3p3aW50CgAAAAAq
    RHVtbXkqAHp3aW50AAAAdmVyc2lvbgBpbnN0YW5jZQAAAAByZWdpc3RlcgAAAAB1bnJlZ2lzdGVy
    AABjYW5jZWwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP//
    //8AAAAA/////wAAAAAAAAAAHEMAAJUOAAAoQwAAdRMAADRDAADFEQAAADwAAD0fAAD0OwAAFR8A
    AEBDAACdFwAAAAAAAAAAAAD/////AAAAAAAAAAAAAAAAAAAAAAAAAIAAAAEAHFEBAMBPAQAAAAAA
    AAAAAAAAAAAAAAAAoDgAAJA4AACAOAAAAAAAAHA4AABgOAAAUDgAAEA4AAAwOAAAIDgAABA4AAAA
    OAAA8DcAAOA3AADQNwAAwDcAALA3AACgNwAAAAAAAJA3AACANwAAcDcAAGA3AABQNwAAQDcAADA3
    AAAgNwAAEDcAAAA3AADwNgAA4DYAANA2AADANgAAsDYAAKA2AACQNgAAgDYAAHA2AABgNgAAUDYA
    AEA2AAAwNgAAIDYAABA2AAAANgAA8DUAAAAAAADgNQAA0DUAAMA1AACwNQAAoDUAAJA1AACANQAA
    cDUAAGA1AABQNQAAQDUAABxRAQBHQ0M6IChHTlUpIDMuMy4yAEdDQzogKExpbmFybyBHQ0MgNC42
    LTIwMTIuMDIpIDQuNi4zIDIwMTIwMjAxIChwcmVyZWxlYXNlKQAA6AwAAAAAAJD8////AAAAAAAA
    AAAgAAAAHQAAAB8AAADAOAAAAAAAkPz///8AAAAAAAAAACAAAAAdAAAAHwAAAGEOAAAAAACA/P//
    /wAAAAAAAAAAIAAAAB0AAAAfAAAAlQ4AAAAAAID8////AAAAAAAAAAAgAAAAHQAAAB8AAADJDgAA
    AAAAgPz///8AAAAAAAAAACgAAAAdAAAAHwAAABEPAAAAAAGA/P///wAAAAAAAAAAcAAAAB0AAAAf
    AAAAhQ8AAAAAA4D8////AAAAAAAAAAA4AAAAHQAAAB8AAAAxEAAAAAADgPz///8AAAAAAAAAAEAA
    AAAdAAAAHwAAAG0RAAAAAAOA/P///wAAAAAAAAAAKAAAAB0AAAAfAAAAxREAAAAAA4D8////AAAA
    AAAAAAAwAAAAHQAAAB8AAAB1EwAAAAADgPz///8AAAAAAAAAAEgCAAAdAAAAHwAAAJ0XAAAAAAOA
    /P///wAAAAAAAAAAQAAAAB0AAAAfAAAAnRgAAAAAA4D8////AAAAAAAAAABIAAAAHQAAAB8AAAAh
    GgAAAAADgPz///8AAAAAAAAAALABAAAdAAAAHwAAAL0eAAAAAAOA/P///wAAAAAAAAAAMAAAAB0A
    AAAfAAAAFR8AAAAAAID8////AAAAAAAAAAAgAAAAHQAAAB8AAAA9HwAAAAAAgPz///8AAAAAAAAA
    ACAAAAAdAAAAHwAAAGUfAAAAAAMA/P///wAAAAAAAAAACAAAAB0AAAAfAAAAvR8AAAAAA4D8////
    AAAAAAAAAABQBAAAHQAAAB8AAADJIgAAAAADgPz///8AAAAAAAAAADAAAAAdAAAAHwAAAHEjAAAA
    AAOA/P///wAAAAAAAAAAGAYAAB0AAAAfAAAAtS4AAAAAA4D8////AAAAAAAAAABIBAAAHQAAAB8A
    AADdMwAAAAADgPz///8AAAAAAAAAADAAAAAdAAAAHwAAAEEPAAAAZ251AAEHAAAABAMALnNoc3Ry
    dGFiAC5yZWdpbmZvAC5keW5hbWljAC5oYXNoAC5keW5zeW0ALmR5bnN0cgAuZ251LnZlcnNpb24A
    LmdudS52ZXJzaW9uX3IALnJlbC5keW4ALmluaXQALnRleHQALk1JUFMuc3R1YnMALmZpbmkALnJv
    ZGF0YQAuZWhfZnJhbWUALmN0b3JzAC5kdG9ycwAuamNyAC5kYXRhLnJlbC5ybwAuZGF0YQAuZ290
    AC5zZGF0YQAuYnNzAC5jb21tZW50AC5wZHIALmdudS5hdHRyaWJ1dGVzAC5tZGVidWcuYWJpMzIA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALAAAABgAAcAIAAAAUAQAA
    FAEAABgAAAAAAAAAAAAAAAQAAAAYAAAAFAAAAAYAAAACAAAALAEAACwBAADwAAAABQAAAAAAAAAE
    AAAACAAAAB0AAAAFAAAAAgAAABwCAAAcAgAANAIAAAQAAAAAAAAABAAAAAQAAAAjAAAACwAAAAIA
    AABQBAAAUAQAAIAEAAAFAAAAAgAAAAQAAAAQAAAAKwAAAAMAAAACAAAA0AgAANAIAAD4AgAAAAAA
    AAAAAAABAAAAAAAAADMAAAD///9vAgAAAMgLAADICwAAkAAAAAQAAAAAAAAAAgAAAAIAAABAAAAA
    /v//bwIAAABYDAAAWAwAACAAAAAFAAAAAQAAAAQAAAAAAAAATwAAAAkAAAACAAAAeAwAAHgMAABw
    AAAABAAAAAAAAAAEAAAACAAAAFgAAAABAAAABgAAAOgMAADoDAAAeAAAAAAAAAAAAAAABAAAAAAA
    AABeAAAAAQAAAAYAAABgDQAAYA0AAOAnAAAAAAAAAAAAABAAAAAAAAAAZAAAAAEAAAAGAAAAQDUA
    AEA1AACAAwAAAAAAAAAAAAAEAAAAAAAAAHAAAAABAAAABgAAAMA4AADAOAAAUAAAAAAAAAAAAAAA
    BAAAAAAAAAB2AAAAAQAAADIAAAAQOQAAEDkAADgKAAAAAAAAAAAAAAQAAAABAAAAfgAAAAEAAAAC
    AAAASEMAAEhDAAAEAAAAAAAAAAAAAAAEAAAAAAAAAIgAAAABAAAAAwAAALRPAQC0TwAACAAAAAAA
    AAAAAAAABAAAAAAAAACPAAAAAQAAAAMAAAC8TwEAvE8AAAgAAAAAAAAAAAAAAAQAAAAAAAAAlgAA
    AAEAAAADAAAAxE8BAMRPAAAEAAAAAAAAAAAAAAAEAAAAAAAAAJsAAAABAAAAAwAAAMhPAQDITwAA
    OAAAAAAAAAAAAAAABAAAAAAAAACoAAAAAQAAAAMAAAAAUAEAAFAAABAAAAAAAAAAAAAAABAAAAAA
    AAAArgAAAAEAAAADAAAQEFABABBQAAAMAQAAAAAAAAAAAAAQAAAABAAAALMAAAABAAAAAwAAEBxR
    AQAcUQAABAAAAAAAAAAAAAAABAAAAAAAAAC6AAAACAAAAAMAAAAgUQEAIFEAAFADAAAAAAAAAAAA
    ABAAAAAAAAAAvwAAAAEAAAAwAAAAAAAAACBRAABLAAAAAAAAAAAAAAABAAAAAQAAAMgAAAABAAAA
    AAAAAAAAAABsUQAA4AIAAAAAAAAAAAAABAAAAAAAAADNAAAA9f//bwAAAAAAAAAATFQAABAAAAAA
    AAAAAAAAAAEAAAAAAAAA3QAAAAEAAAAAAAAAcFQBAFxUAAAAAAAAAAAAAAAAAAABAAAAAAAAAAEA
    AAADAAAAAAAAAAAAAABcVAAA6wAAAAAAAAAAAAAAAQAAAAAAAAA=
    ]])
  else
    -- zwint non-debug version
           zwint_so = b642bin([[
    f0VMRgEBAQAAAAAAAAAAAAMACAABAAAAAA0AADQAAAD8RAAABxAAdDQAIAAHACgAHAAbAAAAAHAU
    AQAAFAEAABQBAAAYAAAAGAAAAAQAAAAEAAAAAQAAAAAAAAAAAAAAAAAAANwwAADcMAAABQAAAAAA
    AQABAAAAvD8AALw/AQC8PwEAWAEAALQEAAAGAAAAAAABAAIAAAAsAQAALAEAACwBAADwAAAA8AAA
    AAcAAAAEAAAAUeV0ZAAAAAAAAAAAAAAAAAAAAAAAAAAABwAAAAQAAABS5XRkvD8AALw/AQC8PwEA
    RAAAAEQAAAAEAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAsgAAAAAA
    AAAAAAAAAAAAAAAAwAEAAQAAAIACAAABAAAAjgIAAAEAAACeAgAADAAAAIAMAAANAAAAIC0AAAQA
    AAAcAgAABQAAAJQIAAAGAAAARAQAAAoAAADgAgAACwAAABAAAAADAAAAEEABABEAAAAgDAAAEgAA
    AGAAAAATAAAACAAAAAEAAHABAAAABQAAcAIAAAAGAABwAAAAAAoAAHAJAAAAEQAAcEUAAAASAABw
    GwAAABMAAHAOAAAA/v//bwAMAAD///9vAQAAAPD//290CwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQwAAAEUAAAAAAAAAEQAAAAAAAAAAAAAAKQAAAEMA
    AAA1AAAAAAAAAAAAAAAVAAAACgAAAAAAAAA0AAAAAAAAAB0AAAAiAAAAAAAAAAUAAAAfAAAAGgAA
    AAMAAAAAAAAAAAAAADoAAAALAAAAEAAAACAAAAAAAAAAAAAAAAwAAAAAAAAAAAAAAC0AAAAAAAAA
    DQAAAAAAAAAvAAAAAAAAACMAAAAqAAAAMQAAABYAAAAAAAAAJAAAAEAAAAAXAAAAGAAAAAAAAAAS
    AAAAIQAAAAAAAABEAAAAAAAAAAAAAAAAAAAAMgAAACwAAAAeAAAAFAAAACsAAAAlAAAADgAAADYA
    AAAwAAAAEwAAAAcAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADgAAAAAAAAAJgAA
    ABsAAAAcAAAAPgAAAAAAAAAPAAAACQAAAAAAAAAoAAAAAAAAAAAAAAAnAAAAGQAAAAAAAAAAAAAA
    PAAAADsAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGAAAACAAAAAAAAAAAAAAAAgAAAAAAAAA/
    AAAAAAAAAAAAAAAzAAAANwAAAAAAAAA9AAAALgAAAAAAAAA5AAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAQgAAAAAAAAAAAAAAQQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACADAAAAAAAAAMACQA1AgAAmSgAANAAAAASAAoA
    rwIAAABAAQAAAAAAEAATABcAAAAAwAEAAAAAABMA8f+2AgAAAMABAAAAAAAQAPH/UAIAAIAMAAAc
    AAAAEgAJAKgCAAAADQAAAAAAABAACgDBAgAAFEEBAAAAAAAQAPH/IAAAACAtAAAcAAAAEgAMALoC
    AAAUQQEAAAAAABAA8f8BAAAAEEABAAAAAAARAPH/0wIAAHBEAQAAAAAAEADx/80CAAAUQQEAAAAA
    ABAA8f+gAAAAAC0AAAAAAAASAAAATAAAAPAsAAAAAAAAEgAAAI4AAADgLAAAAAAAABIAAAA1AAAA
    AAAAAAAAAAAgAAAAwwEAANAsAAAAAAAAEgAAAFYCAADALAAAAAAAABIAAACBAQAAsCwAAAAAAAAS
    AAAASQAAAKAsAAAAAAAAEgAAAKsBAACQLAAAAAAAABIAAADRAQAAgCwAAAAAAAASAAAAQwIAAHAs
    AAAAAAAAEgAAAHUAAABgLAAAAAAAABIAAAAGAQAAUCwAAAAAAAASAAAAoAEAAEAsAAAAAAAAEgAA
    AAUCAAAwLAAAAAAAABIAAABfAAAAAAAAAAAAAAARAAAA5wEAACAsAAAAAAAAEgAAAOoAAAAQLAAA
    AAAAABIAAAC5AAAAACwAAAAAAAASAAAAGQEAAPArAAAAAAAAEgAAAFEBAADgKwAAAAAAABIAAAAw
    AgAA0CsAAAAAAAASAAAAWAEAAMArAAAAAAAAEgAAACgCAACwKwAAAAAAABIAAAAOAgAAoCsAAAAA
    AAASAAAA3wEAAJArAAAAAAAAEgAAANwAAACAKwAAAAAAABIAAADwAQAAcCsAAAAAAAASAAAAGwIA
    AGArAAAAAAAAEgAAACMCAABQKwAAAAAAABIAAABmAAAAQCsAAAAAAAASAAAAvQEAADArAAAAAAAA
    EgAAADMBAAAgKwAAAAAAABIAAADTAAAAECsAAAAAAAASAAAAQwEAAAArAAAAAAAAEgAAAHIBAADw
    KgAAAAAAABIAAACUAAAA4CoAAAAAAAASAAAAeQEAANAqAAAAAAAAEgAAAG4AAADAKgAAAAAAABIA
    AABzAgAAsCoAAAAAAAASAAAA2AEAAKAqAAAAAAAAEgAAAGQCAACQKgAAAAAAABIAAAAuAQAAgCoA
    AAAAAAASAAAAJgAAAAAAAAAAAAAAIgAAAGkBAABwKgAAAAAAABIAAAD4AAAAYCoAAAAAAAASAAAA
    yAAAAFAqAAAAAAAAEgAAAGABAABAKgAAAAAAABIAAACwAAAAMCoAAAAAAAASAAAAkQEAACAqAAAA
    AAAAEgAAAIYAAAAQKgAAAAAAABIAAAD8AQAAACoAAAAAAAASAAAAsAEAAPApAAAAAAAAEgAAAIoB
    AADgKQAAAAAAABIAAABRAAAA0CkAAAAAAAASAAAAAF9HTE9CQUxfT0ZGU0VUX1RBQkxFXwBfZ3Bf
    ZGlzcABfZmluaQBfX2N4YV9maW5hbGl6ZQBfSnZfUmVnaXN0ZXJDbGFzc2VzAHJlZ2ZyZWUAY2xv
    Y2tfZ2V0dGltZQBzdGRlcnIAZnByaW50ZgBzb2NrZXQAX19lcnJub19sb2NhdGlvbgBjb25uZWN0
    AGNsb3NlAGx1YV9wdXNobmlsAGx1YV9wdXNoaW50ZWdlcgBzdHJlcnJvcgBsdWFfcHVzaHN0cmlu
    ZwBsdWFfZ2V0dG9wAGx1YV90eXBlAGx1YV9pc2ludGVnZXIAbHVhTF9hcmdlcnJvcgBsdWFfdG9p
    bnRlZ2VyAHB0aHJlYWRfbXV0ZXhfbG9jawBwdGhyZWFkX211dGV4X3VubG9jawBkdXAyAGx1YV9w
    dXNoYm9vbGVhbgBsdWFfdG9sc3RyaW5nAHN0cmNtcABvcGVuZGlyAHNucHJpbnRmAHJlYWRsaW5r
    AHN0cnRvbAByZWFkZGlyAGNsb3NlZGlyAHN0cmNweQBwdGhyZWFkX2NyZWF0ZQBzb2NrZXRwYWly
    AG9wZW4AbHVhX2lzbnVtYmVyAHdyaXRlAGx1YV90b2Jvb2xlYW4Ac3RybGVuAG1hbGxvYwByZWdj
    b21wAHJlZ2Vycm9yAF9fZmxvYXRzaWRmAF9fZGl2ZGYzAF9fYWRkZGYzAGdldHRpbWVvZmRheQBz
    dHJuY3B5AHJlYWQAcmVnZXhlYwBwb2xsAGx1YW9wZW5fendpbnQAcHRocmVhZF9tdXRleF9pbml0
    AGx1YUxfcmVnaXN0ZXIAbHVhX3B1c2hudW1iZXIAbHVhX3NldGZpZWxkAGxpYmdjY19zLnNvLjEA
    bGlicHRocmVhZC5zby4wAGxpYmMuc28uMABfZnRleHQAX2ZkYXRhAF9ncABfZWRhdGEAX19ic3Nf
    c3RhcnQAX2Zic3MAX2VuZABHQ0NfMy4wAAAAAAABAAEAAAABAAEAAQABAAEAAQABAAEAAQAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAAAAAAAAAAAAQABAIAC
    AAAQAAAAAAAAAFAmeQsAAAIA2AIAAAAAAAAAAAAAAAAAANA/AQADAAAA1D8BAAMAAADYPwEAAwAA
    ANw/AQADAAAA4D8BAAMAAADkPwEAAwAAAOg/AQADAAAA7D8BAAMAAADwPwEAAwAAAPQ/AQADAAAA
    EEEBAAMAAAACABw8gLOcJyHgmQPg/70nEAC8rxwAv68YALyvAQARBAAAAAACABw8XLOcJyHgnwMk
    gJmPvA05J0AAEQQAAAAAEAC8jwEAEQQAAAAAAgAcPDSznCch4J8DJICZj3ApOScjBxEEAAAAABAA
    vI8cAL+PCADgAyAAvScAAAAAAAAAAAIAHDwAs5wnIeCZA9D/vScoALOvGICTjxAAvK8sAL+vIEFi
    kiQAsq8gALGvHACwrxsAQBTggIKPBQBAEByAgo/ggJmPCfggAwAARIwQALyPGICSjyCAkY8YgJCP
    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
    gJow8FyZQOo6ZQaWAWpL6p5lfGcQ8HibCPBA2wIQAVLaYNxnEPDYngjwgJ4AVA1hMPBcmUDqOmUG
    lgFqS+qeZXxnEPB4mwjwQNsQ8FiZAGtI9HzaMPBEmQL2GUpA6jplBpaeZZIWMPBEmd1nMPCEmbOO
    ofYRSobwGExA6jplBpaeZYMWAPACanL3BAsA9EAyaeKaZfZkHGcQ8HiYBNIkZyjxUJsrKlDwXJgQ
    8JiYBtMAbSjxFExA6jplBJYGk55lCSIw8ASYkWeiZ8H3CUhA6DhlOBABaijxUNsQ8HiYQ2dI8RBK
    SPFQ2xDweJhB2qjxWNsw8GSYpvAAS2PaUPBImDDwpJgQ8NiYOmWm8AhNx/cQTkDqkWcEltDwWJgN
    t55lC7Y6ZUDqkWcElgJtkWeeZTDwxJjQ8BCYq+2m8BBOQOg4ZQFqdmSg6ABlAGXNzMzMzMzwPwBl
    AGUAZQBlAgAcPJCWnCch4JkD2P+9JxwAsK8YgJCPEAC8ryAAsa8kAL+vvD8QJgMAABD//xEkCfgg
    A/z/ECYAABmO/P8xFyQAv48gALGPHACwjwgA4AMoAL0nAAAAAAAAAAAAAAAAEICZjyF44AMJ+CAD
    RAAYJBCAmY8heOADCfggA0MAGCQQgJmPIXjgAwn4IANCABgkEICZjyF44AMJ+CADQQAYJBCAmY8h
    eOADCfggA0AAGCQQgJmPIXjgAwn4IAM/ABgkEICZjyF44AMJ+CADPgAYJBCAmY8heOADCfggAz0A
    GCQQgJmPIXjgAwn4IAM8ABgkEICZjyF44AMJ+CADOwAYJBCAmY8heOADCfggAzoAGCQQgJmPIXjg
    Awn4IAM4ABgkEICZjyF44AMJ+CADNwAYJBCAmY8heOADCfggAzYAGCQQgJmPIXjgAwn4IAM1ABgk
    EICZjyF44AMJ+CADNAAYJBCAmY8heOADCfggAzMAGCQQgJmPIXjgAwn4IAMyABgkEICZjyF44AMJ
    +CADMQAYJBCAmY8heOADCfggAzAAGCQQgJmPIXjgAwn4IAMvABgkEICZjyF44AMJ+CADLgAYJBCA
    mY8heOADCfggAy0AGCQQgJmPIXjgAwn4IAMsABgkEICZjyF44AMJ+CADKwAYJBCAmY8heOADCfgg
    AyoAGCQQgJmPIXjgAwn4IAMpABgkEICZjyF44AMJ+CADKAAYJBCAmY8heOADCfggAycAGCQQgJmP
    IXjgAwn4IAMmABgkEICZjyF44AMJ+CADJQAYJBCAmY8heOADCfggAyQAGCQQgJmPIXjgAwn4IAMj
    ABgkEICZjyF44AMJ+CADIgAYJBCAmY8heOADCfggAyEAGCQQgJmPIXjgAwn4IAMgABgkEICZjyF4
    4AMJ+CADHwAYJBCAmY8heOADCfggAx4AGCQQgJmPIXjgAwn4IAMcABgkEICZjyF44AMJ+CADGwAY
    JBCAmY8heOADCfggAxoAGCQQgJmPIXjgAwn4IAMZABgkEICZjyF44AMJ+CADGAAYJBCAmY8heOAD
    CfggAxcAGCQQgJmPIXjgAwn4IAMWABgkEICZjyF44AMJ+CADFQAYJBCAmY8heOADCfggAxQAGCQQ
    gJmPIXjgAwn4IAMTABgkEICZjyF44AMJ+CADEgAYJBCAmY8heOADCfggAxAAGCQQgJmPIXjgAwn4
    IAMPABgkEICZjyF44AMJ+CADDgAYJAAAAAAAAAAAAAAAAAAAAAACABw84JKcJyHgmQPg/70nEAC8
    rxwAv68YALyvAQARBAAAAAACABw8vJKcJyHgnwMkgJmPAA05J+n3EQQAAAAAEAC8jxwAv48IAOAD
    IAC9J3p3aW50IHRocmVhZCBlcnJvcjogJXMgJWQKAAByZXBvcGVuX2h0dHBfZmQAQ2Fubm90IGNv
    bm5lY3QgdG8gc2VydmVyAAAAAERldmljZSBudW1iZXIgbm90IGFuIGludGVnZXIAAAAATm90IHJl
    Z2lzdGVyZWQAAEJhZCBkZXZpY2VfcGF0aABEZXZpY2VfcGF0aCBkb2VzIG5vdCBtYXRjaCBhbHJl
    YWR5IHJlZ2lzdGVyZWQgbmFtZQAAL3Byb2Mvc2VsZi9mZC8AACVzJXMAAAAARGV2aWNlX3BhdGgg
    bm90IGZvdW5kIGluIG9wZW4gZmlsZSBsaXN0AERldmljZV9udW0gbm90IGEgbnVtYmVyAEtleSBu
    b3QgYSBzdHJpbmcAAAAAUGF0dGVybiBub3QgYSBzdHJpbmcAAAAAdGltZW91dCBub3QgYSBudW1i
    ZXIAAAAAUmVzcG9uc2Ugbm90IGEgc3RyaW5nAAAARm9yd2FyZCBub3QgYm9vbGVhbgBHRVQgL2Rh
    dGFfcmVxdWVzdD9pZD1hY3Rpb24mRGV2aWNlTnVtPSVkJnNlcnZpY2VJZD11cm46Z2VuZ2VuX21j
    di1vcmc6c2VydmljZUlkOlpXYXZlTW9uaXRvcjEmYWN0aW9uPSVzJmtleT0lcyZ0aW1lPSVmAAAm
    QyVkPQAAACZFcnJvck1lc3NhZ2U9AAAgSFRUUC8xLjENCkhvc3Q6IDEyNy4wLjAuMQ0KDQoAAEVy
    cm9yAAAAUmVzcG9uc2UgdG9vIGxvbmcAAABGb3J3YXJkIHdyaXRlAAAAUmVzcG9uc2Ugd3JpdGUA
    AEludGVyY2VwdAAAAE1vbml0b3IASW50ZXJjZXB0IHdyaXRlADAxMjM0NTY3ODlBQkNERUYAAAAA
    UmVzcG9uc2Ugc3ludGF4IGVycm9yAAAAVW5tYXRjaGVkIHJlcGxhY2VtZW50AAAAUGFzc3Rocm91
    Z2ggd3JpdGUAAABCYWQgY2hlY2t1bSB3cml0ZQAAAFRhaWwgd3JpdGUAAFRpbWVvdXQAaW50ZXJj
    ZXB0AAAAbW9uaXRvcgBvdXRwdXQAACpEdW1teSoAendpbnQAAAB2ZXJzaW9uAHJlZ2lzdGVyAAAA
    AHVucmVnaXN0ZXIAAGNhbmNlbAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAD/////AAAAAP////8AAAAAAAAAALgwAADREQAAxDAAACEQAACQMAAAcRsA
    AIQwAABJGwAA0DAAABkVAAAAAAAAAAAAAP////8AAAAAAAAAAAAAAAAAAAAAAAAAgAAAAQAQQQEA
    yD8BAAAAAAAAAAAAAAAAAAAAAAAALQAA8CwAAOAsAAAAAAAA0CwAAMAsAACwLAAAoCwAAJAsAACA
    LAAAcCwAAGAsAABQLAAAQCwAADAsAAAAAAAAICwAABAsAAAALAAA8CsAAOArAADQKwAAwCsAALAr
    AACgKwAAkCsAAIArAABwKwAAYCsAAFArAABAKwAAMCsAACArAAAQKwAAACsAAPAqAADgKgAA0CoA
    AMAqAACwKgAAoCoAAJAqAACAKgAAAAAAAHAqAABgKgAAUCoAAEAqAAAwKgAAICoAABAqAAAAKgAA
    8CkAAOApAADQKQAAEEEBAEdDQzogKEdOVSkgMy4zLjIAR0NDOiAoTGluYXJvIEdDQyA0LjYtMjAx
    Mi4wMikgNC42LjMgMjAxMjAyMDEgKHByZXJlbGVhc2UpAACADAAAAAAAkPz///8AAAAAAAAAACAA
    AAAdAAAAHwAAACAtAAAAAACQ/P///wAAAAAAAAAAIAAAAB0AAAAfAAAAAQ4AAAAAA4D8////AAAA
    AAAAAAAoAAAAHQAAAB8AAABpDgAAAAAAgPz///8AAAAAAAAAACgAAAAdAAAAHwAAALEOAAAAAACA
    /P///wAAAAAAAAAAIAAAAB0AAAAfAAAA5Q4AAAAAA4D8////AAAAAAAAAAA4AAAAHQAAAB8AAADJ
    DwAAAAADgPz///8AAAAAAAAAACgAAAAdAAAAHwAAACEQAAAAAAOA/P///wAAAAAAAAAAMAAAAB0A
    AAAfAAAA0REAAAAAA4D8////AAAAAAAAAABQAgAAHQAAAB8AAAAZFQAAAAADgPz///8AAAAAAAAA
    AEAAAAAdAAAAHwAAABkWAAAAAAOA/P///wAAAAAAAAAAOAAAAB0AAAAfAAAA6RYAAAAAA4D8////
    AAAAAAAAAACYAQAAHQAAAB8AAADxGgAAAAADgPz///8AAAAAAAAAADAAAAAdAAAAHwAAAEkbAAAA
    AACA/P///wAAAAAAAAAAIAAAAB0AAAAfAAAAcRsAAAAAAID8////AAAAAAAAAAAgAAAAHQAAAB8A
    AACZGwAAAAADAPz///8AAAAAAAAAAAgAAAAdAAAAHwAAAPEbAAAAAAOA/P///wAAAAAAAAAAUAQA
    AB0AAAAfAAAAGR4AAAAAA4D8////AAAAAAAAAAAwAAAAHQAAAB8AAADBHgAAAAADgPz///8AAAAA
    AAAAABAGAAAdAAAAHwAAAHElAAAAAAOA/P///wAAAAAAAAAAQAQAAB0AAAAfAAAAmSgAAAAAA4D8
    ////AAAAAAAAAAAwAAAAHQAAAB8AAABBDwAAAGdudQABBwAAAAQDAC5zaHN0cnRhYgAucmVnaW5m
    bwAuZHluYW1pYwAuaGFzaAAuZHluc3ltAC5keW5zdHIALmdudS52ZXJzaW9uAC5nbnUudmVyc2lv
    bl9yAC5yZWwuZHluAC5pbml0AC50ZXh0AC5NSVBTLnN0dWJzAC5maW5pAC5yb2RhdGEALmVoX2Zy
    YW1lAC5jdG9ycwAuZHRvcnMALmpjcgAuZGF0YS5yZWwucm8ALmRhdGEALmdvdAAuc2RhdGEALmJz
    cwAuY29tbWVudAAucGRyAC5nbnUuYXR0cmlidXRlcwAubWRlYnVnLmFiaTMyAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACwAAAAYAAHACAAAAFAEAABQBAAAYAAAAAAAA
    AAAAAAAEAAAAGAAAABQAAAAGAAAAAgAAACwBAAAsAQAA8AAAAAUAAAAAAAAABAAAAAgAAAAdAAAA
    BQAAAAIAAAAcAgAAHAIAACgCAAAEAAAAAAAAAAQAAAAEAAAAIwAAAAsAAAACAAAARAQAAEQEAABQ
    BAAABQAAAAIAAAAEAAAAEAAAACsAAAADAAAAAgAAAJQIAACUCAAA4AIAAAAAAAAAAAAAAQAAAAAA
    AAAzAAAA////bwIAAAB0CwAAdAsAAIoAAAAEAAAAAAAAAAIAAAACAAAAQAAAAP7//28CAAAAAAwA
    AAAMAAAgAAAABQAAAAEAAAAEAAAAAAAAAE8AAAAJAAAAAgAAACAMAAAgDAAAYAAAAAQAAAAAAAAA
    BAAAAAgAAABYAAAAAQAAAAYAAACADAAAgAwAAHgAAAAAAAAAAAAAAAQAAAAAAAAAXgAAAAEAAAAG
    AAAAAA0AAAANAADQHAAAAAAAAAAAAAAQAAAAAAAAAGQAAAABAAAABgAAANApAADQKQAAUAMAAAAA
    AAAAAAAABAAAAAAAAABwAAAAAQAAAAYAAAAgLQAAIC0AAFAAAAAAAAAAAAAAAAQAAAAAAAAAdgAA
    AAEAAAAyAAAAcC0AAHAtAABoAwAAAAAAAAAAAAAEAAAAAQAAAH4AAAABAAAAAgAAANgwAADYMAAA
    BAAAAAAAAAAAAAAABAAAAAAAAACIAAAAAQAAAAMAAAC8PwEAvD8AAAgAAAAAAAAAAAAAAAQAAAAA
    AAAAjwAAAAEAAAADAAAAxD8BAMQ/AAAIAAAAAAAAAAAAAAAEAAAAAAAAAJYAAAABAAAAAwAAAMw/
    AQDMPwAABAAAAAAAAAAAAAAABAAAAAAAAACbAAAAAQAAAAMAAADQPwEA0D8AADAAAAAAAAAAAAAA
    AAQAAAAAAAAAqAAAAAEAAAADAAAAAEABAABAAAAQAAAAAAAAAAAAAAAQAAAAAAAAAK4AAAABAAAA
    AwAAEBBAAQAQQAAAAAEAAAAAAAAAAAAAEAAAAAQAAACzAAAAAQAAAAMAABAQQQEAEEEAAAQAAAAA
    AAAAAAAAAAQAAAAAAAAAugAAAAgAAAADAAAAIEEBABRBAABQAwAAAAAAAAAAAAAQAAAAAAAAAL8A
    AAABAAAAMAAAAAAAAAAUQQAASwAAAAAAAAAAAAAAAQAAAAEAAADIAAAAAQAAAAAAAAAAAAAAYEEA
    AKACAAAAAAAAAAAAAAQAAAAAAAAAzQAAAPX//28AAAAAAAAAAABEAAAQAAAAAAAAAAAAAAABAAAA
    AAAAAN0AAAABAAAAAAAAAHBEAQAQRAAAAAAAAAAAAAAAAAAAAQAAAAAAAAABAAAAAwAAAAAAAAAA
    AAAAEEQAAOsAAAAAAAAAAAAAAAEAAAAAAAAA
    ]])
  end

-- These files are the compressed uninstaller. If the installer gets deleted
-- The uninstaller remains, detects that the insatller no longer exists,
-- cleans up the dropped files and unadopts any devices, and cleans up itself.
uninstaller_version = 1.16
-- Auto-generated by MakeUninstaller.bat 
D_GenGenSceneControllerUninstaller_json_lzo = b642bin([[ 
1AgAAAAUew0KCSJkZWZhdWx0X2ljb24iOiAic2NlbmVfY29udHJvbGxlcl/ABAwucG5nIiwNCgki
Zmxhc2j4BXwACnMvZGV2aWNlcy5zd2asBAFpbWdJQAoBQm9keXAKK1AABURpbW1hYmxlL2AAAVR1
cm4zYgBNaYgTKxcBTWF4KAABAmhhbGxvYA4Bc0RpcngCAnBpY3MvlALSBm5TfBppAzCkAg9EaXNw
bGF5U3RhdHVzIjoge32QGwRkb2NfdXJsYAICDQoJCSJ8AQRsYW5ndWFnYRYxcAS0AgJtYW51YWAF
KUwAAnZlcnNpnCgpUAAJcGxhdGZvcm0iOiAwKPkAcKAKXC+IJwEiDQoJpxBUYWJ+EVt7fA8DCSJM
YWJldAy6AQkicBEBX3RhZ2gZBHVuaW5zdGF4NJEaCUAWAXRleHRtA1UpbACECZQLBQkJIlBvc2l0
sRQirCFUBgNUYWJUeXBkHLg72AkHIlRvcE5hdmlnYWQGA1RhYiI6IKQbBAkidG9wX24nbgBfdCtw
AAdDb25maWdGdW5jYAd9ETHoCoAxAkdyb3VwUCzUHAEJImlkKpAAlAssQwBsZWacGuoWCSKdPzLa
CgkigU0yfCgBCQl9XYMtCSJDvFg/uAGVXmfSEiIxNBQBKrwCLWEBIvgbAAMJIkhvcml6b250YWxN
dWx0aXBsaWWIUiikAswH4C4DYnV0dG9uJxwD1wNDb2SYMQFUZXN0KHABLTYICSIvuAeoF6xJfEHc
XEwXxUgJcDpNKzKwUW0ETK0rNShEAAJXaWR0aHA9KUwAAkhlaWdobjAyMIBKKIwBA0NvbW1hbmQ4
J48BU2VyfFpcDAUidXJuOmdlbkgAB19tY3Ytb3JnOnO3A0lkOpRByx5sZXIp1Aon0wMJIkEnFAkn
fAD4HIYRfV14AKBcpBA72AwFc2V0dGluZ3MnyAXxKFPgA3gJ+Bs/wAwHamF2YXNjcmlwdMIKIlOX
AU5hbYQ4BXNoYXJlZC5q/Q0iKlgMA3NpbXBsZVCslCV8DiAIGAMFYWR2YW5jZWTUDigtCEHgA3gJ
MxgD7SsiKdwPIBwYA+wRIBQgA7fHX29wbIX0JCg5A0SSyyBP2AM3UAPgbCAoUAPcEgJ6d2F2ZSd0
AngPIAiIBgRub3RpZmljlKcwYQNOK3QAYAszsQYzwDwgL1wDLHACeQ99UNCEpwgiZXZlbnRMaXN0
MkGHW6wCvDD0lnR6BXNjaGVtYXMtSHtIACd0D7wmOWkPOrxPzt9fdMTPIB5IAQINCn0NChEAAA==
]]) 
D_GenGenSceneControllerUninstaller_xml_lzo = b642bin([[ 
3gMAAAA7PD94bWwgdmVyc2lvbj0iMS4wIj8+Cjxyb290IHhtbG5zPSJ1cm46c2NoZW1hcy11cG5w
LW9yZzpkZXZpY2UtMS0wIj4KICA8c3BlY1a0CHwBCSAgPG1ham9yPjE8L6MBCiAgcAIDaW5vcj4w
UAKAAWUHLy3pADyoC9QIsAECVHlwZT4qHwJnZW5IAAFfbWN2KTQCAAU6U2NlbmVDb250cm9sbGVy
VW5pbnN0YWgBAToxPC8pKAGwEUwDDXRpY0pzb24+RF9HZW5HZW44BAEELmpzb248LynMALAICmZy
aWVuZGx5TmFtZT6wCAJlcmljIIUJICgxAiApNgI8LyvUAKAJAAJtYW51ZmFjdHVyZXI+VmFyaW91
c1wkKlQAoAUOQ2F0ZWdvcnlfTnVtPjE0PC8rQACvBFN1YitXADA8Ly5IAKMFc2VyYDkBTGlzdKQu
bDmsAvwBKEQAPhgG0Ak9HAbUBJAJkBCEQ9YCSWScPFA7SAAnfAcncAA5awExPC8nmAAp6AIGU0NQ
RFVSTD5TIAGEBwJ4bWw8L/wFxBMnUAGoCic4ACjABAw8aW1wbGVtZW50YXRpb26BAw30ByxsAANG
aWxlPkkgBiACMegAugo8LyxoACfEAehcBz4KPC9yb290PgoRAAA=
]]) 
I_GenGenSceneControllerUninstaller_xml_lzo = b642bin([[ 
tAEAAAA8PD94bWwgdmVyc2lvbj0iMS4wIj8+CjxpbXBsZW1lbnRhdGlvbj4KICA8ZmlsZXM+TF9H
ZW5HZW5TY2VuZUNvbnRyb2xsZXJVbmluc3RhaAEDLmx1YTwvtAV8BgVzdGFydHVwPjjEAARfSW5p
dDwv4QUNdgZhY2APAUxpc3RzDyAgPKACsAEAAiAgPHNlcnZpY2VJZD51cm46Z2VuSAAGX21jdi1v
cmc6J3EAOjjTATE8LyeYACdUAQJuYW1lPicuAzwvngEKIIAABTxydW4+CgkJOEkBXyfkAAQobHVs
X2RlZRQp2AcKICByZXR1cm4gdHJ1Zc4CPC+MCnoLPC8ogAPsAbcfPC9pLTAGEQAA
]]) 
L_GenGenSceneControllerUninstaller_lua_lzo = b642bin([[ 
tBgAAAAYLS0gVW5pbnN0YWxsZXIgZm9yIEdlbkdlbmVyaWMgU2NlbmUgQ29udHJvnAMALVZlcnNp
b24gMS4xNg0KLS0gQ29weXJpZ2h0IDIwMTYtMjAxNyBHdXN0YXZvIEEgRmVybmFuZGV6LiBBbGwg
UmAFABJzIFJlc2VydmVkDQpsb2NhbCBWZXJib3NlTG9nZ2luZyA9IDDkAw5uaXhpbyA9IHJlcXVp
cmUgIoMCIg0K4AQFSEFHX1NJRCAuAAAABT0gInVybjptaWNhc2F2ZXJkZS1jb206fA4ACmljZUlk
OkhvbWVBdXRvbWF0aW9uR2F0ZXdheTEpZAEBZnVuY2gDDSBsb2dMaXN0KC4uLikNCgmpFnNQEgIi
Ig0KCWAmAAJpID0gMSwgc2VsZWN0ICgiIyIsIHQFBSBkbw0KCSAgzwZ4ID3OBChpoAQBDQoJCWQJ
B3MgLi4gdG9zdHJeHyh4eAwAAmVuZCANCglyZXR1cm4gcw0KZW5kKNgDKnACJ2ACBnV1cC5sb2co
IikBB1UpbAdsJANsb2c6ICJ4DSpZAyk2eAEBVkxvZ9wLASAgaWYupAYFPiAyIHRoZW54Ij71AXaw
PDT2ASAgmBuQAOg7J4wDDERlbGV0ZUZpbGUoYmFzZXQjnRIigANEJgEgIiwg5AOARAYuZnMucmVt
b3akBngdCCIubW9kaWZpZWQiYAg4mAB4RTeIADegBIgRjBQGQ2FyZWZ1bGx5PbACAiwgIiBj7AWA
DqRLYRlf7BVUTHwBLQADeC2AZ20DX2AWK5wAYAJoUyk9AXUnGQhkK6gAKVwAiF/EVVSBAXQgPSAn
kAR8AbgZbFK8CmwC7A8woACEA2AtKbAAKbABM3EBXymAAEAtU2NpZiB4DO1MCSo8AGURCeQCmA0n
mAAoWAApRAEpdQAJJ7wCKZAIiwgpCQlYDgQJCQllbHNlpAEqswBuYW2kSpEFLJATLdUCCXAHaHVg
ATKcAegMKIQB1BoqIAE+sALwCD6cAiABiAKQHJ5uCQnYADLUAidECmw6nASQAC+uDlJlUa10MawO
oAMtsA6wQ5RYICPECydcDJBGIDD8CimIAieIBGQNhGMqgARMKsw6ASBhbmS0RHByJ1QHJ/gAKfwJ
YCs6rAl0JIwEyAsnwAEnVAEq9AAn7BMnmACMB5A2vDyKAQ0KJ5QViP0opB8p4RhfJy0AKCckAApl
cl9kZXZpY2VfbnVtaAt84ChGACwgrAEIIGluIHBhaXJzKGx8w7ICcymg49CNsAIEX3R5cGUgPd0G
LilQAFQpLKUAZkTBRAWECgdhdHRyX2dldCgixAZxAyL4D/ATeYQowAS8DCV8IAhzY2hlbWFzLWdl
bkgABl9tY3Ytb3JnOqkFOi1IBAlFdm9sdmVMQ0Q6MSJgO2ATbOq1BV9kDwQgPT0gIkRfJ6QABzEu
eG1sIikgb3LQBSAhFAIIQ29vcGVyUkZXQzU/HAIprAAgMSACCk5leGlhT25lVG91Y2g/KAIrtAAg
MTECSSYEKz8hAkcjdCstaAcn+ADEEyVQI4DJuDvkUgJudW1fcFr2bnRtPTEo8Q0JI+glK5gTJ+QA
AnNjcmlwIjApcP4DdG8gYSBnJYEtcyOBLWMngy0iKTtmRQkJKHULcyl0C3JXIiwkbCvsVy6MK7QO
LvIKOjEwVAw2lAEBZmlsZXYMRF8tmAS4WS90DS8cAQFpbXBsnGF0CCAJ3AEDanNvbiIsYGgv3AHI
A6wbJ1gPMOABA252aXNpYrkXMDHkASjUHZg1I9gm0NKvCy5kZSe0BissBgNjYWxsX2EjSTAoJdUx
LCQGKmVEhKEBIiwge6cBTnVtXJO8CWwVAX0sIDDMCZSu5O2wAQwtLSBVSTcgZHJvcHBlZCBxL3NE
2YgTI0QpAAooIi93d3cvY21oL3NraW5zL2RlZmF1bHQvaW1nTAF0sGwCfQBff9Flcy8oABIHXzUw
eDUwLnBuZyOMKSAcVAEpOBEgK1gBK2gQLGMBICAJK8QCAAJ1c3IvbGliL2x1YS96d2ludC5zb5wa
vG4j3CEotAQEa2l0L0tpdLEyLohIaNUgAawABl9WYXJpYWJsZSjQAJU0NS6UBni/K4ACNaMGY29u
OFAGIAwQASAdDAacECAjvAUo0AMovDMCIi9ldGOYVAABendhdmVfcHJvZHVjdHNfdXNlcqCrAw0K
CS0tICe0FS6YC9wHBS1sdWRsL0RfPagWYzoubHqgQChBAignHAIgBh8BeG1sIAIZAUk+OAIgBRkB
TD4bAWx1YSACNQJTPhgBIAU0AiAMGAEjtkdyZTSEEi3oBigAEohoIAJEAy7UJCAEyAApNAwgCZwB
KtAAIAWaBERfK8wMIAmoASzYACAFsAE1oAlgaCACTQRKNGMILmpzIALwADVxCi4gBUwKNfQAA1No
YXJlZCAGDAE1QAogBvAD9AcIWldhdmVNb25pdG+Aj+gfZK1guSc0RCJYLiAQ5BApEDQgCSQIMywT
KiQBIBxwCCARIAE1sAYqIAEgBdQH7C4tyCYqIAEqaAMjXCsgECwlKTQBKdw5JlwlWMgjNCcnlAAj
TFcCIGNvbXAi5FAHZC4gUmVsb2FkaSIQJCJ8LTcSAiAipAUiLCeUCydgVCADnDwFSW5pdChsdWzI
FCKsISSEQyd8XSN9JiAuZEItwBo1aAYn1BwrKA0EaWYgbm90IC2EASb8MpgiM+gJJzQBmAcEZm91
bmQuICcABSJILAZhbGwgcmVsYXQmUSouJXAyOKQHKaRALBgEJtgtJNxWgAgqVGEABGNvcmUgc3Rp
bGwgcHJlc2VudC4gRG9kEwFoaW5n3A4HZW5kDQplbmQNChEAAA==
]]) 
S_GenGenSceneControllerUninstaller_xml_lzo = b642bin([[ 
FAEAAAAtPHNjcGQgeG1sbnM9InVybjpzY2hlbWFzLXVwbnAtb3JnOnNlcnZpY2UtMS0wIj4NCiAg
PHNwZWNWZXJzaW9ugAIJICA8bWFqb3I+MTwvoAF4BHQCA2lub3I+MFQCgAF2AjwvLvUAPMAMB1N0
YXRlVGFibGWSCjwvNVwAB2FjdGlvbkxpc3SfBCAgPKQC1AEAASAgPG5hbWU+VW5pbnN0YWxsPC+c
AXAPASAgPC8psADwAcwJBjwvc2NwZD4NChEAAA==
]]) 
-- End uninstaller

  if luup.version_major >= 7 then
  	json = require ("dkjson")

	UpdateFileWithContent("/www/cmh/skins/default/img/devices/device_states/EvolveLCD1_50x50.png", EvolveLCD1Icon, 644, nil, updated)
	UpdateFileWithContent("/www/cmh/skins/default/img/devices/device_states/CooperRFWC5_50x50.png", CooperRFWC5Icon, 644, nil, updated)
	UpdateFileWithContent("/www/cmh/skins/default/img/devices/device_states/NexiaOneTouch_50x50.png", NexiaOneTouchIcon, 644, nil, updated)

	updateJson("/www/cmh/kit/KitDevice.json",
		function(obj)
			local kits = {{
			   PK_KitDevice = "2501";
		       DeviceFile = "D_EvolveLCD1.xml";
		       RequireMac = "0";
		       Protocol = "1";
		       Model = "LCD1";
		       Name = {
		        lang_tag = "kitdevice_2501";
		        text = "Evolve LCD1"
		       };
		       Manufacturer = "Evolve";
		       NonSpecific = "0";
		       ZWaveClass = "ZWaveController";
		       Invisible = "1";
		       Exclude = "0";
		       ProductID = "19506";
		       ProductType = "17750";
		       MfrId = "275";
		       FK_DeviceWizardCategory_ui7 = "120"
			},
			{
			   PK_KitDevice = "2503";
		       DeviceFile = "D_CooperRFWC5.xml";
		       RequireMac = "0";
		       Protocol = "1";
		       Model = "RFWC5";
		       Name = {
		        lang_tag = "kitdevice_2503";
		        text = "Cooper RFWC5"
		       };
		       Manufacturer = "Cooper Industries";
		       NonSpecific = "0";
		       ZWaveClass = "ZWaveController";
		       Invisible = "1";
		       Exclude = "0";
		       ProductID = "0";
		       ProductType = "22349";
		       MfrId = "26";
		       FK_DeviceWizardCategory_ui7 = "120"
			}, {
			   PK_KitDevice = "2504";
		       DeviceFile = "D_NexiaOneTouch.xml";
		       RequireMac = "0";
		       Protocol = "1";
		       Model = "NX1000";
		       Name = {
		        lang_tag = "kitdevice_2504";
		        text = "Nexia One Touch"
		       };
		       Manufacturer = "Ingersoll Rand";
		       NonSpecific = "0";
		       ZWaveClass = "ZWaveController";
		       Invisible = "1";
		       Exclude = "0";
		       ProductID = "18229";
		       ProductType = "21315";
		       MfrId = "376";
		       FK_DeviceWizardCategory_ui7 = "120"
			}, {
			   PK_KitDevice = "2505";
		       DeviceFile = "D_DimmableRGBLight1.xml";
		       RequireMac = "0";
		       Protocol = "1";
		       Model = "ZMNHWD3";
		       Name = {
		        lang_tag = "kitdevice_2505";
		        text = "Flush RGBW Dimmer"
		       };
		       Manufacturer = "Qubino";
		       NonSpecific = "0";
		       Invisible = "0";
		       Exclude = "0";
		       ProductID = "84";
		       ProductType = "1";
		       MfrId = "345";
			}}

			for j,v in pairs(obj.KitDevice) do
				for i = 1, #kits do
					local e = kits[i]
					if v.Protocol == e.Protocol and
					   v.ProductID == e.ProductID and
					   v.ProductType == e.ProductType and
					   v.MfrId ==e.MfrId then
					   table.delete(obj.KitDevice,j)
					   break
					end
				end
			end
			for i = 1, #kits do
				table.insert(obj.KitDevice, kits[i])
			end
		end, updated )

	updateJson("/www/cmh/kit/KitDevice_Variable.json",
		function(obj)
		    local array = {
				-- Evolve LCD1
			    {
			      PK_KitDevice_Variable = "5001";
			      PK_KitDevice = "2501";
			      Service = "urn:micasaverde-com:serviceId:SceneController1";
			      Variable = "NumButtons";
			      Value = "5"
			    }, {
			      PK_KitDevice_Variable = "5002";
			      PK_KitDevice = "2501";
			      Service = "urn:micasaverde-com:serviceId:SceneController1";
			      Variable = "FiresOffEvents";
			      Value = "1"
			    }, {
			      PK_KitDevice_Variable = "5003";
			      PK_KitDevice = "2501";
			      Service = "urn:micasaverde-com:serviceId:SceneController1";
			      Variable = "ActivationMethod";
			      Value = "0"
			    }, {
			      PK_KitDevice_Variable = "5004";
			      PK_KitDevice = "2501";
			      Service = "urn:micasaverde-com:serviceId:ZWaveDevice1";
			      Variable = "VariablesSet";
			      Value = "20-Display Timeout (seconds),m,,"..
			              "21-Backlight ON level (1-20),m,,"..
			              "22-Backlight OFF level (0-20),m,,"..
			              "23-Button ON level (1-20),m,,"..
			              "24-Button OFF level (0-20),m,,"..
			              "25-LCD Contrast (5-20),m,,"..
			              "26-Orientation(1=rotate 180 0=normal),m,,"..
			              "27-Network Update (seconds),m,,"..
			              "29-backlight level (0-100),m,,"..
			              "32-Backlight Demo mode (0-1),m,"
			    }, {
			      PK_KitDevice_Variable = "5005";
			      PK_KitDevice = "2501";
			      Service = "urn:micasaverde-com:serviceId:HaDevice1";
			      Variable = "Documentation";
			      Value = "http://code.mios.com/trac/mios_evolve-lcd1"
			    }, {
			      PK_KitDevice_Variable = "5006";
			      PK_KitDevice = "2501";
			      Service = "urn:micasaverde-com:serviceId:ZWaveDevice1";
			      Variable = "Documentation";
			      Value = "http://code.mios.com/trac/mios_evolve-lcd1"
				},
				-- Cooper RFWC5
				{
			      PK_KitDevice_Variable = "5011";
			      PK_KitDevice = "2503";
			      Service = "urn:micasaverde-com:serviceId:SceneController1";
			      Variable = "NumButtons";
			      Value = "5"
			    }, {
			      PK_KitDevice_Variable = "5012";
			      PK_KitDevice = "2503";
			      Service = "urn:micasaverde-com:serviceId:SceneController1";
			      Variable = "FiresOffEvents";
			      Value = "1"
			    }, {
			      PK_KitDevice_Variable = "5013";
			      PK_KitDevice = "2503";
			      Service = "urn:micasaverde-com:serviceId:SceneController1";
			      Variable = "ActivationMethod";
			      Value = "0"
			    },
				-- Nexia One Touch
			    {
			      PK_KitDevice_Variable = "5021";
			      PK_KitDevice = "2504";
			      Service = "urn:micasaverde-com:serviceId:SceneController1";
			      Variable = "NumButtons";
			      Value = "5"
			    }, {
			      PK_KitDevice_Variable = "5022";
			      PK_KitDevice = "2504";
			      Service = "urn:micasaverde-com:serviceId:SceneController1";
			      Variable = "FiresOffEvents";
			      Value = "1"
			    }, {
			      PK_KitDevice_Variable = "5023";
			      PK_KitDevice = "2504";
			      Service = "urn:micasaverde-com:serviceId:SceneController1";
			      Variable = "ActivationMethod";
			      Value = "0"
			    }, {
			      PK_KitDevice_Variable = "5024";
			      PK_KitDevice = "2504";
			      Service = "urn:micasaverde-com:serviceId:ZWaveDevice1";
			      Variable = "VariablesSet";
			      Value =  "20-Touch Calibration (1-10),m,,"..
	                       "21-Screen Contrast (1-10),m,,"..
	                       "23-Button LED Level (1-10),m,,"..
	                       "24-Backlight Level (1-10),m,,"..
	                       "25-Scene Button Press Backlight Timeout (10-15),m,,"..
	                       "26-Page Button Press Backlight Timeout (5-15),m,,"..
	                       "28-Screen Timeout (1-240),m,,"..
	                       "29-Screen Timeout Primary Page (0-3),m,,"..
	                       "30-Battery Stat Shutdown Threshold % (0-20),m,,"..
	                       "31-Battery Radio Cutoff Threshold % (0-40),m,,"..
						   "32-Battery LOWBATT Indicator Threshold % (5-50),m,,"..
						   "33-Battery Threshold Value for Midlevel % (30-80),m,"
			    }, {
			      PK_KitDevice_Variable = "5025";
			      PK_KitDevice = "2504";
			      Service = "urn:micasaverde-com:serviceId:HaDevice1";
			      Variable = "Documentation";
			      Value = "http://products.z-wavealliance.org/products/1344"
			    }, {
			      PK_KitDevice_Variable = "5026";
			      PK_KitDevice = "2504";
			      Service = "urn:micasaverde-com:serviceId:ZWaveDevice1";
			      Variable = "Documentation";
			      Value = "http://products.z-wavealliance.org/products/1344"
			    },
			    -- Qubino Flush RGBW Dimmer
				{
			      PK_KitDevice_Variable = "5027";
			      PK_KitDevice = "2505";
			      Service = "urn:micasaverde-com:serviceId:ZWaveDevice1";
			      Variable = "VariablesSet";
			      Value =  "1-Input Switch type (1=toggle 2=pushbutton),m,,"..
	                       "2-Shwitch mode (1=normal 2=brightness 3=rainbow),m,,"..
	                       "3-Auto scene mode set (1=ocean 2=lightning 3=rainbow 4=snow 5=sun),m,,"..
	                       "4-Auto scene duration (1-127),m,"
				}
		    }
			for i, v in pairs(array) do
				for j,v2 in pairs(obj.KitDevice_Variable) do
					if v.PK_KitDevice == v2.PK_KitDevice and
					   v.Service == v2.Service and
					   v.Variable == v2.Variable then
					   table.remove(obj.KitDevice_Variable,j)
					   break
					end
				end
				table.insert(obj.KitDevice_Variable, v)
			end
		end, updated )

  else -- UI5
    UpdateFileWithContent("/www/cmh/skins/default/icons/EvolveLCD1_50x50.png", EvolveLCD1Icon, 644, nil, updated)
    UpdateFileWithContent("/www/cmh/skins/default/icons/CooperRFWC5_50x50.png", CooperRFWC5Icon, 644, nil, updated)
	UpdateFileWithContent("/www/cmh/skins/default/icons/NexiaOneTouch_50x50.png", NexiaOneTouchIcon, 644, nil, updated)
	UpdateFileWithContent("/etc/cmh/zwave_products_user.xml", [[
<root>
	<deviceList>
		<device id="2501" manufacturer_id="0113" basic="" generic="" specific="" child="" prodid="4C32" prodtype="4556" device_file="D_EvolveLCD1.xml" zwave_class="" default_name="Evolve LCD1 Z-Wave" manufacturer_name="Evolve Guest Controls" model="EVLCD1" invisible="1">
			<variable service="urn:micasaverde-com:serviceId:SceneController1" variable="NumButtons" value="5" />
			<variable service="urn:micasaverde-com:serviceId:SceneController1" variable="FiresOffEvents" value="1" />
			<variable service="urn:micasaverde-com:serviceId:SceneController1" variable="ActivationMethod" value="0" />
			<variable service="urn:micasaverde-com:serviceId:ZWaveDevice1" variable="VariablesSet" value="20-Display Timeout (seconds),m,,21-Backlight ON level (1-20),m,,22-Backlight OFF level (0-20),m,,23-Button ON level (1-20),m,,24-Button OFF level (0-20),m,,25-LCD Contrast (5-20),m,,26-Orientation(1=rotate 180 0=normal),m,,27-Network Update (seconds),m,,29-backlight level (0-100),m,,32-Backlight Demo mode (0-1),m," />
			<variable service="urn:micasaverde-com:serviceId:HaDevice1" variable="Documentation" value="http://code.mios.com/trac/mios_evolve-lcd1" />
			<variable service="urn:micasaverde-com:serviceId:ZWaveDevice1" variable="Documentation" value="http://code.mios.com/trac/mios_evolve-lcd1" />
		</device>
		<device id="2502" manufacturer_id="0113" basic="" generic="" specific="" child="" prodid="5434" prodtype="4556" device_file="D_HVAC_ZoneThermostat1.xml" zwave_class="" default_name="Evolve T100R Thermostat" manufacturer_name="Evolve Guest Controls" model="T100R" basic_class="0x25">
			<variable service="urn:micasaverde-com:serviceId:HaDevice1" variable="Commands" value="hvac_off,hvac_auto,hvac_cool,hvac_heat,heating_setpoint,cooling_setpoint,fan_auto,fan_on,fan_circulate,XX_energy_energy,XX_energy_normal" />
			<variable service="urn:micasaverde-com:serviceId:ZWaveDevice1" variable="VariablesSet" value="1-System Type(0=Standard 1=Heat Pump 2=Heat Pump Dual Fuel),m,0,2-Fan Type(0=gas 1=electric),m,0,3-Change Over Type(0=CO w/cool 1=CO w/heat),m,0,4-2nd Stage Heat(0=disable 1=enable),m,0,5-Aux Heat(0=disable 1=enable),m,0,6-2nd Stage Cool(0=disable 1=enable),m,0,7-(0=Centigrade 1=Fahrenheit),m,1,8-Minimum Off Time(5-9),m,5,9-Minimum Run Time(3-9),m,3,10-Setpoint H/C Delta(3-15),m,3,11-H Delta Stage 1 ON(1-6),m,1,12-H Delta Stage 1 OFF(0-8),m,0,13-H Delta Stage 2 ON(2-7),m,2,14-H Delta Stage 2 OFF(0-8),m,0,15-H Delta Aux ON(3-8),m,3,16-H Delta Aux OFF(0-8),m,0,17-C Delta Stage 1 ON(1-7),m,1,18-C Delta Stage 1 OFF(0-8),m,0,19-C Delta Stage 2 ON(2-8),m,2,20-C Delta Stage 2 OFF(0-8),m,0,24-Display Lock(0=unlocked 1=locked),m,0,25-Screen Timeout(0;20-120),m,0,26-Backlight Timer(0;20-120),m,30,27-Backlight On Level(0-20),m,20,28-Backlight Off Level(0-20),m,0,29-Contrast(5-20),m,12,30-Backlight brightness(0-100),m,100,33-UI Max Heat Setpoint(40-109),m,85,34-UI Min Cool Setpoint(43-112),m,65,35-Fan Cycle ON Time(0-120;0=Off),m,0,36-Fan Cycle OFF Time(10-120),m,10,37-Recovery(0=Disabled; 1=Enabled),m,0,38-Schedule(0=Disabled; 1=Enabled),m,0,39-Run/Hold Mode(0=Hold; 1=Run),m,0,40-Setback Mode(0=No Setback; 1=Unoccupied Mode),m,0,41-Unoccupied HSP(65-85),m,68,42-Unoccupied CSP(65-85),n,72,43-R1 Sensor Node#(0=Disabled 1-252),m,0,44-R2 Sensor Node#(0=Disabled 1-252),m,0,45-R1 sensor Type(0=internal;1=outside),m,0,46-R1 Sensor Temperature,m,0,47-R2 Sensor Temperature,m,0,48-Internal Sensor Temp Offset(-7 - 7),m,0,49-R1 Sensor Temp Offset (-7 - 7),m,0,50-R2 Sensor Temp Offset (-7 - 7),m,0,51-Outside Sensor Temp Offset (-7 - 7),m,0,52-Filter Timer(hours),m,0,53-Filter Timer Max(hours),m,0,54-Heat Timer(hours),m,0,55-Cool Timer(hours),m,0,56-Maint Timer(hours),m,0,57-Maint Timer Max(hours),m,0,58-Filter Alert(0=No Alert; 1=Alert),m,0,59-Mait Alert(0=No Alert; 1=Alert),m,0,60-Temperature Response(1-6),m,2" />
			<variable service="urn:upnp-org:serviceId:TemperatureSetpoint1" variable="AutoMode" value="2" />
		</device>
		<device id="2503" manufacturer_id="001A" basic="" generic="" specific="" child="" prodid="0000" prodtype="574D" device_file="D_CooperRFWC5.xml" zwave_class="" default_name="Cooper RFWC5 Z-Wave" manufacturer_name="Cooper Industries" model="RFWC5" invisible="1">
			<variable service="urn:micasaverde-com:serviceId:SceneController1" variable="NumButtons" value="5" />
			<variable service="urn:micasaverde-com:serviceId:SceneController1" variable="FiresOffEvents" value="1" />
			<variable service="urn:micasaverde-com:serviceId:SceneController1" variable="ActivationMethod" value="0" />
		</device>
		<device id="2504" manufacturer_id="0178" basic="" generic="" specific="" child="" prodid="4735" prodtype="5343" device_file="D_NexiaOneTouch.xml" zwave_class="" default_name="Nexia One Touch Z-Wave" manufacturer_name="Ingersoll Rand" model="NX1000" invisible="1">
			<variable service="urn:micasaverde-com:serviceId:SceneController1" variable="NumButtons" value="5" />
			<variable service="urn:micasaverde-com:serviceId:SceneController1" variable="FiresOffEvents" value="1" />
			<variable service="urn:micasaverde-com:serviceId:SceneController1" variable="ActivationMethod" value="0" />
			<variable service="urn:micasaverde-com:serviceId:ZWaveDevice1" variable="VariablesSet" value="20-Touch Calibration (1-10),m,,21-Screen Contrast (1-10),m,,23-Button LED Level (1-10),m,,24-Backlight Level (1-10),m,,25-Scene Button Press Backlight Timeout (10-15),m,,26-Page Button Press Backlight Timeout (5-15),m,,28-Screen Timeout (1-240),m,,29-Screen Timeout Primary Page (0-3),m,,30-Battery Stat Shutdown Threshold % (0-20),m,,31-Battery Radio Cutoff Threshold % (0-40),m,,32-Battery LOWBATT Indicator Threshold % (5-50),m,,33-Battery Threshold Value for Midlevel % (30-80),m," />
			<variable service="urn:micasaverde-com:serviceId:HaDevice1" variable="Documentation" value="http://products.z-wavealliance.org/products/1344" />
			<variable service="urn:micasaverde-com:serviceId:ZWaveDevice1" variable="Documentation" value="http://products.z-wavealliance.org/products/1344" />
		</device>
		<device id="4002" manufacturer_id="86" basic="" generic="" specific="" child="" prodid="50" prodtype="4" device_file="D_Siren1.xml" zwave_class="" default_name="_Aeon Siren Euro" manufacturer_name="Aeon Labs" model="ZW080" basic_class="0x25" basic_class="0x25">
			<variable service="urn:micasaverde-com:serviceId:ZWaveDevice1" variable="VariablesSet" value="37-Sound(0-5)*256 + Volume(0-3),m,,80-Group 1 Notifications (0=no 1=hail 2=basic report),m,,200-Partner ID,m,,252-Enable lock configuration,m," />
			<variable service="urn:micasaverde-com:serviceId:HaDevice1" variable="Documentation" value="http://www.vesternet.com/resources/application-notes/apnt-90" />
			<variable service="urn:micasaverde-com:serviceId:ZWaveDevice1" variable="Documentation" value="http://blog.m.nu/wp-content/uploads/2014/11/Aeon-Labs-Siren-Gen5-V1.23.pdf" />
		</device>
		<device id="4003" manufacturer_id="86" basic="" generic="" specific="" child="" prodid="50" prodtype="104" device_file="D_Siren1.xml" zwave_class="" default_name="_Aeon Siren USA" manufacturer_name="Aeon Labs" model="ZW080" basic_class="0x25">
			<variable service="urn:micasaverde-com:serviceId:ZWaveDevice1" variable="VariablesSet" value="37-Sound(0-5)*256 + Volume(0-3),m,,80-Group 1 Notifications (0=no 1=hail 2=basic report),m,,200-Partner ID,m,,252-Enable lock configuration,m," />
			<variable service="urn:micasaverde-com:serviceId:HaDevice1" variable="Documentation" value="http://www.vesternet.com/resources/application-notes/apnt-90" />
			<variable service="urn:micasaverde-com:serviceId:ZWaveDevice1" variable="Documentation" value="http://blog.m.nu/wp-content/uploads/2014/11/Aeon-Labs-Siren-Gen5-V1.23.pdf" />
		</device>
	    <device id="4000" manufacturer_id="86" basic="" generic="" specific="" child="" prodid="4e" prodtype="3" device_file="D_BinaryLight1.xml" zwave_class="" default_name="_Aeon Heavy Duty Switch" manufacturer_name="Aeon Labs" model="ZW078" basic_class="0x25">
			<variable service="urn:micasaverde-com:serviceId:HaDevice1" variable="Documentation" value="http://www.vesternet.com/resources/application-notes/apnt-89" />
			<variable service="urn:micasaverde-com:serviceId:ZWaveDevice1" variable="Documentation" value="http://www.vesternet.com/resources/application-notes/apnt-89" />
		</device>
	</deviceList>
</root>
]], 644, nil, updated)
	end	-- UI5

	-- Drop the uninstaller files if necessary
  	UpdateFileWithContent("/usr/lib/lua/zwint.so", zwint_so, 755, zwint_so_version)
  	UpdateFileWithContent("/etc/cmh-ludl/D_GenGenSceneControllerUninstaller.json.lzo", D_GenGenSceneControllerUninstaller_json_lzo, 644, uninstaller_version, updated)
  	UpdateFileWithContent("/etc/cmh-ludl/D_GenGenSceneControllerUninstaller.xml.lzo",  D_GenGenSceneControllerUninstaller_xml_lzo,  644, uninstaller_version, updated)
  	UpdateFileWithContent("/etc/cmh-ludl/I_GenGenSceneControllerUninstaller.xml.lzo",  I_GenGenSceneControllerUninstaller_xml_lzo,  644, uninstaller_version, updated)
  	UpdateFileWithContent("/etc/cmh-ludl/L_GenGenSceneControllerUninstaller.lua.lzo",  L_GenGenSceneControllerUninstaller_lua_lzo,  644, uninstaller_version, updated)
  	UpdateFileWithContent("/etc/cmh-ludl/S_GenGenSceneControllerUninstaller.xml.lzo",  S_GenGenSceneControllerUninstaller_xml_lzo,  644, uninstaller_version, updated)

	-- Create the uninstaller device if it does not yet exist
	local uninstaller_found = false
	for dev_num, v in pairs(luup.devices) do
		if v.device_type == "urn:schemas-gengen_mcv-org:device:SceneControllerUninstaller:1" then
			uninstaller_found = true
			break
		end
	end
	if not uninstaller_found then
	    luup.call_action(HAG_SID, "CreateDevice", {
		   	deviceType = "urn:schemas-gengen_mcv-org:device:SceneControllerUninstaller:1";
			Description = "Scene Controller Uninstaller";
		   	UpnpDevFilename = "D_GenGenSceneControllerUninstaller.xml";
		   	UpnpImplFilename =  "I_GenGenSceneControllerUninstaller.xml";
			StateVariables = "invisible=0"; -- TODO Set invisible=1 when we make this into a real plug-in 
		},0)
		reload_needed = "Uninstaller created";
	end


	-- Update scene controller devices which may have been included into the Z-Wave network before the installer ran.
	ScanForNewDevices()

	if reload_needed then
		log("Files updated including ",reload_needed,". Reloading LuaUPnP.")
		luup.call_action(HAG_SID, "Reload", {}, 0)
	else
		VLog("Nothing updated. No need to reload.")
	end
end	-- function SceneControllerInstaller_Init

