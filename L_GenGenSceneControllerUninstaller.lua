-- GenGeneric Scene Controller Uninstaller
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
local VerboseLogging = 0

local nixio = require "nixio"
local HAG_SID                 = "urn:micasaverde-com:serviceId:HomeAutomationGateway1"

local function logList(...)
	local s = ""
	for i = 1, select ("#", ...) do
	  	local x = select(i, ...)
		s = s .. tostring(x)
	end 
	return s
end

local function log(...)
	luup.log("GenGeneric Uninstaller     log: " .. logList(...))
end

local function VLog(...)
  if VerboseLogging > 2 then
	luup.log("GenGeneric Uninstaller verbose: " .. logList(...))
  end
end

local function DeleteFile(base)
	VLog("Deleting ", base)
	nixio.fs.remove(base .. ".modified")
	nixio.fs.remove(base .. ".save")
	nixio.fs.remove(base)
end

local function DeleteFileCarefully(base)
	VLog("Deleting ", base, " carefully")
	local base_modified = base .. ".modified"
	local base_save = base .. ".save"
	local base_uninstalled = base .. ".uninstalled"

	local stat = nixio.fs.stat(base) 
	local stat_save = nixio.fs.stat(base_save)
	local stat_uninstalled = nixio.fs.stat(base_uninstalled)

	if stat then
		if stat then 
			if stat_save then
				if stat_uninstalled then
					nixio.fs.remove(base_save)		
				else
					nixio.fs.rename(base_save, stat_uninstalled)
				end
				nixio.fs.remove(base)		
			else
				if stat_uninstalled then
					nixio.fs.remove(base)		
				else
					nixio.fs.rename(base, stat_uninstalled)
				end
				
			end
		end
		nixio.fs.remove(base_modified)
	end
end

local function RevertFile(base)
	VLog("Reverting ", base)
	local base_modified = base .. ".modified"
	local base_save = base .. ".save"

	local stat = nixio.fs.stat(base) 
	local stat_save = nixio.fs.stat(base_save)
	local stat_modified = nixio.fs.stat(base_modified)

	if stat and stat_save then
		nixio.fs.remove(base)
		nixio.fs.rename(base_save, base)
		if stat_modified then
			nixio.fs.remove(base_modified)
		end
	end
end

