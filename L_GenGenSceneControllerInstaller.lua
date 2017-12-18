-- Installer for GenGeneric Scene Controller Version 0.99
--
-- Includes installation files for
--   Evolve LCD1
--   Cooper RFWC5
--   Nexia One Touch NX1000
-- This installs zwave_products_user.xml for UI5 and modifies KitDevice.json for UI7.
-- It also installs the custom icon in the appropriate places for UI5 or UI7
-- This software is distributed under the terms of the GNU General Public License 2.0
-- http://www.gnu.org/licenses/gpl-2.0.html
local bit = require 'bit'
local nixio = require "nixio"
local nixio2 = require "nixio2"
local socket = require "socket"
local inotify -- Not available in UI5 due to kernel config

local UseNewZWaveInterceptor = true
local UseOldZWaveInterceptor = false
local VerboseLogging = true
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

-- Update file with the given content if the previous version does not exist or is shorter.
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
			log("Baxcking up shorter " .. filename .. " to " .. backupName .. " and replacing with new version.")
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
		local read_file, errno, errmsg = nixio.open(base_save, "r")
		if not read_file then
			error("could not open " .. base_save .. " for reading: " .. errmsg)
		    nixio.fs.rename(base_save, base)
			nixio.fs.rename(base_old, base_modified)
			return nil
		end
		local write_file, errno, errmsg = nixio.open(base_modified, "w", 644)
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
		local str = read_file:readall()
		read_file:close()
		local obj=json.decode(str);
		update_func(obj)
		local state = { indent = true }
		local str2 = json.encode (obj, state)
		write_file:writeall(str2)
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
		elseif device.device_type == "urn:schemas-gengen_mcv-org:device:SceneControllerEvolveLCD:1" and
			   luup.attr_get("impl_file", device_num)  == "I_EvolveLCD1.xml" then
			  reload_needed = true
			  log("Updating the implementation file of the existing Evolve LCD1 peer device: "..tostring(device_num))
			  luup.attr_set("impl_file", "I_GenGenSceneController.xml", device_num);
		elseif device.device_type == "urn:schemas-gengen_mcv-org:device:SceneControllerCooperRFWC5:1" and
			   luup.attr_get("impl_file", device_num) == "I_CooperRFWC5.xml" then
			  reload_needed = true
			  log("Updating the implementation file of the existing Cooper RFWC5 peer device: "..tostring(device_num))
			  luup.attr_set("impl_file", "I_GenGenSceneController.xml", device_num);
		end
	end	-- for device_num
end

