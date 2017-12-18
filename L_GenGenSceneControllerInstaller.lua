-- Installer for GenGeneric Scene Controller Version 1.00
--
-- Includes installation files for
--   Evolve LCD1
--   Cooper RFWC5
--   Nexia One Touch NX1000
-- This installs zwave_products_user.xml for UI5 and modifies KitDevice.json for UI7.
-- It also installs the custom icon in the appropriate places for UI5 or UI7
-- Copyright 2016 Gustavo A Fernandez All Rights Reserved

local bit = require 'bit'
local nixio = require "nixio"
local socket = require "socket"
local inotify -- Not available in UI5 due to kernel config

local UseDebugZWaveInterceptor = false
local VerboseLogging = false
local GenGenInstaller_Version = 18 -- Update this each time we update the installer.

local ANSI_RED     = "\027[31m"
local ANSI_GREEN   = "\027[32m"
local ANSI_YELLOW  = "\027[33m"
local ANSI_BLUE    = "\027[34m"
local ANSI_MAGENTA = "\027[35m"
local ANSI_CYAN    = "\027[36m"
local ANSI_WHITE   = "\027[37m"
local ANSI_RESET   = "\027[0m"

local HAG_SID                 = "urn:micasaverde-com:serviceId:HomeAutomationGateway1"
local ZWN_SID       	      = "urn:micasaverde-com:serviceId:ZWaveNetwork1"

local GENGENINSTALLER_SID     = "urn:gengen_mcv-org:serviceId:SceneControllerInstaller1"
local GENGENINSTALLER_DEVTYPE = "urn:schemas-gengen_mcv-org:device:SceneControllerInstaller:1"

local SID_SCENECONTROLLER     = "urn:gengen_mcv-org:serviceId:SceneController1"

function log(msg)
  luup.log("GenGeneric Scene Controller Installer: " .. msg)
end

function verbose(msg)
  if VerboseLogging then
    luup.log("GenGeneric Scene Controller Installer verbose: " .. msg)
  end
end

function error(msg)
  luup.log(ANSI_RED .. "GenGeneric Scene Controller Installer error: " .. ANSI_RESET .. msg .. debug.traceback(ANSI_CYAN, 2) .. ANSI_RESET)
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

local reload_needed = false