function SceneControllerUninstaller_Uninstall(Uninstaller_device_num)
	for device_num, device in pairs(luup.devices) do
		local device_type = device.device_type
		local device_file = luup.attr_get("device_file", device_num)
		if (device_type == "urn:schemas-gengen_mcv-org:device:SceneControllerEvolveLCD:1" and
		    device_file == "D_EvolveLCD1.xml") or
		   (device_type == "urn:schemas-gengen_mcv-org:device:SceneControllerCooperRFWC5:1" and
		    device_file == "D_CooperRFWC5.xml") or
		   (device_type == "urn:schemas-gengen_mcv-org:device:SceneControllerNexiaOneTouch:1" and
		    device_file == "D_NexiaOneTouch.xml") or
		   (device_type == "urn:schemas-gengen_mcv-org:device:SceneControllerInstaller:1" and
		    device_file == "D_GenGenSceneControllerInstaller.xml") then
			if device.device_num_parent == 1 then
				log("Reverting ", device.description, " to a generic scene controller");
				luup.attr_set("device_type", "urn:schemas-micasaverde-com:device:SceneController:1", device_num)
				luup.attr_set("device_file", "D_SceneController1.xml", device_num)
				luup.attr_set("impl_file", "", device_num)
				luup.attr_set("device_json", "D_SceneController1.json", device_num)
				luup.attr_set("invisible", "0", device_num)
			else
				log("Deleting ", device.description);
				luup.call_action(HAG_SID,"DeleteDevice", {DeviceNum = device_num}, 0);
			end
		end
	end
	-- UI7 dropped files
	DeleteFile("/www/cmh/skins/default/img/devices/device_states/EvolveLCD1_50x50.png")
	DeleteFile("/www/cmh/skins/default/img/devices/device_states/CooperRFWC5_50x50.png")
	DeleteFile("/www/cmh/skins/default/img/devices/device_states/NexiaOneTouch_50x50.png")
  	DeleteFile("/usr/lib/lua/zwint.so")
	RevertFile("/www/cmh/kit/KitDevice.json")
	RevertFile("/www/cmh/kit/KitDevice_Variable.json")
	-- UI5 dropped files
    DeleteFile("/www/cmh/skins/default/icons/EvolveLCD1_50x50.png")
    DeleteFile("/www/cmh/skins/default/icons/CooperRFWC5_50x50.png")
	DeleteFile("/www/cmh/skins/default/icons/NexiaOneTouch_50x50.png")
  	DeleteFile("/usr/lib/lua/zwint.so")
	DeleteFileCarefully("/etc/cmh/zwave_products_user.xml")
	-- Installer
	DeleteFile("/etc/cmh-ludl/D_GenGenSceneControllerInstaller.json.lzo")
	DeleteFile("/etc/cmh-ludl/D_GenGenSceneControllerInstaller.xml.lzo")
	DeleteFile("/etc/cmh-ludl/I_GenGenSceneControllerInstaller.xml.lzo")
	DeleteFile("/etc/cmh-ludl/L_GenGenSceneControllerInstaller.lua.lzo")
	DeleteFile("/etc/cmh-ludl/S_GenGenSceneControllerInstaller.xml.lzo")
	DeleteFile("/etc/cmh-ludl/S_GenGenSceneControllerInstaller.xml.lzo")
	-- Core files
	DeleteFile("/etc/cmh-ludl/D_EvolveLCD1.json.lzo")
	DeleteFile("/etc/cmh-ludl/D_EvolveLCD1.xml.lzo")
	DeleteFile("/etc/cmh-ludl/D_CooperRFWC5.json.lzo")
	DeleteFile("/etc/cmh-ludl/D_CooperRFWC5.xml.lzo")
	DeleteFile("/etc/cmh-ludl/D_NexiaOneTouch.json.lzo")
	DeleteFile("/etc/cmh-ludl/D_NexiaOneTouch.xml.lzo")
	DeleteFile("/etc/cmh-ludl/I_GenGenSceneController.xml.lzo")
	DeleteFile("/etc/cmh-ludl/J_GenGenSceneController.js.lzo")
	DeleteFile("/etc/cmh-ludl/L_GenGenSceneController.lua.lzo")
	DeleteFile("/etc/cmh-ludl/L_GenGenSceneControllerShared.lua.lzo")
	DeleteFile("/etc/cmh-ludl/S_GenGenSceneController.xml.lzo")
	DeleteFile("/etc/cmh-ludl/S_GenGenZWaveMonitor.xml.lzo")
    -- Uninstaller
	DeleteFile("/etc/cmh-ludl/D_GenGenSceneControllerUninstaller.json.lzo")
	DeleteFile("/etc/cmh-ludl/D_GenGenSceneControllerUninstaller.xml.lzo")
	DeleteFile("/etc/cmh-ludl/I_GenGenSceneControllerUninstaller.xml.lzo")
	DeleteFile("/etc/cmh-ludl/L_GenGenSceneControllerUninstaller.lua.lzo")
	DeleteFile("/etc/cmh-ludl/S_GenGenSceneControllerUninstaller.xml.lzo")
	luup.call_action(HAG_SID,"DeleteDevice", {DeviceNum = Uninstaller_device_num}, 0);

	log("Uninstallation completed. Reloading");
	luup.call_action(HAG_SID, "Reload", {}, 0)
end

function SceneControllerUninstaller_Init(lul_device)
	local installer_stat = nixio.fs.stat("/etc/cmh-ludl/L_GenGenSceneControllerInstaller.lua.lzo")
	if not installer_stat then
		log("GenGenSceneControllerInstaller not found. Uninstalling all related files.");
		SceneControllerUninstaller_Uninstall(lul_device)
	else
		VLog("Scene Controller core still present. Do nothing.");
	end
end

