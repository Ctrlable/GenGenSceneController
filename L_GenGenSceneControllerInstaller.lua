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
local socket = require "socket"
local inotify -- Not available in UI5 due to kernel config


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
local GENGENINSTALLER_SID     = "urn:gengen_mcv-org:serviceId:SceneControllerInstaller"
local GENGENINSTALLER_DEVTYPE = "urn:schemas-gengen_mcv-org:device:SceneControllerInstaller:1"

local SID_SCENECONTROLLER     = "urn:gengen_mcv-org:serviceId:SceneController"

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

local reload_needed = false

local nixio = require("nixio")
require("nixio.util")

-- Update file with the given content if the previous version does not exist or is shorter.
function UpdateFileWithContent(filename, content, permissions)
	local update = false
	local backup = false
	if not content then
		error("Missing content for "..filename)
		return
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
			local result, errno, errmsg, bytesWritten = f:writeall(content)
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
-- Returns nexio read and write file handles if update is needed.
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

  -- Nixio supplementary library
  -- The nixio library does not allow use of arbitrary numeric FDs for dup
  -- Include a socketpair API
  -- Adds a "seqpacket" option for socket and socketpair
  -- Adds a "disown" API to disown a file descriptor without closing it.
  local nixio2_so = b642bin([[
	f0VMRgEBAQAAAAAAAAAAAAMACAABAAAAoAgAADQAAAD0HQAABxAAcDQAIAAGACgAGQAYAAAAAHD0
	AAAA9AAAAPQAAAAYAAAAGAAAAAQAAAAEAAAAAQAAAAAAAAAAAAAAAAAAAOwaAADsGgAABQAAAAAA
	AQABAAAA7BoAAOwaAQDsGgEA4AAAAAQBAAAGAAAAAAABAAIAAAAMAQAADAEAAAwBAADQAAAA0AAA
	AAcAAAAEAAAAUeV0ZAAAAAAAAAAAAAAAAAAAAAAAAAAABwAAAAQAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAABAAAAAAAALIAAAAAAAAAAAAAAAAAAAAAIJsBAAEAAACkAQAAAQAAALIBAAAM
	AAAAJAgAAA0AAADgGAAABAAAANwBAAAFAAAA6AUAAAYAAAAoAwAACgAAAOwBAAALAAAAEAAAAAMA
	AAAwGwEAEQAAANQHAAASAAAAUAAAABMAAAAIAAAAAQAAcAEAAAAFAABwAgAAAAYAAHAAAAAACgAA
	cAkAAAARAABwLAAAABIAAHAYAAAAEwAAcA8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAAAAAAAAlAAAALAAAABcAAAAQAAAAJQAAAAMAAAAAAAAAAAAAAB8AAAAA
	AAAAHQAAAAAAAAAgAAAAFAAAAAAAAAAAAAAAAAAAAAAAAAAeAAAAEwAAAAsAAAAVAAAADwAAABkA
	AAAAAAAAKQAAAAAAAAAOAAAAKAAAAAIAAAAAAAAAEgAAACIAAAANAAAAEQAAAAcAAAAkAAAADAAA
	AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACYAAAAAAAAAAAAAAAAAAAAjAAAAAAAAAAAAAAAIAAAA
	CQAAAAoAAAAAAAAAFgAAABgAAAAaAAAAGwAAAAAAAAAFAAAABgAAAAAAAAAEAAAAIQAAACcAAAAc
	AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAqAAAAAAAAAAAAAAArAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAJAgAAAAAAAADAAcAwwEAADAbAQAAAAAAEAAR
	AB0AAAAgmwEAAAAAABMA8f/KAQAAIJsBAAAAAAAQAPH/FwAAACQIAAAcAAAAEgAHAJUBAADgGwEA
	EAAAABEAEwC8AQAAoAgAAAAAAAAQAAgA1QEAAMwbAQAAAAAAEADx/3gBAAB0FgAAQAAAABIACAAm
	AAAA4BgAABwAAAASAAoAzgEAAMwbAQAAAAAAEADx/wEAAAAwGwEAAAAAABEA8f/nAQAA8BsBAAAA
	AAAQAPH/4QEAAMwbAQAAAAAAEADx/3wAAADAGAAAAAAAABIAAAA7AAAAAAAAAAAAAAAgAAAAhwEA
	ALAYAAAAAAAAEgAAABMBAACgGAAAAAAAABIAAADlAAAAkBgAAAAAAAASAAAAiQAAAIAYAAAAAAAA
	EgAAAEABAABwGAAAAAAAABIAAADNAAAAYBgAAAAAAAASAAAA8AAAAFAYAAAAAAAAEgAAAGMBAABA
	GAAAAAAAABIAAACyAAAAMBgAAAAAAAASAAAAogAAACAYAAAAAAAAEgAAANQAAAAQGAAAAAAAABIA
	AAD+AAAAABgAAAAAAAASAAAAlwAAAPAXAAAAAAAAEgAAAMIAAADgFwAAAAAAABIAAABqAQAA0BcA
	AAAAAAASAAAADAEAAMAXAAAAAAAAEgAAAEQBAACwFwAAAAAAABIAAAAsAAAAAAAAAAAAAAAiAAAA
	XgAAAKAXAAAAAAAAEgAAACcBAACQFwAAAAAAABIAAABUAQAAgBcAAAAAAAASAAAANQEAAHAXAAAA
	AAAAEgAAAFsBAABgFwAAAAAAABIAAABvAAAAUBcAAAAAAAASAAAASQEAAEAXAAAAAAAAEgAAABoB
	AAAwFwAAAAAAABIAAABPAAAAIBcAAAAAAAASAAAAAF9HTE9CQUxfT0ZGU0VUX1RBQkxFXwBfaW5p
	dABfZ3BfZGlzcABfZmluaQBfX2N4YV9maW5hbGl6ZQBfSnZfUmVnaXN0ZXJDbGFzc2VzAGx1YV90
	b3VzZXJkYXRhAGx1YV9nZXRtZXRhdGFibGUAbHVhX2dldGZpZWxkAGx1YV9yYXdlcXVhbABsdWFM
	X2FyZ2Vycm9yAGx1YV9zZXR0b3AAbHVhTF9vcHRsc3RyaW5nAGx1YV9uZXd1c2VyZGF0YQBsdWFM
	X2Vycm9yAHN0cmNtcABsdWFfc2V0bWV0YXRhYmxlAHNvY2tldHBhaXIAbml4aW9fX3BlcnJvcgBs
	dWFfdG9sc3RyaW5nAHNvY2tldABmaWxlbm8AbHVhX2lzbnVtYmVyAGx1YV90b2ludGVnZXIAbHVh
	X2dldHRvcABkdXAAZHVwMgBsdWFfb2JqbGVuAG1lbWNweQBmY250bDY0AGZkb3BlbgBsdWFfcHVz
	aHZhbHVlAGx1YW9wZW5fbml4aW8yAGx1YUxfcmVnaXN0ZXIAbml4aW9fX2JpbjJoZXgAbGliZ2Nj
	X3Muc28uMQBsaWJjLnNvLjAAX2Z0ZXh0AF9mZGF0YQBfZ3AAX2VkYXRhAF9fYnNzX3N0YXJ0AF9m
	YnNzAF9lbmQAAAAAAAAAAAAAGwEAAwAAAAQbAQADAAAACBsBAAMAAAAMGwEAAwAAABAbAQADAAAA
	FBsBAAMAAAAYGwEAAwAAABwbAQADAAAAyBsBAAMAAAACABw8/JKcJyHgmQPg/70nEAC8rxwAv68Y
	ALyvAQARBAAAAAACABw82JKcJyHgnwMkgJmPXAk5Jz8AEQQAAAAAEAC8jwEAEQQAAAAAAgAcPLCS
	nCch4J8DJICZj8AWOSeOAxEEAAAAABAAvI8cAL+PCADgAyAAvScAAAAAAgAcPICSnCch4JkD0P+9
	JygAs68YgJOPEAC8rywAv6/QG2KSJACyryAAsa8cALCvGwBAFICAgo8FAEAQHICCj4CAmY8J+CAD
	AABEjBAAvI8YgJKPIICRjxiAkI/0GlImI4gyAoOIEQAHAAAQ//8xJtQbAq6AEAIAIRBSAAAAWYwJ
	+CADAAAAANQbAo4rGFEA9/9gFAEAQiQBAAIk0BtioiwAv48oALOPJACyjyAAsY8cALCPCADgAzAA
	vScCABw8xJGcJyHgmQMYgISP/BqCjAYAQBAAAAAAOICZjwMAIBMAAAAACAAgA/wahCQIAOADAAAA
	AAAAAAAAAAAAAAAAAAIAHDyAkZwnIeCZA9j/vSekgJmPEAC8ryAAsa8cALCvAQAFJCQAv68J+CAD
	IYCAACGIQAAQALyPISAAAgQAQBQBAAUkJICGjzoAABAwGcYkhICZjwAAAAAJ+CADAAAAABAAvI8h
	IAACJICGj5iAmY/w2AUkCfggA1AZxiQQALyPISAAAiSAho+YgJmP8NgFJAn4IANgGcYkEAC8jyEg
	AAIkgIaPmICZj/DYBSQJ+CADbBnGJBAAvI8hIAACNICZj/3/BSQJ+CAD/P8GJBAAvI8JAEAU//8C
	JDSAmY8hIAAC/v8FJAn4IAP8/wYkEAC8jwMAQBD//wIkFQAAEAAAIq40gJmPISAAAv//BSQJ+CAD
	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
	DgBAEAAAAAAkgIWPFAAAEJwapSQMAGAQCABCMA0AQBAAAAAAJICFjw0AABCkGqUkJICFjwoAABCg
	GqUkJICFjwcAABCUGqUkJICFjwQAABCQGqUkJICFjwAAAACYGqUkWICZjwAAAAAJ+CADISAgAhAA
	vI8OAAAQAABCriSAho8hIAACLAC/jygAtI8kALOPIACyjxwAsY8YALCPSICZjwEABSR0GcYkCAAg
	AzAAvSdsgJmPISAAAgn4IAP8/wUkEAC8jyEgAAJkgJmPAAAAAAn4IAP+/wUkBQAAEAAAAAB0gJmP
	ISAAAgn4IAMCAAUkLAC/jwEAAiQoALSPJACzjyAAso8cALGPGACwjwgA4AMwAL0nAgAcPKyEnCch
	4JkDJICFjxiAho/g/70nPICZjxAAvK8cAL+vwBqlJAn4IAMAG8YkHAC/jwEAAiQIAOADIAC9JwAA
	AAAAAAAAAAAAAAIAHDxghJwnIeCZA9j/vSccALCvGICQjxAAvK8gALGvJAC/r+waECYDAAAQ//8R
	JAn4IAP8/xAmAAAZjvz/MRckAL+PIACxjxwAsI8IAOADKAC9JwAAAAAAAAAAAAAAABCAmY8heOAD
	CfggAysAGCQQgJmPIXjgAwn4IAMqABgkEICZjyF44AMJ+CADKQAYJBCAmY8heOADCfggAygAGCQQ
	gJmPIXjgAwn4IAMnABgkEICZjyF44AMJ+CADJgAYJBCAmY8heOADCfggAyUAGCQQgJmPIXjgAwn4
	IAMkABgkEICZjyF44AMJ+CADIwAYJBCAmY8heOADCfggAyEAGCQQgJmPIXjgAwn4IAMgABgkEICZ
	jyF44AMJ+CADHwAYJBCAmY8heOADCfggAx4AGCQQgJmPIXjgAwn4IAMdABgkEICZjyF44AMJ+CAD
	HAAYJBCAmY8heOADCfggAxsAGCQQgJmPIXjgAwn4IAMaABgkEICZjyF44AMJ+CADGQAYJBCAmY8h
	eOADCfggAxgAGCQQgJmPIXjgAwn4IAMXABgkEICZjyF44AMJ+CADFgAYJBCAmY8heOADCfggAxUA
	GCQQgJmPIXjgAwn4IAMUABgkEICZjyF44AMJ+CADEwAYJBCAmY8heOADCfggAxIAGCQQgJmPIXjg
	Awn4IAMRABgkEICZjyF44AMJ+CADDwAYJAAAAAAAAAAAAAAAAAAAAAACABw8QIKcJyHgmQPg/70n
	EAC8rxwAv68YALyvAQARBAAAAAACABw8HIKcJyHgnwMkgJmPoAg5J+H7EQQAAAAAEAC8jxwAv48I
	AOADIAC9J05vdCBhIGZpbGUgZGVzY3JpcHRvciBvYmplY3QAAAAAbml4aW8uc29ja2V0AAAAAG5p
	eGlvLmZpbGUAAEZJTEUqAAAAVW5zdXBwb3J0ZWQgZmlsZSBkZXNjcmlwdG9yAG91dCBvZiBtZW1v
	cnkAAABzdHJlYW0AAGRncmFtAAAAc2VxcGFja2V0AAAAc3VwcG9ydGVkIHZhbHVlczogc3RyZWFt
	LCBkZ3JhbSwgc2VxcGFja2V0AABpbmV0AAAAAGluZXQ2AAAAdW5peAAAAABzdXBwb3J0ZWQgdmFs
	dWVzOiBpbmV0LCBpbmV0NiwgdW5peCwgcGFja2V0AHJhdwBzdXBwb3J0ZWQgdmFsdWVzOiBzdHJl
	YW0sIGRncmFtLCByYXcAAAAAaWNtcAAAAABpY21wdjYAAHN1cHBvcnRlZCB2YWx1ZXM6IFtlbXB0
	eV0sIGljbXAsIGljbXB2NgByKwAAdwAAAHcrAABhAAAAcgAAAGErAABpbnZhbGlkIGZpbGUgZGVz
	Y3JpcHRvcgBuaXhpbzIAAGR1cABzb2NrZXQAAHNvY2tldHBhaXIAAGRpc293bgAAAAAAAP////8A
	AAAA/////wAAAAAAAAAAyBoAAGQSAADMGgAAVA0AANQaAAAYCwAA4BoAAKAJAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAIAAAAEAyBsBAPgaAQAAAAAAAAAAAAAAAAAAAAAAwBgAAAAAAACwGAAAoBgA
	AJAYAACAGAAAcBgAAGAYAABQGAAAQBgAADAYAAAgGAAAEBgAAAAYAADwFwAA4BcAANAXAADAFwAA
	sBcAAAAAAACgFwAAkBcAAIAXAABwFwAAYBcAAFAXAABAFwAAMBcAACAXAADIGwEAR0NDOiAoR05V
	KSAzLjMuMgBHQ0M6IChMaW5hcm8gR0NDIDQuNi0yMDEyLjAyKSA0LjYuMyAyMDEyMDIwMSAocHJl
	cmVsZWFzZSkAACQIAAAAAACQ/P///wAAAAAAAAAAIAAAAB0AAAAfAAAA4BgAAAAAAJD8////AAAA
	AAAAAAAgAAAAHQAAAB8AAACgCQAAAAADgPz///8AAAAAAAAAACgAAAAdAAAAHwAAABgLAAAAAB+A
	/P///wAAAAAAAAAAOAAAAB0AAAAfAAAAVA0AAAAAH4D8////AAAAAAAAAAAwAAAAHQAAAB8AAACs
	EAAAAAAHgPz///8AAAAAAAAAACgAAAAdAAAAHwAAAGQSAAAAAB+A/P///wAAAAAAAAAAMAAAAB0A
	AAAfAAAAdBYAAAAAAID8////AAAAAAAAAAAgAAAAHQAAAB8AAABBDwAAAGdudQABBwAAAAQDAC5z
	aHN0cnRhYgAucmVnaW5mbwAuZHluYW1pYwAuaGFzaAAuZHluc3ltAC5keW5zdHIALnJlbC5keW4A
	LmluaXQALnRleHQALk1JUFMuc3R1YnMALmZpbmkALnJvZGF0YQAuZWhfZnJhbWUALmN0b3JzAC5k
	dG9ycwAuamNyAC5kYXRhLnJlbC5ybwAuZ290AC5zZGF0YQAuYnNzAC5jb21tZW50AC5wZHIALmdu
	dS5hdHRyaWJ1dGVzAC5tZGVidWcuYWJpMzIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAsAAAAGAABwAgAAAPQAAAD0AAAAGAAAAAAAAAAAAAAABAAAABgAAAAUAAAA
	BgAAAAIAAAAMAQAADAEAANAAAAAFAAAAAAAAAAQAAAAIAAAAHQAAAAUAAAACAAAA3AEAANwBAABM
	AQAABAAAAAAAAAAEAAAABAAAACMAAAALAAAAAgAAACgDAAAoAwAAwAIAAAUAAAACAAAABAAAABAA
	AAArAAAAAwAAAAIAAADoBQAA6AUAAOwBAAAAAAAAAAAAAAEAAAAAAAAAMwAAAAkAAAACAAAA1AcA
	ANQHAABQAAAABAAAAAAAAAAEAAAACAAAADwAAAABAAAABgAAACQIAAAkCAAAeAAAAAAAAAAAAAAA
	BAAAAAAAAABCAAAAAQAAAAYAAACgCAAAoAgAAIAOAAAAAAAAAAAAABAAAAAAAAAASAAAAAEAAAAG
	AAAAIBcAACAXAADAAQAAAAAAAAAAAAAEAAAAAAAAAFQAAAABAAAABgAAAOAYAADgGAAAUAAAAAAA
	AAAAAAAABAAAAAAAAABaAAAAAQAAADIAAAAwGQAAMBkAALgBAAAAAAAAAAAAAAQAAAABAAAAYgAA
	AAEAAAACAAAA6BoAAOgaAAAEAAAAAAAAAAAAAAAEAAAAAAAAAGwAAAABAAAAAwAAAOwaAQDsGgAA
	CAAAAAAAAAAAAAAABAAAAAAAAABzAAAAAQAAAAMAAAD0GgEA9BoAAAgAAAAAAAAAAAAAAAQAAAAA
	AAAAegAAAAEAAAADAAAA/BoBAPwaAAAEAAAAAAAAAAAAAAAEAAAAAAAAAH8AAAABAAAAAwAAAAAb
	AQAAGwAAKAAAAAAAAAAAAAAABAAAAAAAAACMAAAAAQAAAAMAABAwGwEAMBsAAJgAAAAAAAAAAAAA
	ABAAAAAEAAAAkQAAAAEAAAADAAAQyBsBAMgbAAAEAAAAAAAAAAAAAAAEAAAAAAAAAJgAAAAIAAAA
	AwAAANAbAQDMGwAAIAAAAAAAAAAAAAAAEAAAAAAAAACdAAAAAQAAADAAAAAAAAAAzBsAAEsAAAAA
	AAAAAAAAAAEAAAABAAAApgAAAAEAAAAAAAAAAAAAABgcAAAAAQAAAAAAAAAAAAAEAAAAAAAAAKsA
	AAD1//9vAAAAAAAAAAAYHQAAEAAAAAAAAAAAAAAAAQAAAAAAAAC7AAAAAQAAAAAAAADwGwEAKB0A
	AAAAAAAAAAAAAAAAAAEAAAAAAAAAAQAAAAMAAAAAAAAAAAAAACgdAADJAAAAAAAAAAAAAAABAAAA
	AAAAAA==
]])

  -- Install inotify bindings 0.4-1 from https://github.com/hoelzro/linotify
  local inotify_so = b642bin([[
	f0VMRgEBAQAAAAAAAAAAAAMACAABAAAA8AkAADQAAABYJAAABxAAcDQAIAAGACgAGQAYAAAAAHD0
	AAAA9AAAAPQAAAAYAAAAGAAAAAQAAAAEAAAAAQAAAAAAAAAAAAAAAAAAADggAAA4IAAABQAAAAAA
	AQABAAAAOCAAADggAQA4IAEAIAEAADgBAAAGAAAAAAABAAIAAAAMAQAADAEAAAwBAADQAAAA0AAA
	AAcAAAAEAAAAUeV0ZAAAAAAAAAAAAAAAAAAAAAAAAAAABwAAAAQAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAABAAAAAAAALIAAAAAAAAAAAAAAAAAAAAAkKABAAEAAAA/AgAAAQAAAE0CAAAM
	AAAAeAkAAA0AAAAAHgAABAAAANwBAAAFAAAAYAYAAAYAAABAAwAACgAAAIcCAAALAAAAEAAAAAMA
	AACgIAEAEQAAAOgIAAASAAAAkAAAABMAAAAIAAAAAQAAcAEAAAAFAABwAgAAAAYAAHAAAAAACgAA
	cAkAAAARAABwMgAAABIAAHAYAAAAEwAAcA4AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAAAAAAAAlAAAAMgAAABgAAAASAAAAKQAAAAMAAAAAAAAAAAAAAAgAAAAA
	AAAAGQAAAAAAAAAAAAAALgAAACYAAAAhAAAAKAAAAAAAAAAQAAAAHgAAAAoAAAAFAAAAAAAAABsA
	AAAWAAAAAAAAAA4AAAANAAAAEwAAAAIAAAAAAAAALwAAACsAAAAMAAAAEQAAAAYAAAAXAAAACwAA
	AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACwAAAAAAAAAIwAAABwAAAAAAAAAAAAAAAcAAAAiAAAA
	CQAAAA8AAAAfAAAAJQAAABQAAAAVAAAALQAAABoAAAAAAAAAAAAAADAAAAAAAAAAJAAAACoAAAAd
	AAAAJwAAAAAAAAAgAAAAAAAAADEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAeAkA
	AAAAAAADAAcAXgIAAFAgAQAAAAAAEAAQAB0AAACQoAEAAAAAABMA8f9lAgAAkKABAAAAAAAQAPH/
	FwAAAHgJAAAcAAAAEgAHAFcCAADwCQAAAAAAABAACABwAgAAWCEBAAAAAAAQAPH//wEAAIwVAAD8
	BQAAEgAIACYAAAAAHgAAHAAAABIACgBpAgAAWCEBAAAAAAAQAPH/AQAAAKAgAQAAAAAAEQDx/4IC
	AABwIQEAAAAAABAA8f98AgAAWCEBAAAAAAAQAPH/lQAAAOAdAAAAAAAAEgAAAIUAAADQHQAAAAAA
	ABIAAADtAQAAwB0AAAAAAAASAAAASQEAALQOAAA4AAAAEgAIADsAAAAAAAAAAAAAACAAAAA7AQAA
	sB0AAAAAAAASAAAAIQIAAKAdAAAAAAAAEgAAABYBAACQHQAAAAAAABIAAABcAQAAgB0AAAAAAAAS
	AAAA2wEAAHAdAAAAAAAAEgAAAIsBAABgHQAAAAAAABIAAACyAAAAUB0AAAAAAAASAAAAXwAAAEAd
	AAAAAAAAEgAAAE8AAAAwHQAAAAAAABIAAACdAQAAIB0AAAAAAAASAAAAewEAABAdAAAAAAAAEgAA
	AA8CAAAAHQAAAAAAABIAAADzAQAA8BwAAAAAAAASAAAA4gAAAOAcAAAAAAAAEgAAAK4BAADQHAAA
	AAAAABIAAADzAAAAwBwAAAAAAAASAAAAZgAAALAcAAAAAAAAEgAAADABAACgHAAAAAAAABIAAACA
	AQAAkBwAAAAAAAASAAAACgEAAIAcAAAAAAAAEgAAAHcAAABwHAAAAAAAABIAAAAvAgAAYBwAAAAA
	AAASAAAApQAAAFAcAAAAAAAAEgAAAL4BAABAHAAAAAAAABIAAAAsAAAAAAAAAAAAAAAiAAAA0AEA
	ADAcAAAAAAAAEgAAANUAAAAgHAAAAAAAABIAAAAnAQAAEBwAAAAAAAASAAAAwQAAALAMAAB4AAAA
	EgAIAGwBAAAAHAAAAAAAABIAAAD8AAAA8BsAAAAAAAASAAAAAF9HTE9CQUxfT0ZGU0VUX1RBQkxF
	XwBfaW5pdABfZ3BfZGlzcABfZmluaQBfX2N4YV9maW5hbGl6ZQBfSnZfUmVnaXN0ZXJDbGFzc2Vz
	AGx1YV9uZXd1c2VyZGF0YQBtZW1zZXQAbHVhX3B1c2hjY2xvc3VyZQBsdWFfcHVzaHZhbHVlAGx1
	YV9jcmVhdGV0YWJsZQBsdWFfcHVzaGludGVnZXIAbHVhX3NldGZpZWxkAGx1YV9wdXNoc3RyaW5n
	AHB1c2hfaW5vdGlmeV9oYW5kbGUAbHVhX2dldGZpZWxkAGx1YV9zZXRtZXRhdGFibGUAbHVhX3R5
	cGUAaW5vdGlmeV9pbml0MQBsdWFfcHVzaG5pbABfX2Vycm5vX2xvY2F0aW9uAHN0cmVycm9yAGx1
	YV9zZXR0b3AAbHVhX3RvYm9vbGVhbgBnZXRfaW5vdGlmeV9oYW5kbGUAbHVhTF9jaGVja3VkYXRh
	AGx1YV90b3VzZXJkYXRhAHJlYWQAbHVhTF9lcnJvcgBsdWFMX2NoZWNraW50ZWdlcgBpbm90aWZ5
	X3JtX3dhdGNoAGx1YV9wdXNoYm9vbGVhbgBsdWFMX2NoZWNrbHN0cmluZwBsdWFfZ2V0dG9wAGlu
	b3RpZnlfYWRkX3dhdGNoAGNsb3NlAGx1YV9yYXdzZXRpAGx1YW9wZW5faW5vdGlmeQBsdWFMX25l
	d21ldGF0YWJsZQBsdWFMX3JlZ2lzdGVyAGx1YV9wdXNobHN0cmluZwBsaWJnY2Nfcy5zby4xAGxp
	YmMuc28uMABfZnRleHQAX2ZkYXRhAF9ncABfZWRhdGEAX19ic3Nfc3RhcnQAX2Zic3MAX2VuZAAA
	AAAAAAAAAABQIAEAAwAAAFQgAQADAAAAWCABAAMAAABcIAEAAwAAAGAgAQADAAAAZCABAAMAAABo
	IAEAAwAAAGwgAQADAAAAcCABAAMAAAB0IAEAAwAAAHggAQADAAAAfCABAAMAAACAIAEAAwAAAIQg
	AQADAAAAkCABAAMAAACUIAEAAwAAAFQhAQADAAAAAgAcPBiXnCch4JkD4P+9JxAAvK8cAL+vGAC8
	rwEAEQQAAAAAAgAcPPSWnCch4J8DJICZj6wKOSc+ABEEAAAAABAAvI8BABEEAAAAAAIAHDzMlpwn
	IeCfAySAmY+QGzknbQQRBAAAAAAQALyPHAC/jwgA4AMgAL0nAgAcPKCWnCch4JkD0P+9JygAs68Y
	gJOPEAC8rywAv69gIWKSJACyryAAsa8cALCvGwBAFKiAgo8FAEAQHICCj6iAmY8J+CADAABEjBAA
	vI8YgJKPIICRjxiAkI9AIFImI4gyAoOIEQAHAAAQ//8xJmQhAq6AEAIAIRBSAAAAWYwJ+CADAAAA
	AGQhAo4rGFEA9/9gFAEAQiQBAAIkYCFioiwAv48oALOPJACyjyAAsY8cALCPCADgAzAAvScCABw8
	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
	EICZjyF44AMJ+CADJgAYJBCAmY8heOADCfggAyUAGCQQgJmPIXjgAwn4IAMkABgkEICZjyF44AMJ
	+CADIwAYJBCAmY8heOADCfggAyIAGCQQgJmPIXjgAwn4IAMhABgkEICZjyF44AMJ+CADIAAYJBCA
	mY8heOADCfggAx8AGCQQgJmPIXjgAwn4IAMeABgkEICZjyF44AMJ+CADHQAYJBCAmY8heOADCfgg
	AxwAGCQQgJmPIXjgAwn4IAMbABgkEICZjyF44AMJ+CADGgAYJBCAmY8heOADCfggAxkAGCQQgJmP
	IXjgAwn4IAMYABgkEICZjyF44AMJ+CADFwAYJBCAmY8heOADCfggAxYAGCQQgJmPIXjgAwn4IAMV
	ABgkEICZjyF44AMJ+CADFAAYJBCAmY8heOADCfggAxMAGCQQgJmPIXjgAwn4IAMQABgkEICZjyF4
	4AMJ+CADDwAYJBCAmY8heOADCfggAw4AGCQAAAAAAAAAAAAAAAAAAAAAAgAcPJCCnCch4JkD4P+9
	JxAAvK8cAL+vGAC8rwEAEQQAAAAAAgAcPGyCnCch4J8DJICZj/AJOSft+hEEAAAAABAAvI8cAL+P
	CADgAyAAvSd3ZAAAbWFzawAAAABjb29raWUAAG5hbWUAAAAASU5PVElGWV9IQU5ETEUAAGJsb2Nr
	aW5nAAAAAHJlYWQgZXJyb3I6ICVzCgBfX2luZGV4AF9fZ2MAAAAAaW5vdGlmeV9oYW5kbGUAAF9f
	dHlwZQAASU5fQUNDRVNTAAAASU5fQVRUUklCAAAASU5fQ0xPU0VfV1JJVEUAAElOX0NMT1NFX05P
	V1JJVEUAAAAASU5fQ1JFQVRFAAAASU5fREVMRVRFAAAASU5fREVMRVRFX1NFTEYAAElOX01PRElG
	WQAAAElOX01PVkVfU0VMRgAAAABJTl9NT1ZFRF9GUk9NAAAASU5fTU9WRURfVE8ASU5fT1BFTgBJ
	Tl9BTExfRVZFTlRTAAAASU5fTU9WRQBJTl9DTE9TRQAAAABJTl9ET05UX0ZPTExPVwAASU5fTUFT
	S19BREQASU5fT05FU0hPVAAASU5fT05MWURJUgAASU5fSUdOT1JFRAAASU5fSVNESVIAAAAASU5f
	UV9PVkVSRkxPVwAAAElOX1VOTU9VTlQAAHJlYWQAAAAAY2xvc2UAAABhZGR3YXRjaAAAAABybXdh
	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
  ]])


  if luup.version_major >= 7 then
  	inotify = require("inotify")
  	json = require ("dkjson")

	UpdateFileWithContent("/www/cmh/skins/default/img/devices/device_states/EvolveLCD1_50x50.png", EvolveLCD1Icon, 644 )
	UpdateFileWithContent("/www/cmh/skins/default/img/devices/device_states/CooperRFWC5_50x50.png", CooperRFWC5Icon, 644 )
	UpdateFileWithContent("/www/cmh/skins/default/img/devices/device_states/NexiaOneTouch_50x50.png", NexiaOneTouchIcon, 644 )
  	-- UpdateFileWithContent("/usr/lib/lua/inotify.so", inotify_so, 755)
  	UpdateFileWithContent("/usr/lib/lua/nixio2.so", nixio2_so, 755)

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
	UpdateFileWithContent("/usr/lib/lua/nixio2.so", nixio2_so, 755)
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
		InitZWaveMonitor()
	end