-- Return whether this is the latest version of the installer and if there
-- is more than one installer device of the same version, whether or not
-- this is the lowest device number
function IsFirstAndLatestInstallerVersion(our_dev_num, our_version)
	local version = 0;
	local count = 0;
	local our index = 0;
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

  -- Install Z-Wave interceptor (zwint)	version 1.0 non-debug
  local zwint_so = b642bin([[
	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
	yAAAAOAlAAAAAAAAEgAAAGABAADQJQAAAAAAABIAAACwAAAAwCUAAAAAAAASAAAAkQEAALAlAAAA
	AAAAEgAAAJYAAACgJQAAAAAAABIAAACwAQAAkCUAAAAAAAASAAAAigEAAIAlAAAAAAAAEgAAAGEA
	AABwJQAAAAAAABIAAAAAX0dMT0JBTF9PRkZTRVRfVEFCTEVfAF9ncF9kaXNwAF9maW5pAF9fY3hh
	X2ZpbmFsaXplAF9Kdl9SZWdpc3RlckNsYXNzZXMAcmVnZnJlZQBsdWFfcHVzaGludGVnZXIAY2xv
	Y2tfZ2V0dGltZQBzdGRlcnIAZnByaW50ZgBzb2NrZXQAX19lcnJub19sb2NhdGlvbgBjb25uZWN0
	AGNsb3NlAGx1YV9wdXNobmlsAHN0cmVycm9yAGx1YV9wdXNoc3RyaW5nAGx1YV9nZXR0b3AAbHVh
	X3R5cGUAbHVhX2lzaW50ZWdlcgBsdWFMX2FyZ2Vycm9yAGx1YV90b2ludGVnZXIAcHRocmVhZF9t
	dXRleF9sb2NrAHB0aHJlYWRfbXV0ZXhfdW5sb2NrAGR1cDIAbHVhX3B1c2hib29sZWFuAGx1YV90
	b2xzdHJpbmcAc3RyY21wAG9wZW5kaXIAc25wcmludGYAcmVhZGxpbmsAc3RydG9sAHJlYWRkaXIA
	Y2xvc2VkaXIAc3RyY3B5AHB0aHJlYWRfY3JlYXRlAHNvY2tldHBhaXIAb3BlbgBsdWFfaXNudW1i
	ZXIAbHVhX3RvYm9vbGVhbgBzdHJsZW4AbWFsbG9jAHJlZ2NvbXAAcmVnZXJyb3IAd3JpdGUAcmVh
	ZAByZWdleGVjAHBvbGwAbHVhb3Blbl96d2ludABwdGhyZWFkX211dGV4X2luaXQAbHVhTF9yZWdp
	c3RlcgBsdWFfcHVzaG51bWJlcgBsdWFfc2V0ZmllbGQAbGliZ2NjX3Muc28uMQBsaWJwdGhyZWFk
	LnNvLjAAbGliYy5zby4wAF9mdGV4dABfZmRhdGEAX2dwAF9lZGF0YQBfX2Jzc19zdGFydABfZmJz
	cwBfZW5kAAAAAAAAAAAAAAAAyC8BAAMAAADMLwEAAwAAANAvAQADAAAA1C8BAAMAAADYLwEAAwAA
	ANwvAQADAAAA4C8BAAMAAADkLwEAAwAAAOgvAQADAAAA7C8BAAMAAADwLwEAAwAAAPQvAQADAAAA
	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
	lJow8ESZoZsAboPzFUqG8gRPQOo6ZQaWnmUOEDDwRJndZzDwhJmzjiH1AUoF9ABMQOo6ZQaWnmV9
	Z1uL//YBIgFrbOoqIgNnARAAaNxnEPDYnpDwWJkOBQbwgJ7g8wduQOo6ZQaWnmUVKt/2CiBcZxDw
	WJoG8ICaMPBcmUDqOmUGlgFqS+qeZXxnEPB4mwbwQNu3FgFS2WC0FjDwRJndZzDwhJmzjiH1AUoF
	9AhMQOo6ZQaWnmWlFgDwAmqx8wQLAPRAMmnimmX2ZBxnEPB4mATSJGcG8VCbGipQ8FyYEPCYmAbT
	AG0G8RRMQOo6ZQSWBpOeZQkiMPAEmJFnomch9hlIQOg4ZScQAWoG8VDbUPBImDDwpJgQ8NiYOmUF
	9BBNxfcITkDqkWcEltDwSJgOt55lDLY6ZUDqkWcElgJtkWeeZTDwxJjQ8ACYq+0F9BhOQOg4ZQFq
	dmSg6ABlAGUAZQAAAAAAAPA/AGUAZQBlAGUCABw88IqcJyHgmQPY/70nHACwrxiAkI8QALyvIACx
	ryQAv6+0LxAmAwAAEP//ESQJ+CAD/P8QJgAAGY78/zEXJAC/jyAAsY8cALCPCADgAygAvScAAAAA
	AAAAAAAAAAAQgJmPIXjgAwn4IAM/ABgkEICZjyF44AMJ+CADPgAYJBCAmY8heOADCfggAz0AGCQQ
	gJmPIXjgAwn4IAM8ABgkEICZjyF44AMJ+CADOwAYJBCAmY8heOADCfggAzoAGCQQgJmPIXjgAwn4
	IAM5ABgkEICZjyF44AMJ+CADOAAYJBCAmY8heOADCfggAzcAGCQQgJmPIXjgAwn4IAM2ABgkEICZ
	jyF44AMJ+CADNAAYJBCAmY8heOADCfggAzMAGCQQgJmPIXjgAwn4IAMyABgkEICZjyF44AMJ+CAD
	MQAYJBCAmY8heOADCfggAzAAGCQQgJmPIXjgAwn4IAMvABgkEICZjyF44AMJ+CADLgAYJBCAmY8h
	eOADCfggAy0AGCQQgJmPIXjgAwn4IAMsABgkEICZjyF44AMJ+CADKwAYJBCAmY8heOADCfggAyoA
	GCQQgJmPIXjgAwn4IAMpABgkEICZjyF44AMJ+CADKAAYJBCAmY8heOADCfggAycAGCQQgJmPIXjg
	Awn4IAMmABgkEICZjyF44AMJ+CADJQAYJBCAmY8heOADCfggAyQAGCQQgJmPIXjgAwn4IAMjABgk
	EICZjyF44AMJ+CADIgAYJBCAmY8heOADCfggAyEAGCQQgJmPIXjgAwn4IAMgABgkEICZjyF44AMJ
	+CADHwAYJBCAmY8heOADCfggAx4AGCQQgJmPIXjgAwn4IAMdABgkEICZjyF44AMJ+CADGwAYJBCA
	mY8heOADCfggAxoAGCQQgJmPIXjgAwn4IAMZABgkEICZjyF44AMJ+CADGAAYJBCAmY8heOADCfgg
	AxcAGCQQgJmPIXjgAwn4IAMWABgkEICZjyF44AMJ+CADFQAYJBCAmY8heOADCfggAxQAGCQQgJmP
	IXjgAwn4IAMTABgkEICZjyF44AMJ+CADEgAYJBCAmY8heOADCfggAxAAGCQQgJmPIXjgAwn4IAMP
	ABgkEICZjyF44AMJ+CADDgAYJAAAAAAAAAAAAAAAAAAAAAACABw8kIecJyHgmQPg/70nEAC8rxwA
	v68YALyvAQARBAAAAAACABw8bIecJyHgnwMkgJmPMAs5J6H4EQQAAAAAEAC8jxwAv48IAOADIAC9
	J3p3aW50IHRocmVhZCBlcnJvcjogJXMgJWQKAAByZXBvcGVuX2h0dHBfZmQAQ2Fubm90IGNvbm5l
	Y3QgdG8gc2VydmVyAAAAAERldmljZSBudW1iZXIgbm90IGFuIGludGVnZXIAAAAATm90IHJlZ2lz
	dGVyZWQAAEJhZCBkZXZpY2VfcGF0aABEZXZpY2VfcGF0aCBkb2VzIG5vdCBtYXRjaCBhbHJlYWR5
	IHJlZ2lzdGVyZWQgbmFtZQAAL3Byb2Mvc2VsZi9mZC8AACVzJXMAAAAARGV2aWNlX3BhdGggbm90
	IGZvdW5kIGluIG9wZW4gZmlsZSBsaXN0AERldmljZV9udW0gbm90IGEgbnVtYmVyAEtleSBub3Qg
	YSBzdHJpbmcAAAAAUGF0dGVybiBub3QgYSBzdHJpbmcAAAAAdGltZW91dCBub3QgYSBudW1iZXIA
	AAAAUmVzcG9uc2Ugbm90IGEgc3RyaW5nAAAAR0VUIC9kYXRhX3JlcXVlc3Q/aWQ9YWN0aW9uJkRl
	dmljZU51bT0lZCZzZXJ2aWNlSWQ9dXJuOmdlbmdlbl9tY3Ytb3JnOnNlcnZpY2VJZDpaV2F2ZU1v
	bml0b3ImYWN0aW9uPSVzJmtleT0lcwAAACZDJWQ9AAAAJkVycm9yTWVzc2FnZT0AACBIVFRQLzEu
	MQ0KSG9zdDogMTI3LjAuMC4xDQpDb25uZWN0aW9uOiBrZWVwLWFsaXZlDQoNCgAARXJyb3IAAABS
	ZXNwb25zZSB0b28gbG9uZwAAAEludGVyY2VwdAAAAE1vbml0b3IASW50ZXJjZXB0IHdyaXRlIHBh
	cnQgMgAAMDEyMzQ1Njc4OUFCQ0RFRgAAAABTeW50YXggZXJyb3IgaW4gcmVzcG9uc2UAAAAATW9y
	ZSByZXBsYWNlbWVudHMgdGhhbiBtYXRjaGVzAABSZXNwb25zZSB0b28gc2hvcnQgZm9yIGNoZWNr
	c3VtAEludGVyY2VwdCB3cml0ZQBQYXNzdGhyb3VnaCB3cml0ZQAAAEJhZCBjaGVja3VtIHdyaXRl
	AAAAVGFpbCB3cml0ZQAAVGltZW91dABpbnRlcmNlcHQAAABtb25pdG9yAG91dHB1dAAAendpbnQA
	AAB2ZXJzaW9uAGluc3RhbmNlAAAAAHJlZ2lzdGVyAAAAAHVucmVnaXN0ZXIAAGNhbmNlbAAAAAAA
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
	AAAAAAAAAAAAAAAAAAD/////AAAAAP////8AAAAAAAAAACAsAAClDAAALCwAAEUQAAA4LAAAkQ4A
	AAAsAADBGAAA9CsAAJkYAABELAAAjRMAAAAAAAAAAAAA/////wAAAAAAAAAAAAAAAAAAAAAAAACA
	AAABAPwwAQDALwEAAAAAAAAAAAAAAAAAAAAAAFAoAABAKAAAMCgAAAAAAAAgKAAAECgAAAAoAADw
	JwAA4CcAANAnAADAJwAAsCcAAKAnAACQJwAAAAAAAIAnAABwJwAAYCcAAFAnAABAJwAAMCcAACAn
	AAAQJwAAACcAAPAmAADgJgAA0CYAAMAmAACwJgAAoCYAAJAmAACAJgAAcCYAAGAmAABQJgAAQCYA
	ADAmAAAgJgAAECYAAAAAAAAAJgAA8CUAAOAlAADQJQAAwCUAALAlAACgJQAAkCUAAIAlAABwJQAA
	/DABAEdDQzogKEdOVSkgMy4zLjIAR0NDOiAoTGluYXJvIEdDQyA0LjYtMjAxMi4wMikgNC42LjMg
	MjAxMjAyMDEgKHByZXJlbGVhc2UpAAC4CgAAAAAAkPz///8AAAAAAAAAACAAAAAdAAAAHwAAAHAo
	AAAAAACQ/P///wAAAAAAAAAAIAAAAB0AAAAfAAAAMQwAAAAAA4D8////AAAAAAAAAAAoAAAAHQAA
	AB8AAAClDAAAAAAAgPz///8AAAAAAAAAACAAAAAdAAAAHwAAANkMAAAAAACA/P///wAAAAAAAAAA
	KAAAAB0AAAAfAAAAIQ0AAAAAAID8////AAAAAAAAAAAgAAAAHQAAAB8AAABVDQAAAAADgPz///8A
	AAAAAAAAADgAAAAdAAAAHwAAADkOAAAAAAOA/P///wAAAAAAAAAAKAAAAB0AAAAfAAAAkQ4AAAAA
	A4D8////AAAAAAAAAAA4AAAAHQAAAB8AAABFEAAAAAADgPz///8AAAAAAAAAAFACAAAdAAAAHwAA
	AI0TAAAAAAOA/P///wAAAAAAAAAAQAAAAB0AAAAfAAAAiRQAAAAAA4D8////AAAAAAAAAACQAQAA
	HQAAAB8AAABBGAAAAAADgPz///8AAAAAAAAAADAAAAAdAAAAHwAAAJkYAAAAAACA/P///wAAAAAA
	AAAAIAAAAB0AAAAfAAAAwRgAAAAAAID8////AAAAAAAAAAAgAAAAHQAAAB8AAADpGAAAAAADAPz/
	//8AAAAAAAAAAAgAAAAdAAAAHwAAAEEZAAAAAAOA/P///wAAAAAAAAAAMAQAAB0AAAAfAAAA1RoA
	AAAAAID8////AAAAAAAAAAAoAAAAHQAAAB8AAAANGwAAAAABgPz///8AAAAAAAAAACAAAAAdAAAA
	HwAAAJUbAAAAAAOA/P///wAAAAAAAAAAEAYAAB0AAAAfAAAAdSEAAAAAA4D8////AAAAAAAAAABA
	BAAAHQAAAB8AAABZJAAAAAADgPz///8AAAAAAAAAADAAAAAdAAAAHwAAAEEPAAAAZ251AAEHAAAA
	BAMALnNoc3RydGFiAC5yZWdpbmZvAC5keW5hbWljAC5oYXNoAC5keW5zeW0ALmR5bnN0cgAucmVs
	LmR5bgAuaW5pdAAudGV4dAAuTUlQUy5zdHVicwAuZmluaQAucm9kYXRhAC5laF9mcmFtZQAuY3Rv
	cnMALmR0b3JzAC5qY3IALmRhdGEucmVsLnJvAC5kYXRhAC5nb3QALnNkYXRhAC5ic3MALmNvbW1l
	bnQALnBkcgAuZ251LmF0dHJpYnV0ZXMALm1kZWJ1Zy5hYmkzMgAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAsAAAAGAABwAgAAABQBAAAUAQAAGAAAAAAAAAAAAAAABAAA
	ABgAAAAUAAAABgAAAAIAAAAsAQAALAEAANgAAAAFAAAAAAAAAAQAAAAIAAAAHQAAAAUAAAACAAAA
	BAIAAAQCAACcAQAABAAAAAAAAAAEAAAABAAAACMAAAALAAAAAgAAAKADAACgAwAAAAQAAAUAAAAC
	AAAABAAAABAAAAArAAAAAwAAAAIAAACgBwAAoAcAAKUCAAAAAAAAAAAAAAEAAAAAAAAAMwAAAAkA
	AAACAAAASAoAAEgKAABwAAAABAAAAAAAAAAEAAAACAAAADwAAAABAAAABgAAALgKAAC4CgAAeAAA
	AAAAAAAAAAAABAAAAAAAAABCAAAAAQAAAAYAAAAwCwAAMAsAAEAaAAAAAAAAAAAAABAAAAAAAAAA
	SAAAAAEAAAAGAAAAcCUAAHAlAAAAAwAAAAAAAAAAAAAEAAAAAAAAAFQAAAABAAAABgAAAHAoAABw
	KAAAUAAAAAAAAAAAAAAABAAAAAAAAABaAAAAAQAAADIAAADAKAAAwCgAAIwDAAAAAAAAAAAAAAQA
	AAABAAAAYgAAAAEAAAACAAAATCwAAEwsAAAEAAAAAAAAAAAAAAAEAAAAAAAAAGwAAAABAAAAAwAA
	ALQvAQC0LwAACAAAAAAAAAAAAAAABAAAAAAAAABzAAAAAQAAAAMAAAC8LwEAvC8AAAgAAAAAAAAA
	AAAAAAQAAAAAAAAAegAAAAEAAAADAAAAxC8BAMQvAAAEAAAAAAAAAAAAAAAEAAAAAAAAAH8AAAAB
	AAAAAwAAAMgvAQDILwAAOAAAAAAAAAAAAAAABAAAAAAAAACMAAAAAQAAAAMAAAAAMAEAADAAABAA
	AAAAAAAAAAAAABAAAAAAAAAAkgAAAAEAAAADAAAQEDABABAwAADsAAAAAAAAAAAAAAAQAAAABAAA
	AJcAAAABAAAAAwAAEPwwAQD8MAAABAAAAAAAAAAAAAAABAAAAAAAAACeAAAACAAAAAMAAAAAMQEA
	ADEAALACAAAAAAAAAAAAABAAAAAAAAAAowAAAAEAAAAwAAAAAAAAAAAxAABLAAAAAAAAAAAAAAAB
	AAAAAQAAAKwAAAABAAAAAAAAAAAAAABMMQAAwAIAAAAAAAAAAAAABAAAAAAAAACxAAAA9f//bwAA
	AAAAAAAADDQAABAAAAAAAAAAAAAAAAEAAAAAAAAAwQAAAAEAAAAAAAAAsDMBABw0AAAAAAAAAAAA
	AAAAAAABAAAAAAAAAAEAAAADAAAAAAAAAAAAAAAcNAAAzwAAAAAAAAAAAAAAAQAAAAAAAAA=
  ]])

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

