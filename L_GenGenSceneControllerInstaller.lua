-- Installer for GenGeneric Scene Controller Version 1.10
-- Copyright 2016-2017 Gustavo A Fernandez. All Rights Reserved
--
-- Includes installation files for
--   Evolve LCD1
--   Cooper RFWC5
--   Nexia One Touch NX1000
-- This installs zwave_products_user.xml for UI5 and modifies KitDevice.json for UI7.
-- It also installs the custom icon in the appropriate places for UI5 or UI7

-- VerboseLogging == 0: important logs and errors:    ELog, log
-- VerboseLogging == 1: Includes debug logs:          ELog, log, DLog, DEntry
-- VerboseLogging == 2: Include extended ZWave Queue  ELog, log, DLog, DEntry
-- VerboseLogging == 3:	Includes verbose logs:        ELog, log, DLog, DEntry, VLog, VEntry
VerboseLogging = 0

-- Set UseDebugZWaveInterceptor to true to enable zwint log messages to log.LuaUPnP (Do not confuse with LuaUPnP.log)
local UseDebugZWaveInterceptor = false

local bit = require 'bit'
local nixio = require "nixio"
local socket = require "socket"
require "L_GenGenSceneControllerShared"

local GenGenInstaller_Version = 21 -- Update this each time we update the installer.

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
function UpdateFileWithContent(filename, content, permissions, version)
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
		if version > oldversion or (version == oldversion and stat.size ~= #content) then
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
				reload_needed = true
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
function PrepFileForUpdate(base)
	local base_modified = base .. ".modified"
	local base_save = base .. ".save"
	local base_old = base .. ".old"
	local base_temp = base .. ".temp"
	local base_mtime, errno, errmsg = nixio.fs.stat(base,"mtime")
	if not base_mtime then
		ELog("could not stat ", base, ": ", errmsg)
		return nil
	end
	local base_modified_mtime, errno, errmsg = nixio.fs.stat(base_modified,"mtime")
	if not base_modified_mtime or base_mtime ~= base_modified_mtime then
		nixio.fs.rename(base_modified, base_old)
		local result, errno, errmsg = nixio.fs.rename(base, base_save)
		if not result then
			ELog("could not rename ", base, " to", base_save, ": ", errmsg)
			nixio.fs.rename(base_old, base_modified)
			return nil
		end
		local read_file, errmsg, errno = io.open(base_save, "r")
		if not read_file then
			ELog("could not open ", base_save, " for reading: ", errmsg)
		    nixio.fs.rename(base_save, base)
			nixio.fs.rename(base_old, base_modified)
			return nil
		end
		local write_file, errmsg, errno = io.open(base_modified, "w", 644)
		if not write_file then
			ELog("could not open ", base_modified, " for writing: ", errmsg)
			read_file:close()
		    nixio.fs.rename(base_save, base)
			nixio.fs.rename(base_old, base_modified)
			return nil
		end
		local result, errno, errmsg = nixio.fs.symlink(base_modified, base)
		if not result then
			ELog("could not symlink ", base_modified, " to", base, ": ", errmsg)
			write_file:close()
			read_file:close()
		    nixio.fs.rename(base_save, base)
			nixio.fs.rename(base_old, base_modified)
			return nil
		end
		nixio.fs.remove(base_old)
		return read_file, write_file
	end
	return nil
end

function updateJson(filename, update_func)
	read_file, write_file = PrepFileForUpdate(filename)
	if read_file then
		log("Updating ", filename)
		local str = read_file:read("*a")
		read_file:close()
		local obj=json.decode(str);
		update_func(obj)
		local state = { indent = true }
		local str2 = json.encode (obj, state)
		write_file:write(str2)
		write_file:close()
		reload_needed = true
	else
		VLog("Not updating ", filename)
	end
end

ScannedDeviceList = {}

function ScanForNewDevices()

	local function AdoptEvolveLCD1(device_num)
		log("Found a new Evolve LCD1 controller. Device: ", device_num)
		luup.attr_set("device_type", "urn:schemas-gengen_mcv-org:device:SceneControllerEvolveLCD:1", device_num)
		luup.attr_set("device_file", "D_EvolveLCD1.xml", device_num)
		luup.attr_set("impl_file", "I_GenGenSceneController.xml", device_num)
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
		log("Found a new Cooper RFWC5 controller. Device: ", device_num)
		luup.attr_set("device_type", "urn:schemas-gengen_mcv-org:device:SceneControllerCooperRFWC5:1", device_num)
		luup.attr_set("device_file", "D_CooperRFWC5.xml", device_num)
		luup.attr_set("impl_file", "I_GenGenSceneController.xml", device_num)
		luup.attr_set("manufacturer", "Cooper Industries", device_num)
		luup.attr_set("name", "Cooper RFWC5 Controller Z-Wave", device_num)
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
		log("Found a new Nexia One Touch controller. Device num: ", device_num)
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
	local function ApplyKichler12387Hack(device_num, node_id)

		local function Kichler12387Callback(peer_dev_num, result)
			log("Kichler 12387 node info intercept: device num=".. device_num.." node_id="..node_id.. "result=".. tableToString(result));
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

42      04/02/17 23:01:39.737     0x1 0xc 0x0 0x49 0x84 0x60 0x6 0x2 0x11 0x0 0x72 0x85 0x26 0x99 (###I#`####r#&#) 
             SOF - Start Of Frame --+   ¦   ¦    ¦    ¦    ¦   ¦   ¦    ¦   ¦    ¦    ¦    ¦    ¦
                      length = 12 ------+   ¦    ¦    ¦    ¦   ¦   ¦    ¦   ¦    ¦    ¦    ¦    ¦
                          Request ----------+    ¦    ¦    ¦   ¦   ¦    ¦   ¦    ¦    ¦    ¦    ¦
    FUNC_ID_ZW_APPLICATION_UPDATE ---------------+    ¦    ¦   ¦   ¦    ¦   ¦    ¦    ¦    ¦    ¦
Update state = Node Info received --------------------+    ¦   ¦   ¦    ¦   ¦    ¦    ¦    ¦    ¦
Node ID: 96 Device 204=UD17F Breakfast undercabinet lights +   ¦   ¦    ¦   ¦    ¦    ¦    ¦    ¦
             Node info length = 6 -----------------------------+   ¦    ¦   ¦    ¦    ¦    ¦    ¦
   Basic type = Static Controller ---------------------------------+    ¦   ¦    ¦    ¦    ¦    ¦
 Generic type = switch multilevel --------------------------------------+   ¦    ¦    ¦    ¦    ¦
         Specific type = Not used ------------------------------------------+    ¦    ¦    ¦    ¦
Can receive command class[1] = COMMAND_CLASS_MANUFACTURER_SPECIFIC --------------+    ¦    ¦    ¦
Can receive command class[2] = COMMAND_CLASS_ASSOCIATION -----------------------------+    ¦    ¦
Can receive command class[3] = COMMAND_CLASS_SWITCH_MULTILEVEL ----------------------------+    ¦
                      Checksum OK --------------------------------------------------------------+
--]==]
		                 "06 01 04 01 60 01 XX 01 0C 00 49 84 " .. string.format("%02X", node_id) .. " 06 02 11 00 72 85 26 XX", -- Autoresponse,
		                 Kichler12387Callback,
		                 false, -- Not OneShot
		                 0, -- no timeout
						 "Kichler12387NodeInfo", -- label
						 false) -- no forward
	end

	-- This is a hack for UI7 1.7.2608 mishandling of the Shlage BE469 lock. It is incorrectly sending a Command Cleass Version, Version Command Class Get in non-secure mode.
	local function ApplySchageLockHack(device_num, node_id)

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
42      04/02/17 15:21:37.631   0x1 0xa 0x0 0x4 0x0 0xba 0x4 0x86 0x14 0x71 0x3 0xbd 
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
                    Version = 3 ----------------------------------------------+    ¦
                    Checksum OK ---------------------------------------------------+
--]==]
		                 "06 01 04 01 \\1 01 XX 01 05 00 \\1 \\2 00 XX 01 0A 00 04 00 " .. string.format("%02X", node_id) .. " 04 86 14 71 03 XX", -- Autoresponse,
		                 ShlageLockVersionCallback,
		                 false, -- Not OneShot
		                 0, -- no timeout
						 "ShlageLockVersion", -- label
						 false) -- no forward
	end

	for device_num, device in pairs(luup.devices) do
		if device.device_type == "urn:schemas-gengen_mcv-org:device:SceneControllerEvolveLCD:1" then
			local impl = luup.attr_get("impl_file", device_num)  
			if impl == "I_EvolveLCD1.xml" then
			  	reload_needed = true
			  	log("Updating the implementation file of the existing Evolve LCD1 peer device: ", device_num)
			  	luup.attr_set("impl_file", "I_GenGenSceneController.xml", device_num);
			end
		elseif device.device_type == "urn:schemas-gengen_mcv-org:device:SceneControllerCooperRFWC5:1" then
			local impl = luup.attr_get("impl_file", device_num) 
			if impl == "I_CooperRFWC5.xml" then
				reload_needed = true
			  	log("Updating the implementation file of the existing Cooper RFWC5 peer device: ", device_num)
			  	luup.attr_set("impl_file", "I_GenGenSceneController.xml", device_num);
			end
		elseif device.device_num_parent and
			luup.devices[device.device_num_parent] and
			luup.devices[device.device_num_parent].device_type == "urn:schemas-micasaverde-com:device:ZWaveNetwork:1" then
	  		local manufacturer_info = luup.variable_get("urn:micasaverde-com:serviceId:ZWaveDevice1", "ManufacturerInfo", device_num)
			local capabilities = luup.variable_get("urn:micasaverde-com:serviceId:ZWaveDevice1", "Capabilities", device_num)
		  	if manufacturer_info == "275,17750,19506" then
	        	if device.device_type ~= 'urn:schemas-gengen_mcv-org:device:SceneControllerEvolveLCD:1' then
					AdoptEvolveLCD1(device_num)
			  		reload_needed = true
				end
			elseif manufacturer_info == "26,22349,0" then
				if device.device_type ~= "urn:schemas-gengen_mcv-org:device:SceneControllerCooperRFWC5:1" then
					AdoptCooperRFWC5(device_num)
		 			reload_needed = true
				end 
			elseif manufacturer_info == "376,21315,18229" then
				if device.device_type ~="urn:schemas-gengen_mcv-org:device:SceneControllerNexiaOneTouch:1" then
					AdoptNexiaOneTouch(device_num)
					reload_needed = true
	  			end
			elseif manufacturer_info == "59,25409,20548" then
				ApplySchageLockHack(device_num, device.id)
			elseif capabilities == "146,150,0,2,17,0,L,B,|38,114,133," then
				ApplyKichler12387Hack(device_num, device.id)
			end
		end
	end	-- for device_num

	local function NexiaManufacturerCallback(peer_dev_num, result)
		local time = tonumber(result.time)
		local receiveStatus = tonumber(result.C1, 16)
		local node_id = tonumber(result.C2, 16)
		local device_num = NodeIdToDeviceNumber(node_id)
		DEntry("NexiaManufacturerCallback")
		if device_num and CheckDups(device_num, time, receiveStatus, "72050178534347359e"..result.C2) then
			local device = luup.devices[device_num]
			if device and device.device_type ~= "urn:schemas-gengen_mcv-org:device:SceneControllerNexiaOneTouch:1" then
				AdoptNexiaOneTouch(device_num)
				log("Nexia One-Touch adopted. Reloading LuaUPnP.")
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
end