-- Update file with the given content if the previous version does not exist or is different.
function UpdateFileWithContent(filename, content, permissions)
	local update = false
	local backup = false
	if not content then
		error("Missing content for "..filename)
		return false
	end
	local stat = nixio.fs.stat(filename)
	local oldName = filename .. ".old"
	local backupName = filename .. ".save"
	if stat then
		if stat.size ~= #content then
			log("Backing up " .. filename .. " to " .. backupName .. " and replacing with new version.")
			verbose("Old " .. filename .. " size was " .. stat.size .. " bytes. new size is " .. #content .. " bytes.")
			nixio.fs.rename(backupName, oldName)
			local result, errno, errmsg =  nixio.fs.rename(filename, backupName)
			if result then
				update = true
				backup = true
			else
				error("could not rename " .. filename .. " to" .. backupName .. ": " .. errmsg)
			end
		else
			verbose("Not updating " .. filename .. " because the new content is " .. #content .. " bytes and the old is " .. stat.size .. " bytes.")
		end
	else
		verbose("updating " .. filename .. " because a previous version does not exist")
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
				verbose("Wrote " .. filename .. " successfully (" .. #content .. " bytes)")
				reload_needed = true
				return true
			else
				error("could not write " .. #content .. " bytes into " .. filename .. ". only " .. bytesWritten .. " bytes written: " .. errmsg)
				f:close()
				if backup then
					nixio.fs.rename(backupName, filename)
					nixio.fs.rename(oldName, backupName)
				end
			end
		else
			error("could not open " .. filename .. " for writing: " .. errmsg)
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
		error("could not stat " .. base .. ": " .. errmsg)
		return nil
	end
	local base_modified_mtime, errno, errmsg = nixio.fs.stat(base_modified,"mtime")
	if not base_modified_mtime or base_mtime ~= base_modified_mtime then
		nixio.fs.rename(base_modified, base_old)
		local result, errno, errmsg = nixio.fs.rename(base, base_save)
		if not result then
			error("could not rename " .. base .. " to" .. base_save .. ": " .. errmsg)
			nixio.fs.rename(base_old, base_modified)
			return nil
		end
		local read_file, errmsg, errno = io.open(base_save, "r")
		if not read_file then
			error("could not open " .. base_save .. " for reading: " .. errmsg)
		    nixio.fs.rename(base_save, base)
			nixio.fs.rename(base_old, base_modified)
			return nil
		end
		local write_file, errmsg, errno = io.open(base_modified, "w", 644)
		if not write_file then
			error("could not open " .. base_modified .. " for writing: " .. errmsg)
			read_file:close()
		    nixio.fs.rename(base_save, base)
			nixio.fs.rename(base_old, base_modified)
			return nil
		end
		local result, errno, errmsg = nixio.fs.symlink(base_modified, base)
		if not result then
			error("could not symlink " .. base_modified .. " to" .. base .. ": " .. errmsg)
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
		log("Updating " .. filename)
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
		verbose("Not updating " .. filename)
	end
end

ScannedDeviceList = {}

function ScanForNewDevices()
	for device_num, device in pairs(luup.devices) do
		if device.device_num_parent and
	       luup.devices[device.device_num_parent] and
	       luup.devices[device.device_num_parent].device_type == "urn:schemas-micasaverde-com:device:ZWaveNetwork:1" then
	  		local manufacturer_info = luup.variable_get("urn:micasaverde-com:serviceId:ZWaveDevice1", "ManufacturerInfo", device_num)
		    local device_file = luup.attr_get("device_file", device_num);
	        if device.device_type == 'urn:schemas-micasaverde-com:device:SceneController:1' then
		  		if manufacturer_info == "275,17750,19506" then
					if device_file =="D_SceneController1.xml" then
			  			reload_needed = true
			  			log("Found a new Evolve LCD1 controller. Device ID: " .. device.id)
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
					end --  device_file =="D_SceneController1.xml"
				elseif manufacturer_info == "26,22349,0" then
					if device_file =="D_SceneController1.xml" then
		 				reload_needed = true
						log("Found a new Cooper RFWC5 controller. Device ID: " .. device.id)
						luup.attr_set("device_type", "urn:schemas-gengen_mcv-org:device:SceneControllerCooperRFWC5:1", device_num)
						luup.attr_set("device_file", "D_CooperRFWC5.xml", device_num)
						luup.attr_set("impl_file", "I_GenGenSceneController.xml", device_num)
						luup.attr_set("manufacturer", "Cooper Industries", device_num)
						luup.attr_set("name", "Cooper RFWC5 Controller Z-Wave", device_num)
						luup.attr_set("device_json", "D_CooperRFWC5.json", device_num)
						luup.attr_set("category_num", "14", device_num)
						luup.attr_set("subcategory_num", "0", device_num)
						luup.attr_set("model", "RFWC5", device_num)
						luup.attr_set("invisible", "1", device_num)
						luup.variable_set("urn:micasaverde-com:serviceId:SceneController1", "NumButtons", "5", device_num)
						luup.variable_set("urn:micasaverde-com:serviceId:SceneController1", "FiresOffEvents", "1", device_num)
						luup.variable_set("urn:micasaverde-com:serviceId:SceneController1", "ActivationMethod", "0", device_num)
					end -- device_file =="D_SceneController1.xml"
				end -- elseif manufacturer_info == "26,22349,0"
			elseif device.device_type == "urn:schemas-micasaverde-com:device:GenericIO:1" then
 				if manufacturer_info == "376,21315,18229" then
					if device_file =="D_GenericIO1.xml" then
						reload_needed = true
						log("Found a new Nexia One Touch controller. Device ID: " .. device.id)
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
	  				end	-- device_file == "D_GenericIO1.xml"
				end -- manufacturer_info == "376,21315,18229"
			end -- device.device_type == "urn:schemas-micasaverde-com:device:GenericIO:1"
		end
		if device.device_type == "urn:schemas-gengen_mcv-org:device:SceneControllerEvolveLCD:1" then
			local impl = luup.attr_get("impl_file", device_num)  
			if impl == "I_EvolveLCD1.xml" then
			  	reload_needed = true
			  	log("Updating the implementation file of the existing Evolve LCD1 peer device: "..tostring(device_num))
			  	luup.attr_set("impl_file", "I_GenGenSceneController.xml", device_num);
			end
		elseif device.device_type == "urn:schemas-gengen_mcv-org:device:SceneControllerCooperRFWC5:1" then
			local impl = luup.attr_get("impl_file", device_num) 
			if impl == "I_CooperRFWC5.xml" then
				reload_needed = true
			  	log("Updating the implementation file of the existing Cooper RFWC5 peer device: "..tostring(device_num))
			  	luup.attr_set("impl_file", "I_GenGenSceneController.xml", device_num);
			end
		end
	end	-- for device_num
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
			log("Removing older installer: device ID " .. dev_num)
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
	log("Removing superfluous installer: device ID " .. lul_device)
	luup.call_action(HAG_SID,"DeleteDevice", {DeviceNum = lul_device}, 0);
	return
  end

  -- Now look for older installers with different names and delete them one at a time
  if DeleteOldInstallers(lul_device) then
	log ("Older installer deleted. Reloading LuaUPnP.")
	luup.call_action(HAG_SID, "Reload", {}, 0)
	return
  end

  luup.attr_set("invisible","1",lul_device)

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

  -- Install Z-Wave interceptor (zwint)	version 1.0
  local zwint_so
  if UseDebugZWaveInterceptor then
    -- zwint debug version
    zwint_so = b642bin([[
    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
    AAAAAAAAEgAAABQCAACwMgAAAAAAABIAAADlAQAAoDIAAAAAAAASAAAA4gAAAJAyAAAAAAAAEgAA
    APYBAACAMgAAAAAAABIAAAAhAgAAcDIAAAAAAAASAAAAKQIAAGAyAAAAAAAAEgAAAFAAAABQMgAA
    AAAAABIAAADDAQAAQDIAAAAAAAASAAAAOQEAADAyAAAAAAAAEgAAANkAAAAgMgAAAAAAABIAAABJ
    AQAAEDIAAAAAAAASAAAAeAEAAAAyAAAAAAAAEgAAAKoAAADwMQAAAAAAABIAAAB/AQAA4DEAAAAA
    AAASAAAAhAAAANAxAAAAAAAAEgAAAHkCAADAMQAAAAAAABIAAADeAQAAsDEAAAAAAAASAAAAagIA
    AKAxAAAAAAAAEgAAADQBAACQMQAAAAAAABIAAAAmAAAAAAAAAAAAAAAiAAAAbwEAAIAxAAAAAAAA
    EgAAAP4AAABwMQAAAAAAABIAAADOAAAAYDEAAAAAAAASAAAAZgEAAFAxAAAAAAAAEgAAALYAAABA
    MQAAAAAAABIAAACXAQAAMDEAAAAAAAASAAAAnAAAACAxAAAAAAAAEgAAAAICAAAQMQAAAAAAABIA
    AAC2AQAAADEAAAAAAAASAAAAkAEAAPAwAAAAAAAAEgAAAHAAAADgMAAAAAAAABIAAAAAX0dMT0JB
    TF9PRkZTRVRfVEFCTEVfAF9ncF9kaXNwAF9maW5pAF9fY3hhX2ZpbmFsaXplAF9Kdl9SZWdpc3Rl
    ckNsYXNzZXMAc3RkZXJyAGZwcmludGYAcmVnZnJlZQBsdWFfcHVzaGludGVnZXIAY2xvY2tfZ2V0
    dGltZQBmcHV0cwBzb2NrZXQAX19lcnJub19sb2NhdGlvbgBjb25uZWN0AGNsb3NlAGx1YV9wdXNo
    bmlsAHN0cmVycm9yAGx1YV9wdXNoc3RyaW5nAGx1YV9nZXR0b3AAbHVhX3R5cGUAbHVhX2lzaW50
    ZWdlcgBsdWFMX2FyZ2Vycm9yAGx1YV90b2ludGVnZXIAcHRocmVhZF9tdXRleF9sb2NrAHB0aHJl
    YWRfbXV0ZXhfdW5sb2NrAGR1cDIAbHVhX3B1c2hib29sZWFuAGx1YV90b2xzdHJpbmcAc3RyY21w
    AG9wZW5kaXIAc25wcmludGYAcmVhZGxpbmsAc3RydG9sAHJlYWRkaXIAY2xvc2VkaXIAc3RyY3B5
    AHB0aHJlYWRfY3JlYXRlAHNvY2tldHBhaXIAb3BlbgBsdWFfaXNudW1iZXIAd3JpdGUAbHVhX3Rv
    Ym9vbGVhbgBzdHJsZW4AbWFsbG9jAHJlZ2NvbXAAcmVnZXJyb3IAX19mbG9hdHNpZGYAX19kaXZk
    ZjMAX19hZGRkZjMAZ2V0dGltZW9mZGF5AHN0cm5jcHkAcmVhZAByZWdleGVjAHBvbGwAbHVhb3Bl
    bl96d2ludABwdGhyZWFkX211dGV4X2luaXQAbHVhTF9yZWdpc3RlcgBsdWFfcHVzaG51bWJlcgBs
    dWFfc2V0ZmllbGQAbGliZ2NjX3Muc28uMQBsaWJwdGhyZWFkLnNvLjAAbGliYy5zby4wAF9mdGV4
    dABfZmRhdGEAX2dwAF9lZGF0YQBfX2Jzc19zdGFydABfZmJzcwBfZW5kAEdDQ18zLjAAAAAAAAEA
    AQAAAAEAAQABAAEAAQABAAEAAQABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAgAAAAAAAAAAAAEAAQCGAgAAEAAAAAAAAABQJnkLAAACAN4CAAAAAAAAAAAA
    AAAAAADIPwEAAwAAAMw/AQADAAAA0D8BAAMAAADUPwEAAwAAANg/AQADAAAA3D8BAAMAAADgPwEA
    AwAAAOQ/AQADAAAA6D8BAAMAAADsPwEAAwAAAPA/AQADAAAA9D8BAAMAAAAUQQEAAwAAAAIAHDxU
    s5wnIeCZA+D/vScQALyvHAC/rxgAvK8BABEEAAAAAAIAHDwws5wnIeCfAySAmY/sDTknQQARBAAA
    AAAQALyPAQARBAAAAAACABw8CLOcJyHgnwMkgJmPgDA5J9wIEQQAAAAAEAC8jxwAv48IAOADIAC9
    JwAAAAAAAAAAAAAAAAIAHDzQspwnIeCZA9D/vScoALOvGICTjxAAvK8sAL+vIEFikiQAsq8gALGv
    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
    sPBQmDDwpJiAmWf1GE1A6jplBpYw8FyYnmW8ZxDwuJ0I8ICdQOo6ZQaWAWpL6p5l3GcQ8NieCPBA
    3lxnEPBYmhDweJgw8KSY6PP0mrDwUJjo89CbgJmH9QxNIPQQ00DqOmUGliD0EJOeZejz0JsBVv/1
    AWGcZxDwmJz/Tujz0Nvo83Sc3/UXI7DwUJgw8KSY4JuAmaf1DE0g9BDTQOo6ZSD0EJMw8ESYgZun
    Q8L3HUoBTUDqOmUGliD0EJOeZbxnQJsQ8Lid6PNU3b/1FCoQ8HiY6PNY268VMPBEmN1nMPCEmLOO
    IfYRSsf1HExA6jplBpaeZaAVAPACalLwBAsA9EAyaeKaZfZkHGcE0nDwVJgkZzDwhJigmlDwUJjn
    9QRMQOo6ZRDweJgElijxUJueZRoqcPBAmBDwmJgG0wBtKPEUTEDqOmUElgaTnmUJIjDwBJiRZ6Jn
    wvAFSEDoOGUnEAFqKPFQ21DwSJgw8KSYEPDYmDpl5/UcTcf3CE5A6pFnBJbQ8FyYDbeeZQu2OmVA
    6pFnBJYCbZFnnmUw8MSY0PAUmKvtB/YETkDoOGUBanZkoOgAZQBlAAAAAAAA8D8CABw8gI+cJyHg
    mQPY/70nHACwrxiAkI8QALyvIACxryQAv6+0PxAmAwAAEP//ESQJ+CAD/P8QJgAAGY78/zEXJAC/
    jyAAsY8cALCPCADgAygAvScAAAAAAAAAAAAAAAAQgJmPIXjgAwn4IANFABgkEICZjyF44AMJ+CAD
    RAAYJBCAmY8heOADCfggA0MAGCQQgJmPIXjgAwn4IANCABgkEICZjyF44AMJ+CADQQAYJBCAmY8h
    eOADCfggA0AAGCQQgJmPIXjgAwn4IAM/ABgkEICZjyF44AMJ+CADPgAYJBCAmY8heOADCfggAz0A
    GCQQgJmPIXjgAwn4IAM8ABgkEICZjyF44AMJ+CADOwAYJBCAmY8heOADCfggAzkAGCQQgJmPIXjg
    Awn4IAM4ABgkEICZjyF44AMJ+CADNwAYJBCAmY8heOADCfggAzYAGCQQgJmPIXjgAwn4IAM1ABgk
    EICZjyF44AMJ+CADNAAYJBCAmY8heOADCfggAzMAGCQQgJmPIXjgAwn4IAMyABgkEICZjyF44AMJ
    +CADMQAYJBCAmY8heOADCfggAzAAGCQQgJmPIXjgAwn4IAMvABgkEICZjyF44AMJ+CADLgAYJBCA
    mY8heOADCfggAy0AGCQQgJmPIXjgAwn4IAMsABgkEICZjyF44AMJ+CADKwAYJBCAmY8heOADCfgg
    AyoAGCQQgJmPIXjgAwn4IAMpABgkEICZjyF44AMJ+CADKAAYJBCAmY8heOADCfggAycAGCQQgJmP
    IXjgAwn4IAMmABgkEICZjyF44AMJ+CADJQAYJBCAmY8heOADCfggAyQAGCQQgJmPIXjgAwn4IAMj
    ABgkEICZjyF44AMJ+CADIgAYJBCAmY8heOADCfggAyEAGCQQgJmPIXjgAwn4IAMgABgkEICZjyF4
    4AMJ+CADHwAYJBCAmY8heOADCfggAx0AGCQQgJmPIXjgAwn4IAMcABgkEICZjyF44AMJ+CADGwAY
    JBCAmY8heOADCfggAxoAGCQQgJmPIXjgAwn4IAMZABgkEICZjyF44AMJ+CADGAAYJBCAmY8heOAD
    CfggAxcAGCQQgJmPIXjgAwn4IAMWABgkEICZjyF44AMJ+CADFQAYJBCAmY8heOADCfggAxQAGCQQ
    gJmPIXjgAwn4IAMTABgkEICZjyF44AMJ+CADEgAYJBCAmY8heOADCfggAxAAGCQQgJmPIXjgAwn4
    IAMPABgkEICZjyF44AMJ+CADDgAYJAAAAAAAAAAAAAAAAAAAAAACABw8wIucJyHgmQPg/70nEAC8
    rxwAv68YALyvAQARBAAAAAACABw8nIucJyHgnwMkgJmPMA05Jy32EQQAAAAAEAC8jxwAv48IAOAD
    IAC9J3p3aW50IHRocmVhZCBlcnJvcjogJXMgJWQKAABkZWxldGUgJXMuIGxhc3QgbW9uaXRvcgoA
    AAAAZGVsZXRlICVzIC0+ICVzIC0+ICVzIC0+ICVzCgAAAAByZXBvcGVuX2h0dHBfZmQoKQoAAHJl
    cG9wZW5faHR0cF9mZABDYW5ub3QgY29ubmVjdCB0byBzZXJ2ZXIAAAAAICBodHRwX2ZkKCk9JWQK
    AERldmljZSBudW1iZXIgbm90IGFuIGludGVnZXIAAAAATm90IHJlZ2lzdGVyZWQAAEJhZCBkZXZp
    Y2VfcGF0aABEZXZpY2VfcGF0aCBkb2VzIG5vdCBtYXRjaCBhbHJlYWR5IHJlZ2lzdGVyZWQgbmFt
    ZQAAL3Byb2Mvc2VsZi9mZC8AACVzJXMAAAAAb3JpZ2luYWxfY29tbXBvcnRfZmQ9JWQKAAAAAERl
    dmljZV9wYXRoIG5vdCBmb3VuZCBpbiBvcGVuIGZpbGUgbGlzdABDcmVhdGVkIHNvY2tldCBwYWly
    LiBmZHMgJWQgYW5kICVkCgBEdXAyLiBvbGRfZmQ9JWQsIG5ld19mZD0lZCwgcmVzdWx0PSVkCgAA
    Q2xvc2luZyBmZCAlZCBhZnRlciBkdXAyCgAAAE5ldyBjb21tcG9ydCBmZD0lZAoARGV2aWNlX251
    bSBub3QgYSBudW1iZXIAS2V5IG5vdCBhIHN0cmluZwAAAAAgICBTZW5kaW5nIGh0dHA6ICglZCBi
    eXRlcykgJXMKACAgIFdyb3RlICVkIGJ5dGVzIHRvIEhUVFAgc2VydmVyCgAAACAgIHJldHJ5OiBX
    cm90ZSAlZCBieXRlcyB0byBIVFRQIHNlcnZlcgoAAAAAaW50ZXJjZXB0AAAAbW9uaXRvcgBQYXR0
    ZXJuIG5vdCBhIHN0cmluZwAAAAB0aW1lb3V0IG5vdCBhIG51bWJlcgAAAABSZXNwb25zZSBub3Qg
    YSBzdHJpbmcAAABMdWEgJXM6IGtleT0lcyBhcm1fcGF0dGVybj0lcyBwYXR0ZXJuPSVzIHJlc3Bv
    bnNlPSVzIG9uZXNob3Q9JWQgdGltZW91dD0lZAoAaW5zZXJ0ICVzIC0+ICVzIC0+ICVzIC0+ICVz
    CgAAAABHRVQgL2RhdGFfcmVxdWVzdD9pZD1hY3Rpb24mRGV2aWNlTnVtPSVkJnNlcnZpY2VJZD11
    cm46Z2VuZ2VuX21jdi1vcmc6c2VydmljZUlkOlpXYXZlTW9uaXRvcjEmYWN0aW9uPSVzJmtleT0l
    cyZ0aW1lPSVmAAAmQyVkPQAAACZFcnJvck1lc3NhZ2U9AAAgSFRUUC8xLjENCkhvc3Q6IDEyNy4w
    LjAuMQ0KDQoAAHNlbmRfaHR0cDogaHR0cF9zdGF0ZT0lZAoAAABRdWV1ZWluZyBuZXh0IGh0dHAg
    cmVxdWVzdEAlcC4gbGFzdFJlcXVlc3RAJXAgaHR0cF9zdGF0ZT0lZCByZXF1ZXN0PSVzCgBRdWV1
    ZWluZyBmaXRzdCBhbmQgbGFzdCBodHRwIHJlcXVlc3RAJXAuIGh0dHBfc3RhdGU9JWQgcmVxdWVz
    dD0lcwoAAEVycm9yAAAAUmVzcG9uc2UgdG9vIGxvbmcAAABob3N0LT5jb250cm9sbGVyAAAAAGNv
    bnRyb2xsZXItPmhvc3QAAAAAcwAAAEludGVyY2VwdAAAAE1vbml0b3IAJXMgR290ICVkIGJ5dGUl
    cyBvZiBkYXRhIGZyb20gZmQgJWQKAAAAACAgIHMtPnN0YXRlPSVkIGM9MHglMDJYCgAAAAAgICBT
    d2FsbG93aW5nIGFjayAlZCBvZiAlZAoAICAgV3JpdGluZyBwYXJ0ICVkIG9mIHJlc3BvbnNlOiAl
    ZCBieXRlcwoAAABJbnRlcmNlcHQgd3JpdGUAICAgY2hlY2tzdW09MHglMDJYCgAwMTIzNDU2Nzg5
    QUJDREVGAAAAACAgIGhleGJ1ZmY9JXMKAAAgICBUcnlpbmcgbW9uaXRvcjogJXMKAAAgICBNb25p
    dG9yOiAlcyBwYXNzZWQKAAAgICBNb25pdG9yICVzIGlzIG5vdyBhcm1lZAoAICAgICAgUmVzcG9u
    c2UgYz0lYyByc3RhdGU9JWQgYnl0ZT0weCUwMlgKAAAgICAgICBSZXNwb25zZSBzeW50YXggZXJy
    b3IKAAAAAFJlc3BvbnNlIHN5bnRheCBlcnJvcgAAAFVubWF0Y2hlZCByZXBsYWNlbWVudAAAACAg
    IERlbGV0aW5nIG9uZXNob3Q6ICVzCgAAAAAgICBNb25pdG9yICVzIGlzIG5vdyB1bmFybWVkCgAA
    AFBhc3N0aHJvdWdoIHdyaXRlAAAAICAgTm90IGludGVyY2VwdGVkLiBQYXNzIHRocm91Z2ggJWQg
    Ynl0ZSVzIHRvIGZkICVkLiByZXN1bHQ9JWQKAEJhZCBjaGVja3VtIHdyaXRlAAAAICAgQmFkIGNo
    ZWNrc3VtLiBQYXNzIHRocm91Z2ggJWQgYnl0ZSVzIHRvIGZkICVkLiByZXN1bHQ9JWQKAAAAAFRh
    aWwgd3JpdGUAACAgIFdyaXRpbmcgJWQgdHJhaWxpbmcgb3V0cHV0IGJ5dGUlcyB0byBmZCAlZC4g
    UmVzdWx0PSVkCgAAAFN0YXJ0IHp3aW50IHRocmVhZAoAQ2FsbGluZyBwb2xsLiB0aW1lb3V0PSVk
    CgAAAFBvbGwgcmV0dXJuZWQgJWQKAAAAVGltaW5nIG91dCBtb25pdG9yIHdpdGgga2V5OiAlcwoA
    AAAAVGltZW91dABob3N0X2ZkICVkIHJldmVudHMgPSAlZAoAAAAAY29udHJvbGxlcl9mZCAlZCBy
    ZXZlbnRzID0gJWQKAABodHRwX2ZkICVkIHJldmVudHMgPSAlZAoAAAAAUmVjZWl2ZWQgJWQgYnl0
    ZXMgKHRvdGFsICVkIGJ5dGVzKSBmcm9tIGh0dHAgc2VydmVyOiAlcwoAAAAAaHR0cF9mZCBjbG9z
    ZWQKAENsb3NpbmcgaHR0cF9mZCAlZAoAaHR0cF9zdGF0ZT0lZCBuZXh0UmVxdWVzdEAlcAoAAABE
    ZXF1ZXVlaW5nIEhUVFAgcmVxdWVzdC4gaHR0cF9zdGF0ZT0lZCBuZXh0QCVwCgBvdXRwdXQAAFN0
    YXJ0IGx1YW9wZW5fendpbnQKAAAAAHp3aW50AAAAdmVyc2lvbgBpbnN0YW5jZQAAAAByZWdpc3Rl
    cgAAAAB1bnJlZ2lzdGVyAABjYW5jZWwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAA/////wAAAAD/////AAAAAAAAAAAMPgAAJQ8AABg+AADREgAAJD4AAB0RAAAsNwAAZR0A
    ACA3AAA9HQAAMD4AAOEWAAAAAAAAAAAAAP////8AAAAAAAAAAAAAAAAAAAAAAAAAgAAAAQAUQQEA
    wD8BAAAAAAAAAAAAAAAAAAAAAAAgNAAAEDQAAAA0AAAAAAAA8DMAAOAzAADQMwAAwDMAALAzAACg
    MwAAkDMAAIAzAABwMwAAYDMAAFAzAABAMwAAAAAAADAzAAAgMwAAEDMAAAAzAADwMgAA4DIAANAy
    AADAMgAAsDIAAKAyAACQMgAAgDIAAHAyAABgMgAAUDIAAEAyAAAwMgAAIDIAABAyAAAAMgAA8DEA
    AOAxAADQMQAAwDEAALAxAACgMQAAkDEAAAAAAACAMQAAcDEAAGAxAABQMQAAQDEAADAxAAAgMQAA
    EDEAAAAxAADwMAAA4DAAABRBAQBHQ0M6IChHTlUpIDMuMy4yAEdDQzogKExpbmFybyBHQ0MgNC42
    LTIwMTIuMDIpIDQuNi4zIDIwMTIwMjAxIChwcmVyZWxlYXNlKQAArAwAAAAAAJD8////AAAAAAAA
    AAAgAAAAHQAAAB8AAABANAAAAAAAkPz///8AAAAAAAAAACAAAAAdAAAAHwAAADEOAAAAAACA/P//
    /wAAAAAAAAAAIAAAAB0AAAAfAAAAZQ4AAAAAA4D8////AAAAAAAAAAAwAAAAHQAAAB8AAAAlDwAA
    AAAAgPz///8AAAAAAAAAACAAAAAdAAAAHwAAAFkPAAAAAACA/P///wAAAAAAAAAAKAAAAB0AAAAf
    AAAAoQ8AAAAAA4D8////AAAAAAAAAAA4AAAAHQAAAB8AAADFEAAAAAADgPz///8AAAAAAAAAACgA
    AAAdAAAAHwAAAB0RAAAAAAOA/P///wAAAAAAAAAAOAAAAB0AAAAfAAAA0RIAAAAAA4D8////AAAA
    AAAAAABQAgAAHQAAAB8AAADhFgAAAAADgPz///8AAAAAAAAAAEAAAAAdAAAAHwAAAN0XAAAAAAOA
    /P///wAAAAAAAAAAMAAAAB0AAAAfAAAAqRgAAAAAA4D8////AAAAAAAAAACoAQAAHQAAAB8AAADl
    HAAAAAADgPz///8AAAAAAAAAADAAAAAdAAAAHwAAAD0dAAAAAACA/P///wAAAAAAAAAAIAAAAB0A
    AAAfAAAAZR0AAAAAAID8////AAAAAAAAAAAgAAAAHQAAAB8AAACNHQAAAAADAPz///8AAAAAAAAA
    AAgAAAAdAAAAHwAAAOUdAAAAAAOA/P///wAAAAAAAAAAUAQAAB0AAAAfAAAAwSAAAAAAA4D8////
    AAAAAAAAAAAwAAAAHQAAAB8AAABdIQAAAAADgPz///8AAAAAAAAAABgGAAAdAAAAHwAAAK0qAAAA
    AAOA/P///wAAAAAAAAAASAQAAB0AAAAfAAAAuS8AAAAAA4D8////AAAAAAAAAAAwAAAAHQAAAB8A
    AABBDwAAAGdudQABBwAAAAQDAC5zaHN0cnRhYgAucmVnaW5mbwAuZHluYW1pYwAuaGFzaAAuZHlu
    c3ltAC5keW5zdHIALmdudS52ZXJzaW9uAC5nbnUudmVyc2lvbl9yAC5yZWwuZHluAC5pbml0AC50
    ZXh0AC5NSVBTLnN0dWJzAC5maW5pAC5yb2RhdGEALmVoX2ZyYW1lAC5jdG9ycwAuZHRvcnMALmpj
    cgAuZGF0YS5yZWwucm8ALmRhdGEALmdvdAAuc2RhdGEALmJzcwAuY29tbWVudAAucGRyAC5nbnUu
    YXR0cmlidXRlcwAubWRlYnVnLmFiaTMyAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAACwAAAAYAAHACAAAAFAEAABQBAAAYAAAAAAAAAAAAAAAEAAAAGAAAABQAAAAGAAAA
    AgAAACwBAAAsAQAA8AAAAAUAAAAAAAAABAAAAAgAAAAdAAAABQAAAAIAAAAcAgAAHAIAACwCAAAE
    AAAAAAAAAAQAAAAEAAAAIwAAAAsAAAACAAAASAQAAEgEAABgBAAABQAAAAIAAAAEAAAAEAAAACsA
    AAADAAAAAgAAAKgIAACoCAAA5gIAAAAAAAAAAAAAAQAAAAAAAAAzAAAA////bwIAAACOCwAAjgsA
    AIwAAAAEAAAAAAAAAAIAAAACAAAAQAAAAP7//28CAAAAHAwAABwMAAAgAAAABQAAAAEAAAAEAAAA
    AAAAAE8AAAAJAAAAAgAAADwMAAA8DAAAcAAAAAQAAAAAAAAABAAAAAgAAABYAAAAAQAAAAYAAACs
    DAAArAwAAHgAAAAAAAAAAAAAAAQAAAAAAAAAXgAAAAEAAAAGAAAAMA0AADANAACwIwAAAAAAAAAA
    AAAQAAAAAAAAAGQAAAABAAAABgAAAOAwAADgMAAAYAMAAAAAAAAAAAAABAAAAAAAAABwAAAAAQAA
    AAYAAABANAAAQDQAAFAAAAAAAAAAAAAAAAQAAAAAAAAAdgAAAAEAAAAyAAAAkDQAAJA0AACoCQAA
    AAAAAAAAAAAEAAAAAQAAAH4AAAABAAAAAgAAADg+AAA4PgAABAAAAAAAAAAAAAAABAAAAAAAAACI
    AAAAAQAAAAMAAAC0PwEAtD8AAAgAAAAAAAAAAAAAAAQAAAAAAAAAjwAAAAEAAAADAAAAvD8BALw/
    AAAIAAAAAAAAAAAAAAAEAAAAAAAAAJYAAAABAAAAAwAAAMQ/AQDEPwAABAAAAAAAAAAAAAAABAAA
    AAAAAACbAAAAAQAAAAMAAADIPwEAyD8AADgAAAAAAAAAAAAAAAQAAAAAAAAAqAAAAAEAAAADAAAA
    AEABAABAAAAQAAAAAAAAAAAAAAAQAAAAAAAAAK4AAAABAAAAAwAAEBBAAQAQQAAABAEAAAAAAAAA
    AAAAEAAAAAQAAACzAAAAAQAAAAMAABAUQQEAFEEAAAQAAAAAAAAAAAAAAAQAAAAAAAAAugAAAAgA
    AAADAAAAIEEBABhBAADgAgAAAAAAAAAAAAAQAAAAAAAAAL8AAAABAAAAMAAAAAAAAAAYQQAASwAA
    AAAAAAAAAAAAAQAAAAEAAADIAAAAAQAAAAAAAAAAAAAAZEEAAMACAAAAAAAAAAAAAAQAAAAAAAAA
    zQAAAPX//28AAAAAAAAAACREAAAQAAAAAAAAAAAAAAABAAAAAAAAAN0AAAABAAAAAAAAAABEAQA0
    RAAAAAAAAAAAAAAAAAAAAQAAAAAAAAABAAAAAwAAAAAAAAAAAAAANEQAAOsAAAAAAAAAAAAAAAEA
    AAAAAAAA
    ]])
  else
    -- zwint non-debug version
           zwint_so = b642bin([[
    f0VMRgEBAQAAAAAAAAAAAAMACAABAAAAAA0AADQAAAD8NAAABxAAdDQAIAAHACgAHAAbAAAAAHAU
    AQAAFAEAABQBAAAYAAAAGAAAAAQAAAAEAAAAAQAAAAAAAAAAAAAAAAAAAJAvAACQLwAABQAAAAAA
    AQABAAAAvC8AALwvAQC8LwEAWAEAAEQEAAAGAAAAAAABAAIAAAAsAQAALAEAACwBAADwAAAA8AAA
    AAcAAAAEAAAAUeV0ZAAAAAAAAAAAAAAAAAAAAAAAAAAABwAAAAQAAABS5XRkvC8AALwvAQC8LwEA
    RAAAAEQAAAAEAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAsgAAAAAA
    AAAAAAAAAAAAAAAAsAEAAQAAAIACAAABAAAAjgIAAAEAAACeAgAADAAAAIAMAAANAAAAECwAAAQA
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
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACADAAAAAAAAAMACQA1AgAAsScAALAAAAASAAoA
    rwIAAAAwAQAAAAAAEAATABcAAAAAsAEAAAAAABMA8f+2AgAAALABAAAAAAAQAPH/UAIAAIAMAAAc
    AAAAEgAJAKgCAAAADQAAAAAAABAACgDBAgAAFDEBAAAAAAAQAPH/IAAAABAsAAAcAAAAEgAMALoC
    AAAUMQEAAAAAABAA8f8BAAAAEDABAAAAAAARAPH/0wIAAAA0AQAAAAAAEADx/80CAAAUMQEAAAAA
    ABAA8f+gAAAA8CsAAAAAAAASAAAATAAAAOArAAAAAAAAEgAAAI4AAADQKwAAAAAAABIAAAA1AAAA
    AAAAAAAAAAAgAAAAwwEAAMArAAAAAAAAEgAAAFYCAACwKwAAAAAAABIAAACBAQAAoCsAAAAAAAAS
    AAAASQAAAJArAAAAAAAAEgAAAKsBAACAKwAAAAAAABIAAADRAQAAcCsAAAAAAAASAAAAQwIAAGAr
    AAAAAAAAEgAAAHUAAABQKwAAAAAAABIAAAAGAQAAQCsAAAAAAAASAAAAoAEAADArAAAAAAAAEgAA
    AAUCAAAgKwAAAAAAABIAAABfAAAAAAAAAAAAAAARAAAA5wEAABArAAAAAAAAEgAAAOoAAAAAKwAA
    AAAAABIAAAC5AAAA8CoAAAAAAAASAAAAGQEAAOAqAAAAAAAAEgAAAFEBAADQKgAAAAAAABIAAAAw
    AgAAwCoAAAAAAAASAAAAWAEAALAqAAAAAAAAEgAAACgCAACgKgAAAAAAABIAAAAOAgAAkCoAAAAA
    AAASAAAA3wEAAIAqAAAAAAAAEgAAANwAAABwKgAAAAAAABIAAADwAQAAYCoAAAAAAAASAAAAGwIA
    AFAqAAAAAAAAEgAAACMCAABAKgAAAAAAABIAAABmAAAAMCoAAAAAAAASAAAAvQEAACAqAAAAAAAA
    EgAAADMBAAAQKgAAAAAAABIAAADTAAAAACoAAAAAAAASAAAAQwEAAPApAAAAAAAAEgAAAHIBAADg
    KQAAAAAAABIAAACUAAAA0CkAAAAAAAASAAAAeQEAAMApAAAAAAAAEgAAAG4AAACwKQAAAAAAABIA
    AABzAgAAoCkAAAAAAAASAAAA2AEAAJApAAAAAAAAEgAAAGQCAACAKQAAAAAAABIAAAAuAQAAcCkA
    AAAAAAASAAAAJgAAAAAAAAAAAAAAIgAAAGkBAABgKQAAAAAAABIAAAD4AAAAUCkAAAAAAAASAAAA
    yAAAAEApAAAAAAAAEgAAAGABAAAwKQAAAAAAABIAAACwAAAAICkAAAAAAAASAAAAkQEAABApAAAA
    AAAAEgAAAIYAAAAAKQAAAAAAABIAAAD8AQAA8CgAAAAAAAASAAAAsAEAAOAoAAAAAAAAEgAAAIoB
    AADQKAAAAAAAABIAAABRAAAAwCgAAAAAAAASAAAAAF9HTE9CQUxfT0ZGU0VUX1RBQkxFXwBfZ3Bf
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
    gJmPvA05J0AAEQQAAAAAEAC8jwEAEQQAAAAAAgAcPDSjnCch4J8DJICZj2AoOSffBhEEAAAAABAA
    vI8cAL+PCADgAyAAvScAAAAAAAAAAAIAHDwAo5wnIeCZA9D/vScoALOvGICTjxAAvK8sAL+vIDFi
    kiQAsq8gALGvHACwrxsAQBTggIKPBQBAEByAgo/ggJmPCfggAwAARIwQALyPGICSjyCAkY8YgJCP
    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
    RfccTcX3EE5A6pFnBJbQ8FiYDreeZQy2OmVA6pFnBJYCbZFnnmUw8MSY0PAQmKvtZfcETkDoOGUB
    anZkoOgAZQBlAGUAAAAAAADwPwIAHDygh5wnIeCZA9j/vSccALCvGICQjxAAvK8gALGvJAC/r7wv
    ECYDAAAQ//8RJAn4IAP8/xAmAAAZjvz/MRckAL+PIACxjxwAsI8IAOADKAC9JwAAAAAAAAAAAAAA
    ABCAmY8heOADCfggA0QAGCQQgJmPIXjgAwn4IANDABgkEICZjyF44AMJ+CADQgAYJBCAmY8heOAD
    CfggA0EAGCQQgJmPIXjgAwn4IANAABgkEICZjyF44AMJ+CADPwAYJBCAmY8heOADCfggAz4AGCQQ
    gJmPIXjgAwn4IAM9ABgkEICZjyF44AMJ+CADPAAYJBCAmY8heOADCfggAzsAGCQQgJmPIXjgAwn4
    IAM6ABgkEICZjyF44AMJ+CADOAAYJBCAmY8heOADCfggAzcAGCQQgJmPIXjgAwn4IAM2ABgkEICZ
    jyF44AMJ+CADNQAYJBCAmY8heOADCfggAzQAGCQQgJmPIXjgAwn4IAMzABgkEICZjyF44AMJ+CAD
    MgAYJBCAmY8heOADCfggAzEAGCQQgJmPIXjgAwn4IAMwABgkEICZjyF44AMJ+CADLwAYJBCAmY8h
    eOADCfggAy4AGCQQgJmPIXjgAwn4IAMtABgkEICZjyF44AMJ+CADLAAYJBCAmY8heOADCfggAysA
    GCQQgJmPIXjgAwn4IAMqABgkEICZjyF44AMJ+CADKQAYJBCAmY8heOADCfggAygAGCQQgJmPIXjg
    Awn4IAMnABgkEICZjyF44AMJ+CADJgAYJBCAmY8heOADCfggAyUAGCQQgJmPIXjgAwn4IAMkABgk
    EICZjyF44AMJ+CADIwAYJBCAmY8heOADCfggAyIAGCQQgJmPIXjgAwn4IAMhABgkEICZjyF44AMJ
    +CADIAAYJBCAmY8heOADCfggAx8AGCQQgJmPIXjgAwn4IAMeABgkEICZjyF44AMJ+CADHAAYJBCA
    mY8heOADCfggAxsAGCQQgJmPIXjgAwn4IAMaABgkEICZjyF44AMJ+CADGQAYJBCAmY8heOADCfgg
    AxgAGCQQgJmPIXjgAwn4IAMXABgkEICZjyF44AMJ+CADFgAYJBCAmY8heOADCfggAxUAGCQQgJmP
    IXjgAwn4IAMUABgkEICZjyF44AMJ+CADEwAYJBCAmY8heOADCfggAxIAGCQQgJmPIXjgAwn4IAMQ
    ABgkEICZjyF44AMJ+CADDwAYJBCAmY8heOADCfggAw4AGCQAAAAAAAAAAAAAAAAAAAAAAgAcPPCD
    nCch4JkD4P+9JxAAvK8cAL+vGAC8rwEAEQQAAAAAAgAcPMyDnCch4J8DJICZjwANOSct+BEEAAAA
    ABAAvI8cAL+PCADgAyAAvSd6d2ludCB0aHJlYWQgZXJyb3I6ICVzICVkCgAAcmVwb3Blbl9odHRw
    X2ZkAENhbm5vdCBjb25uZWN0IHRvIHNlcnZlcgAAAABEZXZpY2UgbnVtYmVyIG5vdCBhbiBpbnRl
    Z2VyAAAAAE5vdCByZWdpc3RlcmVkAABCYWQgZGV2aWNlX3BhdGgARGV2aWNlX3BhdGggZG9lcyBu
    b3QgbWF0Y2ggYWxyZWFkeSByZWdpc3RlcmVkIG5hbWUAAC9wcm9jL3NlbGYvZmQvAAAlcyVzAAAA
    AERldmljZV9wYXRoIG5vdCBmb3VuZCBpbiBvcGVuIGZpbGUgbGlzdABEZXZpY2VfbnVtIG5vdCBh
    IG51bWJlcgBLZXkgbm90IGEgc3RyaW5nAAAAAFBhdHRlcm4gbm90IGEgc3RyaW5nAAAAAHRpbWVv
    dXQgbm90IGEgbnVtYmVyAAAAAFJlc3BvbnNlIG5vdCBhIHN0cmluZwAAAEdFVCAvZGF0YV9yZXF1
    ZXN0P2lkPWFjdGlvbiZEZXZpY2VOdW09JWQmc2VydmljZUlkPXVybjpnZW5nZW5fbWN2LW9yZzpz
    ZXJ2aWNlSWQ6WldhdmVNb25pdG9yMSZhY3Rpb249JXMma2V5PSVzJnRpbWU9JWYAACZDJWQ9AAAA
    JkVycm9yTWVzc2FnZT0AACBIVFRQLzEuMQ0KSG9zdDogMTI3LjAuMC4xDQoNCgAARXJyb3IAAABS
    ZXNwb25zZSB0b28gbG9uZwAAAEludGVyY2VwdAAAAE1vbml0b3IASW50ZXJjZXB0IHdyaXRlADAx
    MjM0NTY3ODlBQkNERUYAAAAAUmVzcG9uc2Ugc3ludGF4IGVycm9yAAAAVW5tYXRjaGVkIHJlcGxh
    Y2VtZW50AAAAUGFzc3Rocm91Z2ggd3JpdGUAAABCYWQgY2hlY2t1bSB3cml0ZQAAAFRhaWwgd3Jp
    dGUAAFRpbWVvdXQAaW50ZXJjZXB0AAAAbW9uaXRvcgBvdXRwdXQAAHp3aW50AAAAdmVyc2lvbgBy
    ZWdpc3RlcgAAAAB1bnJlZ2lzdGVyAABjYW5jZWwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAP////8AAAAA/////wAAAAAAAAAAbC8AAOERAAB4LwAALRAA
    AEwvAADJGgAAQC8AAKEaAACELwAAKRUAAAAAAAAAAAAA/////wAAAAAAAAAAAAAAAAAAAAAAAACA
    AAABABAxAQDILwEAAAAAAAAAAAAAAAAAAAAAAPArAADgKwAA0CsAAAAAAADAKwAAsCsAAKArAACQ
    KwAAgCsAAHArAABgKwAAUCsAAEArAAAwKwAAICsAAAAAAAAQKwAAACsAAPAqAADgKgAA0CoAAMAq
    AACwKgAAoCoAAJAqAACAKgAAcCoAAGAqAABQKgAAQCoAADAqAAAgKgAAECoAAAAqAADwKQAA4CkA
    ANApAADAKQAAsCkAAKApAACQKQAAgCkAAHApAAAAAAAAYCkAAFApAABAKQAAMCkAACApAAAQKQAA
    ACkAAPAoAADgKAAA0CgAAMAoAAAQMQEAR0NDOiAoR05VKSAzLjMuMgBHQ0M6IChMaW5hcm8gR0ND
    IDQuNi0yMDEyLjAyKSA0LjYuMyAyMDEyMDIwMSAocHJlcmVsZWFzZSkAAIAMAAAAAACQ/P///wAA
    AAAAAAAAIAAAAB0AAAAfAAAAECwAAAAAAJD8////AAAAAAAAAAAgAAAAHQAAAB8AAAABDgAAAAAD
    gPz///8AAAAAAAAAACgAAAAdAAAAHwAAAHUOAAAAAACA/P///wAAAAAAAAAAKAAAAB0AAAAfAAAA
    vQ4AAAAAAID8////AAAAAAAAAAAgAAAAHQAAAB8AAADxDgAAAAADgPz///8AAAAAAAAAADgAAAAd
    AAAAHwAAANUPAAAAAAOA/P///wAAAAAAAAAAKAAAAB0AAAAfAAAALRAAAAAAA4D8////AAAAAAAA
    AAA4AAAAHQAAAB8AAADhEQAAAAADgPz///8AAAAAAAAAAFACAAAdAAAAHwAAACkVAAAAAAOA/P//
    /wAAAAAAAAAAQAAAAB0AAAAfAAAAJRYAAAAAA4D8////AAAAAAAAAAAwAAAAHQAAAB8AAACRFgAA
    AAADgPz///8AAAAAAAAAAJABAAAdAAAAHwAAAEkaAAAAAAOA/P///wAAAAAAAAAAMAAAAB0AAAAf
    AAAAoRoAAAAAAID8////AAAAAAAAAAAgAAAAHQAAAB8AAADJGgAAAAAAgPz///8AAAAAAAAAACAA
    AAAdAAAAHwAAAPEaAAAAAAMA/P///wAAAAAAAAAACAAAAB0AAAAfAAAASRsAAAAAA4D8////AAAA
    AAAAAABQBAAAHQAAAB8AAACpHQAAAAADgPz///8AAAAAAAAAADAAAAAdAAAAHwAAAEUeAAAAAAOA
    /P///wAAAAAAAAAAEAYAAB0AAAAfAAAAVSQAAAAAA4D8////AAAAAAAAAABABAAAHQAAAB8AAACx
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
    AAAAAQAAAAYAAAAADQAAAA0AAMAbAAAAAAAAAAAAABAAAAAAAAAAZAAAAAEAAAAGAAAAwCgAAMAo
    AABQAwAAAAAAAAAAAAAEAAAAAAAAAHAAAAABAAAABgAAABAsAAAQLAAAUAAAAAAAAAAAAAAABAAA
    AAAAAAB2AAAAAQAAADIAAABgLAAAYCwAACwDAAAAAAAAAAAAAAQAAAABAAAAfgAAAAEAAAACAAAA
    jC8AAIwvAAAEAAAAAAAAAAAAAAAEAAAAAAAAAIgAAAABAAAAAwAAALwvAQC8LwAACAAAAAAAAAAA
    AAAABAAAAAAAAACPAAAAAQAAAAMAAADELwEAxC8AAAgAAAAAAAAAAAAAAAQAAAAAAAAAlgAAAAEA
    AAADAAAAzC8BAMwvAAAEAAAAAAAAAAAAAAAEAAAAAAAAAJsAAAABAAAAAwAAANAvAQDQLwAAMAAA
    AAAAAAAAAAAABAAAAAAAAACoAAAAAQAAAAMAAAAAMAEAADAAABAAAAAAAAAAAAAAABAAAAAAAAAA
    rgAAAAEAAAADAAAQEDABABAwAAAAAQAAAAAAAAAAAAAQAAAABAAAALMAAAABAAAAAwAAEBAxAQAQ
    MQAABAAAAAAAAAAAAAAABAAAAAAAAAC6AAAACAAAAAMAAAAgMQEAFDEAAOACAAAAAAAAAAAAABAA
    AAAAAAAAvwAAAAEAAAAwAAAAAAAAABQxAABLAAAAAAAAAAAAAAABAAAAAQAAAMgAAAABAAAAAAAA
    AAAAAABgMQAAoAIAAAAAAAAAAAAABAAAAAAAAADNAAAA9f//bwAAAAAAAAAAADQAABAAAAAAAAAA
    AAAAAAEAAAAAAAAA3QAAAAEAAAAAAAAAADQBABA0AAAAAAAAAAAAAAAAAAABAAAAAAAAAAEAAAAD
    AAAAAAAAAAAAAAAQNAAA6wAAAAAAAAAAAAAAAQAAAAAAAAA=
    ]])
  end

  if luup.version_major >= 7 then
  	inotify = require("inotify")
  	json = require ("dkjson")

	UpdateFileWithContent("/www/cmh/skins/default/img/devices/device_states/EvolveLCD1_50x50.png", EvolveLCD1Icon, 644 )
	UpdateFileWithContent("/www/cmh/skins/default/img/devices/device_states/CooperRFWC5_50x50.png", CooperRFWC5Icon, 644 )
	UpdateFileWithContent("/www/cmh/skins/default/img/devices/device_states/NexiaOneTouch_50x50.png", NexiaOneTouchIcon, 644 )
  	UpdateFileWithContent("/usr/lib/lua/zwint.so", zwint_so, 755)

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
    UpdateFileWithContent("/www/cmh/skins/default/icons/EvolveLCD1_50x50.png", EvolveLCD1Icon, 644)
    UpdateFileWithContent("/www/cmh/skins/default/icons/CooperRFWC5_50x50.png", CooperRFWC5Icon, 644)
	UpdateFileWithContent("/www/cmh/skins/default/icons/NexiaOneTouch_50x50.png", NexiaOneTouchIcon, 644)
  	UpdateFileWithContent("/usr/lib/lua/zwint.so", zwint_so, 755)
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
]], 644)
	end	-- UI5

	-- Update scene controller devices which may have been included into the Z-Wave network before the installer ran.
	ScanForNewDevices()

	if reload_needed then
		log ("Files updated. Reloading LuaUPnP.")
		luup.call_action(HAG_SID, "Reload", {}, 0)
	else
		verbose("Nothing updated. No need to reload.")
	end
end	-- function SceneControllerInstaller_Init