end	-- function SceneControllerInstaller_Init

--
-- Z-Wave monitoring support
--

function InitZWaveMonitor()
	EnableZWaveReceiveLogging()
	SetFlushLogs(false)
	if inotify then
		local e1, e2
		inotify_handle, e1, e2 = inotify.init()
		if not inotify_handle then
		  luup.log("inotify_handle is nil: ".. tostring(e1).." "..torstring(e2))
		end
	end

-- Test code
--[[
42      11/12/16 6:15:45.115    0x1 0x5 0x0 0x13 0x38 0x1 0xd0 (####8##)
           SOF - Start Of Frame ──┘   │   │    │    │   │    │
                     length = 5 ──────┘   │    │    │   │    │
                        Request ──────────┘    │    │   │    │
           FUNC_ID_ZW_SEND_DATA ───────────────┘    │   │    │
                  Callback = 56 ────────────────────┘   │    │
       TRANSMIT_COMPLETE_NO_ACK ────────────────────────┘    │
                    Checksum OK ─────────────────────────────┘
]]
	--SceneControllerInstaller_MonitorZWave(123, 456, "^ZZ0x1 0x%x+ 0x0.+0x1 0x%x+$","NoAck", 10000)

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
	local kill = true
    if flushLogs == nil then
    	kill = false
        if flush then
            flushLogs = 0
        else
            flushLogs = 1
        end
    end
    if flush then
        if flushLogs <= 0 then
            nixio.fs.unlink(CMH_CONF)
            nexio.fs.link(CMH_CONF_FLUSH,CMH_CONF,true) -- Symbolic link. Hard links don't work due to overlayfs bug
            if kill then
            	nixio.kill(nixio.getpid(),nixio.const_sock.SIGUSR2) -- See rotate_logs() in /www/cgi-bin/cmn/log_level.sh
            end
        end
        flushLogs = flushLogs + 1
    else
        if flushLogs > 0 then
            if flushLogs == 1 then
                nixio.fs.unlink(CMH_CONF)
                nixio.fs.link(CMH_CONF_NOFLUSH,CMH_CONF,true)
                if kill then
                	nixio.kill(nixio.getpid(),nixio.const_sock.SIGUSR2)
                end
            end
            flushLogs = flushLogs - 1
        end
    end
end

local logStartPos = -1;
local ZWavepatternState = nil

-- Take a hex string of Z-Wave protocol, clean it up and check it against
-- any patterns
function CheckZWavepatterns(zwave)
	verbose("CheckZWavepatterns: "..zwave)
	local state = 0
	local len = 0
	if ZWavepatternState then
		zwave = ZWavepatternState .. zwave
		ZWavepatternState = nil
	end
	for x in string.gmatch(zwave,"0x%x+") do
		if state == 0 then
			if x == "0x1" then -- Start of frame
				state = 1
			elseif x == "0x6" then -- Remove leading Ack
				zwave = string.sub(zwave, 5)
			else
				verbose("Discarding bad Z-Wave string: "..zwave)
				return
			end
		elseif state == 1 then
			len = tonumber(x)
			state = 2
		else
			state = state + 1
		end
	end
	if state > 1 and state < len + 2 then
		verbose("Z-Wave string too short. Will concatenate next string: ".. zwave)
		ZWavepatternState = zwave
		return
	end
	for i = #MonitorList, 1, -1 do
		local c = string.match(zwave, MonitorList[i].pattern)
		if c then
			verbose("Matched a Z-Wave entry: "..c)
  			luup.call_action(SID_SCENECONTROLLER, "ZWaveMonitorResponse",
  				{ response=c, context=MonitorList[i].context },
  				MonitorList[i].responseDevice)
			table.remove(MonitorList, i)
		end
	end
end

-- Examine the next chunk of LuaUPnP.log to look for Z-Wave responses.
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
        --log("found Z-Wave response: '" .. tostring(zwave) .. "'")
        CheckZWavepatterns(zwave)
    end
end

timesChecked = 0
-- Check to see if any of the monitoring jobs has timed-out. and delete if so.
function CheckMonitorTimeouts()
	timesChecked = timesChecked + 1
	local t = socket.gettime()
	if #MonitorList == 0 then
		return false
	end
	if MonitorList[1].timeout > t then
		return true
	end
	while #MonitorList > 0 do
		verbose("DoTimeout: passed by ".. (t - MonitorList[1].timeout) .. " seconds. pattern="..MonitorList[1].pattern.." timesChecked="..tostring(timesChecked))
		luup.call_action(SID_SCENECONTROLLER, "ZWaveMonitorResponse",
			{ context=MonitorList[1].context },
			MonitorList[1].responseDevice)
		table.remove(MonitorList, 1)
	end
	return false
end

-- This is the Z-Wave poll loop. In UI7, we use inotify to trigger only when
-- LuaUPnP.log has changed. For UI5, we nust use a delay wait.
function DoZWavePoll(data)
	if inotify_handle then
	    local events = inotify_handle:read()

	    for n, ev in ipairs(events) do
	        if bit.band(ev.mask, inotify.IN_MODIFY) ~= 0 then
	            LuaUPnPLogModified()
	        else
	            log("TODO: Special inotify: ".. tostring(ev.mask))
	        end
	    end
	else
		luup.sleep(100)
		LuaUPnPLogModified()
	end

    if zwave_monitoring and CheckMonitorTimeouts() then
        luup.call_delay("DoZWavePoll", 0, "", true)
    else
        MonitorList = {}
        zwave_monitoring = false
        SetFlushLogs(false);
        if inotify_handle then
        	inotify_handle:rmwatch(inotify_wd)
        end
    end
end

zwave_monitoring = false
MonitorList = {}

-- This is called from any of the scene controller devices to schedule a
-- one-shot Z-Wave monitor.
function SceneControllerInstaller_MonitorZWave(device,responseDevice,pattern,context,timeout)
	verbose("SceneControllerInstaller_MonitorZWave: device="..tostring(device)..
		                                          " responseDevice="..tostring(responseDevice)..
		                                          " pattern="..tostring(pattern)..
		                                          " context="..tostring(context)..
		                                          " timeout="..tostring(timeout))
	local entry = {
		responseDevice = responseDevice,
		pattern = pattern,
		context = context,
		timeout = socket.gettime() + timeout / 1000
	}
	table.insert(MonitorList, entry)
	table.sort(MonitorList, function(a, b) return a.timeout < b.timeout; end)
	if #MonitorList == 1 then
		SetFlushLogs(true)
		zwave_monitoring = true
		logStartPos = -1
		if inotify_handle then
			-- Watch for new files and renames
			inotify_wd = inotify_handle:addwatch('/var/log/cmh/LuaUPnP.log', bit.band(inotify.IN_ALL_EVENTS, bit.bnot(
			        bit.bor(inotify.IN_ACCESS,inotify.IN_OPEN,inotify.IN_CLOSE))))
			verbose("using inotify. wd="..tostring(inotify_wd))
		end
		luup.call_delay("DoZWavePoll", 0, "", true)
	end
end

