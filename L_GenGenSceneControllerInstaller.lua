-- Installer for GenGeneric Scene Controller Version 1.08
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

-- Set UseDebugZWaveInterceptor to true to enable zwint log messages to log.init-LuaUPnP (Do not confuse with LuaUPnP.log)
local UseDebugZWaveInterceptor = false

local bit = require 'bit'
local nixio = require "nixio"
local socket = require "socket"
require "L_GenGenSceneControllerShared"

local UseDebugZWaveInterceptor = false
local GenGenInstaller_Version = 20 -- Update this each time we update the installer.

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
	                 "06", -- ACK response,
	                 NexiaManufacturerCallback,
	                 false, -- Not OneShot
	                 0, -- no timeout
					 "NexiaManufacturer")

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

  -- First, make sure that we are the latest version of this installer
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
  local zwint_so_version = 1.03
  local zwint_so
  if UseDebugZWaveInterceptor then
    -- zwint debug version
    zwint_so = b642bin([[
    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
    AABIAgAA0DYAAAAAAAASAAAAcAEAAMA2AAAAAAAAEgAAAEACAACwNgAAAAAAABIAAAAmAgAAoDYA
    AAAAAAASAAAA9wEAAJA2AAAAAAAAEgAAAPQAAACANgAAAAAAABIAAAAIAgAAcDYAAAAAAAASAAAA
    MwIAAGA2AAAAAAAAEgAAADsCAABQNgAAAAAAABIAAABQAAAAQDYAAAAAAAASAAAA1QEAADA2AAAA
    AAAAEgAAAEsBAAAgNgAAAAAAABIAAADrAAAAEDYAAAAAAAASAAAAWwEAAAA2AAAAAAAAEgAAAIoB
    AADwNQAAAAAAABIAAAC8AAAA4DUAAAAAAAASAAAAkQEAANA1AAAAAAAAEgAAAJYAAADANQAAAAAA
    ABIAAACLAgAAsDUAAAAAAAASAAAA8AEAAKA1AAAAAAAAEgAAAHwCAACQNQAAAAAAABIAAABGAQAA
    gDUAAAAAAAASAAAAJgAAAAAAAAAAAAAAIgAAAIEBAABwNQAAAAAAABIAAAAQAQAAYDUAAAAAAAAS
    AAAA4AAAAFA1AAAAAAAAEgAAAHgBAABANQAAAAAAABIAAADIAAAAMDUAAAAAAAASAAAAqQEAACA1
    AAAAAAAAEgAAAK4AAAAQNQAAAAAAABIAAAAUAgAAADUAAAAAAAASAAAAyAEAAPA0AAAAAAAAEgAA
    AKIBAADgNAAAAAAAABIAAABoAAAA0DQAAAAAAAASAAAAAF9HTE9CQUxfT0ZGU0VUX1RBQkxFXwBf
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
    BAAAAAAQALyPAQARBAAAAAACABw8zMKcJyHgnwMkgJmPcDQ5J8kJEQQAAAAAEAC8jxwAv48IAOAD
    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
    nmUHKjDwxJlslAVtp/MQTuIX8PBUmWyUBW1A6jplYNIKlvDwWJlslJ5lQOo6ZQqWBlKeZRZh0PBE
    mWyUBm1A6jplCpaeZRUi0PBImWyUDAYGbUDqOmUKlgFrXdKeZV/TDxAw8ASZAG9f12f2FEhd0AcQ
    MPDkmQBrX9Nn9hRPXdfw8FiZbJRA6jplCpYHUp5lG2HQ8ESZbJQHbUDqOmUKlp5lEiLQ8EiZbJQN
    BgdtQOo6ZQqWXtKeZQ4qMPDEmWyUB23H8whOhxcw8ASZAGoN0mf2FEhe0FDwXJlhlEDqOmUCZwqW
    UPBcmV6UnmVA6jplSeAKlodC8PBAmZ5lW0xA6jplCpZc0p5lDSpw8ESZMPAkmUDqOmWgmmyUYvEN
    SUDpOWVdF1yQsPBEmWKVNEhj0JBnA25A6jplCpYCZ55lDCKCZ5DwQJljlf9vEAYtT0DqOmUKlp5l
    IxBfkz8jXJOw8ESZXZUUS4NnA25m00DqOmUKlgJnZpOeZTAigmeQ8ECZ/2+jZxAGLU9A6jplCpZQ
    8FSZY5SeZUDqOmUKlp5lMPBYmVyUQOo6ZQqW0PBQmWyUnmVA6jplCpYw8FSZbJSeZTplQOqwZwqW
    kPAomWyUnmUQBUDpOWUDauUQZJNckBDxVJlhlWLYYEiQZ0DqOmUKllyVUPBcmZ5lA92QZ0DqOmUK
    lgFKQeCeZd1nsPHkRuCnXJZdZ5DxZELwxl+XQKN9ZwFfUcZw8axDWGdgpVPGEPFUmV6VcsaQZ0Dq
    OmUNkgEqAGhck2CXAGwV2wBtDycw8ESZwfYJSkDqOmVgkBniwPcDNEPujeNYZ4ZndeJckJbYt9gw
    8ASZAfcRSEDoOGVckwqWcPBcmbCDnmWAmnBnBSUw8MSZh/METgQQMPDEmYfzEE5ckDDwpJnjmF2Q
    5/MATQTQYpAF0F6QBtBckFGAYJBm0wfSsPBYmQjQEPAYmUDqOmUKlnDwSJkq8RRIkGeeZUDqOmVc
    khDw+Jlmk9eaqvGQn7aaB2dEZy5lBxAQ8PiZQJpK8RBP/+IUJ9aa95oeZclnre4OZdhnze/IZwQm
    CSfYZ9/lBBDr7u3uwPfCNwFX5WChmlyXQN+h3+Dd4dqO6gIqqvHw2EDrO2UKljDwpJmeZarx0Jgc
    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
    EICZjyF44AMJ+CADPQAYJBCAmY8heOADCfggAzsAGCQQgJmPIXjgAwn4IAM6ABgkEICZjyF44AMJ
    +CADOQAYJBCAmY8heOADCfggAzgAGCQQgJmPIXjgAwn4IAM3ABgkEICZjyF44AMJ+CADNgAYJBCA
    mY8heOADCfggAzUAGCQQgJmPIXjgAwn4IAM0ABgkEICZjyF44AMJ+CADMwAYJBCAmY8heOADCfgg
    AzIAGCQQgJmPIXjgAwn4IAMxABgkEICZjyF44AMJ+CADMAAYJBCAmY8heOADCfggAy8AGCQQgJmP
    IXjgAwn4IAMuABgkEICZjyF44AMJ+CADLQAYJBCAmY8heOADCfggAywAGCQQgJmPIXjgAwn4IAMr
    ABgkEICZjyF44AMJ+CADKgAYJBCAmY8heOADCfggAykAGCQQgJmPIXjgAwn4IAMoABgkEICZjyF4
    4AMJ+CADJwAYJBCAmY8heOADCfggAyYAGCQQgJmPIXjgAwn4IAMlABgkEICZjyF44AMJ+CADJAAY
    JBCAmY8heOADCfggAyMAGCQQgJmPIXjgAwn4IAMiABgkEICZjyF44AMJ+CADIQAYJBCAmY8heOAD
    CfggAx8AGCQQgJmPIXjgAwn4IAMeABgkEICZjyF44AMJ+CADHQAYJBCAmY8heOADCfggAxwAGCQQ
    gJmPIXjgAwn4IAMbABgkEICZjyF44AMJ+CADGgAYJBCAmY8heOADCfggAxkAGCQQgJmPIXjgAwn4
    IAMYABgkEICZjyF44AMJ+CADFwAYJBCAmY8heOADCfggAxYAGCQQgJmPIXjgAwn4IAMVABgkEICZ
    jyF44AMJ+CADFAAYJBCAmY8heOADCfggAxMAGCQQgJmPIXjgAwn4IAMSABgkEICZjyF44AMJ+CAD
    EAAYJBCAmY8heOADCfggAw8AGCQQgJmPIXjgAwn4IAMOABgkAAAAAAAAAAAAAAAAAAAAAAIAHDyw
    l5wnIeCZA+D/vScQALyvHAC/rxgAvK8BABEEAAAAAAIAHDyMl5wnIeCfAySAmY9gDTknNfURBAAA
    AAAQALyPHAC/jwgA4AMgAL0nendpbnQgdGhyZWFkIGVycm9yOiAlcyAlZAoAADc3ICAgICAgJTAy
    ZC8lMDJkLyUwMmQgJWQ6JTAyZDolMDJkLiUwM2QgICAgAAAAAGRlbGV0ZSAlcyAtPiAlcyAtPiAl
    cyAtPiAlcwoAAAAAcmVwb3Blbl9odHRwX2ZkKCkKAAByZXBvcGVuX2h0dHBfZmQAQ2Fubm90IGNv
    bm5lY3QgdG8gc2VydmVyAAAAACAgaHR0cF9mZCgpPSVkCgBEZXZpY2UgbnVtYmVyIG5vdCBhbiBp
    bnRlZ2VyAAAAAE5vdCByZWdpc3RlcmVkAABCYWQgZGV2aWNlX3BhdGgARGV2aWNlX3BhdGggZG9l
    cyBub3QgbWF0Y2ggYWxyZWFkeSByZWdpc3RlcmVkIG5hbWUAAC9wcm9jL3NlbGYvZmQvAAAlcyVz
    AAAAAG9yaWdpbmFsX2NvbW1wb3J0X2ZkPSVkCgAAAABEZXZpY2VfcGF0aCBub3QgZm91bmQgaW4g
    b3BlbiBmaWxlIGxpc3QAQ3JlYXRlZCBzb2NrZXQgcGFpci4gZmRzICVkIGFuZCAlZAoARHVwMi4g
    b2xkX2ZkPSVkLCBuZXdfZmQ9JWQsIHJlc3VsdD0lZAoAAENsb3NpbmcgZmQgJWQgYWZ0ZXIgZHVw
    MgoAAABOZXcgY29tbXBvcnQgZmQ9JWQKAERldmljZV9udW0gbm90IGEgbnVtYmVyAEtleSBub3Qg
    YSBzdHJpbmcAAAAARGVxdWV1ZUhUVFBEYXRhOiBuZXh0UmVxdWVzdEAlcCBodHRwX2FjdGl2ZT0l
    ZCBodHRwX2hvbGRvZmY9JWQKACAgIFNlbmRpbmcgaHR0cDogKCVkIGJ5dGVzKSAlcwoAICAgV3Jv
    dGUgJWQgYnl0ZXMgdG8gSFRUUCBzZXJ2ZXIKAAAAICAgcmV0cnk6IFdyb3RlICVkIGJ5dGVzIHRv
    IEhUVFAgc2VydmVyCgAAAABpbnRlcmNlcHQAAABtb25pdG9yAFBhdHRlcm4gbm90IGEgc3RyaW5n
    AAAAAHRpbWVvdXQgbm90IGEgbnVtYmVyAAAAAFJlc3BvbnNlIG5vdCBhIHN0cmluZwAAAEx1YSAl
    czoga2V5PSVzIGFybV9wYXR0ZXJuPSVzIHBhdHRlcm49JXMgcmVzcG9uc2U9JXMgb25lc2hvdD0l
    ZCB0aW1lb3V0PSVkCgBpbnNlcnQgJXMgLT4gJXMgLT4gJXMgLT4gJXMKAAAAAEdFVCAvZGF0YV9y
    ZXF1ZXN0P2lkPWFjdGlvbiZEZXZpY2VOdW09JWQmc2VydmljZUlkPXVybjpnZW5nZW5fbWN2LW9y
    ZzpzZXJ2aWNlSWQ6WldhdmVNb25pdG9yMSZhY3Rpb249JXMma2V5PSVzJnRpbWU9JWYAACZDJWQ9
    AAAAJkVycm9yTWVzc2FnZT0AACBIVFRQLzEuMQ0KSG9zdDogMTI3LjAuMC4xDQoNCgAAc2VuZF9o
    dHRwOiBodHRwX2FjdGl2ZT0lZCBodHRwX2hvbGRvZmY9JWQKAABRdWV1ZWluZyBuZXh0IGh0dHAg
    cmVxdWVzdEAlcC4gbGFzdFJlcXVlc3RAJXAgaHR0cF9hY3RpdmU9JWQgaHR0cF9ob2xkb2ZmPSVk
    IHJlcXVlc3Q9JXMKAAAAAFF1ZXVlaW5nIGZpcnN0IGFuZCBsYXN0IGh0dHAgcmVxdWVzdEAlcC4g
    aHR0cF9hY3RpdmU9JWQgaHR0cF9ob2xkb2ZmPSVkIHJlcXVlc3Q9JXMKAEVycm9yAAAAUmVzcG9u
    c2UgdG9vIGxvbmcAAABob3N0LT5jb250cm9sbGVyAAAAAGNvbnRyb2xsZXItPmhvc3QAAAAAcwAA
    AEludGVyY2VwdAAAAE1vbml0b3IAJXMgR290ICVkIGJ5dGUlcyBvZiBkYXRhIGZyb20gZmQgJWQK
    AAAAACAgIHMtPnN0YXRlPSVkIGM9MHglMDJYCgAAAAAgICBTd2FsbG93aW5nIGFjayAlZCBvZiAl
    ZAoAICAgV3JpdGluZyBwYXJ0ICVkIG9mIHJlc3BvbnNlOiAlZCBieXRlcwoAAABJbnRlcmNlcHQg
    d3JpdGUAICAgY2hlY2tzdW09MHglMDJYCgAwMTIzNDU2Nzg5QUJDREVGAAAAACAgIGhleGJ1ZmY9
    JXMKAAAgICBUcnlpbmcgbW9uaXRvcjogJXMKAAAgICBNb25pdG9yOiAlcyBwYXNzZWQKAAAgICBN
    b25pdG9yICVzIGlzIG5vdyBhcm1lZAoAICAgICAgUmVzcG9uc2UgYz0lYyByc3RhdGU9JWQgYnl0
    ZT0weCUwMlgKAAAgICAgICBSZXNwb25zZSBzeW50YXggZXJyb3IKAAAAAFJlc3BvbnNlIHN5bnRh
    eCBlcnJvcgAAAFVubWF0Y2hlZCByZXBsYWNlbWVudAAAACAgIE1vbml0b3IgJXMgaXMgbm93IHVu
    YXJtZWQKAAAAICAgRGVsZXRpbmcgb25lc2hvdDogJXMKAAAAAFBhc3N0aHJvdWdoIHdyaXRlAAAA
    ICAgTm90IGludGVyY2VwdGVkLiBQYXNzIHRocm91Z2ggJWQgYnl0ZSVzIHRvIGZkICVkLiByZXN1
    bHQ9JWQKAEJhZCBjaGVja3VtIHdyaXRlAAAAICAgQmFkIGNoZWNrc3VtLiBQYXNzIHRocm91Z2gg
    JWQgYnl0ZSVzIHRvIGZkICVkLiByZXN1bHQ9JWQKAAAAAFRhaWwgd3JpdGUAACAgIFdyaXRpbmcg
    JWQgdHJhaWxpbmcgb3V0cHV0IGJ5dGUlcyB0byBmZCAlZC4gUmVzdWx0PSVkCgAAAFN0YXJ0IHp3
    aW50IHRocmVhZAoAQ2FsbGluZyBwb2xsLiB0aW1lb3V0PSVkCgAAAFBvbGwgcmV0dXJuZWQgJWQK
    AAAAVGltaW5nIG91dCBtb25pdG9yIHdpdGgga2V5OiAlcwoAAAAAVGltZW91dABob3N0X2ZkICVk
    IHJldmVudHMgPSAlZAoAAAAAY29udHJvbGxlcl9mZCAlZCByZXZlbnRzID0gJWQKAABodHRwX2Zk
    ICVkIHJldmVudHMgPSAlZAoAAAAAUmVjZWl2ZWQgJWQgYnl0ZXMgKHRvdGFsICVkIGJ5dGVzKSBm
    cm9tIGh0dHAgc2VydmVyOiAlcwoAAAAAaHR0cF9mZCBjbG9zZWQKAENsb3NpbmcgaHR0cF9mZCAl
    ZAoAb3V0cHV0AABTdGFydCBsdWFvcGVuX3p3aW50CgAAAAAqRHVtbXkqAHp3aW50AAAAdmVyc2lv
    bgBpbnN0YW5jZQAAAAByZWdpc3RlcgAAAAB1bnJlZ2lzdGVyAABjYW5jZWwAAAAAAAAAAAAAAAAA
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
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP//
    //8AAAAA/////wAAAAAAAAAAXEIAAJUOAABoQgAAdRMAAHRCAADFEQAAkDsAAOUeAACEOwAAvR4A
    AIBCAACdFwAAAAAAAAAAAAD/////AAAAAAAAAAAAAAAAAAAAAAAAAIAAAAEAHFEBAMBPAQAAAAAA
    AAAAAAAAAAAAAAAAMDgAACA4AAAQOAAAAAAAAAA4AADwNwAA4DcAANA3AADANwAAsDcAAKA3AACQ
    NwAAgDcAAHA3AABgNwAAUDcAAEA3AAAwNwAAAAAAACA3AAAQNwAAADcAAPA2AADgNgAA0DYAAMA2
    AACwNgAAoDYAAJA2AACANgAAcDYAAGA2AABQNgAAQDYAADA2AAAgNgAAEDYAAAA2AADwNQAA4DUA
    ANA1AADANQAAsDUAAKA1AACQNQAAgDUAAAAAAABwNQAAYDUAAFA1AABANQAAMDUAACA1AAAQNQAA
    ADUAAPA0AADgNAAA0DQAABxRAQBHQ0M6IChHTlUpIDMuMy4yAEdDQzogKExpbmFybyBHQ0MgNC42
    LTIwMTIuMDIpIDQuNi4zIDIwMTIwMjAxIChwcmVyZWxlYXNlKQAA6AwAAAAAAJD8////AAAAAAAA
    AAAgAAAAHQAAAB8AAABQOAAAAAAAkPz///8AAAAAAAAAACAAAAAdAAAAHwAAAGEOAAAAAACA/P//
    /wAAAAAAAAAAIAAAAB0AAAAfAAAAlQ4AAAAAAID8////AAAAAAAAAAAgAAAAHQAAAB8AAADJDgAA
    AAAAgPz///8AAAAAAAAAACgAAAAdAAAAHwAAABEPAAAAAAGA/P///wAAAAAAAAAAcAAAAB0AAAAf
    AAAAhQ8AAAAAA4D8////AAAAAAAAAAA4AAAAHQAAAB8AAAAxEAAAAAADgPz///8AAAAAAAAAAEAA
    AAAdAAAAHwAAAG0RAAAAAAOA/P///wAAAAAAAAAAKAAAAB0AAAAfAAAAxREAAAAAA4D8////AAAA
    AAAAAAAwAAAAHQAAAB8AAAB1EwAAAAADgPz///8AAAAAAAAAAEgCAAAdAAAAHwAAAJ0XAAAAAAOA
    /P///wAAAAAAAAAAQAAAAB0AAAAfAAAAnRgAAAAAA4D8////AAAAAAAAAABIAAAAHQAAAB8AAAAh
    GgAAAAADgPz///8AAAAAAAAAALABAAAdAAAAHwAAAGUeAAAAAAOA/P///wAAAAAAAAAAMAAAAB0A
    AAAfAAAAvR4AAAAAAID8////AAAAAAAAAAAgAAAAHQAAAB8AAADlHgAAAAAAgPz///8AAAAAAAAA
    ACAAAAAdAAAAHwAAAA0fAAAAAAMA/P///wAAAAAAAAAACAAAAB0AAAAfAAAAZR8AAAAAA4D8////
    AAAAAAAAAABQBAAAHQAAAB8AAABxIgAAAAADgPz///8AAAAAAAAAADAAAAAdAAAAHwAAAA0jAAAA
    AAOA/P///wAAAAAAAAAAIAYAAB0AAAAfAAAAVS4AAAAAA4D8////AAAAAAAAAABIBAAAHQAAAB8A
    AAB1MwAAAAADgPz///8AAAAAAAAAADAAAAAdAAAAHwAAAEEPAAAAZ251AAEHAAAABAMALnNoc3Ry
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
    AABeAAAAAQAAAAYAAABgDQAAYA0AAHAnAAAAAAAAAAAAABAAAAAAAAAAZAAAAAEAAAAGAAAA0DQA
    ANA0AACAAwAAAAAAAAAAAAAEAAAAAAAAAHAAAAABAAAABgAAAFA4AABQOAAAUAAAAAAAAAAAAAAA
    BAAAAAAAAAB2AAAAAQAAADIAAACgOAAAoDgAAOgJAAAAAAAAAAAAAAQAAAABAAAAfgAAAAEAAAAC
    AAAAiEIAAIhCAAAEAAAAAAAAAAAAAAAEAAAAAAAAAIgAAAABAAAAAwAAALRPAQC0TwAACAAAAAAA
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
    f0VMRgEBAQAAAAAAAAAAAAMACAABAAAAAA0AADQAAAD8NAAABxAAdDQAIAAHACgAHAAbAAAAAHAU
    AQAAFAEAABQBAAAYAAAAGAAAAAQAAAAEAAAAAQAAAAAAAAAAAAAAAAAAAKgvAACoLwAABQAAAAAA
    AQABAAAAvC8AALwvAQC8LwEAWAEAALQEAAAGAAAAAAABAAIAAAAsAQAALAEAACwBAADwAAAA8AAA
    AAcAAAAEAAAAUeV0ZAAAAAAAAAAAAAAAAAAAAAAAAAAABwAAAAQAAABS5XRkvC8AALwvAQC8LwEA
    RAAAAEQAAAAEAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAsgAAAAAA
    AAAAAAAAAAAAAAAAsAEAAQAAAIACAAABAAAAjgIAAAEAAACeAgAADAAAAIAMAAANAAAAICwAAAQA
    AAAcAgAABQAAAJQIAAAGAAAARAQAAAoAAADgAgAACwAAABAAAAADAAAAEDABABEAAAAgDAAAEgAA
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
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACADAAAAAAAAAMACQA1AgAApScAAMwAAAASAAoA
    rwIAAAAwAQAAAAAAEAATABcAAAAAsAEAAAAAABMA8f+2AgAAALABAAAAAAAQAPH/UAIAAIAMAAAc
    AAAAEgAJAKgCAAAADQAAAAAAABAACgDBAgAAFDEBAAAAAAAQAPH/IAAAACAsAAAcAAAAEgAMALoC
    AAAUMQEAAAAAABAA8f8BAAAAEDABAAAAAAARAPH/0wIAAHA0AQAAAAAAEADx/80CAAAUMQEAAAAA
    ABAA8f+gAAAAACwAAAAAAAASAAAATAAAAPArAAAAAAAAEgAAAI4AAADgKwAAAAAAABIAAAA1AAAA
    AAAAAAAAAAAgAAAAwwEAANArAAAAAAAAEgAAAFYCAADAKwAAAAAAABIAAACBAQAAsCsAAAAAAAAS
    AAAASQAAAKArAAAAAAAAEgAAAKsBAACQKwAAAAAAABIAAADRAQAAgCsAAAAAAAASAAAAQwIAAHAr
    AAAAAAAAEgAAAHUAAABgKwAAAAAAABIAAAAGAQAAUCsAAAAAAAASAAAAoAEAAEArAAAAAAAAEgAA
    AAUCAAAwKwAAAAAAABIAAABfAAAAAAAAAAAAAAARAAAA5wEAACArAAAAAAAAEgAAAOoAAAAQKwAA
    AAAAABIAAAC5AAAAACsAAAAAAAASAAAAGQEAAPAqAAAAAAAAEgAAAFEBAADgKgAAAAAAABIAAAAw
    AgAA0CoAAAAAAAASAAAAWAEAAMAqAAAAAAAAEgAAACgCAACwKgAAAAAAABIAAAAOAgAAoCoAAAAA
    AAASAAAA3wEAAJAqAAAAAAAAEgAAANwAAACAKgAAAAAAABIAAADwAQAAcCoAAAAAAAASAAAAGwIA
    AGAqAAAAAAAAEgAAACMCAABQKgAAAAAAABIAAABmAAAAQCoAAAAAAAASAAAAvQEAADAqAAAAAAAA
    EgAAADMBAAAgKgAAAAAAABIAAADTAAAAECoAAAAAAAASAAAAQwEAAAAqAAAAAAAAEgAAAHIBAADw
    KQAAAAAAABIAAACUAAAA4CkAAAAAAAASAAAAeQEAANApAAAAAAAAEgAAAG4AAADAKQAAAAAAABIA
    AABzAgAAsCkAAAAAAAASAAAA2AEAAKApAAAAAAAAEgAAAGQCAACQKQAAAAAAABIAAAAuAQAAgCkA
    AAAAAAASAAAAJgAAAAAAAAAAAAAAIgAAAGkBAABwKQAAAAAAABIAAAD4AAAAYCkAAAAAAAASAAAA
    yAAAAFApAAAAAAAAEgAAAGABAABAKQAAAAAAABIAAACwAAAAMCkAAAAAAAASAAAAkQEAACApAAAA
    AAAAEgAAAIYAAAAQKQAAAAAAABIAAAD8AQAAACkAAAAAAAASAAAAsAEAAPAoAAAAAAAAEgAAAIoB
    AADgKAAAAAAAABIAAABRAAAA0CgAAAAAAAASAAAAAF9HTE9CQUxfT0ZGU0VUX1RBQkxFXwBfZ3Bf
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
    AAAQAAAAAAAAAFAmeQsAAAIA2AIAAAAAAAAAAAAAAAAAANAvAQADAAAA1C8BAAMAAADYLwEAAwAA
    ANwvAQADAAAA4C8BAAMAAADkLwEAAwAAAOgvAQADAAAA7C8BAAMAAADwLwEAAwAAAPQvAQADAAAA
    EDEBAAMAAAACABw8gKOcJyHgmQPg/70nEAC8rxwAv68YALyvAQARBAAAAAACABw8XKOcJyHgnwMk
    gJmPvA05J0AAEQQAAAAAEAC8jwEAEQQAAAAAAgAcPDSjnCch4J8DJICZj3AoOSfjBhEEAAAAABAA
    vI8cAL+PCADgAyAAvScAAAAAAAAAAAIAHDwAo5wnIeCZA9D/vScoALOvGICTjxAAvK8sAL+vIDFi
    kiQAsq8gALGvHACwrxsAQBTggIKPBQBAEByAgo/ggJmPCfggAwAARIwQALyPGICSjyCAkY8YgJCP
    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
    ZJhl9wxLY9pQ8EiYMPCkmBDw2Jg6ZWX3FE3F9xBOQOqRZwSW0PBYmAy3nmUKtjplQOqRZwSWAm2R
    Z55lMPDEmNDwEJir7WX3HE5A6DhlAWp2ZKDoexSuR+F68D8CABw8kIecJyHgmQPY/70nHACwrxiA
    kI8QALyvIACxryQAv6+8LxAmAwAAEP//ESQJ+CAD/P8QJgAAGY78/zEXJAC/jyAAsY8cALCPCADg
    AygAvScAAAAAAAAAAAAAAAAQgJmPIXjgAwn4IANEABgkEICZjyF44AMJ+CADQwAYJBCAmY8heOAD
    CfggA0IAGCQQgJmPIXjgAwn4IANBABgkEICZjyF44AMJ+CADQAAYJBCAmY8heOADCfggAz8AGCQQ
    gJmPIXjgAwn4IAM+ABgkEICZjyF44AMJ+CADPQAYJBCAmY8heOADCfggAzwAGCQQgJmPIXjgAwn4
    IAM7ABgkEICZjyF44AMJ+CADOgAYJBCAmY8heOADCfggAzgAGCQQgJmPIXjgAwn4IAM3ABgkEICZ
    jyF44AMJ+CADNgAYJBCAmY8heOADCfggAzUAGCQQgJmPIXjgAwn4IAM0ABgkEICZjyF44AMJ+CAD
    MwAYJBCAmY8heOADCfggAzIAGCQQgJmPIXjgAwn4IAMxABgkEICZjyF44AMJ+CADMAAYJBCAmY8h
    eOADCfggAy8AGCQQgJmPIXjgAwn4IAMuABgkEICZjyF44AMJ+CADLQAYJBCAmY8heOADCfggAywA
    GCQQgJmPIXjgAwn4IAMrABgkEICZjyF44AMJ+CADKgAYJBCAmY8heOADCfggAykAGCQQgJmPIXjg
    Awn4IAMoABgkEICZjyF44AMJ+CADJwAYJBCAmY8heOADCfggAyYAGCQQgJmPIXjgAwn4IAMlABgk
    EICZjyF44AMJ+CADJAAYJBCAmY8heOADCfggAyMAGCQQgJmPIXjgAwn4IAMiABgkEICZjyF44AMJ
    +CADIQAYJBCAmY8heOADCfggAyAAGCQQgJmPIXjgAwn4IAMfABgkEICZjyF44AMJ+CADHgAYJBCA
    mY8heOADCfggAxwAGCQQgJmPIXjgAwn4IAMbABgkEICZjyF44AMJ+CADGgAYJBCAmY8heOADCfgg
    AxkAGCQQgJmPIXjgAwn4IAMYABgkEICZjyF44AMJ+CADFwAYJBCAmY8heOADCfggAxYAGCQQgJmP
    IXjgAwn4IAMVABgkEICZjyF44AMJ+CADFAAYJBCAmY8heOADCfggAxMAGCQQgJmPIXjgAwn4IAMS
    ABgkEICZjyF44AMJ+CADEAAYJBCAmY8heOADCfggAw8AGCQQgJmPIXjgAwn4IAMOABgkAAAAAAAA
    AAAAAAAAAAAAAAIAHDzgg5wnIeCZA+D/vScQALyvHAC/rxgAvK8BABEEAAAAAAIAHDy8g5wnIeCf
    AySAmY8ADTknKfgRBAAAAAAQALyPHAC/jwgA4AMgAL0nendpbnQgdGhyZWFkIGVycm9yOiAlcyAl
    ZAoAAHJlcG9wZW5faHR0cF9mZABDYW5ub3QgY29ubmVjdCB0byBzZXJ2ZXIAAAAARGV2aWNlIG51
    bWJlciBub3QgYW4gaW50ZWdlcgAAAABOb3QgcmVnaXN0ZXJlZAAAQmFkIGRldmljZV9wYXRoAERl
    dmljZV9wYXRoIGRvZXMgbm90IG1hdGNoIGFscmVhZHkgcmVnaXN0ZXJlZCBuYW1lAAAvcHJvYy9z
    ZWxmL2ZkLwAAJXMlcwAAAABEZXZpY2VfcGF0aCBub3QgZm91bmQgaW4gb3BlbiBmaWxlIGxpc3QA
    RGV2aWNlX251bSBub3QgYSBudW1iZXIAS2V5IG5vdCBhIHN0cmluZwAAAABQYXR0ZXJuIG5vdCBh
    IHN0cmluZwAAAAB0aW1lb3V0IG5vdCBhIG51bWJlcgAAAABSZXNwb25zZSBub3QgYSBzdHJpbmcA
    AABHRVQgL2RhdGFfcmVxdWVzdD9pZD1hY3Rpb24mRGV2aWNlTnVtPSVkJnNlcnZpY2VJZD11cm46
    Z2VuZ2VuX21jdi1vcmc6c2VydmljZUlkOlpXYXZlTW9uaXRvcjEmYWN0aW9uPSVzJmtleT0lcyZ0
    aW1lPSVmAAAmQyVkPQAAACZFcnJvck1lc3NhZ2U9AAAgSFRUUC8xLjENCkhvc3Q6IDEyNy4wLjAu
    MQ0KDQoAAEVycm9yAAAAUmVzcG9uc2UgdG9vIGxvbmcAAABJbnRlcmNlcHQAAABNb25pdG9yAElu
    dGVyY2VwdCB3cml0ZQAwMTIzNDU2Nzg5QUJDREVGAAAAAFJlc3BvbnNlIHN5bnRheCBlcnJvcgAA
    AFVubWF0Y2hlZCByZXBsYWNlbWVudAAAAFBhc3N0aHJvdWdoIHdyaXRlAAAAQmFkIGNoZWNrdW0g
    d3JpdGUAAABUYWlsIHdyaXRlAABUaW1lb3V0AGludGVyY2VwdAAAAG1vbml0b3IAb3V0cHV0AAAq
    RHVtbXkqAHp3aW50AAAAdmVyc2lvbgByZWdpc3RlcgAAAAB1bnJlZ2lzdGVyAABjYW5jZWwAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAP////8AAAAA/////wAAAAAAAAAAhC8AANERAACQLwAAIRAA
    AFwvAAAdGwAAUC8AAPUaAACcLwAAGRUAAAAAAAAAAAAA/////wAAAAAAAAAAAAAAAAAAAAAAAACA
    AAABABAxAQDILwEAAAAAAAAAAAAAAAAAAAAAAAAsAADwKwAA4CsAAAAAAADQKwAAwCsAALArAACg
    KwAAkCsAAIArAABwKwAAYCsAAFArAABAKwAAMCsAAAAAAAAgKwAAECsAAAArAADwKgAA4CoAANAq
    AADAKgAAsCoAAKAqAACQKgAAgCoAAHAqAABgKgAAUCoAAEAqAAAwKgAAICoAABAqAAAAKgAA8CkA
    AOApAADQKQAAwCkAALApAACgKQAAkCkAAIApAAAAAAAAcCkAAGApAABQKQAAQCkAADApAAAgKQAA
    ECkAAAApAADwKAAA4CgAANAoAAAQMQEAR0NDOiAoR05VKSAzLjMuMgBHQ0M6IChMaW5hcm8gR0ND
    IDQuNi0yMDEyLjAyKSA0LjYuMyAyMDEyMDIwMSAocHJlcmVsZWFzZSkAAIAMAAAAAACQ/P///wAA
    AAAAAAAAIAAAAB0AAAAfAAAAICwAAAAAAJD8////AAAAAAAAAAAgAAAAHQAAAB8AAAABDgAAAAAD
    gPz///8AAAAAAAAAACgAAAAdAAAAHwAAAGkOAAAAAACA/P///wAAAAAAAAAAKAAAAB0AAAAfAAAA
    sQ4AAAAAAID8////AAAAAAAAAAAgAAAAHQAAAB8AAADlDgAAAAADgPz///8AAAAAAAAAADgAAAAd
    AAAAHwAAAMkPAAAAAAOA/P///wAAAAAAAAAAKAAAAB0AAAAfAAAAIRAAAAAAA4D8////AAAAAAAA
    AAAwAAAAHQAAAB8AAADREQAAAAADgPz///8AAAAAAAAAAFACAAAdAAAAHwAAABkVAAAAAAOA/P//
    /wAAAAAAAAAAQAAAAB0AAAAfAAAAGRYAAAAAA4D8////AAAAAAAAAAA4AAAAHQAAAB8AAADpFgAA
    AAADgPz///8AAAAAAAAAAJABAAAdAAAAHwAAAJ0aAAAAAAOA/P///wAAAAAAAAAAMAAAAB0AAAAf
    AAAA9RoAAAAAAID8////AAAAAAAAAAAgAAAAHQAAAB8AAAAdGwAAAAAAgPz///8AAAAAAAAAACAA
    AAAdAAAAHwAAAEUbAAAAAAMA/P///wAAAAAAAAAACAAAAB0AAAAfAAAAnRsAAAAAA4D8////AAAA
    AAAAAABQBAAAHQAAAB8AAADBHQAAAAADgPz///8AAAAAAAAAADAAAAAdAAAAHwAAAF0eAAAAAAOA
    /P///wAAAAAAAAAAEAYAAB0AAAAfAAAAhSQAAAAAA4D8////AAAAAAAAAABABAAAHQAAAB8AAACl
    JwAAAAADgPz///8AAAAAAAAAADAAAAAdAAAAHwAAAEEPAAAAZ251AAEHAAAABAMALnNoc3RydGFi
    AC5yZWdpbmZvAC5keW5hbWljAC5oYXNoAC5keW5zeW0ALmR5bnN0cgAuZ251LnZlcnNpb24ALmdu
    dS52ZXJzaW9uX3IALnJlbC5keW4ALmluaXQALnRleHQALk1JUFMuc3R1YnMALmZpbmkALnJvZGF0
    YQAuZWhfZnJhbWUALmN0b3JzAC5kdG9ycwAuamNyAC5kYXRhLnJlbC5ybwAuZGF0YQAuZ290AC5z
    ZGF0YQAuYnNzAC5jb21tZW50AC5wZHIALmdudS5hdHRyaWJ1dGVzAC5tZGVidWcuYWJpMzIAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALAAAABgAAcAIAAAAUAQAAFAEA
    ABgAAAAAAAAAAAAAAAQAAAAYAAAAFAAAAAYAAAACAAAALAEAACwBAADwAAAABQAAAAAAAAAEAAAA
    CAAAAB0AAAAFAAAAAgAAABwCAAAcAgAAKAIAAAQAAAAAAAAABAAAAAQAAAAjAAAACwAAAAIAAABE
    BAAARAQAAFAEAAAFAAAAAgAAAAQAAAAQAAAAKwAAAAMAAAACAAAAlAgAAJQIAADgAgAAAAAAAAAA
    AAABAAAAAAAAADMAAAD///9vAgAAAHQLAAB0CwAAigAAAAQAAAAAAAAAAgAAAAIAAABAAAAA/v//
    bwIAAAAADAAAAAwAACAAAAAFAAAAAQAAAAQAAAAAAAAATwAAAAkAAAACAAAAIAwAACAMAABgAAAA
    BAAAAAAAAAAEAAAACAAAAFgAAAABAAAABgAAAIAMAACADAAAeAAAAAAAAAAAAAAABAAAAAAAAABe
    AAAAAQAAAAYAAAAADQAAAA0AANAbAAAAAAAAAAAAABAAAAAAAAAAZAAAAAEAAAAGAAAA0CgAANAo
    AABQAwAAAAAAAAAAAAAEAAAAAAAAAHAAAAABAAAABgAAACAsAAAgLAAAUAAAAAAAAAAAAAAABAAA
    AAAAAAB2AAAAAQAAADIAAABwLAAAcCwAADQDAAAAAAAAAAAAAAQAAAABAAAAfgAAAAEAAAACAAAA
    pC8AAKQvAAAEAAAAAAAAAAAAAAAEAAAAAAAAAIgAAAABAAAAAwAAALwvAQC8LwAACAAAAAAAAAAA
    AAAABAAAAAAAAACPAAAAAQAAAAMAAADELwEAxC8AAAgAAAAAAAAAAAAAAAQAAAAAAAAAlgAAAAEA
    AAADAAAAzC8BAMwvAAAEAAAAAAAAAAAAAAAEAAAAAAAAAJsAAAABAAAAAwAAANAvAQDQLwAAMAAA
    AAAAAAAAAAAABAAAAAAAAACoAAAAAQAAAAMAAAAAMAEAADAAABAAAAAAAAAAAAAAABAAAAAAAAAA
    rgAAAAEAAAADAAAQEDABABAwAAAAAQAAAAAAAAAAAAAQAAAABAAAALMAAAABAAAAAwAAEBAxAQAQ
    MQAABAAAAAAAAAAAAAAABAAAAAAAAAC6AAAACAAAAAMAAAAgMQEAFDEAAFADAAAAAAAAAAAAABAA
    AAAAAAAAvwAAAAEAAAAwAAAAAAAAABQxAABLAAAAAAAAAAAAAAABAAAAAQAAAMgAAAABAAAAAAAA
    AAAAAABgMQAAoAIAAAAAAAAAAAAABAAAAAAAAADNAAAA9f//bwAAAAAAAAAAADQAABAAAAAAAAAA
    AAAAAAEAAAAAAAAA3QAAAAEAAAAAAAAAcDQBABA0AAAAAAAAAAAAAAAAAAABAAAAAAAAAAEAAAAD
    AAAAAAAAAAAAAAAQNAAA6wAAAAAAAAAAAAAAAQAAAAAAAAA=
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
  	UpdateFileWithContent("/usr/lib/lua/zwint.so", zwint_so, 755, nil)
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