-- Return whether this is the latest version of the installer and if there
-- is more than one installer device of the same version, whether or not
-- this is the lowest device number
function IsFirstAndLatestInstallerVersion(our_dev_num, our_version)
	local version = 0;
	local count = 0;
	local our_index = 0;
	local sorted = {}
	local ourVerStr = luup.variable_get(GENGENINSTALLER_SID, "Version", our_dev_num)
	if not ourVerStr then
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
				if ver > our_version then
					return false -- The version of the other device is greater than ours
				elseif ver == our_version and our_index == 0 then
					return false -- We found the same version of another device before we found us.
				end
			end
		end
	end
	return true
end

function DeleteOldInstallers(our_dev_num)
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
  if not IsFirstAndLatestInstallerVersion(lul_device, GenGenInstaller_Version) then
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
  local zwint_so_version = 1.04
  local zwint_so
  if UseDebugZWaveInterceptor then
    -- zwint debug version
    zwint_so = b642bin([[
    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
    AABIAgAAYDcAAAAAAAASAAAAcAEAAFA3AAAAAAAAEgAAAEACAABANwAAAAAAABIAAAAmAgAAMDcA
    AAAAAAASAAAA9wEAACA3AAAAAAAAEgAAAPQAAAAQNwAAAAAAABIAAAAIAgAAADcAAAAAAAASAAAA
    MwIAAPA2AAAAAAAAEgAAADsCAADgNgAAAAAAABIAAABQAAAA0DYAAAAAAAASAAAA1QEAAMA2AAAA
    AAAAEgAAAEsBAACwNgAAAAAAABIAAADrAAAAoDYAAAAAAAASAAAAWwEAAJA2AAAAAAAAEgAAAIoB
    AACANgAAAAAAABIAAAC8AAAAcDYAAAAAAAASAAAAkQEAAGA2AAAAAAAAEgAAAJYAAABQNgAAAAAA
    ABIAAACLAgAAQDYAAAAAAAASAAAA8AEAADA2AAAAAAAAEgAAAHwCAAAgNgAAAAAAABIAAABGAQAA
    EDYAAAAAAAASAAAAJgAAAAAAAAAAAAAAIgAAAIEBAAAANgAAAAAAABIAAAAQAQAA8DUAAAAAAAAS
    AAAA4AAAAOA1AAAAAAAAEgAAAHgBAADQNQAAAAAAABIAAADIAAAAwDUAAAAAAAASAAAAqQEAALA1
    AAAAAAAAEgAAAK4AAACgNQAAAAAAABIAAAAUAgAAkDUAAAAAAAASAAAAyAEAAIA1AAAAAAAAEgAA
    AKIBAABwNQAAAAAAABIAAABoAAAAYDUAAAAAAAASAAAAAF9HTE9CQUxfT0ZGU0VUX1RBQkxFXwBf
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
    BAAAAAAQALyPAQARBAAAAAACABw8zMKcJyHgnwMkgJmPADU5J+0JEQQAAAAAEAC8jxwAv48IAOAD
    IAC9JwIAHDygwpwnIeCZA9D/vScoALOvGICTjxAAvK8sAL+vIFFikiQAsq8gALGvHACwrxsAQBTs
    gIKPBQBAEByAgo/sgJmPCfggAwAARIwQALyPGICSjyCAkY8YgJCPvE9SJiOIMgKDiBEABwAAEP//
    MSYkUQKugBACACEQUgAAAFmMCfggAwAAAAAkUQKOKxhRAPf/YBQBAEIkAQACJCBRYqIsAL+PKACz
    jyQAso8gALGPHACwjwgA4AMwAL0nAgAcPOTBnCch4JkDGICEj8RPgowGAEAQAAAAAECAmY8DACAT
    AAAAAAgAIAPET4QkCADgAwAAAAAAAAAAAAAAAAAAAAAA8AJqmPEcCwD0QDJp4sRkmmUE0lxncPB8
    muVnMPCkmrDwWJrEZ4CbJ/EQTUDqOmVEZKDoAPACanjxCAsA9EAyaeLEZJplBNJcZxDweJow8FSa
    avSsmwFNavSs20DqOmVEZCDoAWoAZQDwAmo48RQLAPRAMmnixWSaZQTSXGcQ8ViaBgUBbEDqOmUG
    k+DzCGoHlFjrBrNFZBLqeuwBK+XoEutp4sD3QzOg6ABlQEIPAADwAmr48AwLAPRAMmnimmXuZBxn
    CtJw8EyYDARA6jplCpZw8FSYDASeZQ8FQOo6ZXDwXJgUkwqWgJpkalrrASrl6H1nMPCkmLDwGJie
    ZRKXE5Y4ZUfxDE0Q6gTSEZIF0hCSBtIPkgfSWqtA6AjSbmSg6ABlAPACanjwGAsA9EAyaeKaZfdk
    PGcG0hDwWJkEZ6rxeJpq7GCcAmGq8XjagZiB22GYgJiA2zDwZJkI0gH3EUtA6ztlBpYIknDwnJme
    Zarx2JqAnDDwpJlgnsOeZ/EcTUCb45tjmgTTQJpDmgXSsPBYmUDqOmUGllKAnmUIIlDwVJmHQBFM
    QOo6ZQaWnmVQ8FSZh0AxTEDqOmUGljDwOJmQZ55lQOk5ZXdkoOgAZQDwAmrX9wwLAPRAMmnimmX4
    ZBxnEPB4mATSMPAkmArwQJsB9xFJAFJoYArTQOk5ZXDwXJgEljDwhJigmlDwUJieZYfxHExA6jpl
    BJbQ8FiYAmyeZaRnAG5A6jplBJYKkwBSnmUK8EDbEmBw8ESYQOo6ZTDwhJgw8ASYoJqn8RBMYfYB
    SEDoOGUBakvqUhAAa51nCNMJ0wJrbMzs9xNra+ttzCazgmcQ8UiYEG4H0wYFQOo6ZQSWAFKeZR9g
    cPBEmEDqOmWgmjDwRJgw8ISYYfYBSsfxAExA6jplEPBYmASWCvCAmjDwXJieZUDqOmUQ8HiYAWpL
    6grwQNtA6TllBJYw8KSYsPAYmJ5lXGd8Z3DwXJoQ8Hibx/EcTYCaCvDAm0DoOGUElp5lnGcQ8Jic
    CvBAnHhkoOgAZX8AAAEA8AJql/YQCwD0QDJp4pplCPD1ZBxnBNLQ8FCYJGdA6jplBJYw8FSYC5We
    ZZFnQOo6ZQSWEPFAmAuUnmVA6jplBJaQ8AiYkWeiZ55lQOg4ZXVkIOgDagBlAPACajf2GAsA9EAy
    aeKaZfZkHGcE0vDwWJgkZ0DqOmUElgFSnmUnYdDwRJiRZwFtQOo6ZQSWnmUeIrDwSJiRZwFtQOo6
    ZQSWnmULKjDwxJiQ8ASYkWcBbefxDE5A6DhlchDw8FSYAW2RZ0DqOmUElqJnnmUCEAFtq+0Q8HiY
    cPBImAfVKvEUS4NnBtNA6jplBJYGkweVnmUQ8NiYqvFcngFSJmCQ8EyYg2cG1kDqOmUEltDwUJiR
    Z55lBpY6ZarxvJ5A6gfVBJYw8FSYB5WeZTplQOqRZwSWMPCkmJDwCJieZZFnB/IMTUDoOGUDal4Q
    /0qq8VzeKioQ8FiYEPCYmAbTyvGkmvDwSJjK8YCcQOo6ZQSWAFKeZRdgcPBEmEDqOmWgmgSWkPBM
    mAaTMPAEmDplg2eeZUDqB9UHlWLxDUiRZ0DoOGUyEAFtq+0Q8FiYqvGYmhMQAFVAnANhYpxq7Qxh
    MPBkmAbSB9WB9wVLQOs7ZQSWB5UGkp5lgmcQ8FiYSvEQSkvk5yqcZ5DwTJgQ8JicKvEUTEDqOmUE
    ltDwAJiRZ55lAW1A6DhlAWp2ZKDoAPACapf0CAsA9EAyaeKaZUTw+WQcZwbS0PBImAkGAW1A6jpl
    BpaL0p5lAyIJkiBaB2Ew8MSYkpQBbQfyHE4rEBDwOJhw8EiYKvEUSZFnQOo6ZRDwWJgGlqrxfJqe
    ZSYjkPBQmBDwuJiLlI3TyvEITUDqOmUGlo2TnmUSIpDwTJiRZ0DqOmUGlpKUAW2eZTDwxJgn8gxO
    kPAEmEDoOGXAERDwWJgBS6rxfNqgETDwJJiQ8FiYZ/IASZFnQOo6ZQaWitKeZcDwBCIQ8FiYAWtr
    68rxZNpbECqiCmtu6VcpC0r8Z4zSBNIw8MSY8PBcmDDw5J//bUoEAU1n8hBOZ/IAT0DqOmUGlvDw
    UJhKBJ5lCgX/bkDqOmUGlp5lOCIIA0njKMKQ8FCYi5UKBEDqOmUGlp5lLCrQ8EyYjJQKbggFQOo6
    ZQiTBpZgg55lICt8ZxDweJvK8UTbMPBEmAH3EUpA6jplBpZw8FyYMPCkmJ5lgJpcZxDwWJpn8hhN
    yvHEmrDwWJhA6jplBpaeZQgQ0PBUmIqUQOo6ZQaWnmWdKlDwTJiKlEDqOmUGlp5lfGcQ8HibyvFE
    mwBSEmCcZ5DwTJgQ8JicKvEUTEDqOmUGlpKUAW2eZTDwxJiH8hROXRcQ8HiYEPFUmIuVyvEIS4Nn
    itNA6jplBpYQ8JiYEPFEmJ5lMPDEmABt6vEITOX2CU7lZ0DqOmUGliJnnmXA8BYq/Gdw8FCYEPD4
    nwBuAWwCberxDE9A6jplBpaeZRIinGeQ8EyYEPCYnCrxFExA6jplBpaeZXDwRJhA6jploJqSlMAQ
    MPAkmAH3EUlA6TllBpYw8KSYnmVcZ3xnEPB4m3DwXJqn8hxN6vHMm4CaQ2fq8QxK4Zqw8FiYQOo6
    ZQaWnmVcZ3xnEPBYmhDweJvK8aSa8PBImOrxjJtA6jpli9JA6TllBpYw8KSYnmV8Z3DwfJtcZxDw
    WJqAm3xnEPB4m+rxzJqw8FiYyvHkm4uT5/IATTplQOoE0waWnmVcZxDwWJrq8YyaMPBcmEDqOmVA
    6TllBpYw8KSYnmVcZ3xnEPBYmnDwfJsH8whN6vHMmrDwWJiAm0DqOmWLkwaWAFOeZQ5gcPBEmEDq
    OmUGliCanmVcZxDwWJrq8QxKgZoyEFDwWJiKlAJtQOo6ZRDweJg5ZcrxQNtA6Y3TBpaNkzDwpJie
    ZVxncPBcmsrxwJsn8wRNgJqw8FiYQOo6ZY2TBpbK8UCbnmUAUiVgcPBEmEDqOmUGliCanmV8ZxDw
    eJvq8QxLgZsw8FyYQOo6ZQaWnmWcZ5DwTJgQ8JicKvEUTEDqOmWSlLFnMPAEmGLxDUhA6DhlWRZ8
    ZxDweJucZxDwmJyq8VybKvEUTAFKqvFc25DwTJhA6jplBpbQ8ACYkpSeZQFtQOg4ZQFqQPB5ZKDo
    AGUA8AJqd/AACwD0QDJp4pplBPD4ZBxnBNIQ8VCYAW1A6jplBJaeZQcqMPDEmBCUAW0n8xhOGhDw
    8FSYEJQBbUDqOmUJ0gSW0PBImBCUnmUCbQYGQOo6ZQSWCNKeZQsqMPDEmBCUAm1H8xBOkPAEmEDo
    OGVDEBDweJhw8EiYKvEUS4NnOmVA6grTBJYQ8FiYnmWq8TiaGRBCmQmTauoUYZDwUJiDmQiVQOo6
    ZQSWnmULKjDwRJiRZwFpgfcFSkDqOmUElp5lCBAgmRDwWJhK8RBKS+HhKgBpnGeQ8EyYEPCYnCrx
    FExA6jplBJbQ8ACYEJSeZbFnQOg4ZQFqeGSg6ABlAPACanb3AAsA9EAyaeKaZflkHGcw8CSYBtIB
    9xFJQOk5ZXDwXJgQ8HiYBpaAmhDwWJgw8KSYnmVK9PyaEPBYmGr0yJsN02r0QJpn8wRNBNKw8FiY
    QOo6ZQ2TavRImwnSgPANIhDweJhK9FybgPAHKhDweJhq9ECbgPABKgmTOWVhmwjTCZMIS0DpCtNw
    8FyYBpYw8KSYgJqw8FiYnmUKlwiWp/METUDqOmUw8GSYIvARSztlQOsN0xDw+JgGlrDwXJgK8ICf
    nmUKlQiWDNdA6jplC9JA6TllcPBcmAaWMPCkmICasPBYmJ5lC5bH8wRNQOo6ZQuSBpYNkwFSnmUM
    lydgAWpL6grwQN9A6ztlDJcGlrDwXJgK8ICfnmUKlQiWQOo6ZQjSQOk5ZQaWcPB8mDDwpJiw8FiY
    nmWAmwiW5/MITUDqOmUIkwaWAVOeZQZhfGcQ8HibAWpK9FzbCZNAm3xnEPB4m2r0SNsEKhDweJhq
    9ETbMPAYmAmUQOg4ZXlkoOgAZQDwAmrW9RwLAPRAMmnimmU48PZkPGcK0vDwVJkBbUDqOmVl0gqW
    0PBImWyUnmUCbQ8GQOo6ZQqWYdKeZQcqMPDEmWyUAm1H8xBOERDQ8EiZbJQOBgNtQOo6ZQqWYtKe
    ZQsqMPDEmWyUA20n9AhOkPAkmUDpOWUPElDwRJlslARtQOo6ZWbSCpYQ8VCZbJSeZQVtQOo6ZQqW
    nmUHKjDwxJlslAVtR/QATuIX8PBUmWyUBW1A6jplYNIKlvDwWJlslJ5lQOo6ZQqWBlKeZRZh0PBE
    mWyUBm1A6jplCpaeZRUi0PBImWyUDAYGbUDqOmUKlgFrXdKeZV/TDxAw8ASZAG9f10f3GEhd0AcQ
    MPDkmQBrX9NH9xhPXdfw8FiZbJRA6jplCpYHUp5lG2HQ8ESZbJQHbUDqOmUKlp5lEiLQ8EiZbJQN
    BgdtQOo6ZQqWXtKeZQ4qMPDEmWyUB21H9BhOhxcw8ASZAGoN0kf3GEhe0PDwWJlslEDqOmUKlgBv
    CFKeZWTXG2HQ8ESZbJQIbUDqOmUKlgFynmUKYVDwRJlslAhtQOo6ZQqWZNKeZQcQMPDEmWyUCG1n
    9BBOWhdQ8FyZYZRA6jplAmcKllDwXJlelJ5lQOo6ZUngCpaHQvDwQJmeZWNMQOo6ZQqWXNKeZQ0q
    cPBEmTDwJJlA6jploJpslGLxDUlA6TllNxdckLDwRJlilThIY9CQZwNuQOo6ZQqWAmeeZQwigmeQ
    8ECZY5X/bxAGLU9A6jplCpaeZSMQX5M/I1yTsPBEmV2VGEuDZwNuZ9NA6jplCpYCZ2eTnmUwIoJn
    kPBAmf9vo2cQBi1PQOo6ZQqWUPBUmWOUnmVA6jplCpaeZTDwWJlclEDqOmUKltDwUJlslJ5lQOo6
    ZQqWMPBUmWyUnmU6ZUDqsGcKlpDwKJlslJ5lEAVA6TllA2rsEGWTXJAQ8VSZYZVi2GhIkGdA6jpl
    CpZclVDwXJmeZQPdkGdA6jplCpYBSkHgnmXdZ7Dx5Ebgp1yWXWeQ8WhC8MZfl0CjfWcBX1HGcPGs
    Q1hnYKVTxhDxVJlelXLGkGdA6jplDZIBKgBovWeQ8cBFXJOgpmCXFtu0wwBsAG0PJzDwRJnB9glK
    QOo6ZWCQGeLA9wM0Q+6N41hnhmd14lyQmNi52DDwBJkB9xFIQOg4ZVyTCpZw8FyZsIOeZYCacGcF
    JTDwxJkH9BROBBAw8MSZJ/QATlyQMPCkmeOYXZCH9ARNBNBikAXQXpAG0FyQUYBgkGfTB9II0LDw
    WJlkkAnQEPAYmUDqOmUKlnDwSJkq8RRIkGeeZUDqOmVckhDw+Jlnk9maqvGYn7iaB2dEZy5lBxAQ
    8PiZQJpK8RBP/+IUJ9ia+ZoeZclnre4OZdhnze/IZwQmCSfYZ9/lBBDr7u3uwPfCNwFX5WChmlyX
    QN+h3+Dd4dqO6gIqqvH42EDrO2UKljDwpJmeZarx2JgcZ3DwHJhgnsOegJhAm+Obx/QcTWOaBNNA
    mkOaBdKw8FiZQOo6ZQqWkPBMmZ5lnGcQ8JicKvEUTEDqOmUKltDwIJlslJ5lAW1A6TllAWow8HZk
    oOgA8AJqVvEACwD0QDJp4ppl9mQ8ZwTSEPFQmWVnBtMBbTplQOoEZwSWBpOeZQsqMPDEmZDwJJmQ
    ZwFtJ/MYTkDpOWUIEDDwJJmQZ6NnI/IBSUDpOWV2ZKDoAPACavbwCAsA9EAyaeLEZJplBNJcZzDw
    RJoBbaP2HUpA6jplRGSg6ADwAmrW8AALAPRAMmnixGSaZQTSXGcw8ESaAG2j9h1KQOo6ZURkoOgA
    8AJqlvAYCwD0QDJp4rFkmmVPZQBrFxDghkXkAU4gdy9l+GcBQgsvJW/gwQHkMmkgwEHkMGkDSiLA
    QN0DEElnQMEA3QFL6mfi6wRgQJ3g8wVa4mExZKDoAPACalbwAAsA9EAyaeKO8PpkCNKaZUKcPGdl
    ZyD0CNKw8ECZA5wAbQsEIPQY00DqOmUw8ISZCJYg9BiTsPBMmef0HEwg9ATUC5SeZQXQOmVA6gTT
    IPQQ0giWsPBMmQyUnmUg9BTTQOo6ZQiWEPEMmaa3nmWktjhlgmdA6KNnCJZw8BiZIPQQlCD0FJWe
    ZeNnwmdA6DhlCJYG0vDwXJmeZSD0CJcg9ASW4PMIbQfTDQRA6jplCJZA9ByVCtKeZUclQp0AUgVh
    CWsg9ATTAWsDEABrIPQE00D0HJRsMCD0CNMB5C8QQJgAUiZhCpPw8FyZMPDEmQ0FIPQIl3Hl4PMI
    bXflZ/UUTiD0GNNA6jplIPQYk+CYDQRJ4wrSQPQYk0GYCgX54//iMPBEmWP3BUpA6jplCJaeZSD0
    CJMISAFLIPQI0yD0CJMg9ASUYuzLYGD0AJUlJQqQ8PBcmTDwxJkNB+DzCG0R5xflZ/UcTkDqOmVJ
    4AiWCtJQ8FyZYPQAlJ5lQOo6ZeJnMPBEmWD0AJYNBGP3BUoKBUDqOmUIlp5lCpANAjDwxJkR4vDw
    XJng8whtF+WH9QxOQOo6ZTDwZJlJ4ArSAfcRSyD0GNNA6ztlCJYw8KSZnmVcZxDwWJr8Z3Dw/J9K
    9NyaXGcQ8FiagJ+n9QxNavTgmrDwWJlA6jplCJYKlPDwQJmeZQlMQOo6ZQiWAmcg9BiTnmVwIgBq
    QNgKlrDwUJmHQMHYAUw6ZSD0GNMNBUDqAU4Q8FiZIPQYk2r0hJo7ZSwkwOsIljDwpJmeZXxncPB8
    m1xnEPBYmoCbfGcQ8HibavTkmtBnSvRcm3xnEPB4mwTSx/UYTWr0QJsF0g0CBtKw8FiZQOo6ZQiW
    nmV8ZxDweJtq9ESbANojEMDrCJaeZVxnfGcQ8FiaEPB4m7xncPC8nUr0/Jpq9ECbgJ0w8KSZBNIN
    AgXSsPBYmdBnJ/YUTUDqOmUIlhDwWJmeZWr0CNp8ZzDwJJkQ8Hibg/AdSWr0BNtA6TllgPB6ZKDo
    AGUAZQAAAACAhC5BAPACajX1FAsA9EAyaeL2ZAbSAPEUnWdFfktv4O3jmmWBU1xnAGs1YTDwpJow
    8GSaMPBEmgBuh/YQS6P3HUo6ZQTTh/YITUDq5mcBaiUQQKYA8ZSdAU5AxADxCJ0hRADxNN0OKAFy
    FGEBagDxSN0BakvqIPGM3SDxUMUA8TjdCBAg8ZClAUgA8Qjdjuog8VDFAUvi69xhAGp2ZKDoAPAC
    apX0GAsA9EAyaeKaZczw82Q8ZwbSsPBUmX0F4PMIbgD2ANdA6jplAVLg9QDSoPUEYTDwBJkB9xFI
    QOg4ZXDwXJkGlgD2AJOAmiD2AJKeZQUiMPDEmaf2BE4EEDDwxJmn9hhO4PUAlQF1BWEw8ESZR/cY
    SgQQMPBEmcf2DEoA9hiXBNIw8KSZsPBYmQXX4PUAlwD2ANMH9xhNQOo6ZeD1AJQGln0CieJ9AJ5l
    4PUc0uD1BNAA9gCTAPUEEOD1BJX8Z+D1BJYw8OSfoKUBTgH3EU/g9QDV4PUM1gD2ANNA7z9lBpYA
    9gCTMPCkmZ5lXGdw8FyagPDAm+D1AJeAmrDwWJlH9wBNQOo6ZQaWAPYAkyD2AJSeZYDwQJug8AIk
    APGQmwDxrJui7IDwG2CA8Bkq4PUAlQZ1uGfg9QjVgPAOLdxnMPDEngFMAPGQ2wH3EU4A9gDTQO4+
    ZQaWAPYAkzDwpJmeZfxncPD8n7DwWJkA8dCbgJ8A8eybR/ccTUDqOmUA9gCTBpYA8VCbAPGMm55l
    gupRYIdCQExGSog0SDKR40njAZxBmkPgXGcw8ESaAfcRSkDqOmUGlgD2AJMw8KSZnmX8Z3Dw/J8A
    8dCbsPBYmYCfZ/cYTfBnAU5A6jplAPYAkwaWAPYYlADxUJueZdBnRkpIMknjoZqw8FyZQOo6ZQaW
    AFLg9QyQnmUA9gCTQPQVYHDwRJlA6jploJow8ESZMPCEmWH2AUqn9wRMQOo6ZQaWnmU5EBDwWJng
    9QiUAPYA02r0gNow8ESZg/AdSkDqOmUGluD1DJCeZSYQAPFM2wEQJirg9QCVAXUg9AdhAWqA8EDb
    QMPg9QyWAWpL6oDwRMNBQMPqAPQZYLDwXJkA9hyU/04b5rBnAPYA00DqOmUGluD1BJCeZQD2AJMA
    9AYQAXIWYeD1AJf+MgIiWGf8E51nAmrg9aBEgKWA8EDb4PUAlYDwRKOBw67qgPBEw+4T3Wfg9eBG
    wKdR4+D1AJfAxIDwhKPu7IDwhMOBo6FEquoBSsDzGWFcZzDwRJoCTOD1ENQB9xFKAPYA00DqOmUG
    lgD2AJMw8KSZnmXcZ3Dw3J6w8FiZp/cUTYCegPDEo0DqOmUA9gCTBpaA8ESjnmUFImMTIG2iwgNK
    AhAAbB0ClePApTDwpJkBTNI3x/cITb3n4Kfgwg9v7O615uD1EJegpeLsocKiQuVhAGpAxVxnMPBE
    mgD2ANMB9xFKQOo6ZQaWMPCkmbDwWJmeZdxncPDcnsf3HE06ZYCeQOodBhDwWJkGlgD2AJOq8Via
    nmXg9QDS2xLg9QCXIPYAlZCHU4eu7ErswPIMYAdnGEgBIiBI3Gcw8MSeAPYA0wH3EU5A7j5lBpbg
    9QCSMPCkmZ5l/Gdw8Pyfw5qw8FiZgJ/n9wxNQOo6ZQBqBpYE0pDwXJmeZZBnCm4dBQkHQOo6ZQaW
    AmcA9gCTnmWA8hsqnGcw8IScAfcRTEDsPGUGluD1AJcw8KSZnmXcZ3Dw3J6w8FiZCPAETYCew59A
    6jpl4PUAlAaWAPYAk1OEnmUhKrxnMPCknQFqU8QB9xFNAPYA00DtPWUGluD1AJcw8KSZnmXcZ3Dw
    3J6w8FiZCPAcTYCew59A6jplBpYA9gCTnmVaEuD1AJJWmuD1FNLA8Rgih0N+TABuvWcA8QzbAPEQ
    2wDxCNsg8ADF4PUY1ADxlNsA8Zzb4PUI1gZnRhH8ZzDw5J8A9gDTAfcRT0DvP2UGluD1AJUA9gCT
    nmVcZ3DwXJqAmlSFBSIw8MSZx/YQTgQQMPDEmcf2GE4E0P1nIPBApzDwpJng9QSXBdKw8FiZKPAY
    TQD2ANNA6jplnWfg9aREQKUGlgD2AJMR6ohC2EwKXJ5lBmAEUARg4PUEktBKXRCIQqdMBlwGYAJQ
    BGDg9QSSqUpTEL9KBloGYAJQFGDg9QSSyUpKEOD1BJYgdgVh4PALIAFwE2FdEOD1BJdcdwNhwPAf
    IAsQ4PUEklhyAmB4cgVhwPAYIARwgPASYJxnMPCEnAD2ANMB9xFMQOw8ZQaWMPCEmVDwUJmeZdxn
    cPDcnmjwAEw6ZUDqoJ4w8ESZMPCkmeD1AJSI8ABKBNIw8ESZAG7mZ6P3HUqH9ghNQOo6ZQaWAPYA
    k55lrBEGWKDwBGAEDAQ1teSgjZHlgOwAZQ0AFwAlADEAOwGzAP1nIPBAxwFokhC9ZyDwgKWQNIni
    IPBAxeD1AJSjZwgGAW80EEwyCAZJ5oGaAFQeYDDwRJkw8KSZ4PUAlIjwGEoE0jDwRJkAbuZno/cd
    Sof2CE0A9gDTQOo6ZQaWAW/g9QjXnmUAaAD2AJNhEANtuuwBLeXo4poCT5/n4PUAlBLu2eO67wEt
    5eijZxLvMPBEmQD2ANPE8glKQOo6ZQaW4PUI0p5l3xcA8UibAlIfYQDxmJsg8dCj/0qgpAFvTu3O
    7SDxsMNAxDDwRJng9QCUMPHAQ8TyCUqjZwD2ANNA6jplBpYA9gCTnmUFKgcQAWrg9QjSAxABbOD1
    CNQA8aybAPFUm4FFR02oNbXjBFQA8YzbQd0DYQFt4PUI1SDxTNsAagDxSNsCZwMQA2gBEARo4PUU
    luD1FJfAhgFP4PUU1+D1BNYFJuD1CJK/9gsi9RDg9QiU4PARLAFwE2Ew8ESZ4PUAlKNnxPIJSggG
    APYA0wFvQOo6ZQaWAPYAk55lwPAcKgDxTJsA8ZSbp0I/Tag1teOhnYPtCWADUgdgoUJHSkgySeMA
    8azbgdrg9QCXIPHAm+D1GJVUhwD2GJS75gIiAPYclLDwXJng9RiVAPYA00DqOmUGlgBSAPYAk55l
    HWDg9QCUVIQFIjDwBJnn9gRIBBAw8ASZ5/YUSHDwRJkA9gDTQOo6ZaCaMPBEmZBnYfYBSkDqOmUA
    9gCTAGoBbQDxUNvg9QTVAxAAbuD1BNYg9gCXCycA8UybAVJg8QlhEPBYmQFsavSA2mMRMPCkmQf3
    EE0w8ESZ4PUAlABoo/cdSh0GOmUA9gDTBNBA6gkH4PUAlAaWAPYAk1KEnmUfIrxnMPCknQH3EU1A
    7T1lBpbg9QCXMPCkmZ5l3Gdw8NyesPBYmajwEE2AnsOfQOo6ZeD1AJIGlhPCAPYAk55l4PUAlFGE
    KSK8ZzDwpJ0BnAD2ANMB9xFNQO09ZQaW4PUAlzDwpJmeZdxncPDcnrDwWJnI8BBNgJ7Dn0DqOmUw
    8ESZ4PUAlIH3BUpA6jplBpYA9gCT4PUA0J5l4PUEkoDwFyrg9QCUgJzg9QDUEPBYmeD1AJVK8RBK
    S+Uf9RwqsPBcmeD1EJYA9hyUo2cA9gDTQOo6ZQaWAFICZ55lAPYAkxNgcPBEmUDqOmWgmjDwRJkw
    8ISZYfYBSujwDExA6jplBpYA9gCTnmXcZzDwxJ4A9gDTAfcRTkDuPmUGljDwpJkA9hySnmX8Z3Dw
    /J8I8QBNgJ8w8OSZBNIF0D4QsPBcmeD1EJYA9hyUo2cA9gDTQOo6ZQaWAFICZ55lAPYAkxNgcPBE
    mUDqOmWgmjDwRJkw8ISZYfYBSkjxAExA6jplBpYA9gCTnmWcZzDwhJwA9gDTAfcRTEDsPGUGljDw
    5JmeZbxncPC8nQD2HJaAnTDwpJkE1gXQSPEUTbDwWJng9RCWx/YMT0DqOmUGlgD2AJOeZQBqgPBA
    2+D1DJACEIDwQNvg9QyX4PUE1+D1BJLg9RyUg+r/8hVhgPBAm1Eqg+hPYLDwXJkf5AD2HJSwZ8dn
    4PUA10DqOmUGlgBSAmeeZRFgcPBEmUDqOmWgmjDwRJkw8ISZYfYBSojxFExA6jplBpaeZVxnMPBE
    mgH3EUpA6jplBpbg9QCXnmW8Z3DwvJ0Bd4CdBWEw8OSZR/cYTwQQMPDkmcf2DE8w8KSZAPYckrDw
    OJng9QCWBNIF0KjxAE1A6TllBRAw8KSZB/cETZwWwPBzZKDoAGUA8AJqFPEUCwD0QDJp4pplgPD5
    ZBxnMPAkmAbSAfcRSUDpOWUGljDwhJhQ8FCYnmVw8NyYyPEcTKCeIPQM1kDqOmUQ8HiYBpZw8EiY
    KvEUS55lg2cg9BDTQOo6ZRDwWJgQ8NiYEPC4mOrxDEog9ADSQZqdZwFrCNLK8UCecsx2zArSCvBA
    nXrMEPB4mAzSAGpTzFfMW8yq8VibmJpZmo3qDiIw8ESYIPQM1MH2CUpA6jplIPQMlE/kAVMFYAMQ
    AWtr6wEQAWsg9BDTQOk5ZQaWIPQQkzDwpJieZdxncPDcnrDwWJjo8RBNgJ46ZUDqw2cGlpDwTJie
    ZZxnEPCYnCrxFExA6jplIPQQkwaWkPBUmAgEnmUDbcNnQOo6ZSD0BNJA6TllBpYw8KSYnmVcZ3Dw
    XJog9ASWCPIMTYCasPBYmEDqOmUGlnDwSJieZZxnEPCYnCrxFExA6jplEPBYmAaWqvFcmp5lAVIt
    YHxnEPB4mzDwXJjq8QxLgZtA6jplBpaeZdxnEPDYngrwgJ4AVA1hMPBcmEDqOmUGlgFqS+qeZXxn
    EPB4mwrwQNucZ5DwDJgQ8JicKvEUTEDoOGWA8HlkIOgAajDwRJjB9glKQOo6ZQaWIPQI0p5lPhAg
    9BDTQOk5ZQaWMPCkmJ5lnGcQ8Jic3Gdw8NyeqvFYnCjyAE2AnsOasPBYmEDqOmUGljDwpJieZVxn
    EPBYmkjyBE2q8ZiaAGrCZ+JnBNIw8ESYo/cdSkDqOmUGljDwRJieZdxnEPDYnoH3BUqq8ZieQOo6
    ZQaWIPQQk55lnGcQ8JicqvFYnJiaWZqkZ03tCCVC6wZhbuq0KiD0CJaD7rBgIPQEkgFS//YMYX1n
    U4s6IkDpOWUGliD0AJJ9Z55l3Gdw8NyeMPCkmPOLgJ7BmrDwWJhI8gxNQOo6ZZ1ns4wGlgFqrOqe
    ZRQiXGcQ8FiaIPQAlhDw+JjK8aCaMPBEmIGe6vEUT2TzBUoBbkDqOmUKEDDwRJgw8ISYYfYBSgf0
    FExA6jplfWdXiz4iQOk5ZQaWfWcw8KSYnmXcZ1xncPDcnhDwWJr3i4CeyvHAmrDwWJho8ghNQOo6
    ZZ1nV6wGlgFrbOqeZRQiIPQAktxnEPDYnqGaMPBEmBDw+JjK8YCeZPMFSgBuKvMIT0DqOmUMEDDw
    RJgw8ISYfWezi2H2AUon9ABMQOo6ZZ1nW4x/9goiQOk5ZQaWfWcw8KSYnmXcZ1xncPDcnhDwWJr7
    i4CeCvDAmrDwWJiI8ghNQOo6ZZ1nW6wGlgFrbOqeZaDwACIAayD0ANMBa9xnEPDYnrDwVJgg9BDT
    CvCAng4F4PMHbkDqOmUGlgFSIPQQk55lJmEg9ACTCARN4yD0ANNN5ABsmMMg9AzSQOk5ZQaWIPQM
    kjDwpJieZdxncPDcniD0AJcOA4Cewmew8FiYBNOo8gRNQOo6ZQaWAGueZcYXJSokI0DpOWUGljDw
    hJhQ8FCYnmXcZ3Dw3J7o8gBMOmVA6qCeBpaeZVxnEPBYmgrwgJow8FyYQOo6ZQaWAWpL6p5lfGcQ
    8HibCvBA25xnEPCYnArwQJwAUilhQOk5ZQaWMPCkmJ5l3GdcZ3Dw3J4Q8Fia6PIQTYCeCvDAmrDw
    WJhA6jplBpYw8FyYnmV8ZxDweJsK8ICbQOo6ZQaWAWpL6p5lnGcQ8JicCvBA3BDwWJgAa0r0fNow
    8ESYg/AdSkDqOmWrFTDwRJgw8ISY3WezjmH2AUoI8wRMQOo6ZZ4VAPACavPzFAsA9EAyaeKaZfZk
    HGcE0jDwRJgkZwH3EUpA6jplcPBcmASWMPCEmKCaUPBQmJ5lCPMMTEDqOmUQ8HiYBJYq8VCbnmUr
    KnDwQJgQ8JiYBtMAbSrxFExA6jplBJYGk55lCSIw8ASYkWeiZ2LxDUhA6DhlOBABairxUNsQ8HiY
    Q2dK8RBKSvFQ2xDweJhB2qrxWNsw8GSYKPMES2PaUPBImDDwpJgQ8NiYOmUo8wxNyfcITkDqkWcE
    lvDwRJgNt55lC7Y6ZUDqkWcElgJtkWeeZTDwxJjQ8ByYq+0o8xROQOg4ZQFqdmSg6ABlpHA9Ctej
    8D8CABw8AJucJyHgmQPY/70nHACwrxiAkI8QALyvIACxryQAv6+0TxAmAwAAEP//ESQJ+CAD/P8Q
    JgAAGY78/zEXJAC/jyAAsY8cALCPCADgAygAvScAAAAAAAAAAAAAAAAQgJmPIXjgAwn4IANHABgk
    EICZjyF44AMJ+CADRgAYJBCAmY8heOADCfggA0UAGCQQgJmPIXjgAwn4IANEABgkEICZjyF44AMJ
    +CADQwAYJBCAmY8heOADCfggA0IAGCQQgJmPIXjgAwn4IANBABgkEICZjyF44AMJ+CADQAAYJBCA
    mY8heOADCfggAz8AGCQQgJmPIXjgAwn4IAM+ABgkEICZjyF44AMJ+CADPQAYJBCAmY8heOADCfgg
    AzsAGCQQgJmPIXjgAwn4IAM6ABgkEICZjyF44AMJ+CADOQAYJBCAmY8heOADCfggAzgAGCQQgJmP
    IXjgAwn4IAM3ABgkEICZjyF44AMJ+CADNgAYJBCAmY8heOADCfggAzUAGCQQgJmPIXjgAwn4IAM0
    ABgkEICZjyF44AMJ+CADMwAYJBCAmY8heOADCfggAzIAGCQQgJmPIXjgAwn4IAMxABgkEICZjyF4
    4AMJ+CADMAAYJBCAmY8heOADCfggAy8AGCQQgJmPIXjgAwn4IAMuABgkEICZjyF44AMJ+CADLQAY
    JBCAmY8heOADCfggAywAGCQQgJmPIXjgAwn4IAMrABgkEICZjyF44AMJ+CADKgAYJBCAmY8heOAD
    CfggAykAGCQQgJmPIXjgAwn4IAMoABgkEICZjyF44AMJ+CADJwAYJBCAmY8heOADCfggAyYAGCQQ
    gJmPIXjgAwn4IAMlABgkEICZjyF44AMJ+CADJAAYJBCAmY8heOADCfggAyMAGCQQgJmPIXjgAwn4
    IAMiABgkEICZjyF44AMJ+CADIQAYJBCAmY8heOADCfggAx8AGCQQgJmPIXjgAwn4IAMeABgkEICZ
    jyF44AMJ+CADHQAYJBCAmY8heOADCfggAxwAGCQQgJmPIXjgAwn4IAMbABgkEICZjyF44AMJ+CAD
    GgAYJBCAmY8heOADCfggAxkAGCQQgJmPIXjgAwn4IAMYABgkEICZjyF44AMJ+CADFwAYJBCAmY8h
    eOADCfggAxYAGCQQgJmPIXjgAwn4IAMVABgkEICZjyF44AMJ+CADFAAYJBCAmY8heOADCfggAxMA
    GCQQgJmPIXjgAwn4IAMSABgkEICZjyF44AMJ+CADEAAYJBCAmY8heOADCfggAw8AGCQQgJmPIXjg
    Awn4IAMOABgkAAAAAAAAAAAAAAAAAAAAAAIAHDwgl5wnIeCZA+D/vScQALyvHAC/rxgAvK8BABEE
    AAAAAAIAHDz8lpwnIeCfAySAmY9gDTknEfURBAAAAAAQALyPHAC/jwgA4AMgAL0nendpbnQgdGhy
    ZWFkIGVycm9yOiAlcyAlZAoAADc3ICAgICAgJTAyZC8lMDJkLyUwMmQgJWQ6JTAyZDolMDJkLiUw
    M2QgICAgAAAAAGRlbGV0ZSAlcyAtPiAlcyAtPiAlcyAtPiAlcwoAAAAAcmVwb3Blbl9odHRwX2Zk
    KCkKAAByZXBvcGVuX2h0dHBfZmQAQ2Fubm90IGNvbm5lY3QgdG8gc2VydmVyAAAAACAgaHR0cF9m
    ZCgpPSVkCgBEZXZpY2UgbnVtYmVyIG5vdCBhbiBpbnRlZ2VyAAAAAE5vdCByZWdpc3RlcmVkAABC
    YWQgZGV2aWNlX3BhdGgARGV2aWNlX3BhdGggZG9lcyBub3QgbWF0Y2ggYWxyZWFkeSByZWdpc3Rl
    cmVkIG5hbWUAAC9wcm9jL3NlbGYvZmQvAAAlcyVzAAAAAG9yaWdpbmFsX2NvbW1wb3J0X2ZkPSVk
    CgAAAABEZXZpY2VfcGF0aCBub3QgZm91bmQgaW4gb3BlbiBmaWxlIGxpc3QAQ3JlYXRlZCBzb2Nr
    ZXQgcGFpci4gZmRzICVkIGFuZCAlZAoARHVwMi4gb2xkX2ZkPSVkLCBuZXdfZmQ9JWQsIHJlc3Vs
    dD0lZAoAAENsb3NpbmcgZmQgJWQgYWZ0ZXIgZHVwMgoAAABOZXcgY29tbXBvcnQgZmQ9JWQKAERl
    dmljZV9udW0gbm90IGEgbnVtYmVyAEtleSBub3QgYSBzdHJpbmcAAAAARGVxdWV1ZUhUVFBEYXRh
    OiBuZXh0UmVxdWVzdEAlcCBodHRwX2FjdGl2ZT0lZCBodHRwX2hvbGRvZmY9JWQKACAgIFNlbmRp
    bmcgaHR0cDogKCVkIGJ5dGVzKSAlcwoAICAgV3JvdGUgJWQgYnl0ZXMgdG8gSFRUUCBzZXJ2ZXIK
    AAAAICAgcmV0cnk6IFdyb3RlICVkIGJ5dGVzIHRvIEhUVFAgc2VydmVyCgAAAABpbnRlcmNlcHQA
    AABtb25pdG9yAFBhdHRlcm4gbm90IGEgc3RyaW5nAAAAAHRpbWVvdXQgbm90IGEgbnVtYmVyAAAA
    AFJlc3BvbnNlIG5vdCBhIHN0cmluZwAAAEZvcndhcmQgbm90IGJvb2xlYW4ATHVhICVzOiBrZXk9
    JXMgYXJtX3BhdHRlcm49JXMgcGF0dGVybj0lcyByZXNwb25zZT0lcyBvbmVzaG90PSVkIHRpbWVv
    dXQ9JWQgZm9yd2FyZD0lZAoAAGluc2VydCAlcyAtPiAlcyAtPiAlcyAtPiAlcwoAAAAAR0VUIC9k
    YXRhX3JlcXVlc3Q/aWQ9YWN0aW9uJkRldmljZU51bT0lZCZzZXJ2aWNlSWQ9dXJuOmdlbmdlbl9t
    Y3Ytb3JnOnNlcnZpY2VJZDpaV2F2ZU1vbml0b3IxJmFjdGlvbj0lcyZrZXk9JXMmdGltZT0lZgAA
    JkMlZD0AAAAmRXJyb3JNZXNzYWdlPQAAIEhUVFAvMS4xDQpIb3N0OiAxMjcuMC4wLjENCg0KAABz
    ZW5kX2h0dHA6IGh0dHBfYWN0aXZlPSVkIGh0dHBfaG9sZG9mZj0lZAoAAFF1ZXVlaW5nIG5leHQg
    aHR0cCByZXF1ZXN0QCVwLiBsYXN0UmVxdWVzdEAlcCBodHRwX2FjdGl2ZT0lZCBodHRwX2hvbGRv
    ZmY9JWQgcmVxdWVzdD0lcwoAAAAAUXVldWVpbmcgZmlyc3QgYW5kIGxhc3QgaHR0cCByZXF1ZXN0
    QCVwLiBodHRwX2FjdGl2ZT0lZCBodHRwX2hvbGRvZmY9JWQgcmVxdWVzdD0lcwoARXJyb3IAAABS
    ZXNwb25zZSB0b28gbG9uZwAAAGhvc3QtPmNvbnRyb2xsZXIAAAAAY29udHJvbGxlci0+aG9zdAAA
    AABzAAAAZm9yd2FyZAByZXNwb25zZQAAAABGb3J3YXJkIHdyaXRlAAAAUmVzcG9uc2Ugd3JpdGUA
    AEludGVyY2VwdAAAAE1vbml0b3IAJXMgR290ICVkIGJ5dGUlcyBvZiBkYXRhIGZyb20gZmQgJWQK
    AAAAACAgIHMtPnN0YXRlPSVkIGM9MHglMDJYCgAAAAAgICBTd2FsbG93aW5nIGFjayAlZCBvZiAl
    ZAoAICAgV3JpdGluZyBwYXJ0ICVkIG9mIHJlc3BvbnNlOiAlZCBieXRlcwoAAABJbnRlcmNlcHQg
    d3JpdGUAICAgY2hlY2tzdW09MHglMDJYCgAwMTIzNDU2Nzg5QUJDREVGAAAAACAgIGhleGJ1ZmY9
    JXMKAAAgICBUcnlpbmcgbW9uaXRvcjogJXMKAAAgICBNb25pdG9yOiAlcyBwYXNzZWQKAAAgICBN
    b25pdG9yICVzIGlzIG5vdyBhcm1lZAoAICAgICAgJXMgYz0lYyByc3RhdGU9JWQgYnl0ZT0weCUw
    MlgKAAAAACAgICAgIFJlc3BvbnNlIHN5bnRheCBlcnJvcgoAAAAAUmVzcG9uc2Ugc3ludGF4IGVy
    cm9yAAAAVW5tYXRjaGVkIHJlcGxhY2VtZW50AAAAICAgTW9uaXRvciAlcyBpcyBub3cgdW5hcm1l
    ZAoAAAAgICBEZWxldGluZyBvbmVzaG90OiAlcwoAAAAAUGFzc3Rocm91Z2ggd3JpdGUAAAAgICBO
    b3QgaW50ZXJjZXB0ZWQuIFBhc3MgdGhyb3VnaCAlZCBieXRlJXMgdG8gZmQgJWQuIHJlc3VsdD0l
    ZAoAQmFkIGNoZWNrdW0gd3JpdGUAAAAgICBCYWQgY2hlY2tzdW0uIFBhc3MgdGhyb3VnaCAlZCBi
    eXRlJXMgdG8gZmQgJWQuIHJlc3VsdD0lZAoAAAAAVGFpbCB3cml0ZQAAICAgV3JpdGluZyAlZCB0
    cmFpbGluZyBvdXRwdXQgYnl0ZSVzIHRvIGZkICVkLiBSZXN1bHQ9JWQKAAAAU3RhcnQgendpbnQg
    dGhyZWFkCgBDYWxsaW5nIHBvbGwuIHRpbWVvdXQ9JWQKAAAAUG9sbCByZXR1cm5lZCAlZAoAAABU
    aW1pbmcgb3V0IG1vbml0b3Igd2l0aCBrZXk6ICVzCgAAAABUaW1lb3V0AGhvc3RfZmQgJWQgcmV2
    ZW50cyA9ICVkCgAAAABjb250cm9sbGVyX2ZkICVkIHJldmVudHMgPSAlZAoAAGh0dHBfZmQgJWQg
    cmV2ZW50cyA9ICVkCgAAAABSZWNlaXZlZCAlZCBieXRlcyAodG90YWwgJWQgYnl0ZXMpIGZyb20g
    aHR0cCBzZXJ2ZXI6ICVzCgAAAABodHRwX2ZkIGNsb3NlZAoAQ2xvc2luZyBodHRwX2ZkICVkCgBv
    dXRwdXQAAFN0YXJ0IGx1YW9wZW5fendpbnQKAAAAACpEdW1teSoAendpbnQAAAB2ZXJzaW9uAGlu
    c3RhbmNlAAAAAHJlZ2lzdGVyAAAAAHVucmVnaXN0ZXIAAGNhbmNlbAAAAAAAAAAAAAAAAAAAAAAA
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
    //8AAAAA/////wAAAAAAAAAAPEMAAJUOAABIQwAAdRMAAFRDAADFEQAAIDwAAD0fAAAUPAAAFR8A
    AGBDAACdFwAAAAAAAAAAAAD/////AAAAAAAAAAAAAAAAAAAAAAAAAIAAAAEAHFEBAMBPAQAAAAAA
    AAAAAAAAAAAAAAAAwDgAALA4AACgOAAAAAAAAJA4AACAOAAAcDgAAGA4AABQOAAAQDgAADA4AAAg
    OAAAEDgAAAA4AADwNwAA4DcAANA3AADANwAAAAAAALA3AACgNwAAkDcAAIA3AABwNwAAYDcAAFA3
    AABANwAAMDcAACA3AAAQNwAAADcAAPA2AADgNgAA0DYAAMA2AACwNgAAoDYAAJA2AACANgAAcDYA
    AGA2AABQNgAAQDYAADA2AAAgNgAAEDYAAAAAAAAANgAA8DUAAOA1AADQNQAAwDUAALA1AACgNQAA
    kDUAAIA1AABwNQAAYDUAABxRAQBHQ0M6IChHTlUpIDMuMy4yAEdDQzogKExpbmFybyBHQ0MgNC42
    LTIwMTIuMDIpIDQuNi4zIDIwMTIwMjAxIChwcmVyZWxlYXNlKQAA6AwAAAAAAJD8////AAAAAAAA
    AAAgAAAAHQAAAB8AAADgOAAAAAAAkPz///8AAAAAAAAAACAAAAAdAAAAHwAAAGEOAAAAAACA/P//
    /wAAAAAAAAAAIAAAAB0AAAAfAAAAlQ4AAAAAAID8////AAAAAAAAAAAgAAAAHQAAAB8AAADJDgAA
    AAAAgPz///8AAAAAAAAAACgAAAAdAAAAHwAAABEPAAAAAAGA/P///wAAAAAAAAAAcAAAAB0AAAAf
    AAAAhQ8AAAAAA4D8////AAAAAAAAAAA4AAAAHQAAAB8AAAAxEAAAAAADgPz///8AAAAAAAAAAEAA
    AAAdAAAAHwAAAG0RAAAAAAOA/P///wAAAAAAAAAAKAAAAB0AAAAfAAAAxREAAAAAA4D8////AAAA
    AAAAAAAwAAAAHQAAAB8AAAB1EwAAAAADgPz///8AAAAAAAAAAEgCAAAdAAAAHwAAAJ0XAAAAAAOA
    /P///wAAAAAAAAAAQAAAAB0AAAAfAAAAnRgAAAAAA4D8////AAAAAAAAAABIAAAAHQAAAB8AAAAh
    GgAAAAADgPz///8AAAAAAAAAALABAAAdAAAAHwAAAL0eAAAAAAOA/P///wAAAAAAAAAAMAAAAB0A
    AAAfAAAAFR8AAAAAAID8////AAAAAAAAAAAgAAAAHQAAAB8AAAA9HwAAAAAAgPz///8AAAAAAAAA
    ACAAAAAdAAAAHwAAAGUfAAAAAAMA/P///wAAAAAAAAAACAAAAB0AAAAfAAAAvR8AAAAAA4D8////
    AAAAAAAAAABQBAAAHQAAAB8AAADJIgAAAAADgPz///8AAAAAAAAAADAAAAAdAAAAHwAAAGUjAAAA
    AAOA/P///wAAAAAAAAAAGAYAAB0AAAAfAAAA6S4AAAAAA4D8////AAAAAAAAAABIBAAAHQAAAB8A
    AAAJNAAAAAADgPz///8AAAAAAAAAADAAAAAdAAAAHwAAAEEPAAAAZ251AAEHAAAABAMALnNoc3Ry
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
    AABeAAAAAQAAAAYAAABgDQAAYA0AAAAoAAAAAAAAAAAAABAAAAAAAAAAZAAAAAEAAAAGAAAAYDUA
    AGA1AACAAwAAAAAAAAAAAAAEAAAAAAAAAHAAAAABAAAABgAAAOA4AADgOAAAUAAAAAAAAAAAAAAA
    BAAAAAAAAAB2AAAAAQAAADIAAAAwOQAAMDkAADgKAAAAAAAAAAAAAAQAAAABAAAAfgAAAAEAAAAC
    AAAAaEMAAGhDAAAEAAAAAAAAAAAAAAAEAAAAAAAAAIgAAAABAAAAAwAAALRPAQC0TwAACAAAAAAA
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
    AQAAFAEAABQBAAAYAAAAGAAAAAQAAAAEAAAAAQAAAAAAAAAAAAAAAAAAAIwwAACMMAAABQAAAAAA
    AQABAAAAvD8AALw/AQC8PwEAWAEAALQEAAAGAAAAAAABAAIAAAAsAQAALAEAACwBAADwAAAA8AAA
    AAcAAAAEAAAAUeV0ZAAAAAAAAAAAAAAAAAAAAAAAAAAABwAAAAQAAABS5XRkvD8AALw/AQC8PwEA
    RAAAAEQAAAAEAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAsgAAAAAA
    AAAAAAAAAAAAAAAAwAEAAQAAAIACAAABAAAAjgIAAAEAAACeAgAADAAAAIAMAAANAAAA0CwAAAQA
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
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACADAAAAAAAAAMACQA1AgAAVSgAAMwAAAASAAoA
    rwIAAABAAQAAAAAAEAATABcAAAAAwAEAAAAAABMA8f+2AgAAAMABAAAAAAAQAPH/UAIAAIAMAAAc
    AAAAEgAJAKgCAAAADQAAAAAAABAACgDBAgAAFEEBAAAAAAAQAPH/IAAAANAsAAAcAAAAEgAMALoC
    AAAUQQEAAAAAABAA8f8BAAAAEEABAAAAAAARAPH/0wIAAHBEAQAAAAAAEADx/80CAAAUQQEAAAAA
    ABAA8f+gAAAAsCwAAAAAAAASAAAATAAAAKAsAAAAAAAAEgAAAI4AAACQLAAAAAAAABIAAAA1AAAA
    AAAAAAAAAAAgAAAAwwEAAIAsAAAAAAAAEgAAAFYCAABwLAAAAAAAABIAAACBAQAAYCwAAAAAAAAS
    AAAASQAAAFAsAAAAAAAAEgAAAKsBAABALAAAAAAAABIAAADRAQAAMCwAAAAAAAASAAAAQwIAACAs
    AAAAAAAAEgAAAHUAAAAQLAAAAAAAABIAAAAGAQAAACwAAAAAAAASAAAAoAEAAPArAAAAAAAAEgAA
    AAUCAADgKwAAAAAAABIAAABfAAAAAAAAAAAAAAARAAAA5wEAANArAAAAAAAAEgAAAOoAAADAKwAA
    AAAAABIAAAC5AAAAsCsAAAAAAAASAAAAGQEAAKArAAAAAAAAEgAAAFEBAACQKwAAAAAAABIAAAAw
    AgAAgCsAAAAAAAASAAAAWAEAAHArAAAAAAAAEgAAACgCAABgKwAAAAAAABIAAAAOAgAAUCsAAAAA
    AAASAAAA3wEAAEArAAAAAAAAEgAAANwAAAAwKwAAAAAAABIAAADwAQAAICsAAAAAAAASAAAAGwIA
    ABArAAAAAAAAEgAAACMCAAAAKwAAAAAAABIAAABmAAAA8CoAAAAAAAASAAAAvQEAAOAqAAAAAAAA
    EgAAADMBAADQKgAAAAAAABIAAADTAAAAwCoAAAAAAAASAAAAQwEAALAqAAAAAAAAEgAAAHIBAACg
    KgAAAAAAABIAAACUAAAAkCoAAAAAAAASAAAAeQEAAIAqAAAAAAAAEgAAAG4AAABwKgAAAAAAABIA
    AABzAgAAYCoAAAAAAAASAAAA2AEAAFAqAAAAAAAAEgAAAGQCAABAKgAAAAAAABIAAAAuAQAAMCoA
    AAAAAAASAAAAJgAAAAAAAAAAAAAAIgAAAGkBAAAgKgAAAAAAABIAAAD4AAAAECoAAAAAAAASAAAA
    yAAAAAAqAAAAAAAAEgAAAGABAADwKQAAAAAAABIAAACwAAAA4CkAAAAAAAASAAAAkQEAANApAAAA
    AAAAEgAAAIYAAADAKQAAAAAAABIAAAD8AQAAsCkAAAAAAAASAAAAsAEAAKApAAAAAAAAEgAAAIoB
    AACQKQAAAAAAABIAAABRAAAAgCkAAAAAAAASAAAAAF9HTE9CQUxfT0ZGU0VUX1RBQkxFXwBfZ3Bf
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
    gJmPvA05J0AAEQQAAAAAEAC8jwEAEQQAAAAAAgAcPDSznCch4J8DJICZjyApOScPBxEEAAAAABAA
    vI8cAL+PCADgAyAAvScAAAAAAAAAAAIAHDwAs5wnIeCZA9D/vScoALOvGICTjxAAvK8sAL+vIEFi
    kiQAsq8gALGvHACwrxsAQBTggIKPBQBAEByAgo/ggJmPCfggAwAARIwQALyPGICSjyCAkY8YgJCP
    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
    eJsI8EDbEPBYmQBrSPR82jDwRJkC9hlKQOo6ZQaWnmWWFjDwRJndZzDwhJmzjqH2EUpG8AhMQOo6
    ZQaWnmWHFgDwAmqy9wgLAPRAMmnimmX2ZBxnEPB4mATSJGco8VCbKypQ8FyYEPCYmAbTAG0o8RRM
    QOo6ZQSWBpOeZQkiMPAEmJFnomfB9wlIQOg4ZTgQAWoo8VDbEPB4mENnSPEQSkjxUNsQ8HiYQdqo
    8VjbMPBkmEbwEEtj2lDwSJgw8KSYEPDYmDplRvAYTcf3EE5A6pFnBJbQ8FiYDLeeZQq2OmVA6pFn
    BJYCbZFnnmUw8MSY0PAQmKvtZvAATkDoOGUBanZkoOikcD0K16PwPwIAHDzglpwnIeCZA9j/vScc
    ALCvGICQjxAAvK8gALGvJAC/r7w/ECYDAAAQ//8RJAn4IAP8/xAmAAAZjvz/MRckAL+PIACxjxwA
    sI8IAOADKAC9JwAAAAAAAAAAAAAAABCAmY8heOADCfggA0QAGCQQgJmPIXjgAwn4IANDABgkEICZ
    jyF44AMJ+CADQgAYJBCAmY8heOADCfggA0EAGCQQgJmPIXjgAwn4IANAABgkEICZjyF44AMJ+CAD
    PwAYJBCAmY8heOADCfggAz4AGCQQgJmPIXjgAwn4IAM9ABgkEICZjyF44AMJ+CADPAAYJBCAmY8h
    eOADCfggAzsAGCQQgJmPIXjgAwn4IAM6ABgkEICZjyF44AMJ+CADOAAYJBCAmY8heOADCfggAzcA
    GCQQgJmPIXjgAwn4IAM2ABgkEICZjyF44AMJ+CADNQAYJBCAmY8heOADCfggAzQAGCQQgJmPIXjg
    Awn4IAMzABgkEICZjyF44AMJ+CADMgAYJBCAmY8heOADCfggAzEAGCQQgJmPIXjgAwn4IAMwABgk
    EICZjyF44AMJ+CADLwAYJBCAmY8heOADCfggAy4AGCQQgJmPIXjgAwn4IAMtABgkEICZjyF44AMJ
    +CADLAAYJBCAmY8heOADCfggAysAGCQQgJmPIXjgAwn4IAMqABgkEICZjyF44AMJ+CADKQAYJBCA
    mY8heOADCfggAygAGCQQgJmPIXjgAwn4IAMnABgkEICZjyF44AMJ+CADJgAYJBCAmY8heOADCfgg
    AyUAGCQQgJmPIXjgAwn4IAMkABgkEICZjyF44AMJ+CADIwAYJBCAmY8heOADCfggAyIAGCQQgJmP
    IXjgAwn4IAMhABgkEICZjyF44AMJ+CADIAAYJBCAmY8heOADCfggAx8AGCQQgJmPIXjgAwn4IAMe
    ABgkEICZjyF44AMJ+CADHAAYJBCAmY8heOADCfggAxsAGCQQgJmPIXjgAwn4IAMaABgkEICZjyF4
    4AMJ+CADGQAYJBCAmY8heOADCfggAxgAGCQQgJmPIXjgAwn4IAMXABgkEICZjyF44AMJ+CADFgAY
    JBCAmY8heOADCfggAxUAGCQQgJmPIXjgAwn4IAMUABgkEICZjyF44AMJ+CADEwAYJBCAmY8heOAD
    CfggAxIAGCQQgJmPIXjgAwn4IAMQABgkEICZjyF44AMJ+CADDwAYJBCAmY8heOADCfggAw4AGCQA
    AAAAAAAAAAAAAAAAAAAAAgAcPDCTnCch4JkD4P+9JxAAvK8cAL+vGAC8rwEAEQQAAAAAAgAcPAyT
    nCch4J8DJICZjwANOSf99xEEAAAAABAAvI8cAL+PCADgAyAAvSd6d2ludCB0aHJlYWQgZXJyb3I6
    ICVzICVkCgAAcmVwb3Blbl9odHRwX2ZkAENhbm5vdCBjb25uZWN0IHRvIHNlcnZlcgAAAABEZXZp
    Y2UgbnVtYmVyIG5vdCBhbiBpbnRlZ2VyAAAAAE5vdCByZWdpc3RlcmVkAABCYWQgZGV2aWNlX3Bh
    dGgARGV2aWNlX3BhdGggZG9lcyBub3QgbWF0Y2ggYWxyZWFkeSByZWdpc3RlcmVkIG5hbWUAAC9w
    cm9jL3NlbGYvZmQvAAAlcyVzAAAAAERldmljZV9wYXRoIG5vdCBmb3VuZCBpbiBvcGVuIGZpbGUg
    bGlzdABEZXZpY2VfbnVtIG5vdCBhIG51bWJlcgBLZXkgbm90IGEgc3RyaW5nAAAAAFBhdHRlcm4g
    bm90IGEgc3RyaW5nAAAAAHRpbWVvdXQgbm90IGEgbnVtYmVyAAAAAFJlc3BvbnNlIG5vdCBhIHN0
    cmluZwAAAEZvcndhcmQgbm90IGJvb2xlYW4AR0VUIC9kYXRhX3JlcXVlc3Q/aWQ9YWN0aW9uJkRl
    dmljZU51bT0lZCZzZXJ2aWNlSWQ9dXJuOmdlbmdlbl9tY3Ytb3JnOnNlcnZpY2VJZDpaV2F2ZU1v
    bml0b3IxJmFjdGlvbj0lcyZrZXk9JXMmdGltZT0lZgAAJkMlZD0AAAAmRXJyb3JNZXNzYWdlPQAA
    IEhUVFAvMS4xDQpIb3N0OiAxMjcuMC4wLjENCg0KAABFcnJvcgAAAFJlc3BvbnNlIHRvbyBsb25n
    AAAARm9yd2FyZCB3cml0ZQAAAFJlc3BvbnNlIHdyaXRlAABJbnRlcmNlcHQAAABNb25pdG9yAElu
    dGVyY2VwdCB3cml0ZQAwMTIzNDU2Nzg5QUJDREVGAAAAAFJlc3BvbnNlIHN5bnRheCBlcnJvcgAA
    AFVubWF0Y2hlZCByZXBsYWNlbWVudAAAAFBhc3N0aHJvdWdoIHdyaXRlAAAAQmFkIGNoZWNrdW0g
    d3JpdGUAAABUYWlsIHdyaXRlAABUaW1lb3V0AGludGVyY2VwdAAAAG1vbml0b3IAb3V0cHV0AAAq
    RHVtbXkqAHp3aW50AAAAdmVyc2lvbgByZWdpc3RlcgAAAAB1bnJlZ2lzdGVyAABjYW5jZWwAAAAA
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
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAD/////AAAAAP////8AAAAAAAAAAGgwAADREQAAdDAAACEQAABAMAAAcRsA
    ADQwAABJGwAAgDAAABkVAAAAAAAAAAAAAP////8AAAAAAAAAAAAAAAAAAAAAAAAAgAAAAQAQQQEA
    yD8BAAAAAAAAAAAAAAAAAAAAAACwLAAAoCwAAJAsAAAAAAAAgCwAAHAsAABgLAAAUCwAAEAsAAAw
    LAAAICwAABAsAAAALAAA8CsAAOArAAAAAAAA0CsAAMArAACwKwAAoCsAAJArAACAKwAAcCsAAGAr
    AABQKwAAQCsAADArAAAgKwAAECsAAAArAADwKgAA4CoAANAqAADAKgAAsCoAAKAqAACQKgAAgCoA
    AHAqAABgKgAAUCoAAEAqAAAwKgAAAAAAACAqAAAQKgAAACoAAPApAADgKQAA0CkAAMApAACwKQAA
    oCkAAJApAACAKQAAEEEBAEdDQzogKEdOVSkgMy4zLjIAR0NDOiAoTGluYXJvIEdDQyA0LjYtMjAx
    Mi4wMikgNC42LjMgMjAxMjAyMDEgKHByZXJlbGVhc2UpAACADAAAAAAAkPz///8AAAAAAAAAACAA
    AAAdAAAAHwAAANAsAAAAAACQ/P///wAAAAAAAAAAIAAAAB0AAAAfAAAAAQ4AAAAAA4D8////AAAA
    AAAAAAAoAAAAHQAAAB8AAABpDgAAAAAAgPz///8AAAAAAAAAACgAAAAdAAAAHwAAALEOAAAAAACA
    /P///wAAAAAAAAAAIAAAAB0AAAAfAAAA5Q4AAAAAA4D8////AAAAAAAAAAA4AAAAHQAAAB8AAADJ
    DwAAAAADgPz///8AAAAAAAAAACgAAAAdAAAAHwAAACEQAAAAAAOA/P///wAAAAAAAAAAMAAAAB0A
    AAAfAAAA0REAAAAAA4D8////AAAAAAAAAABQAgAAHQAAAB8AAAAZFQAAAAADgPz///8AAAAAAAAA
    AEAAAAAdAAAAHwAAABkWAAAAAAOA/P///wAAAAAAAAAAOAAAAB0AAAAfAAAA6RYAAAAAA4D8////
    AAAAAAAAAACYAQAAHQAAAB8AAADxGgAAAAADgPz///8AAAAAAAAAADAAAAAdAAAAHwAAAEkbAAAA
    AACA/P///wAAAAAAAAAAIAAAAB0AAAAfAAAAcRsAAAAAAID8////AAAAAAAAAAAgAAAAHQAAAB8A
    AACZGwAAAAADAPz///8AAAAAAAAAAAgAAAAdAAAAHwAAAPEbAAAAAAOA/P///wAAAAAAAAAAUAQA
    AB0AAAAfAAAAGR4AAAAAA4D8////AAAAAAAAAAAwAAAAHQAAAB8AAAC1HgAAAAADgPz///8AAAAA
    AAAAABAGAAAdAAAAHwAAADUlAAAAAAOA/P///wAAAAAAAAAAQAQAAB0AAAAfAAAAVSgAAAAAA4D8
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
    AAAAAA0AAAANAACAHAAAAAAAAAAAAAAQAAAAAAAAAGQAAAABAAAABgAAAIApAACAKQAAUAMAAAAA
    AAAAAAAABAAAAAAAAABwAAAAAQAAAAYAAADQLAAA0CwAAFAAAAAAAAAAAAAAAAQAAAAAAAAAdgAA
    AAEAAAAyAAAAIC0AACAtAABoAwAAAAAAAAAAAAAEAAAAAQAAAH4AAAABAAAAAgAAAIgwAACIMAAA
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

  if luup.version_major >= 7 then
  	json = require ("dkjson")

	UpdateFileWithContent("/www/cmh/skins/default/img/devices/device_states/EvolveLCD1_50x50.png", EvolveLCD1Icon, 644, nil)
	UpdateFileWithContent("/www/cmh/skins/default/img/devices/device_states/CooperRFWC5_50x50.png", CooperRFWC5Icon, 644, nil)
	UpdateFileWithContent("/www/cmh/skins/default/img/devices/device_states/NexiaOneTouch_50x50.png", NexiaOneTouchIcon, 644, nil)
  	UpdateFileWithContent("/usr/lib/lua/zwint.so", zwint_so, 755, zwint_so_version)

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
		        text = "Evolve LCD1 5 button controller"
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
		        text = "Cooper RFWC5 5 button controller"
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
		        text = "Nexia One Touch 5 button controller"
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
		end )

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
		    } }
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
		end )

  else -- UI5
    UpdateFileWithContent("/www/cmh/skins/default/icons/EvolveLCD1_50x50.png", EvolveLCD1Icon, 644, nil)
    UpdateFileWithContent("/www/cmh/skins/default/icons/CooperRFWC5_50x50.png", CooperRFWC5Icon, 644, nil)
	UpdateFileWithContent("/www/cmh/skins/default/icons/NexiaOneTouch_50x50.png", NexiaOneTouchIcon, 644, nil)
  	UpdateFileWithContent("/usr/lib/lua/zwint.so", zwint_so, 755, zwint_so_version)
	UpdateFileWithContent("/etc/cmh/zwave_products_user.xml", [[
<root>
	<deviceList>
		<device id="2501" manufacturer_id="0113" basic="" generic="" specific="" child="" prodid="4C32" prodtype="4556" device_file="D_EvolveLCD1.xml" zwave_class="" default_name="Evolve LCD1 Controller Z-Wave" manufacturer_name="Evolve Guest Controls" model="EVLCD1" invisible="1">
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
		<device id="2503" manufacturer_id="001A" basic="" generic="" specific="" child="" prodid="0000" prodtype="574D" device_file="D_CooperRFWC5.xml" zwave_class="" default_name="Cooper RF2C5 Scene Controller Z-Wave" manufacturer_name="Cooper Industries" model="RFWC5" invisible="1">
			<variable service="urn:micasaverde-com:serviceId:SceneController1" variable="NumButtons" value="5" />
			<variable service="urn:micasaverde-com:serviceId:SceneController1" variable="FiresOffEvents" value="1" />
			<variable service="urn:micasaverde-com:serviceId:SceneController1" variable="ActivationMethod" value="0" />
		</device>
		<device id="2504" manufacturer_id="0178" basic="" generic="" specific="" child="" prodid="4735" prodtype="5343" device_file="D_NexiaOneTouch.xml" zwave_class="" default_name="Nexia One Touch Controller Z-Wave" manufacturer_name="Ingersoll Rand" model="NX1000" invisible="1">
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
]], 644, nil)
	end	-- UI5

	-- Update scene controller devices which may have been included into the Z-Wave network before the installer ran.
	ScanForNewDevices()

	if reload_needed then
		log("Files updated. Reloading LuaUPnP.")
		luup.call_action(HAG_SID, "Reload", {}, 0)
	else
		VLog("Nothing updated. No need to reload.")
	end
end	-- function SceneControllerInstaller_Init

