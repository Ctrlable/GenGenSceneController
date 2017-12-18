-- GenGeneric Scene Controller Version 1.12
-- Copyright 2016-2017 Gustavo A Fernandez. All Rights Reserved
-- Supports Evolve LCD1, Cooper RFWC5 and Nexia One Touch Controller

-- VerboseLogging == 0: important logs and errors:    ELog, log
-- VerboseLogging == 1: Includes debug logs:          ELog, log, DLog, DEntry
-- VerboseLogging == 3:	Includes verbose logs:        ELog, log, DLog, DEntry, VLog, VEntry
VerboseLogging = 0

posix = require "posix"
socket = require "socket"
zwint = require "zwint"
require "L_GenGenSceneControllerShared"

DEVTYPE_EVOLVELCD1    = "urn:schemas-gengen_mcv-org:device:SceneControllerEvolveLCD:1"
DEVTYPE_COOPEREFWC5   = "urn:schemas-gengen_mcv-org:device:SceneControllerCooperRFWC5:1"
DEVTYPE_NEXIAONETOUCH = "urn:schemas-gengen_mcv-org:device:SceneControllerNexiaOneTouch:1"

local SCObj

Devices = {
	-- Evolve LCD1-specific
	[DEVTYPE_EVOLVELCD1] = {
		Name                    = "Evolve LCD1",
		HasScreen               = true,
		HasMultipleScreens      = true,
		HasPresetLanguages      = true,
		HasThremostatControl    = true,
		HasBattery				= false,
	    NumButtons              = 5,
	    LastFixedSceneId        = 10,
		MaxDirectAssociations   = 30,
		HasOffScenes            = true,
		HasIndicator			= true,
		HasButtonModes			= true,
		HasCooperConfiguration  = false,
		HasCentralScene         = false,
		DefaultScreen           = "C1",
		DefaultModeString       = "M",
		DevType                 = DEVTYPE_EVOLVELCD1,
		DeviceXml               = "D_EvolveLCD1.xml",
		OldServiceId            = "urn:gengen_mcv-org:serviceId:EvolveLCD1",
		OldParamPrefix          = "LCD",
		ScreenList              = {C=9,T=9,P=41},
		NumTemperatureScreens   = 3, -- Preset Pages 8, 16, and 40
		-- The "Large" font is actually narrower than the small font and can thus fit more characters per line.
		-- However two lines of the small font can fit in one line of the large font.
	    LargeFontWidths         = {
									3,5,7,9,9,15,11,4,6,7,8,9,4,6,4,8,
									9,9,10,9,9,9,9,9,9,9,4,4,9,8,9,7,
									11,9,9,9,9,8,8,10,10,6,6,9,9,11,10,11,
									9,11,10,9,9,10,9,14,9,10,8,6,8,6,10,11,
									6,8,8,8,8,8,6,8,8,4,5,8,4,12,8,8,
									8,8,7,7,6,8,8,12,8,8,7,8,5,9,10,11},
	    SmallFontWidths         = {
									3,4,7,11,10,16,13,3,7,7,9,11,5,6,4,10,
									10,9,10,10,11,10,10,10,10,10,5,6,11,11,11,9,
									13,11,11,11,11,10,9,11,11,8,8,11,11,13,12,12,
									10,12,12,10,10,11,11,16,11,11,10,7,9,6,10,11,
									7,9,10,9,10,9,7,10,10,4,6,9,4,14,10,10,
									10,10,8,8,7,10,9,14,9,9,8,10,6,10,12,13},
		ScreenWidth 		    = 65,
		RightJustifyScreenWidth = 67,
		SetTuningParameters = function(zwave_dev_num, peer_dev_num)
		    VEntry()
			local versionString
			local retry = 0
			while retry < 10 do
				versionString = luup.variable_get(SID_ZWDEVICE, "VersionInfo", zwave_dev_num)
				if 	versionString == nil then
				    log("waiting for VersionInfo for device #", zwave_dev_num, ": ", luup.devices[zwave_dev_num].description)
					luup.sleep(1000)
					retry = retry + 1;
				else
					break
				end
			end
			if not versionString then
				versionString = "1,3,20,0,39";
				log("Could not get versionInfo. Defaulting to ", versionString);
			end
			-- "VersionInfo" returns a string sunch as "1,3,20,0,37" which corresponds to firmware rev 0.37
			local version = tonumber(versionString:match("%d+,%d+,%d+,%d+,(%d+)"))
			if version == nil then
			    version = 39
			end
			if version >= 39 then
				-- This works OK for firmware version 00.00.39
				GetTuningParameter("BaseDelay"     		, 300 , zwave_dev_num)
				GetTuningParameter("ClearDelay"    		, 700 , zwave_dev_num)
				GetTuningParameter("ScrollDelay"    	, 1000 , zwave_dev_num)
				GetTuningParameter("LineDelay"     		, 35  , zwave_dev_num)
				GetTuningParameter("CharDelay"     		, 8   , zwave_dev_num)
				GetTuningParameter("ResponseDelay" 		, 30  , zwave_dev_num)
				GetTuningParameter("BackoffDelay"  		, 50  , zwave_dev_num)
				GetTuningParameter("MaxParts"      		, 2   , zwave_dev_num)
				GetTuningParameter("UseClearScreen"		, 1   , zwave_dev_num)
				GetTuningParameter("Retries"       		, 0   , zwave_dev_num)
			elseif version >= 37 then
				-- This works OK for firmware version 00.00.37
				GetTuningParameter("BaseDelay"     		, 100 , zwave_dev_num)
				GetTuningParameter("ClearDelay"    		, 700 , zwave_dev_num)
				GetTuningParameter("ScrollDelay"    	, 1000 , zwave_dev_num)
				GetTuningParameter("LineDelay"     		, 100 , zwave_dev_num)
				GetTuningParameter("CharDelay"     		, 10  , zwave_dev_num)
				GetTuningParameter("ResponseDelay" 		, 30  , zwave_dev_num)
				GetTuningParameter("BackoffDelay"  		, 50  , zwave_dev_num)
				GetTuningParameter("MaxParts"      		, 2   , zwave_dev_num)
				GetTuningParameter("UseClearScreen"		, 1   , zwave_dev_num)
				GetTuningParameter("Retries"       		, 10  , zwave_dev_num)
			else
				-- From Sig's feedback on forum.micasaverde.com
				-- for version 00.00.31
				-- "I tried a bunch of different settings - none of them, including these, really resulted
				--  in perfectly stable operation - the device still reboots almost every time I do a screen
				--  change.  But as I mentioned in my prior note, the controllers are now set to how I use
				--  them, and I'm not re-drawing screens during normal operation, so they're working just fine."
				GetTuningParameter("BaseDelay"     		, 3000, zwave_dev_num)
				GetTuningParameter("ClearDelay"    		, 5   , zwave_dev_num)
				GetTuningParameter("ScrollDelay"    	, 1000 , zwave_dev_num)
				GetTuningParameter("LineDelay"     		, 5   , zwave_dev_num)
				GetTuningParameter("CharDelay"     		, 5   , zwave_dev_num)
				GetTuningParameter("ResponseDelay" 		, 30  , zwave_dev_num)
				GetTuningParameter("BackoffDelay"  		, 50  , zwave_dev_num)
				GetTuningParameter("MaxParts"      		, 1   , zwave_dev_num)
				GetTuningParameter("UseClearScreen"		, 0   , zwave_dev_num)
				GetTuningParameter("Retries"       		, 10  , zwave_dev_num)
			end
			GetTuningParameter("SwitchScreenDelay"	    , 50  , zwave_dev_num)
			GetTuningParameter("InitStaggerSeconds"	    , 15  , zwave_dev_num)
			GetTuningParameter("MinReinitSeconds"	    , 60 * 60 * 24  , zwave_dev_num)
			GetTuningParameter("ReturnRouteDelay"		, 500 , zwave_dev_num)
			GetTuningParameter("UseWithSlaveController"  , 0   , zwave_dev_num)
			GetTuningParameter("AssociationDelay"        , 0   , zwave_dev_num)
			GetTuningParameter("SceneControllerConfDelay", 375 , zwave_dev_num)
			GetTuningParameter("UnassociateDelay"        , 0   , zwave_dev_num)
			GetTuningParameter("IndicatorDelay"          , 200 , zwave_dev_num)
		end,

		DoDeviceConfiguration = function(peer_dev_num, node_id, zwave_dev_num)
			-- Enable fan mode control on button 3.
			SetConfigurationOption("FanModeControl", peer_dev_num, node_id, 36, 1)
		end,

		SetDefaultLabels = function(peer_dev_num)
			local labels = {"One", "Two", "Three", "Four", "Five",
							"Six", "Seven", "Eight", "Nine", "Ten",
							"Eleven", "Twelve", "Thir-teen", "Four-teen", "Fifteen",
							"Sixteen", "Seven-teen", "Eight-teen", "Nine-teen", "Twenty",
							"Twenty one", "Twenty two", "Twenty three", "Twenty four", "Twenty five",
							"Twenty six", "Twenty seven", "Twenty eight", "Twenty nine", "Thirty"}
			for screen = 1,6 do
				for i = 1,5 do
					luup.variable_set(SID_SCENECONTROLLER, "Label_C" .. screen .. "_" .. i, labels[i + (screen - 1) * 5], peer_dev_num)
					luup.variable_set(SID_SCENECONTROLLER, "Mode_C"  .. screen .. "_" .. i, "M",  peer_dev_num)
				end
			end
			local labels2 = {"Forty-one", "Forty-five", "Forty-six", "Fifty",
							 "Fifty-one", "Fifty-five", "Fifty-six", "Sixty"}
			for screen = 1, 4 do
				luup.variable_set(SID_SCENECONTROLLER, "Label_T" .. screen+2 .. "_" .. 1, labels2[1 + (screen - 1) * 2], peer_dev_num)
				luup.variable_set(SID_SCENECONTROLLER, "Mode_T"  .. screen+2 .. "_" .. 1, "M",  peer_dev_num)
				luup.variable_set(SID_SCENECONTROLLER, "Label_T" .. screen+2 .. "_" .. 5, labels2[2 + (screen - 1) * 2], peer_dev_num)
				luup.variable_set(SID_SCENECONTROLLER, "Mode_T"  .. screen+2 .. "_" .. 5, "M",  peer_dev_num)
			end
		end,

		PhysicalButtonToIndicator = function(button, on)
			-- Bits 0 and 1 are used for "Do Not Disturb" and "Housekeeping"
			-- Bits 2-6 are buttons 1-5
			if on then
				return bit.lshift(2, button)
			else
				return bit.bxor(bit.lshift(2 ,button), 0x7C)
			end
		end,

		PhysicalButtonToGroupIds = function(button, mode)
			return button, button + 5, button, button + 5
		end,

		SetButtonType = function(peer_dev_num, node_id, physicalButton, newType, force, oldType)
			local delay = 0
			if physicalButton >= 2 and physicalButton <= 4 and (newType == 3 or oldType == 3 or force) then -- Thermostat mode
				delay = 500
			end
			if force or oldType ~= newType then
				SetConfigurationOption("SetButtonType", peer_dev_num, node_id, physicalButton, newType, delay)
			end
		end,

		ScreenPage = function(screen)
			local prefix = screen:sub(1,1)
			local suffix = screen:sub(2)
			if prefix == "C" then
				return 17
			elseif prefix == "T" then
				if suffix == "1" then
					return 8
				elseif suffix == "2" then
					return 16
				elseif suffix == "3" then
					return 40
				else
					return 17
				end
			elseif prefix == "P" then
				return tonumber(suffix)
			else
				ELog("ScreenPage: Unknown screen: ", screen);
				return 17
			end
		end,

	    SetDeviceScreen = function(peer_dev_num, screen)
		   	local node_id = GetZWaveNode(peer_dev_num)
			SetConfigurationOption("SetScreen", peer_dev_num, node_id, 17, SCObj.ScreenPage(screen))
		end,

		SetLanguage = function(peer_dev_num, language)
		   	local node_id = GetZWaveNode(peer_dev_num)
		   	SetConfigurationOption("SetPresetLanguage", peer_dev_num, node_id, 16, language)
		end,

		SetBacklight = function(peer_dev_num, blackLightOn)
			DEntry("SetBacklight")
			local node_id = GetZWaveNode(peer_dev_num)
			local level = 0
			if blackLightOn then
				level = 15
			end
			-- Set backlight off level (range 0-20)
			SetConfigurationOption("Backlight_on", peer_dev_num, node_id, 22, level)
			-- Set buttons off level (range 0-20)
			SetConfigurationOption("Buttons_on", peer_dev_num, node_id, 24, level)
		end,

		-- Evolve LCD1 button mode types:
		-- 0=Scene control momentary
		-- 1=Scen control toggle
		-- 2=basic set toggle
		-- 3=Temperature (buttons 2, 3, 4 only)
		-- 4=Privacy
		-- 5=Housekeeping
		-- 6=Scen Control toggle on, Basic set toggle off
		ModeMap = { M=0,  -- Momentary
		            D=0,  -- Direct	(Deprecated)
					T=1,  -- Toggle
					["2"]=0, -- Two-state
					["3"]=0, -- Three-state
					["4"]=0, -- Four-state
					["5"]=0, -- Five-state
					["6"]=0, -- Six-state
					["7"]=0, -- Seven-state
					["8"]=0, -- Eight-state
					["9"]=0, -- Nine-state
					S=1,  -- Direct Toggle (Deprecated)
					X=1,  -- Exclusive
					N=0,  -- Switch Screen
					H=3,  -- Temperature
					W=0,  -- Welcome
					P=0,  -- Thermostat Operating mode
					E=0,  -- Thermostat Energy mode
		},

		-- Convert a mode object to a mode type.
		ModeType = function(mode)
			local result = SCObj.ModeMap[mode.prefix];
			if result == nil then
				result = 0
			elseif result == 1 and #mode > 0 and not mode.sceneControllable then
			    -- There are non-scene-capable direct associations, so we need to use basic set rather than scene activate/deactivate messages.
				result = 2
			end
			return result
		end,
	}, -- DEVTYPE_EVOLVELCD1

	-- Cooper RFWC5-Specific
	[DEVTYPE_COOPEREFWC5] = {
		Name                    = "Cooper RFWC5",
		HasScreen               = false,
		HasMultipleScreens      = false,
		HasPresetLanguages      = false,
		HasThremostatControl    = false,
		HasBattery				= false,
	    NumButtons              = 5,
	    LastFixedSceneId        = 5,
		MaxDirectAssociations   = 5,
		HasOffScenes            = false,
		HasIndicator			= true,
		HasButtonModes			= false,
		HasCooperConfiguration  = true,
		HasCentralScene         = false,
		DefaultScreen           = "P1",
		DefaultModeString       = "T",
		DevType                 = DEVTYPE_COOPEREFWC5,
		OldServiceId             = "urn:gengen_mcv-org:serviceId:CooperRFWC5",
		OldParamPrefix          = "RFWC5",
		DeviceXml               = "D_CooperRFWC5.xml",
		ScreenList              = {P=1},
		NumTemperatureScreens   = 0,
	    LargeFontWidths         = {}, -- Empty if not HasScreen
	    SmallFontWidths         = {}, -- Empty if not HasScreen
		screenWidth             = 1,  -- Dummy if not HasScreen
		rightJustifyScreenWidth = 1,
		SetTuningParameters = function(zwave_dev_num, peer_dev_num)
		    VEntry()
			GetTuningParameter("InitStaggerSeconds"	    , 30            , zwave_dev_num)
			GetTuningParameter("MinReinitSeconds"	    , 60 * 60 * 24  , zwave_dev_num)
			GetTuningParameter("ReturnRouteDelay"		, 500           , zwave_dev_num)
			GetTuningParameter("UseWithSlaveController"  , 0             , zwave_dev_num)
			GetTuningParameter("Retries"       		    , 0             , zwave_dev_num)
			GetTuningParameter("AssociationDelay"        , 5000          , zwave_dev_num)
			GetTuningParameter("SceneControllerConfDelay", 0             , zwave_dev_num)
			GetTuningParameter("UnassociateDelay"        , 0             , zwave_dev_num)
			GetTuningParameter("IndicatorDelay"          , 0 			 , zwave_dev_num)
		end,

		DoDeviceConfiguration = function(peer_dev_num, node_id, zwave_dev_num)
		end,

		SetDefaultLabels = function(peer_dev_num)
			-- Empty if not HasScreen
		end,

		PhysicalButtonToIndicator = function(button, on)
			if on then
				return bit.lshift(1, button - 1)
			else
				return bit.bxor(bit.lshift(1, button - 1), 0x1F)
			end
		end,

		PhysicalButtonToGroupIds = function(button, mode)
			return button, nil, button, nil
		end,

		SetButtonType = function(peer_dev_num, node_id, physicalButton, newType, force, oldType)
			-- TODO: Can we switch between momentary and toggle?
		end,

		ScreenPage = function(screen)
			-- stub if not HasMultipleScreens
			return 0
		end,

	    SetDeviceScreen = function(peer_dev_num, screen)
			-- No screen-type support
		end,

		SetLanguage = function(peer_dev_num, language)
			-- empty if not HasPresetLanguages
		end,

		SetBacklight = function(peer_dev_num, blackLightOn)
			-- empty if no backlight
		end,

		-- TODO: Can we get at least toggle vs momentary modes from the Cooper RFWC5
		-- These modes are bogus. Same as the LCD1 for now.
		ModeMap = { M=0,  -- Momentary
		            D=0,  -- Direct	(Deprecated)
					T=1,  -- Toggle
					["2"]=0, -- Two-state
					["3"]=0, -- Three-state
					["4"]=0, -- Four-state
					["5"]=0, -- Five-state
					["6"]=0, -- Six-state
					["7"]=0, -- Seven-state
					["8"]=0, -- Eight-state
					["9"]=0, -- Nine-state
					S=1,  -- Direct Toggle (Deprecated)
					X=1,  -- Exclusive
					N=0,  -- Switch Screen
					H=3,  -- Temperature
					W=0,  -- Welcome
					P=0,  -- Thermostat Operating mode
					E=0,  -- Thermostat Energy mode
		},

		-- Convert a mode object to a mode type.
		ModeType = function (mode)
			local result = SCObj.ModeMap[mode.prefix];
			if result == nil then
				result = 0
			end
			return result
		end,

	}, -- DEVTYPE_COOPEREFWC5

	-- Nexia One-Touch-Specific
	[DEVTYPE_NEXIAONETOUCH] = {
		Name                    = "Nexia One Touch",
		HasScreen               = true,
		HasMultipleScreens      = true,
		HasPresetLanguages      = false,
		HasThremostatControl    = true,
		HasBattery				= true,
	    NumButtons              = 15,
	    LastFixedSceneId        = 46,
		MaxDirectAssociations   = 2,
		HasOffScenes            = false,
		HasIndicator			= false,
		HasButtonModes			= true,
		HasCooperConfiguration  = false,
		HasCentralScene         = true,
		DefaultScreen           = "C1",
		DefaultModeString       = "M",
		DevType                 = DEVTYPE_NEXIAONETOUCH,
		OldServiceId             = "urn:gengen_mcv-org:serviceId:NexiaOneTouch",
		OldParamPrefix          = "NEXIA",
		DeviceXml               = "D_NexiaOneTouch.xml",
		ScreenList              = {C=1},
		NumTemperatureScreens   = 0,
		-- The "Large" font is actually narrower than the small font and can thus fit more characters per line.
		-- However two lines of the small font can fit in one line of the large font.
	    LargeFontWidths         = {
									3,5,7,9,9,15,11,4,6,7,8,9,4,6,4,8,
									9,9,10,9,9,9,9,9,9,9,4,4,9,8,9,7,
									11,9,9,9,9,8,8,10,10,6,6,9,9,11,10,11,
									9,11,10,9,9,10,9,14,9,10,8,6,8,6,10,11,
									6,8,8,8,8,8,6,8,8,4,5,8,4,12,8,8,
									8,8,7,7,6,8,8,12,8,8,7,8,5,9,10,11},
	    SmallFontWidths         = {
									3,4,7,11,10,16,13,3,7,7,9,11,5,6,4,10,
									10,9,10,10,11,10,10,10,10,10,5,6,11,11,11,9,
									13,11,11,11,11,10,9,11,11,8,8,11,11,13,12,12,
									10,12,12,10,10,11,11,16,11,11,10,7,9,6,10,11,
									7,9,10,9,10,9,7,10,10,4,6,9,4,14,10,10,
									10,10,8,8,7,10,9,14,9,9,8,10,6,10,12,13},
		ScreenWidth 		    = 65,
		RightJustifyScreenWidth = 67,
		SetTuningParameters = function(zwave_dev_num, peer_dev_num)
		    VEntry()
			GetTuningParameter("BaseDelay"     		, 300 , zwave_dev_num)
			GetTuningParameter("ClearDelay"    		, 700 , zwave_dev_num)
			GetTuningParameter("ScrollDelay"    	, 1000 , zwave_dev_num)
			GetTuningParameter("LineDelay"     		, 35  , zwave_dev_num)
			GetTuningParameter("CharDelay"     		, 8   , zwave_dev_num)
			GetTuningParameter("ResponseDelay" 		, 30  , zwave_dev_num)
			GetTuningParameter("BackoffDelay"  		, 50  , zwave_dev_num)
			GetTuningParameter("MaxParts"      		, 2   , zwave_dev_num)
			GetTuningParameter("UseClearScreen"		, 1   , zwave_dev_num)
			GetTuningParameter("Retries"       		, 0   , zwave_dev_num)
			GetTuningParameter("SwitchScreenDelay"	    , 50  , zwave_dev_num)
			GetTuningParameter("InitStaggerSeconds"	    , 15  , zwave_dev_num)
			GetTuningParameter("MinReinitSeconds"	    , 60 * 60 * 24  , zwave_dev_num)
			GetTuningParameter("ReturnRouteDelay"		, 500 , zwave_dev_num)
			GetTuningParameter("UseWithSlaveController" , 0   , zwave_dev_num)
			GetTuningParameter("AssociationDelay"       , 0   , zwave_dev_num)
			GetTuningParameter("SceneControllerConfDelay", 0  , zwave_dev_num)
			GetTuningParameter("UnassociateDelay"        , 0  , zwave_dev_num)
			GetTuningParameter("IndicatorDelay"          , 0  , zwave_dev_num)

		   	local node_id = GetZWaveNode(zwave_dev_num)

			-- Here we set up kluges to avoid problems with UI7 with the Nexia One-Touch
			-- LuaUPnP does not handle the ASSOCIATION_GROUP_INFO_GET command in list mode
			-- correctly. The device is allowed to send all of its associations in one list
			-- or as several reports. The Nexia one-touch sends 46 such reports and this
			-- seriously confuses LuaUPnP which is trying to get other information from the
			-- device.
			-- Vera should use the results of ASSOCIATION_GROUPTINGS_GET to decide how much 
			-- data to expect from the device.
			-- Our work around is return 1 association (the lifeline) to vera (we know better)
			-- and then to fake-out the call to ASSOCIATION_GROUP_INFO_GET to return only one
			-- info packet.
			-- The nexia 1-touch for its part is sending the wrong profile for group 1
			-- It should be 0x0001 (lifeline) rather 0x0000 (N/A) but this is relatively minor
			-- and we fix that here too. 

			MonitorZWaveData( true, -- outgoing
							  peer_dev_num,
							  nil, -- No arm data
--[==[
                                              C1                       C2
41      12/29/16 18:40:07.189   0x1 0x9 0x0 0x13 0xf 0x2 0x85 0x5 0x5 0x6 0x6b (##########k) 
           SOF - Start Of Frame --+   ¦   ¦    ¦   ¦   ¦    ¦   ¦   ¦   ¦    ¦
                     length = 9 ------+   ¦    ¦   ¦   ¦    ¦   ¦   ¦   ¦    ¦
                        Request ----------+    ¦   ¦   ¦    ¦   ¦   ¦   ¦    ¦
           FUNC_ID_ZW_SEND_DATA ---------------+   ¦   ¦    ¦   ¦   ¦   ¦    ¦
Device 45=Nexia One Touch Scene Controller Z-Wave -+   ¦    ¦   ¦   ¦   ¦    ¦
                Data length = 2 -----------------------+    ¦   ¦   ¦   ¦    ¦
      COMMAND_CLASS_ASSOCIATION ----------------------------+   ¦   ¦   ¦    ¦
      ASSOCIATION_GROUPINGS_GET --------------------------------+   ¦   ¦    ¦
Xmit options = ACK | AUTO_ROUTE ------------------------------------+   ¦    ¦
                   Callback = 6 ----------------------------------------+    ¦
                    Checksum OK ---------------------------------------------+
--]==]
							  "^01 .. 00 (..) " .. string.format("%02X", node_id) .. " .. 85 05 .* (..) ..$",
--[==[
42      12/29/16 18:40:07.221   0x6 0x1 0x4 0x1 0x13 0x1 0xe8 (#######) 
              ACK - Acknowledge --+   ¦   ¦   ¦    ¦   ¦    ¦
           SOF - Start Of Frame ------+   ¦   ¦    ¦   ¦    ¦
                     length = 4 ----------+   ¦    ¦   ¦    ¦
                       Response --------------+    ¦   ¦    ¦
           FUNC_ID_ZW_SEND_DATA -------------------+   ¦    ¦
                     RetVal: OK -----------------------+    ¦
                    Checksum OK ----------------------------+
42      12/29/16 18:40:07.222   got expected ACK 
41      12/29/16 18:40:07.222   ACK: 0x6 (#) 
42      12/29/16 18:40:07.261   0x1 0x5 0x0 0x13 0x6 0x0 0xef (#######) 
           SOF - Start Of Frame --+   ¦   ¦    ¦   ¦   ¦    ¦
                     length = 5 ------+   ¦    ¦   ¦   ¦    ¦
                        Request ----------+    ¦   ¦   ¦    ¦
           FUNC_ID_ZW_SEND_DATA ---------------+   ¦   ¦    ¦
                   Callback = 6 -------------------+   ¦    ¦
           TRANSMIT_COMPLETE_OK -----------------------+    ¦
                    Checksum OK ----------------------------+
41      12/29/16 18:40:07.261   ACK: 0x6 (#) 
42      12/29/16 18:40:07.361   0x1 0x9 0x0 0x4 0x0 0xf 0x3 0x85 0x6 0x2e 0x53 (#########.S) 
           SOF - Start Of Frame --+   ¦   ¦   ¦   ¦   ¦   ¦    ¦   ¦    ¦    ¦
                     length = 9 ------+   ¦   ¦   ¦   ¦   ¦    ¦   ¦    ¦    ¦
                        Request ----------+   ¦   ¦   ¦   ¦    ¦   ¦    ¦    ¦
FUNC_ID_APPLICATION_COMMAND_HANDLER ----------+   ¦   ¦   ¦    ¦   ¦    ¦    ¦
          Receive Status SINGLE ------------------+   ¦   ¦    ¦   ¦    ¦    ¦
Device 45=Nexia One Touch Scene Controller Z-Wave ----+   ¦    ¦   ¦    ¦    ¦
                Data length = 3 --------------------------+    ¦   ¦    ¦    ¦
      COMMAND_CLASS_ASSOCIATION -------------------------------+   ¦    ¦    ¦
   ASSOCIATION_GROUPINGS_REPORT -----------------------------------+    ¦    ¦
       Supported Groupings = 46 ----------------------------------------+    ¦
                    Checksum OK ---------------------------------------------+
--]==]
							  "06 01 04 01 \\1 01 XX 01 05 00 \\1 \\2 00 XX 01 09 00 04 00 " .. string.format("%02X", node_id) .. " 03 85 06 01 XX",
							  DummyCallback, 
							  false, -- not oneShot
							  0, -- no timeout
							  "NexiaBypass1")

			MonitorZWaveData( true, -- outgoing
							  peer_dev_num,
							  nil, -- No arm data
--[==[
                                              C1                                 C2
41      12/29/16 19:20:35.302   0x1 0xb 0x0 0x13 0xf 0x4 0x59 0x3 0x40 0x0 0x5 0x2b 0xd8 (######Y#@##+#) 
           SOF - Start Of Frame --+   ¦   ¦    ¦   ¦   ¦    ¦   ¦    ¦   ¦   ¦    ¦    ¦
                    length = 11 ------+   ¦    ¦   ¦   ¦    ¦   ¦    ¦   ¦   ¦    ¦    ¦
                        Request ----------+    ¦   ¦   ¦    ¦   ¦    ¦   ¦   ¦    ¦    ¦
           FUNC_ID_ZW_SEND_DATA ---------------+   ¦   ¦    ¦   ¦    ¦   ¦   ¦    ¦    ¦
Device 45=Nexia One Touch Scene Controller Z-Wave -+   ¦    ¦   ¦    ¦   ¦   ¦    ¦    ¦
                Data length = 4 -----------------------+    ¦   ¦    ¦   ¦   ¦    ¦    ¦
COMMAND_CLASS_ASSOCIATION_GRP_INFO -------------------------+   ¦    ¦   ¦   ¦    ¦    ¦
     ASSOCIATION_GROUP_INFO_GET --------------------------------+    ¦   ¦   ¦    ¦    ¦
              Flags = List Mode -------------------------------------+   ¦   ¦    ¦    ¦
        Grouping Identifier = 0 -----------------------------------------+   ¦    ¦    ¦
Xmit options = ACK | AUTO_ROUTE ---------------------------------------------+    ¦    ¦
                  Callback = 43 --------------------------------------------------+    ¦
                    Checksum OK -------------------------------------------------------+
--]==]
							  "^01 .. 00 (..) " .. string.format("%02X", node_id) .. " .. 59 03 40 00 .* (..) ..$",
--[==[
42      12/29/16 19:20:35.321   0x6 0x1 0x4 0x1 0x13 0x1 0xe8 (#######) 
              ACK - Acknowledge --+   ¦   ¦   ¦    ¦   ¦    ¦
           SOF - Start Of Frame ------+   ¦   ¦    ¦   ¦    ¦
                     length = 4 ----------+   ¦    ¦   ¦    ¦
                       Response --------------+    ¦   ¦    ¦
           FUNC_ID_ZW_SEND_DATA -------------------+   ¦    ¦
                     RetVal: OK -----------------------+    ¦
                    Checksum OK ----------------------------+
41      12/29/16 19:20:35.321   ACK: 0x6 (#) 
42      12/29/16 19:20:35.353   0x1 0x5 0x0 0x13 0x2b 0x0 0xc2 (####+##) 
           SOF - Start Of Frame --+   ¦   ¦    ¦    ¦   ¦    ¦
                     length = 5 ------+   ¦    ¦    ¦   ¦    ¦
                        Request ----------+    ¦    ¦   ¦    ¦
           FUNC_ID_ZW_SEND_DATA ---------------+    ¦   ¦    ¦
                  Callback = 43 --------------------+   ¦    ¦
           TRANSMIT_COMPLETE_OK ------------------------+    ¦
                    Checksum OK -----------------------------+
41      12/29/16 19:20:35.354   ACK: 0x6 (#) 

42      12/29/16 19:20:35.387   0x1 0x10 0x0 0x4 0x0 0xf 0xa 0x59 0x4 0x81 0x1 0x0 0x0 0x0 0x0 0x0 0x0 0x33 (######\nY#########3) 
           SOF - Start Of Frame --+    ¦   ¦   ¦   ¦   ¦   ¦    ¦   ¦    ¦   ¦   ¦ +-----+   ¦ +-----+    ¦
                    length = 16 -------+   ¦   ¦   ¦   ¦   ¦    ¦   ¦    ¦   ¦   ¦    ¦      ¦    ¦       ¦
                        Request -----------+   ¦   ¦   ¦   ¦    ¦   ¦    ¦   ¦   ¦    ¦      ¦    ¦       ¦
FUNC_ID_APPLICATION_COMMAND_HANDLER -----------+   ¦   ¦   ¦    ¦   ¦    ¦   ¦   ¦    ¦      ¦    ¦       ¦
          Receive Status SINGLE -------------------+   ¦   ¦    ¦   ¦    ¦   ¦   ¦    ¦      ¦    ¦       ¦
Device 45=Nexia One Touch Scene Controller Z-Wave -----+   ¦    ¦   ¦    ¦   ¦   ¦    ¦      ¦    ¦       ¦
               Data length = 10 ---------------------------+    ¦   ¦    ¦   ¦   ¦    ¦      ¦    ¦       ¦
COMMAND_CLASS_ASSOCIATION_GRP_INFO -----------------------------+   ¦    ¦   ¦   ¦    ¦      ¦    ¦       ¦
  ASSOCIATION_GROUP_INFO_REPORT ------------------------------------+    ¦   ¦   ¦    ¦      ¦    ¦       ¦
Flags = List Mode | Group Count=1 ---------------------------------------+   ¦   ¦    ¦      ¦    ¦       ¦
        Grouping Identifier = 1 ---------------------------------------------+   ¦    ¦      ¦    ¦       ¦
                       Mode = 0 -------------------------------------------------+    ¦      ¦    ¦       ¦
       Profile = AGI_GENERAL_NA ------------------------------------------------------+      ¦    ¦       ¦
                   Reserved = 0 -------------------------------------------------------------+    ¦       ¦
                 Event Code = 0 ------------------------------------------------------------------+       ¦
                    Checksum OK --------------------------------------------------------------------------+
		end,
--]==]
							  "06 01 04 01 \\1 01 XX 01 05 00 \\1 \\2 00 XX 01 10 00 04 00 " .. string.format("%02X", node_id) .. " 0A 59 04 81 01 00 00 01 00 00 00 XX",
							  DummyCallback, 
							  false, -- not oneShot,
							  0, -- no timeout
							  "NexiaBypass2")
		end,

		DoDeviceConfiguration = function(peer_dev_num, node_id, zwave_dev_num)
  			local veraZWaveNode, ZWaveNetworkDeviceId = GetVeraIDs()
			local associateList	= {[ZWaveNetworkDeviceId] = {level=255, dimmingDuration=255}}
			UnassociateDevice(zwave_dev_num, nil, 1, 1, 1, 0) -- Clear central scene association
			AssociateDevice(zwave_dev_num, associateList, 1, 1, 1, 0) -- Associate central scene with Vera
		end,

		SetDefaultLabels = function(peer_dev_num)
			local labels = {"One", "Two", "Three", "Four", "Five",
							"Six", "Seven", "Eight", "Nine", "Ten",
							"Eleven", "Twelve", "Thir-teen", "Four-teen", "Fifteen",
							"Sixteen", "Seven-teen", "Eight-teen", "Nine-teen", "Twenty",
							"Twenty one", "Twenty two", "Twenty three", "Twenty four", "Twenty five",
							"Twenty six", "Twenty seven", "Twenty eight", "Twenty nine", "Thirty"}
			for i = 1,15 do
				luup.variable_set(SID_SCENECONTROLLER, "Label_C1_" .. i, labels[i], peer_dev_num)
				luup.variable_set(SID_SCENECONTROLLER, "Mode_C1_" .. i, "M",  peer_dev_num)
			end
		end,

		PhysicalButtonToIndicator = function(button, on)
			-- Nexia One Touch does not support the indicator command class
			return 0
		end,

		PhysicalButtonToGroupIds = function(button, mode)
			if mode.prefix == 'H' then 
			    -- Thermostat
				return button + 31, nil, button, nil
			elseif mode.sceneControllable then -- Scene activation
				if mode.prefix == "T" then 
				    -- For scene controllable toggle we need to associate with both the scene and the basic set groups. 
					return button + 16, button + 1, button, nil
				else
				    -- Scene compatible momentary
					return button + 16, nil, button, nil
				end
			else
			    -- Basic set
				return button + 1,  nil, button, nil
			end
		end,

		SetButtonType = function(peer_dev_num, node_id, physicalButton, newType, force, oldType)
			DEntry("SetButtonType")
			if force or oldType ~= newType then
				SetConfigurationOption("SetButtonType", peer_dev_num, node_id, physicalButton + 1, newType)
			end
		end,

		ScreenPage = function(screen)
			-- Stub if device does not support multiple screens
			return 0
		end,

	    SetDeviceScreen = function(peer_dev_num, screen)
			-- No screen-type support
		end,

		SetLanguage = function(peer_dev_num, language)
			-- No language support
		end,

		SetBacklight = function(peer_dev_num, blackLightOn)
			-- TODO - Is there a way to trigger the backlight?
		end,

		-- Nexia One-Touch button mode types:
		-- 0=Central Scene
		-- 1=Scene Control Momentary
		-- 2=BASIC SET Toggle
		-- 3=Scene Control/BASIC SET toggle
		-- 4=Thermostat
		ModeMap = { M=1,  -- Momentary
		            D=1,  -- Direct	(Deprecated)
					T=3,  -- Toggle
					["2"]=1, -- Two-state
					["3"]=1, -- Three-state
					["4"]=1, -- Four-state
					["5"]=1, -- Five-state
					["6"]=1, -- Six-state
					["7"]=1, -- Seven-state
					["8"]=1, -- Eight-state
					["9"]=1, -- Nine-state
					S=3,  -- Direct Toggle (Deprecated)
					X=3,  -- Exclusive
					N=1,  -- Switch Screen
					H=4,  -- Temperature
					W=1,  -- Welcome
					P=1,  -- Thermostat Operating mode
					E=1,  -- Thermostat Energy mode
		},

		-- Convert a mode object to a mode type.
		ModeType = function (mode)
			local result = SCObj.ModeMap[mode.prefix];
			if result == nil then
				return 1
			end
			if result == 3 and not mode.sceneControllable then
			    -- There are non-scene-capable direct associations, so we need to use basic set rather than scene activate/deactivate messages.
				result = 2
			end
			return result
		end,
	}, -- DEVTYPE_NEXIAONETOUCH
} -- Devices

DEVTYPE_ZWN        		= "urn:schemas-micasaverde-com:device:ZWaveNetwork:1"
DEVTYPE_BINARY     		= "urn:schemas-upnp-org:device:BinaryLight:1"
DEVTYPE_DIMMABLE   		= "urn:schemas-upnp-org:device:DimmableLight:1"
DEVTYPE_THERMOSTAT 		= "urn:schemas-upnp-org:device:HVAC_ZoneThermostat:1"
DEVTYPE_WINDOWCOVERING 	= "urn:schemas-micasaverde-com:device:WindowCovering:1"

SID_HADEVICE       = "urn:micasaverde-com:serviceId:HaDevice1"
SID_HAG            = "urn:micasaverde-com:serviceId:HomeAutomationGateway1"
SID_SCTRL          = "urn:micasaverde-com:serviceId:SceneController1"
SID_ZWDEVICE       = "urn:micasaverde-com:serviceId:ZWaveDevice1"
SID_DIMMING        = "urn:upnp-org:serviceId:Dimming1"
SID_FANMODE        = "urn:upnp-org:serviceId:HVAC_FanOperatingMode1"
SID_USERMODE       = "urn:upnp-org:serviceId:HVAC_UserOperatingMode1"
SID_SWITCHPOWER    = "urn:upnp-org:serviceId:SwitchPower1"
SID_TEMPSENSOR     = "urn:upnp-org:serviceId:TemperatureSensor1"
SID_TEMPSETPOINT   = "urn:upnp-org:serviceId:TemperatureSetpoint1"
SID_COOLSETPOINT   = "urn:upnp-org:serviceId:TemperatureSetpoint1_Cool"
SID_HEATSETPOINT   = "urn:upnp-org:serviceId:TemperatureSetpoint1_Heat"
SID_HVACOPSTATE    = "urn:micasaverde-com:serviceId:HVAC_OperatingState1"

HVACOPSTATE_VAR     = "ModeState"
HVACOPSTATE_IDLE    = "Idle"
HVACOPSTATE_HEATING = "Heating"
HVACOPSTATE_COOLING = "Cooling"

ACTUATOR_CONF	   = "SceneActuatorConf"
CURRENT_INDICATOR  = "CurrentIndicator"
CURRENT_SCREEN     = "CurrentScreen"
FANMODE_AUTO       = "Auto"
FANMODE_ON         = "ContinuousOn"
FANMODE_CYCLE	   = "PeriodicOn"
FANMODE_VAR        = "Mode"
NUMLINES_VAR       = "NumLines"
PRESET_LANGUAGE    = "PresetLanguage"
RETURN_ROUTES      = "ReturnRoutes"
SCROLLOFFSET_VAR   = "ScrollOffset"
SETPOINT_TARG      = "SetpointTarget"
SETPOINT_VAR       = "CurrentSetpoint"
ALLSETPOINTS_VAR   = "AllSetpoints"
TEMPSENSOR_VAR     = "CurrentTemperature"
USERMODE_VAR       = "ModeStatus"
USERMODE_AUTO      = "AutoChangeOver"
USERMODE_COOL      = "CoolOn"
USERMODE_HEAT      = "HeatOn"
USERMODE_OFF       = "Off"
ENERGYMODE_VAR     = "EnergyModeStatus"
ENERGYMODE_NORMAL  = "Normal"
ENERGYMODE_SAVING  = "EnergySavingsMode"

SIGUSR2 = 17  -- Vera posix library does not define this - MIPS-specific value

SCREEN_MD = {
   -- Screen flags
   ClearScreen = 0x00,
   ScrollDown  = 0x08,
   ScrollUp    = 0x10,
   NoChange    = 0x38,
   ScreenMask  = 0x38,

   MoreData    = 0x80,

   -- Line Flags
   StdFont     = 0x00,
   Highlighted = 0x20,
   LargeFont   = 0x40,

   NoClearLine = 0x00,
   ClearLine   = 0x10,

   Line1       = 0x00,
   Line2       = 0x01,
   Line3       = 0x02,
   Line4       = 0x03,
   Line5       = 0x04
}

--
-- Globals
--

local ZWaveSceneIdCacheList = {}
local param = {}
local lastChangedModes = {}
local temperatureAutoChoices = {}
local IndicatorLocks = {}

-- Make sure tha all of the log functions work before even the SCObj global is set.
function GetDeviceName()
  local name = "Scene Controller"
  if SCObj then
	 name = SCObj.Name
  end
  return name
end


--
-- Start benchmark code
--
function findBestDelay(labels, node_id, zwave_dev_num, first, last, screenFlags)
	local save_retries = param.SCENE_CTRL_Retries
	param.SCENE_CTRL_Retries = 1
	local low = 1
	local high = 1000
	while high > low do
	    local test = math.floor((high + low) / 2)
	    local count = 0
		local bad = 0
		for i = 1,10 do
			log("Benchmark Testing ", labels, "delay=", test, " iteration=", i)
		    if EVLCDWrapStrings(labels, {}, {}, node_id, zwave_dev_num, first, last, screenFlags, test) then
				count = count + 1
			else
			    bad = bad + 1
				if bad > 1 then
			 		break
				end
			end
		end
		if count >= 9 then
			log("Benchmark test ", labels, " delay=", test, " passed")
			high = test
		else
			log("Benchmark test ", labels, " delay=", test, " failed")
			low = test+1
		end
	end
	log ("Benchmark test ", labels, " Best value is ", high)
	param.SCENE_CTRL_Retries = save_retries
	return high
end

tests = {}
function test(labels)
	tests[labels] = findBestDelay(labels, test_node_id, test_zwave_dev_num, 1, #labels, test_clear)
end

function Benchmark(peer_dev_num, screen)
	test_node_id, test_zwave_dev_num = GetZWaveNode(peer_dev_num)
	EVLCDWrapStrings({""}, {}, {}, test_node_id, test_zwave_dev_num, 1, 1, true, 1000)
	if screen == 1 then
		test_clear = SCREEN_MD.ClearScreen
	else
		test_clear = SCREEN_MD.NoChange
	end
	test {"1"}
	test {"22"}
	test {"333"}
	test {"4444"}
	test {"55555"}
	test {"666666"}
	test {"7777777"}
	test {"88888888"}
	test {"999999999"}
	printTable(tests,"Benchmark: ")
	test {"1","2"}
	test {"1","2","3"}
	test {"1","2","3","4"}
	test {"1","2","3","4","5"}
	test {"1\r1"}
	test {"1\r1","2\r2"}
	test {"1\r1","2\r2","3\r3"}
	test {"1\r1","2\r2","3\r3","4\r4"}
	test {"1\r1","2\r2","3\r3","4\r4","5\r5"}
	printTable(tests,"Benchmark: ")
end


--
-- Parameters and defaults
--
function SceneController_ParamChange(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
	param[lul_variable] = tonumber(lul_value_new)
end

function SceneController_VerboseLoggingChange(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
	local oldVerboseLogging = VerboseLogging
	VerboseLogging = tonumber(lul_value_new)
	log("VerboseLogging changed: Old level was ", oldVerboseLogging, " New level is ", VerboseLogging)
	local firstInstaller = GetFirstInstaller();
	local firstNodeId, firstZWave = GetZWaveNode(firstInstaller)
	if lul_device ~= firstZWave then
		luup.variable_set(SID_SCENECONTROLLER, "SCENE_CTRL_VerboseLogging", VerboseLogging, firstZWave)
	end
end


local SceneController_ForceDefaultParameters = true
function GetTuningParameter(name, default_value, zwave_dev_num, functionName)
	local value = luup.variable_get(SID_SCENECONTROLLER, "SCENE_CTRL_"..name, zwave_dev_num)
	if value == nil then
		value = luup.variable_get(SCObj.OldServiceId, SCObj.OldParamPrefix.."_"..name, zwave_dev_num)
		if value ~= nil then
		    luup.variable_set(SID_SCENECONTROLLER, "SCENE_CTRL_"..name, value, zwave_dev_num, true)
			luup.variable_set(SCObj.OldServiceId, SCObj.OldParamPrefix.."_"..name, "", zwave_dev_num, true)
		end 
	end
	if SceneController_ForceDefaultParameters or value == nil then
		value = default_value
	else
		value = tonumber(value)
	end
	param["SCENE_CTRL_"..name] = value
	if not functionName then
		functionName = "SceneController_ParamChange"
	end
	luup.variable_watch(functionName, SID_SCENECONTROLLER, "SCENE_CTRL_"..name, zwave_dev_num)
end

-- 
-- Z-Wave Queue
--

function EnqueueActionOrMessage(queueNode)
  VEntry()
  local peer_dev_num = GetPeerDevNum(luup.device)
  local description = ""
  if peer_dev_num then
	description = queueNode.description or luup.devices[peer_dev_num].description
	if not queueNode.responseDevice then
		queueNode.responseDevice = peer_dev_num
	end
	if queueNode.hasBattery == nil then
		queueNode.hasBattery = SCObj.HasBattery
	end
  end
  queueNode.description = description
  VLog("EnqueueActionOrMessage-External: ", queueNode)
  table.insert(ExternalZWaveQueue, queueNode)
end

-- Enqueue a local Z-Wave controller message.
function EnqueueZWaveControllerMessage(name, node_id, data, dev_num, delay)
  VEntry()
  EnqueueActionOrMessage({
  	type=0,
  	name=name,
	description=luup.devices[dev_num].description,
	device=dev_num,
  	node_id=node_id,
  	data=data,
  	delay=delay})
end

-- Enqueue a Z-Wave message. No response is expected. Wait <delay> milliseconds
-- before sending a Z-Wave command to the same device
function EnqueueZWaveMessage(name, node_id, data, dev_num, delay)
  VEntry()
  local hasBattery = false
  local obj = Devices[luup.devices[dev_num].device_type]
  if obj then
	hasBattery = obj.HasBattery
  end	
  EnqueueActionOrMessage({
  	type=1,
  	name=name,
	description=luup.devices[dev_num].description,
	device=dev_num,
  	node_id=node_id,
	hasBattery=hasBattery,
  	data=data,
  	delay=delay})
end

-- Enqueue a Lua action within the Z-Wave queue
function EnqueueLuupAction(name, device, service, action, arguments, delay)
  VEntry()
  EnqueueActionOrMessage({
  	type=2,
  	name=name,
  	device=device,
  	node_id=-1,
  	service=service,
	description=service..": "..action,
  	action=action,
  	arguments=arguments,
  	delay=delay})
end

-- Enqueue a Z-Wave message, expecting a response.
-- pattern is a Linux externed refular expression which will be matched against the hexified incoming Z-Wave data.
-- Callback is a function which is passed the peer device number and any captures from the regex. 
--    The capture array is nil if a timeout occurred.
--    If callback is nil, then this can be used to wait until the response is receviced, without regard to its value,
--    before sending any other commands to that specific device.
-- Oneshot is true if the monitor should be canceled as soon as it matches.
-- Timeout and delay are in milliseconds.
--   If timeeout is 0 or nil then the monitor will be active until canceled with CancelZWaveMonitor
-- If armPattern is not nil then the given pattern must be sent first to arm the monitor.
-- If autoResponse is not nil then the received data is not received by LuaUPnP and the given autoResponse is sent to the device instead.
-- Delay is applied after the response is received but ignored in case of a timeout.
-- Returns a context which can be passed to CancelZWaveMonitor if callback is not nil.
function EnqueueZWaveMessageWithResponse(name, node_id, data, delay, pattern, callback, oneshot, dev_num, timeout, armPattern, autoResponse)
  VEntry()
  local context
  if callback then
    MonitorContextNum = MonitorContextNum + 1
  	context = "R_" .. name .. "_" .. node_id .. "_" .. MonitorContextNum
  	MonitorContextList[context] = {incoming=true, callback=callback, oneshot=oneshot, releaseNodeId=node_id}
  end
  EnqueueActionOrMessage({
  	type=1,
  	name=name,
	description=luup.devices[dev_num].description,
  	node_id=node_id,
	device=dev_num,
  	data=data,
  	delay=delay,
  	pattern=pattern,
  	context=context,
	oneshot=oneshot,
  	timeout=timeout,
  	armPattern=armPattern,
  	autoResponse=autoResponse})
  return context
end

--
-- Sceen display
--

function ExpandString(s)
  out = s:len()
  for i=1,s:len() do
     out = out .. " " .. s:byte(i)
  end
  return out
end

--EVLCDLabel(screenFlags,{line1,line2,...,linen)
--linex = {lineFlags,linePosition,label}
function EVLCDLabel(screenFlags,lineArray, node_id, zwave_dev_num, delay_override)
	if not SCObj.HasScreen then
		return true
	end
	local peer_dev_num = GetPeerDevNum(zwave_dev_num)
	if param.SCENE_CTRL_CharDelay == nil then
		SCObj.SetTuningParameters(zwave_dev_num)
	end
	local data = "146 2 " .. tostring(screenFlags) -- COMMAND_CLASS_SCREEN_META_DATA version 1 REPORT
	local part = 1
	local delay = param.SCENE_CTRL_BaseDelay
	local screenMask = bit.band(screenFlags,SCREEN_MD.ScreenMask)
	if screedMask == SCREEN_MD.ClearScreen then
		delay = delay + param.SCENE_CTRL_ClearDelay
	elseif screedMask ~= SCREEN_MD.NoChange then
		delay = delay + param.SCENE_CTRL_ScrollDelay
	end
	for lnum = 1,#lineArray do
   		local line = lineArray[lnum]
   		assert(#line == 3,"EVDLCDLabel Line " .. lnum .. ": Each line must have 3 parts: flags, position, label")
		assert(line[1] >= 0 and line[1] <= 255, "EVDLCDLabel Line " .. lnum .. ": Flags must be 1 byte")
   		assert(line[2] >= 0                  ,  "EVDLCDLabel Line " .. lnum .. ": position should be between >= 0")
   		assert(#line[3] <= 16,                  "EVDLCDLabel Line " .. lnum .. ": Label too long")
   		data = data .. " " .. tostring(line[1])
        	        .. " " .. tostring(line[2])
             	    .. " " .. ExpandString(line[3])
        delay = delay + #line[3] * param.SCENE_CTRL_CharDelay
   		if part == 1 and lnum < #lineArray and param.SCENE_CTRL_MaxParts > 1 then
			delay = delay + param.SCENE_CTRL_LineDelay
   	  		part = 2
   		else
			if delay_override then
				delay = delay_override
			end
			EnqueueZWaveMessage("SetLabel_"..node_id, node_id, data, peer_dev_num, delay);
			screenFlags = SCREEN_MD.NoChange
	        data = "0x92 2 " .. tostring(screenFlags)
			part = 1
			delay = param.SCENE_CTRL_BaseDelay
		end
   	end -- for lnum
	return true
end -- EVDLCDLabel

--
-- Screen display function. Pass an array of up to 5 strings.
-- Lines will automatically wrap at word boundaries.
--
function  EVLCDWrapStrings(stringArray, fontArray, alignArray, node_id, zwave_dev_num, first, last, screenFlags, delay_override)
	if not SCObj.HasScreen then
		return true
	end
	local lineArray = {}
	local entryNum = 1
	for lnum = first-1, last-1 do
		local index = 2+lnum-first;
		local displayString = stringArray[index]
		local font = fontArray[index];
		local align = alignArray[index];
		if type(displayString) == "string" then
			local part = 1
			local pos = 1
			local width = 0
			local lastSpace = 0
			local label = ""
			local label1 = ""
			local width1 = ""
			local flags1 = 0
			local word = ""
			local wordWidth = 0
			local prevc
			local cWidth
			local spaceWidth = 0
			local space = ""
			local longWord = false;
			local addLine;
			local widths = SCObj.SmallFontWidths;
			local lineFlags = 0;
			if font == nil or font == "" then
				font = "Normal"
			end
			if align == nil or align == "" then
				align = "Center"
			end
			if font == "Normal" then  -- Only the normal font can get 2 lines and thus gets - or \r subsitutions
				displayString = displayString:gsub("\\r",      "\r")
				displayString = displayString:gsub("-([^\r])", "-\r%1")
			elseif font == "Compressed" then -- The "Large" font is taller but actually the compressed font
				widths = SCObj.LargeFontWidths
				lineFlags = SCREEN_MD.LargeFont;
			else  -- Inverted
				lineFlags = SCREEN_MD.Highlighted;
			end

			if align:sub(1,3) == "Raw" then
				local offset = 0
				if align:len() > 3 then
					local offsetString = align:sub(4);
					offset = tunumber(offsetString);
				end
				local flags = lineFlags;
				if screenFlags ~= SCREEN_MD.ClearScreen then
					flags = bit.bor(flags, SCREEN_MD.ClearLine)
				end
				lineArray[entryNum] = { bit.bor(flags,lnum), offset, displayString:sub(1,16) }
	    		entryNum = entryNum + 1
			else
				local eol;
				if displayString == "" then
					eol = 0;
				else
					eol = displayString:byte(#displayString)
				end
				if eol ~= 13 and eol ~= 10 then
					displayString = displayString .. '\r';
				end
				while pos <= #displayString and lnum < last do
			  		if longWord then
			    		longWord = false
						label = word
						width = wordWidth;
						addLine = true
						word = ""
						wordWidth = 0
					else
						addLine = pos == #displayString
						longWord = false;
						local c = displayString:byte(pos)
						if c == 32 then -- space
							if wordWidth > 0 then
					  			if font ~= "Normal" or (width + spaceWidth + wordWidth <= SCObj.ScreenWidth) then
									label = label .. space .. word
									width = width + spaceWidth + wordWidth
									word = ""
									wordWidth = 0
									space = " "
									spaceWidth = widths[1]
								else
									addLine = true
					  			end
					  		else -- wordWidth > 0
					  			space = space .. " "
					  			spaceWidth = spaceWidth + widths[1]
							end -- wordWidth > 0
			      		elseif (c == 10 or c == 13) and (font == "Normal" or pos == #displayString) then -- \n or \r
				    		if c == 13 or prevc ~= 13 then -- ignore lf after cr
					  			if width > 0 or wordWidth > 0 then
					    			if wordWidth > 0 then
						  				label = label .. space .. word
						  				width = width + spaceWidth + wordWidth
						  				word = ""
						  				wordWidth = 0
									end
					    			addLine = true;
					  			end -- cr/lf processing
							end
				  		elseif (c > 32 and c <= 127) or (c >= 160 and c <= 255) then -- normal character
							if (c <= 127) then
				      			cWidth = widths[c-31]
				    		else
					  			cWidth = widths[c-159]
							end
							if font ~= "Normal" or (width + spaceWidth + wordWidth + cWidth <= SCObj.ScreenWidth) then
					  			word = word .. string.char(c)
					  			wordWidth = wordWidth + cWidth
							elseif width > 0 then -- Current word must spill to next line
					  			if wordWidth > SCObj.ScreenWidth then -- output current line followed by long word.
					    			longWord = true;
					    			addLine = true;
					  			else -- Normal word wrap
					    			word = word .. string.char(c)
					    			wordWidth = wordWidth + cWidth
					    			addLine = true;
					  			end
				    		else -- long word but nothing else on this line
					  			label = word
					  			word = string.char(c)
					  			wordWidth = cWidth
					  			addLine = true;
							end
				  		end -- regular character processing
				  		prevc = c
				  		pos = pos + 1
					end -- not longWord
			    	if addLine then
						DLog("Adding line \"", label, "\" entryNum=", entryNum, " lnum=", lnum, " part=", part, " word=", word, " wordWidth=", wordWidth, " font=", font, " align=", align)
						local flags = lineFlags;
				  		if part == 1 then
							if screenFlags ~= SCREEN_MD.ClearScreen then
								flags = bit.bor(flags, SCREEN_MD.ClearLine)
							end
							label1 = label;
							width1 = width;
							flags1 = flags;
							local offset = 0;
							if align == "Left" then -- Left justify 1 line.
							    spaces = math.floor((SCObj.ScreenWidth - width) / widths[1]);
							    if spaces < 0 then
							    	spaces = 0
							    end
							    while spaces > 0 and #label < 16 do
									label = label .. " ";
							    end
							elseif align == "Right" then -- Right justify 1 line.
								offset = math.floor((SCObj.RightJustifyScreenWidth - width) / 3);
								if offset < 0 then
									offset = 0
								end
							end
							lineArray[entryNum] = { bit.bor(flags,lnum), offset, label:sub(1,16) }
				    		entryNum = entryNum + 1
							part = 2
				  		else
							local offset = 0;
							if align == "Left" then -- Left justify 2 lines;
								while width1 < SCObj.ScreenWidth and width < SCObj.ScreenWidth and #label1 + #label < 15 do
									if width1 < SCObj.ScreenWidth and #label1 + #label < 15 then
										label1 = label1 .. " ";
										width1 = width1 + widths[1];
									end
									if width < SCObj.ScreenWidth and #label1 + #label < 15 then
										label = label .. " ";
										width = width + widths[1];
									end
								end
							elseif align == "Right" then -- Right justify 2 lines
								while (width <= width1 - widths[1]) and #label1 + #label < 15 do
									label = " " .. label;
									width = width + widths[1];
								end
								while (width1 <= width - widths[1]) and #label1 + #label < 15 do
									label1 = " " .. label1;
									width1 = width1 + widths[1];
								end
								if width > width1 then
									offset = math.floor((SCObj.RightJustifyScreenWidth - width) / 3);
								else
									offset = math.floor((SCObj.RightJustifyScreenWidth - width1) / 3);
								end
							end
							lineArray[entryNum-1][2] = offset;
					  		lineArray[entryNum-1][3] = (label1 .. "\r" .. label):sub(1,16);
							break
				  		end
				  		label = ""
				  		width = 0
				  		space = ""
				  		spaceWidth = 0
					end -- if addline
				end -- pos <= #displayString and lnum < last
			end -- else not raw
		end -- if string
	end -- for lnum
	-- printTable(lineArray)
	local result
	--if param.SCENE_CTRL_Retries > 0 then
	  --	SetFlushLogs(true)
	--end
	if screenFlags == SCREEN_MD.NoChange then
		result = EVLCDLabel(screenFlags, lineArray, node_id, zwave_dev_num, delay_override)
	else
		result = EVLCDLabel(bit.bor(SCREEN_MD.MoreData, screenFlags), lineArray, node_id, zwave_dev_num, delay_override)
	end
	--if param.SCENE_CTRL_Retries > 0 then
	--	SetFlushLogs(false)
	--end
	return result
end

--
-- Initialization, primary controller and peer handling
--

-- GetDeviceCounter returns 1 for the lowest numbered controller, 2 for the second, etc.
-- ordered by device ID.
function GetDeviceCounter(our_zwave_dev_num)
	local count = 0;
	for dev_num, v in pairs(luup.devices) do
		if Devices[v.device_type] and v.device_num_parent == 1 then
			if our_zwave_dev_num >= dev_num then
				count = count + 1
			end
		end
	end
	if count == 0 then
		ELog("GetDeviceCounter: Error device ", our_zwave_dev_num, "not found.")
	end
	return count
end

-- A dummy callback used by Z-Wave intercepts where we really don't need the data or the event.
function DummyCallback(peer_dev_num, captures)
	VEntry()
end

function SceneController_Init(lul_device)
	DEntry()
	if zwint.instance then -- Only in debug version
		log("ZWInt instance is ", zwint.instance())
	end
	if lul_device == 1 then
		CreatePeerDevices()
	else
		ConnectPeerDevice(lul_device)
		local zwave_node, zwave_dev = GetZWaveNode(lul_device)
		local veraZWaveNode, ZWaveNetworkDeviceId = GetVeraIDs()
	    local ComPort = luup.variable_get(SID_ZWN, "ComPort", ZWaveNetworkDeviceId)
		VLog("SceneController_Init: calling zwint.register(", ComPort, ")");
		local result, errcode, errmsg = zwint.register(ComPort);
		VLog("SceneController_Init: zwint.register(", ComPort, ") returned result=", result, " errcode=", errcode, " errmsg=", errmsg);
		RegisterClientDevice()

		    -- Devices are connected. Perform normal initialization on reload.

--[==[
                                                 C1                   C2   C3
42      12/11/16 20:04:55.812   0x1 0xa 0x0 0x4 0x8 0x7 0x4 0x2b 0x1 0x1 0xff 0x2e (#\n#####+###.)
           SOF - Start Of Frame --+   ¦   ¦   ¦   ¦   ¦   ¦    ¦   ¦   ¦    ¦    ¦
                    length = 10 ------+   ¦   ¦   ¦   ¦   ¦    ¦   ¦   ¦    ¦    ¦
                        Request ----------+   ¦   ¦   ¦   ¦    ¦   ¦   ¦    ¦    ¦
FUNC_ID_APPLICATION_COMMAND_HANDLER ----------+   ¦   ¦   ¦    ¦   ¦   ¦    ¦    ¦
           Receive Status MULTI ------------------+   ¦   ¦    ¦   ¦   ¦    ¦    ¦
Device 10=Cooper RFWC5 Scene Controller Z-Wave -------+   ¦    ¦   ¦   ¦    ¦    ¦
                Data length = 4 --------------------------+    ¦   ¦   ¦    ¦    ¦
 COMMAND_CLASS_SCENE_ACTIVATION -------------------------------+   ¦   ¦    ¦    ¦
           SCENE_ACTIVATION_SET -----------------------------------+   ¦    ¦    ¦
                   Scene ID = 1 ---------------------------------------+    ¦    ¦
         Dimming Duration = 255 --------------------------------------------+    ¦
                    Checksum OK -------------------------------------------------+
--]==]
		MonitorZWaveData(false, -- incoming,
						 lul_device, -- peer_dev_num
		                 nil, -- No arm_regex
		                 "^01 .. 00 04 (..) " .. string.format("%02X", zwave_node) .. " .. 2B 01 (..) (..)", -- Main RegEx
		                 "06", -- ACK response,
		                 SceneActivatedMonitorCallback,
		                 false, -- Not OneShot
		                 0, -- no timeout
						 "SceneActivate")


--[==[
                                                 C1                  C2
42      12/11/16 20:53:12.232   0x1 0x9 0x0 0x4 0x8 0x7 0x3 0x20 0x1 0x0 0xdf (####### ###)
           SOF - Start Of Frame --+   ¦   ¦   ¦   ¦   ¦   ¦    ¦   ¦   ¦    ¦
                     length = 9 ------+   ¦   ¦   ¦   ¦   ¦    ¦   ¦   ¦    ¦
                        Request ----------+   ¦   ¦   ¦   ¦    ¦   ¦   ¦    ¦
FUNC_ID_APPLICATION_COMMAND_HANDLER ----------+   ¦   ¦   ¦    ¦   ¦   ¦    ¦
           Receive Status MULTI ------------------+   ¦   ¦    ¦   ¦   ¦    ¦
Device 10=Cooper RFWC5 Scene Controller Z-Wave -------+   ¦    ¦   ¦   ¦    ¦
                Data length = 3 --------------------------+    ¦   ¦   ¦    ¦
            COMMAND_CLASS_BASIC -------------------------------+   ¦   ¦    ¦
                      BASIC_SET -----------------------------------+   ¦    ¦
              Value = BASIC_OFF ---------------------------------------+    ¦
                    Checksum OK --------------------------------------------+
--]==]
		MonitorZWaveData(false, -- incoming,
						 lul_device, -- peer_dev_num
		                 nil, -- No arm_regex
		                 "^01 .. 00 04 (..) " .. string.format("%02X", zwave_node) .. " .. 20 01 (..)", -- Main RegEx
		                 "06", -- ACK response,
		                 BasicSetMonitorCallback,
		                 false, -- Not OneShot
		                 0, -- no timeout
						 "BasicSet")

--[==[
                                                 C1
42      01/09/17 23:22:45.021   0x1 0x8 0x0 0x4 0x8 0xc 0x2 0x26 0x5 0xd6 (#######&##) 
           SOF - Start Of Frame --+   ¦   ¦   ¦   ¦   ¦   ¦    ¦   ¦    ¦
                     length = 8 ------+   ¦   ¦   ¦   ¦   ¦    ¦   ¦    ¦
                        Request ----------+   ¦   ¦   ¦   ¦    ¦   ¦    ¦
FUNC_ID_APPLICATION_COMMAND_HANDLER ----------+   ¦   ¦   ¦    ¦   ¦    ¦
           Receive Status MULTI ------------------+   ¦   ¦    ¦   ¦    ¦
Device 39=Cooper RFWC5 Scene Controller Z-Wave -------+   ¦    ¦   ¦    ¦
                Data length = 2 --------------------------+    ¦   ¦    ¦
COMMAND_CLASS_SWITCH_MULTILEVEL -------------------------------+   ¦    ¦
SWITCH_MULTILEVEL_STOP_LEVEL_CHANGE -------------------------------+    ¦
                    Checksum OK ----------------------------------------+
--]==]
		MonitorZWaveData(false, -- incoming,
						 lul_device, -- peer_dev_num
		                 nil, -- No arm_regex
		                 "^01 .. 00 04 (..) " .. string.format("%02X", zwave_node) .. " .. 26 05", -- Main RegEx
		                 "06", -- ACK response,
		                 MultiLevelSwitchStopLevelChangeMonitorCallback,
		                 false, -- Not OneShot
		                 0, -- no timeout
						 "MultilevelStop")

--[==[
                                                     C1               C2  C3   C4
42      01/14/17 10:23:29.612   0x1 0xb 0x0 0x4 0x8 0xb 0x5 0x43 0x1 0x1 0x9 0x3f 0x83 (#######C###?#) 
           SOF - Start Of Frame --+   ¦   ¦   ¦   ¦   ¦   ¦    ¦   ¦   ¦   ¦    ¦    ¦
                    length = 11 ------+   ¦   ¦   ¦   ¦   ¦    ¦   ¦   ¦   ¦    ¦    ¦
                        Request ----------+   ¦   ¦   ¦   ¦    ¦   ¦   ¦   ¦    ¦    ¦
FUNC_ID_APPLICATION_COMMAND_HANDLER ----------+   ¦   ¦   ¦    ¦   ¦   ¦   ¦    ¦    ¦
           Receive Status MULTI ------------------+   ¦   ¦    ¦   ¦   ¦   ¦    ¦    ¦
Device 38=Evolve LCD1 Scene Controller Z-Wave --------+   ¦    ¦   ¦   ¦   ¦    ¦    ¦
                Data length = 5 --------------------------+    ¦   ¦   ¦   ¦    ¦    ¦
COMMAND_CLASS_THERMOSTAT_SETPOINT -----------------------------+   ¦   ¦   ¦    ¦    ¦
        THERMOSTAT_SETPOINT_SET -----------------------------------+   ¦   ¦    ¦    ¦
           SetPoint = Heating 1 ---------------------------------------+   ¦    ¦    ¦
Level2 = Size=1 | Fahrenheit | Precision=0 --------------------------------+    ¦    ¦
                     Value = 63 ------------------------------------------------+    ¦
                    Checksum OK -----------------------------------------------------+
--]==]
		MonitorZWaveData(false, -- incoming,
						 lul_device, -- peer_dev_num
		                 nil, -- No arm_regex
		                 "^01 .. 00 04 (..) " .. string.format("%02X", zwave_node) .. " .. 43 01 (..) (..) (..)", -- Main RegEx
		                 "06", -- ACK response,
		                 ThermostatSetPointMonitorCallback,
		                 false, -- Not OneShot
		                 0, -- no timeout
						 "ThermostatSetPoint")

--[==[
                                                 c1                   C2
42      01/14/17 16:32:44.900   0x1 0x9 0x0 0x4 0x8 0xb 0x3 0x44 0x1 0x0 0xb7 (#######D###) 
           SOF - Start Of Frame --+   ¦   ¦   ¦   ¦   ¦   ¦    ¦   ¦   ¦    ¦
                     length = 9 ------+   ¦   ¦   ¦   ¦   ¦    ¦   ¦   ¦    ¦
                        Request ----------+   ¦   ¦   ¦   ¦    ¦   ¦   ¦    ¦
FUNC_ID_APPLICATION_COMMAND_HANDLER ----------+   ¦   ¦   ¦    ¦   ¦   ¦    ¦
           Receive Status MULTI ------------------+   ¦   ¦    ¦   ¦   ¦    ¦
Device 18=Evolve LCD1 Scene Controller Z-Wave --------+   ¦    ¦   ¦   ¦    ¦
                Data length = 3 --------------------------+    ¦   ¦   ¦    ¦
COMMAND_CLASS_THERMOSTAT_FAN_MODE -----------------------------+   ¦   ¦    ¦
        THERMOSTAT_FAN_MODE_SET -----------------------------------+   ¦    ¦
              Mode = Auto | Low ---------------------------------------+    ¦
                    Checksum OK --------------------------------------------+
--]==]
		MonitorZWaveData(false, -- incoming,
						 lul_device, -- peer_dev_num
		                 nil, -- No arm_regex
		                 "^01 .. 00 04 (..) " .. string.format("%02X", zwave_node) .. " .. 44 01 (..)", -- Main RegEx
		                 "06", -- ACK response,
		                 ThermostatFanModeMonitorCallback,
		                 false, -- Not OneShot
		                 0, -- no timeout
						 "ThermostatFanMode")

--[==[
42      08/29/17 20:17:08.480       0x1 0xa 0x0 0x4 0x0 0xd7 0x4 0x92 0x1 0x5 0x0 0xb4 (#\n##########) 
               SOF - Start Of Frame --+   ¦   ¦   ¦   ¦    ¦   ¦    ¦   ¦   ¦   ¦    ¦
                        length = 10 ------+   ¦   ¦   ¦    ¦   ¦    ¦   ¦   ¦   ¦    ¦
                            Request ----------+   ¦   ¦    ¦   ¦    ¦   ¦   ¦   ¦    ¦
FUNC_ID_APPLICATION_COMMAND_HANDLER --------------+   ¦    ¦   ¦    ¦   ¦   ¦   ¦    ¦
              Receive Status SINGLE ------------------+    ¦   ¦    ¦   ¦   ¦   ¦    ¦
Device 148=EC14 Breakfast Nook-Family Romm entrance Z-Wave +   ¦    ¦   ¦   ¦   ¦    ¦
                    Data length = 4 ---------------------------+    ¦   ¦   ¦   ¦    ¦
            COMMAND_CLASS_SCREEN_MD --------------------------------+   ¦   ¦   ¦    ¦
                SCREEN_METADATA_GET ------------------------------------+   ¦   ¦    ¦
                numberOfReports = 5 ----------------------------------------+   ¦    ¦
                Node ID: 0 : *None* --------------------------------------------+    ¦
                        Checksum OK -------------------------------------------------+
41      08/29/17 20:17:08.480   ACK: 0x6 (#)
--]==]
		MonitorZWaveData(false, -- incoming,
						 lul_device, -- peer_dev_num
		                 nil, -- No arm_regex
		                 "^01 .. 00 04 (..) " .. string.format("%02X", zwave_node) .. " .. 92 01", -- Main RegEx
		                 "06", -- ACK response,
		                 ScreenMDGetMonitorCallback,
		                 false, -- Not OneShot
		                 0, -- no timeout
						 "ScreenMDGet")

	end
	RunZWaveQueue("Init", 0)
	return true, "ok", SCObj.Name
end

-- SceneController_InitScreen gets called once for each device a variable delay after initialization.
function SceneController_InitScreen(peer_dev_num_string)
	DEntry()
	local peer_dev_num = tonumber(peer_dev_num_string)
	local currentScreen
	if SCObj.HasMultipleScreens then
		currentScreen = luup.variable_get(SID_SCENECONTROLLER, CURRENT_SCREEN, peer_dev_num)
	else
		currentScreen = SCObj.DefaultScreen
	end
	if currentScreen then
		log("SceneController_InitScreen starting for peer device ", peer_dev_num, " currentScreen=", currentScreen);
		-- doTimeOut, Force, not IndicatorOnly
		SetScreen(peer_dev_num, currentScreen, true, true, false);
		RunZWaveQueue("InitScreen", 0);
	end
end

function MigrateVariableToNewServiceId(varName, dev_num)
	local value = luup.variable_get(SCObj.OldServiceId, varName, dev_num)
	if value ~= nil then
		luup.variable_set(SID_SCENECONTROLLER, varName, value, dev_num)
		if varName ~= "PeerID" then -- Keep PeerID to not confuse old versions which may still be active.
			luup.variable_set(SCObj.OldServiceId, varName, "", dev_num)
		end		
	end
	return value
end

-- Iterate through all variables using the old service ID and move them to the new (generic) service ID
function MigrateDeviceToNewServiceId(dev_num)
	ForAllVariables(dev_num, MigrateVariableToNewServiceId)
end

--
-- 	Called at initialization to possibly create the peer (Lua) device for the Z-Wave device.
--  If a device is created, then the luup engine is reloaded and the two-way linke between
--  two devices is formed.
--
function CreatePeerDevices()
    DEntry()
	local count = 0;
	for zwave_dev_num,v in pairs(luup.devices) do
		local candidate = Devices[v.device_type]
		if candidate and v.device_num_parent == 1 then
			SCObj = candidate
			DLog("  CreatePeerDevices: Found z-wave device ", zwave_dev_num, ": ", SCObj.Name, "named ", v.description)
	       	local peerID = luup.variable_get(SID_SCENECONTROLLER,"PeerID",zwave_dev_num);
			if not peerID then
	       		peerID = luup.variable_get(SCObj.OldServiceId,"PeerID",zwave_dev_num);
				if peerID then
					MigrateDeviceToNewServiceId(zwave_dev_num)
				end
			end
			local peer_dev_num = tonumber(peerID)
			if peer_dev_num ~= nil and peer_dev_num > 0 and luup.devices[peer_dev_num] == nil then
			   	log("Peer Device", peer_dev_num, " Deleted. Also deleting Z-Wave device ", zwave_dev_num, ", ZWave node ID ", v.id)
			   	luup.variable_set(SID_SCENECONTROLLER,"PeerID","",zwave_dev_num)
		   		luup.call_action(SID_HAG,"DeleteDevice", {DeviceNum = zwave_dev_num}, 0);
			elseif peerID == nil or peerID == "" or (peerID ~= "Pending" and luup.devices[tonumber(peerID)] == nil) then
			   	log("Creating peer device for Vera device ID ", zwave_dev_num, " ZWave node ID ", v.id)
			   	count = count + 1
			   	luup.variable_set(SID_SCENECONTROLLER,"PeerID","Pending",zwave_dev_num)
		   		luup.variable_set(SID_SCENECONTROLLER,"ShowSingleDevice","1",zwave_dev_num)
				luup.attr_set("invisible","1",zwave_dev_num)
				luup.attr_set("Invisible","1",zwave_dev_num)
			    luup.call_action(SID_HAG,"CreateDevice", {
				   	deviceType = SCObj.DevType;
				   	internalID = zwave_dev_num;
					Description = SCObj.Name .. " Scene Controller";
				   	UpnpDevFilename = SCObj.DeviceXml;
				   	UpnpImplFilename =  "I_GenGenSceneController.xml";
					RoomNum = v.room_num;
					StateVariables = SID_SCENECONTROLLER .. ",PeerID=" .. zwave_dev_num .. "\n" ..
					                 SID_SCENECONTROLLER .. ",ShowSingleDevice=1" },0)
			end
		end
	end
	if count > 0 then
		log("Peer devices created: ", count, " reloading.")
		luup.call_action(SID_HAG, "Reload", {}, 0)
	end
	VLog("Finish CreatePeerDevices()")
end


function CheckInvisible(devNumString)
    VEntry()
	local zwave_dev_num = tonumber(devNumString)
	local retry = false
	if zwave_dev_num < 0 then
		zwave_dev_num = -zwave_dev_num
		retry = true
	end
	local ShowSingleDevice = luup.variable_get(SID_SCENECONTROLLER,"ShowSingleDevice",zwave_dev_num)
	if type(ShowSingleDevice) ~= "string" or (ShowSingleDevice ~= "1" and ShowSingleDevice ~= "0") then
		ShowSingleDevice = "1"
		DLog("  CheckInvisible: Setting ShowSingleDevice for the first time.")
		luup.variable_set(SID_SCENECONTROLLER,"ShowSingleDevice",ShowSingleDevice,zwave_dev_num)
	end
	local invisible = luup.attr_get("invisible",zwave_dev_num)
	local Invisible = luup.attr_get("Invisible",zwave_dev_num)
    DLog("  CheckInvisible: zwave_dev_num=", zwave_dev_num, " ShowSingleDevice=", ShowSingleDevice, " invisible=", invisible, " retry=", retry)
	if ShowSingleDevice == "0" then
  		if luup.version_major < 7 then
			ShowSingleDevice = "" -- invisible should be 1 or empty in UI5
		end
		retry = false -- no need to retry below if we are allowing the z-wayve device to be seen.
	end
	if invisible ~= ShowSingleDevice then
		-- UI5 bug has capitalization issues with "I/invisible" so set it both ways.
		DLog("  CheckInvisible: zwave_dev_num=", zwave_dev_num, ": Setting invisible and Invisible to ", ShowSingleDevice)
		luup.attr_set("invisible",ShowSingleDevice,zwave_dev_num)
		luup.attr_set("Invisible",ShowSingleDevice,zwave_dev_num)
	end
	-- Ugly hack: Due to a bug/misfeature in UI7 which keeps resetting "invisible" to 0, we need to retry again after the initial scan
	-- SetTuningParameters calls CheckInvisible with a negative number to signify a one-time retry through call_delay.
	-- if retry then
	--  luup.call_delay("CheckInvisible",5,tostring(zwave_dev_num),true)
	-- end
end

--
-- Called in the second pass of initialization after the peer device is created to connect it
-- back to the ZWave device
--
-- ZWave device --> PeerID = Peer Device
-- Peer device --> id = ZWave device
--
function ConnectPeerDevice(peer_dev_num)
	DEntry()
	local v2 = luup.devices[peer_dev_num]
	local candidate = Devices[v2.device_type]
	if candidate then
		SCObj = candidate
		DLog("  ConnectPeerDevice: peer_dev_num=", peer_dev_num, " Found device: ", SCObj.Name)
	else
		ELog("ConnectPeerDevice: Device", peer_dev_num, " type ", v2.device_type, " not supported.")
		return
	end
	local newDevice = false;
	if v2.device_type == SCObj.DevType and v2.device_num_parent == 0 then
		local zwave_dev_num = tonumber(v2.id);
		local v = luup.devices[zwave_dev_num]
		if v == nil then
			log("Device ", zwave_dev_num, " for peer device ", peer_dev_num, " no longer exists. Deleting")
			ForAllModes(peer_dev_num, function(mode, screen, virtualButton)
				if mode.zWaveSceneId then
					for i = 1, #mode do
						RemoveDeviceActuatorConf(mode[i].device, mode.zWaveSceneId, mode.offZWaveSceneId)
					end
				end
			end )
			ZWaveSceneIdCacheList[zwave_dev_num] = nil
		   	luup.call_action(SID_HAG,"DeleteDevice", {DeviceNum = peer_dev_num}, 0);
		else
			CheckInvisible(-zwave_dev_num)
			SCObj.SetTuningParameters(zwave_dev_num, peer_dev_num)
			GetTuningParameter("VerboseLogging", VerboseLogging, zwave_dev_num, "SceneController_VerboseLoggingChange");
			peerID = luup.variable_get(SID_SCENECONTROLLER,"PeerID",zwave_dev_num)
		    if peerID == "Pending" then
				log("Connecting Device ", zwave_dev_num, "(ZWave node ", v.id, ") to peer device ", peer_dev_num)
		   		luup.variable_set(SID_SCENECONTROLLER,"PeerID",peer_dev_num,zwave_dev_num)
				if IsVeraPrimaryController() then
					SCObj.SetDefaultLabels(peer_dev_num);
				end
				newDevice = true;
			elseif tonumber(peerID) ~= peer_dev_num then
				ELog("ZWave device ", zwave_dev_num, " PeerID is ", tostring(peerID), ", should have been ", peer_dev_num, ". Deleting peer device ", peer_dev_num)
		   		luup.call_action(SID_HAG,"DeleteDevice", {DeviceNum = peer_dev_num}, 0);
				return;
			end
			local zpeer = luup.variable_get(SID_SCENECONTROLLER,"PeerID",peer_dev_num)
			if not zpeer then
				zpeer = luup.variable_get(SCObj.OldServiceId,"PeerID",peer_dev_num)
				if zpeer then 
					MigrateDeviceToNewServiceId(peer_dev_num)
				end
			end
			if zpeer ~= tostring(zwave_dev_num) then
				luup.variable_set(SID_SCENECONTROLLER, "PeerID", tostring(zwave_dev_num), peer_dev_num)
			end
			if IsVeraPrimaryController() then
              VariableWatch("SceneController_ConfiguredChanged",SID_HADEVICE,"Configured",zwave_dev_num,"")
			  VariableWatch("SceneController_CommFailureChanged",SID_HADEVICE,"CommFailure",zwave_dev_num,"")
			  PropagateCommFailure(zwave_dev_num, peer_dev_num)
			end
			-- Rename the Z-Wave device to match the peer device
			local zwave_name = luup.attr_get("name",zwave_dev_num);
			local peer_name = luup.attr_get("name",peer_dev_num);
			local desired_name = peer_name .. " Z-Wave";
			if zwave_name ~= desired_name then
				luup.attr_set("name", desired_name, zwave_dev_num);
			end
			local currentScreen = luup.variable_get(SID_SCENECONTROLLER, CURRENT_SCREEN, peer_dev_num)
			if not currentScreen then
				currentScreen = SCObj.DefaultScreen
			end
			if IsVeraPrimaryController() then
				if newDevice then
					-- doTimeout, force, not indicatorOnly
					SetScreen(peer_dev_num,currentScreen, true, true, false);
				else
					-- doTimeout, no force, indicatorOnly
					SetScreen(peer_dev_num,currentScreen, true, false, true);
				end
			end
		end
	else
		ELog("Incorrect peer device ", peer_dev_num)
	end
	VLog("Finish ConnectPeerDevice()")
end

-- Given either the Z-Wave or the peer device number, GetZWaveNode returns the Z-Wave node ID and the Z-Wave device number.
function GetZWaveNode(peer_dev_num)
  	local veraZWaveNode, ZWaveNetworkDeviceId = GetVeraIDs()
	peer_dev_num = tonumber(peer_dev_num)
	if peer_dev_num == ZWaveNetworkDeviceId then
		return veraZWaveNode, ZWaveNetworkDeviceId
	end
	local v2 = luup.devices[peer_dev_num]
	if v2 == nil then
	    ELog("GetZWaveNode: cannot find device for peer_dev_num=", peer_dev_num)
		return nil, nil
	end
	local zwave_dev_num = tonumber(v2.id);
	if v2.device_num_parent == ZWaveNetworkDeviceId then
	    -- Caller passed the ZWave device number.
		return zwave_dev_num, peer_dev_num
	end
	-- caller passed the peer device number
	local v = luup.devices[zwave_dev_num]
	if v == nil then
	    ELog("GetZWaveNode: cannot find device for zwave_dev_num=", peer_dev_num)
		return nil, nil
	end
	local node_id = tonumber(v.id)
	return node_id, zwave_dev_num
end

-- Given either the Z-Wave or the peer device number, GetPeerDevNum returns the peer device number.
function GetPeerDevNum(dev_num)
	local v2 = luup.devices[dev_num]
	if v2 == nil then
	    ELog("GetPeerDevNum: cannot find device for dev_num=", dev_num)
		return nil
	end
	if tonumber(v2.device_num_parent) == 1 then
	    -- Caller passed the ZWave device number.
		local peer_dev_num_str = luup.variable_get(SID_SCENECONTROLLER,"PeerID",dev_num)
		local peer_dev_num = tonumber(peer_dev_num_str)
		return peer_dev_num
	end
	-- caller passed the peer device number
	return dev_num
end

local IsPrimaryController
function IsVeraPrimaryController()
	if IsPrimaryController == nil then
		if param.SCENE_CTRL_UseWithSlaveController > 0 then
		   IsPrimaryController = true
		else
			IsPrimaryController = false
			for k,v in pairs(luup.devices) do
				if v.device_type == DEVTYPE_ZWN then
					local role = luup.variable_get(SID_ZWN, "Role", k)
					local masterslave, sis, pri = tostring(role):match("(%a+) SIS:(%a+) PRI:(%a+)")
					if pri ~= "NO" then
						IsPrimaryController = true
					end
					DLog("  IsVeraPrimaryController: Found Z-Wave network=", k, " Role=", role, " masterslave=", masterslave, " sis=", sis, " pri=", pri, " IsPrimaryController=", IsPrimaryController)
					break
				end
			end
		end
		if not IsPrimaryController then
			log("This is not the primary controller. Most functions disabled.")
		end
	end
	return IsPrimaryController
end

function SetConfigurationOption(name, dev_num, node_id, option, value, delay)
	if not delay then
		delay = 0
	end
	local data = "112 4 " .. tostring(option) .. " 1 " .. tostring(value)
    EnqueueZWaveMessage("SetConfigurationOption("..name..":"..tostring(option).."="..tostring(value)..")"..node_id, node_id, data, dev_num, delay)
end

timeoutSequenceNumber = 0
timeoutList = {}
function SceneController_ScreenTimeout(data)
	if IsVeraPrimaryController() then
		local peerStr, seqStr, timeoutScreen = data:match("^(%d+),(%d+),(.+)$")
		local peer_dev_num = tonumber(peerStr)
		local sequenceNumber = tonumber(seqStr)
		if peer_dev_num and sequenceNumber and timeoutList[peer_dev_num] == sequenceNumber then
			DLog("ScreenTimeout: peer_dev_num=", peer_dev_num, " sequenceNumber=", sequenceNumber, " timeoutScreen=", timeoutScreen);
			-- DoTimeout, not force, not indicatorOnly
			SetScreen(peer_dev_num, timeoutScreen, true, false, false);
			RunZWaveQueue("ScreenTimeout", 0)
		else
			DLog("ScreenTimeout: Ignore stale ScreenTimeout(", data, ") Current timeoutSequenceNumber=", timeoutSequenceNumber);
		end
	end
end

function SceneController_SetScreenTimeout(peer_dev_num, screen, timeoutEnable, timeoutScreen, timeoutSeconds)
	DEntry()
	if IsVeraPrimaryController() then
		local enable = timeoutEnable == 1 or timeoutEnable == "1" or timeoutEnable == "true" or timeoutEnable == "yes" or timeoutEnable == true	-- FOr UPnP boolean spec compatibility
		luup.variable_set(SID_SCENECONTROLLER, "TimeoutEnable_" .. screen, tostring(enable), peer_dev_num)
		luup.variable_set(SID_SCENECONTROLLER, "TimeoutScreen_" .. screen, timeoutScreen, peer_dev_num)
		luup.variable_set(SID_SCENECONTROLLER, "TimeoutSeconds_" .. screen, tostring(timeoutSeconds), peer_dev_num)
		local currentScreen = luup.variable_get(SID_SCENECONTROLLER, CURRENT_SCREEN, peer_dev_num)
		if currentScreen == screen then
			SetScreenTimeout(peer_dev_num, screen, true)
			RunZWaveQueue("SetScreenTimeout", 0);
		end
	end
end

-- Update the timeout for the current screen to go to the next screen if enabled
-- doTimeout is true to enable and override all previous timeouts, 
-- false to disable and override all previous timeouts,
-- nil to do nothing
function SetScreenTimeout(peer_dev_num, screen, doTimeout)
	DEntry()
	if doTimeout ~= nil then
		-- Whatever we do below, always make any previous timer stale
		timeoutSequenceNumber = timeoutSequenceNumber + 1
		timeoutList[peer_dev_num] = timeoutSequenceNumber
		if doTimeout then
			local enable = luup.variable_get(SID_SCENECONTROLLER, "TimeoutEnable_" .. screen, peer_dev_num)
			local seconds = luup.variable_get(SID_SCENECONTROLLER, "TimeoutSeconds_" .. screen, peer_dev_num);
			local timeoutScreen = luup.variable_get(SID_SCENECONTROLLER, "TimeoutScreen_" .. screen, peer_dev_num);
			if seconds == nil then
				seconds = 0
			end
			seconds = tonumber(seconds)
			if enable == "true" and seconds > 0 and timeoutScreen then
				DLog("SetScreenTimeout: Setting timeout timer for ", seconds, " seconds. peer_dev_num=", peer_dev_num, " current screen=", screen, " timeoutScreen=", timeoutScreen, " timeoutSequenceNumber=", timeoutSequenceNumber);
				luup.call_delay("SceneController_ScreenTimeout", tonumber(seconds), tostring(peer_dev_num)..","..tostring(timeoutSequenceNumber)..","..timeoutScreen, true);
			end
		end
	end
end

function SceneController_SetNumLines(peer_dev_num, screen, lines)
	if IsVeraPrimaryController() then
		DLog("SceneController_SetNumLines: peer_dev_num=", peer_dev_num, " screen=", screen, " lines=", lines);
		local oldLines = luup.variable_get(SID_SCENECONTROLLER, "NumLines_" .. screen, peer_dev_num)
		if oldLines then
			oldLines = tonumber(oldLines)
		else
			oldLines = SCObj.NumButtons
		end
		lines = tonumber(lines)
		if lines < SCObj.NumButtons then
			lines = SCObj.NumButtons
		elseif lines > SCObj.NumButtons*2 then
			lines = SCObj.NumButtons*2
		end
		luup.variable_set(SID_SCENECONTROLLER, "NumLines_" .. screen, tostring(lines), peer_dev_num)
		local currentScreen = luup.variable_get(SID_SCENECONTROLLER, CURRENT_SCREEN, peer_dev_num)
		if currentScreen == screen and oldLines ~= lines then
			-- doTimeout, force, not indicatorOnly
			SetScreen(peer_dev_num, currentScreen, true, true, false);
			RunZWaveQueue("SetNumLines", 0);
		end
	end
end

-- Mode strings consist or Prefix{newScreen:}?S?{zWaveSceneId@{offZWaveSceneId@}?}|C?{entry}*
-- Prefix is M for momentary, T for Toggle, etc.
-- Prefix S is legacy "direct toggle" and should not be confused with S as the second character.
-- newScreen is a letter/digit such as C3 for Custom 3 or P4 for Preset 4
-- The S flag indicates that all associated devices are scene capable
--   and is optionally followed by zWaveSceneId@ and offZWaveSceneId@
-- The C flag indicats Cooper RFWC5-style Scen/Config pair setting
-- Scene-capable modes are a ; separated list of 0 or more deviceNum,level,dimmingDuration triplets
-- Cooper configuration modes are a ; separated list of 0 or more deviceNum,level pairs
-- Non-scene capabile modes are a ; separated list of 0 or more deviceNums
function ParseModeString(str)
	VEntry()
	local mode = {};
	if not str or (str == "") then
	    str = "M"
	end
    mode.prefix = str:sub(1,1)
	if mode.prefix == "S" then
		-- Legacy direct toggle. Change into T
		mode.prefix = "T"
	end
	str = str:sub(2)
	local newScreen, remaining = str:match("^(%a%d):+(.*)$") -- :+ to deal with old bug
	if newScreen then
		mode.newScreen = newScreen
		str = remaining
	elseif mode.prefix == "N" then
	    -- Legacy newScreen without :
		mode.prefix = "M"
		mode.newScreen = str
		return mode
	end
	local i = 1;
	local char2 = str:sub(1,1)
	if char2 == "S" or char2 == "C" then
		mode.sceneControllable = true
		str = str:sub(2)
		local sceneIdStr, rest = string.match(str, "^(%d+)@(.*)$")
		if sceneIdStr then
			mode.zWaveSceneId = tonumber(sceneIdStr)
			str = rest;
			local offZWaveSceneIdStr, offRest = string.match(str, "^(%d+)@(.*)$")
			if offZWaveSceneIdStr then
				mode.offZWaveSceneId = tonumber(offZWaveSceneIdStr)
				str = offRest;
			end
		end
	end
	if not string.match(str,";$") then
		str = str .. ";"
	end
	while true do
		local device, level, dimmingDuration, rest = string.match(str, "^(%d+),(%d+),(%d+),?;(.*)")
		if device then
	    	mode[i] = {device=tonumber(device), level=tonumber(level), dimmingDuration=tonumber(dimmingDuration)};
		else
			device, level, rest = string.match(str, "^(%d+),(%d+);(.*)")
			if device then
	    		mode[i] = {device=tonumber(device), level=tonumber(level)};
			else
				device, rest = string.match(str, "^(%d+);(.*)")
				if device then
	    			mode[i] = {device=tonumber(device)};
				else
					break
				end
			end
		end
		str = rest
		i = i + 1
	end
	return mode;
end

function GenerateModeString(mode)
	if not mode then
		mode = {}
	end
	if not mode.prefix then
		mode.prefix = "M"
	end
	local str=mode.prefix
	if mode.newScreen then
		str = str .. mode.newScreen .. ":"
	end
	if #mode > 0 then
		if mode.sceneControllable then
			str = str .. "S"
			if mode.zWaveSceneId then
				str = str .. mode.zWaveSceneId .. "@"
				if mode.offZWaveSceneId then
					str = str .. mode.offZWaveSceneId .. "@"
				end
			end
		end
		local first = true
		for i = 0, #mode do
			if mode[i] and mode[i].device then
				if not first then
					str = str .. ";"
				end
				first = false
				if mode[i].dimmingDuration then
					str = str .. mode[i].device .. "," .. mode[i].level .. "," .. mode[i].dimmingDuration
				elseif mode[i].level then
					str = str .. mode[i].device .. "," .. mode[i].level
				else
					str = str .. mode[i].device
				end
			end
		end
	end
	return str;
end

function SetIndicatorValue(peer_dev_num, indicator, force)
	if SCObj.HasIndicator then
	    DLog("SetIndicatorValue peer_dev_num=", peer_dev_num," indicator=", indicator, " force=", force)
		local node_id, zwave_dev_num = GetZWaveNode(peer_dev_num)
		if not node_id then
			ELog("SetIndicatorValue: bad peer_dev_num=", peer_dev_num)
			return
		end
		local previous_indicator_string = luup.variable_get(SID_SCENECONTROLLER, CURRENT_INDICATOR, peer_dev_num)
		local previous_indicator = tonumber(previous_indicator_string)
		if force or previous_indicator ~= indicator then
			local delay = 0
			if param.SCENE_CTRL_IndicatorDelay > 0 then
				if force then
					delay = param.SCENE_CTRL_IndicatorDelay * SCObj.NumButtons
				else
					local delayDiff = bit.bxor(previous_indicator, indicator)
					while delayDiff ~= 0 do
						if bit.band(1, delayDiff) ~= 0 then
						   delay = delay + param.SCENE_CTRL_IndicatorDelay	
						end
						delayDiff = bit.rshift(delayDiff, 1)
					end
				end
			end
			-- The * at the start of the label indicates that this can replace an existing command with a similar node ID and label (up to the first "(")
			-- We avoid merging in force mode to resolve redraw issues on Evolve LCD1.
			local label = "SetIndicator("..indicator..")"..node_id
			if param.SCENE_CTRL_IndicatorDelay == 0 or not force then
				label = "*" .. label
			end 
			EnqueueZWaveMessage(label, node_id,  "0x87 0x01 "..indicator, zwave_dev_num, delay);
			luup.variable_set(SID_SCENECONTROLLER, CURRENT_INDICATOR, tostring(indicator), peer_dev_num)
		end
	end
end

-- Return a score between 0 and 1 indicating how close the devices for this mode match the target levels. Higher is closer.
function GetDeviceScoreForMode(mode, peer_dev_num, screen)
	local score = 1
	local count = 0
	for i = 1, #mode do
		local device = mode[i].device
		local status, lastUpdate, service, variable = GetDeviceStatus(device)
		if VerboseLogging > 0 then
			DLog("GetDeviceScoreForMode: monitored device=", device, " status=", status, " lastUpdate=", os.date(nil,tonumber(lastUpdate)), " service=", service, " variable=", variable)
		end
		if status ~= nil then
			local target = 100;
			if mode[i].level ~= nil then
				target = mode[i].level
			end
			count = count + 1
			score = score + ((target - status) ^ 2)
			local context = tostring(peer_dev_num) .. "," .. screen
			VariableWatch("SceneController_WatchedIndicatorDeviceChanged", service, variable, device, context)
		end
	end
	if count == 0 then
		return 0
	else
		return 1 / score
	end
end


function ChooseBestFromMultiState(peer_dev_num, screen, virtualButton, mode)
    DEntry()
	local states = tonumber(mode.prefix)
	local bestState = 1
	local bestScore	= 0
	for state = 1, states do
		local curButton = virtualButton+(state-1)*1000
		if state > 1 then
			modeStr = luup.variable_get(SID_SCENECONTROLLER,"Mode_"..screen.."_"..curButton,peer_dev_num)
			if modeStr == nil then
				modeStr = "M"
			end
			mode = ParseModeString(modeStr)
		end
		local score = GetDeviceScoreForMode(mode, peer_dev_num, screen)
		DLog("  ChooseBestFromMultiState:    state=", state, " curButton=", curButton, " mode=", mode, " score=", score)
		if score > bestScore then
			bestState = state
		    bestScore = score
		end
	end
	if bestScore <= 0 then
		local oldState = luup.variable_get(SID_SCENECONTROLLER,"State_"..screen.."_"..virtualButton, peer_dev_num)
		if not oldState then
			oldState = "1"
		end
		bestState = tonumber(oldState)
	else
		luup.variable_set(SID_SCENECONTROLLER,"State_"..screen.."_"..virtualButton, tostring(bestState), peer_dev_num)
	end
	DLog("  ChooseBestFromMultiState: bestState=", bestState, " bestScore=", bestScore)
	return bestState
end

function SetIndicator(peer_dev_num, screen, force)
	DEntry()
	if SCObj.HasIndicator then
		if IndicatorLocks[peer_dev_num] and IndicatorLocks[peer_dev_num] > 0 then
			-- Handle a nasty race condition:
			-- 1. Cooper RFWC5 does an "All off" operation which controls a Cooper dimmer
			-- 2. Cooper dimmer sends Hail to vera
			-- 3. Vera queries dimmer status, determines it is off.
			-- 4. GenGenSceneController detects that the dimmer's status has changed, calls SetIndicator with only one bit cleared
			-- 5. This messes up the "Indicator Get/Indicator Report" operation done when GenGenSceneController detects the Basic Set Off.
			-- We solve this by temporarily deferring any SetIndicator operations on the given device while a Indicator Get is in progress.
			DLog("  SetIndicator. Quick return because IndicatorLocks[", peer_dev_num, "]=", IndicatorLocks[peer_dev_num])
			IndicatorLocks[peer_dev_num] = 2
			return
		end
	    local indicator = 0
		local threshold = 5
		local bestXbutton = 0
		local bestXscore = 0
		local xsCeneFound = false
		local numLines, scrollOffset = GetNumLinesAndScrollOffset(peer_dev_num, screen)
		local node_id, zwave_dev_num = GetZWaveNode(peer_dev_num)
		local oldIndicator = luup.variable_get(SID_SCENECONTROLLER, CURRENT_INDICATOR, peer_dev_num)
		if oldIndicator then
			oldIndicator = tonumber(oldIndicator)
		else
			oldIndicator = 0
		end
		for physicalButton = 1, SCObj.NumButtons do
			local virtualButton = physicalButton+scrollOffset
		    local highlighted = false;
			if numLines == SCObj.NumButtons or ((physicalButton ~= 1 or scrollOffset == 0) and (physicalButton ~= SCObj.NumButtons or scrollOffset == numLines-SCObj.NumButtons)) then
				local modeStr = luup.variable_get(SID_SCENECONTROLLER,"Mode_"..screen.."_"..virtualButton,peer_dev_num)
				local mode  = ParseModeString(modeStr)
				if #mode == 0 then
					highlighted = bit.band(oldIndicator,SCObj.PhysicalButtonToIndicator(physicalButton, true)) ~= 0
				elseif mode.prefix >= "2" and mode.prefix <= "9" then
					local oldModeStr = GetModeStr(peer_dev_num, screen, virtualButton)
					local oldState = luup.variable_get(SID_SCENECONTROLLER,"State_"..screen.."_"..virtualButton,peer_dev_num)
					if not oldState then
						oldState = "1"
					end
					oldState = tonumber(oldState)
					local state
					if SCObj.HasScreen then
						local oldLabels, oldFonts, oldAligns = {}, {}, {}
						ChooseLabelFontAndAlign(peer_dev_num, screen, 1, virtualButton, oldState, oldLabels, oldFonts, oldAligns)
						local newLabels, newFonts, newAligns = {}, {}, {}
						state = ChooseLabelFontAndAlign(peer_dev_num, screen, 1, virtualButton, nil, newLabels, newFonts, newAligns)
						if (oldLabels[1] ~= newLabels[1] or oldFonts[1] ~= newFonts[1] or oldAligns[1] ~= newAligns[1]) then
							EVLCDWrapStrings(newLabels, newFonts, newAligns, node_id, zwave_dev_num, physicalButton, physicalButton, SCREEN_MD.NoChange)
						end
					else
						state = ChooseBestFromMultiState(peer_dev_num, screen, virtualButton, mode)
					end
					if state ~= oldState or force then
						local node_id, zwave_dev_num = GetZWaveNode(peer_dev_num)
						local newModeStr, nextState = GetModeStr(peer_dev_num, screen, virtualButton)
						UpdateAssociationForPhysicalButton(zwave_dev_num, screen, force, oldModeStr, newModeStr, physicalButton, virtualButton+(nextState-1)*1000)
					end
				elseif mode.prefix == "T" then
					local num_off = 0
					local num_on = 0
					for i = 1, #mode do
						local device = mode[i].device
						local status, lastUpdate, service, variable = GetDeviceStatus(device)
						if VerboseLogging > 0 then
							DLog("  monitored device=", device, " threshold=", threshold, " status=", status, " lastUpdate=", os.date(nil,tonumber(lastUpdate)), " service=", service, " variable=", variable)
						end
						if status ~= nil then
							if status >= threshold then
								num_on = num_on + 1
							else
								num_off = num_off + 1
							end
							local context = tostring(peer_dev_num) .. "," .. screen
							VariableWatch("SceneController_WatchedIndicatorDeviceChanged", service, variable, device, context)
						end
					end
					if num_on >= num_off and num_on > 0 then
						highlighted = true
					end
				    DLog("  button=", physicalButton, " mode=", modeStr, " num_on=", num_on, " num_off=", num_off, " highlighted=", highlighted)
				elseif mode.prefix == "X" then
					if #mode > 0 then
						local score = GetDeviceScoreForMode(mode, peer_dev_num, screen)
						if score > bestXscore then
							bestXscore = score
							bestXbutton = physicalButton
						end
					else
				   		local scene = luup.variable_get(SID_SCTRL, "sl_SceneActivated", peer_dev_num)
						if scene then
							scene = tonumber(scene)
							local sceneButton = ((scene-1) % SCObj.NumButtons) + 1
							if scene >= 300 then
								sceneButton = sceneButton + math.floor((scene-200)/100) * SCObj.NumButtons
							end
							highlighted = sceneButton == virtualButton
						else
							highlighted = false
						end
						if highlighted then
							xsCeneFound = true
						end
					end
				end
			end
			if highlighted then
				indicator = bit.bor(indicator,SCObj.PhysicalButtonToIndicator(physicalButton, true))
			end
		end
		if bestXbutton > 0 and not xsCeneFound then
			indicator = bit.bor(indicator,SCObj.PhysicalButtonToIndicator(bestXbutton, true))
		end
		DLog("  New indicator value=", indicator)
		SetIndicatorValue(peer_dev_num, indicator, force)
	end
end

-- This is a variable watch trigger which gets called whenever a device status changes which
-- may affect the highlighting on the screen. It is called in a call_delay since it may call SendData
function SceneController_WatchedIndicatorDeviceChanged(device, service, variable, value_old, value_new, context)
	DEntry()
	if IsVeraPrimaryController() then
		local ix1, ix2, peer_string, screen = context:find("(%d+),(%w+)")
		local peer_dev_num = tonumber(peer_string)
		local curScreen = GetCurrentScreen(peer_dev_num)
		DLog("  WatchedIndicatorDeviceChanged: context=", context, " peer_dev_num=", peer_dev_num, " screen=", screen, " curScreen=", curScreen);
		if not SCObj.HasScreen or curScreen == screen then
			SetIndicator(peer_dev_num, screen, false)
		end
		RunZWaveQueue("WatchedIndicatorDeviceChanged", 250) -- 250ms delay to avoid a "cannot get lock" crash as job is in progress
	end
end

function GetNumLinesAndScrollOffset(peer_dev_num, screen)
	local numLines = luup.variable_get(SID_SCENECONTROLLER, NUMLINES_VAR .. "_"  .. screen, peer_dev_num)
	local scrollOffset = 0
	if numLines then
		numLines = tonumber(numLines)
		if numLines < SCObj.NumButtons then
			numLines = SCObj.NumButtons
		end
		scrollOffset = luup.variable_get(SID_SCENECONTROLLER, SCROLLOFFSET_VAR .. "_"  .. screen, peer_dev_num)
		if scrollOffset then
			scrollOffset = tonumber(scrollOffset)
		else
			scrollOffset = 0
		end
		local maxScroll = numLines - SCObj.NumButtons
		if scrollOffset < 0 then
			scrollOffset = 0
		elseif scrollOffset > maxScroll then
			scrollOffset = maxScroll
		end
	else
		numLines = SCObj.NumButtons
	end
	return numLines, scrollOffset
end

-- being used either by another screen or button in this controller or by another controller
-- operating on the same target device. We only create a set of unused Z-Wave scene Ids up until
-- the maximum seen so far. If the given Z-Wave scen Id is greter than the current max, then
-- we mark the next N Z-Wave cenes Ids up to the new one-1 as unused. Otherwise, we mark
-- the given Z-Wave scene Id used.
-- Note. The first SCObj.LastFixedSceneId Z-Wave Scene Iss are "default" scene IDs matching the
-- Z-Wave scene group if the selection algorithm fails.
function MarkZWaveSceneIdUsed(zWaveSceneId, sceneSet)
	if zWaveSceneId and zWaveSceneId > SCObj.LastFixedSceneId then
		if zWaveSceneId > sceneSet.max then
			for i = sceneSet.max+1, zWaveSceneId-1 do
				sceneSet[i] = true
			end
			sceneSet.max = zWaveSceneId
		else
			sceneSet[zWaveSceneId] = nil
		end
		return true
	end
	return false
end

-- Helper function for SelectZWaveSceneId to choose an available Z-Wave scene Id from the remaining sceneSet
-- Take the current Z-Wave scene ID as a hint and reuse it if it is still available. Otherwise, if the
-- Z-Wave scene Ids have not reached the max of 255, then use the next higher number, otherwise choose
-- one scene ID from the set
-- Note, some Evolve dimmers cannot accept scene ID's > 60, hence the hack below
function pickSceneId(current, sceneSet, needSceneId, defaultScene)
	DEntry()
	if not needSceneId then
		return defaultScene
	end
	if current and current > SCObj.LastFixedSceneId and current <= 60 and MarkZWaveSceneIdUsed(current, sceneSet) then
		return current
	end
	for k, v in pairs(sceneSet) do
		if k ~= "max" then
			sceneSet[k] = nil
			return k
		end
	end
	if sceneSet.max < 255 then
		sceneSet.max = sceneSet.max + 1
		return sceneSet.max
	end
	return defaultScene
end

-- Iterate through all existing modes in all screens of a given device.
-- Passes the mode(object), the screen(string) and the virtual button(number) to the function.
-- The algorithm here is simialr to MigrateDeviceToNewServiceId
function ForAllModes(peer_dev_num, func)
	local ScreenList = SCObj.ScreenList
	for prefix, numScreens in pairs(ScreenList) do
		for screenNum = 1, numScreens do
			local screen = prefix .. screenNum
			local numLines = SCObj.NumButtons
			local lineStep = 1
			if prefix == "C" then
				local numLinesStr = luup.variable_get(SID_SCENECONTROLLER, "NumLines_" .. screen, peer_dev_num)
				if numLinesStr then
					numLines = tonumber(numLinesStr)
				end
			elseif prefix == "T" then
				lineStep = 4 -- Just do lines 1 and 5 for temperature screens
			end
			for line = 1, numLines, lineStep do
				local modeStr = luup.variable_get(SID_SCENECONTROLLER,"Mode_"..screen.."_"..line, peer_dev_num)
				if modeStr then
					local mode = ParseModeString(modeStr)
					func(mode, screen, line)
					if mode.prefix >= "2" and mode.prefix <= "9" then
						local numStates = tonumber(mode.prefix)
						for state=2, numStates do
							local virtualButton = line + (state-1)*1000
							local modeStr2 = luup.variable_get(SID_SCENECONTROLLER,"Mode_"..screen.."_"..virtualButton, peer_dev_num)
							if modeStr2 then
								func(ParseModeString(modeStr2), screen, virtualButton)
							end
						end
					end
				end
			end
		end
	end
end

-- Iterate through all scene controller variables for the given device number
-- Passes the name of the variable (name) and the device number (integer) to the function. 
-- Not all variables may exist but the list is comprehensive.
-- The algorithm here is similar to but more inclusive than ForAllModes
function ForAllVariables(peer_dev_num, func)
	VEntry()
	local ScreenList = SCObj.ScreenList
	local varList = {"PeerID", "ShowSingleDevice", "CurrentScreen", "CurrentIndicator"}
	for i, v in ipairs(varList) do
		func(v, peer_dev_num)
	end 
	for prefix, numScreens in pairs(ScreenList) do
		for screenNum = 1, numScreens do
			local screen = prefix .. screenNum
			local numLines = SCObj.NumButtons
			local lineStep = 1
			func("TimeoutEnable_"..screen, peer_dev_num)
			func("TimeoutScreen_"..screen, peer_dev_num)
			func("TimeoutSeconds_"..screen, peer_dev_num)
			if prefix == "C" then
				local numLinesKey = "NumLines_" .. screen
				local numLinesStr = func(numLinesKey, peer_dev_num)
				if numLinesStr then
					numLines = tonumber(numLinesStr)
				end
			elseif prefix == "T" then
				lineStep = 4 -- Just do lines 1 and 5 for temperature screens
				func("TemperatureDevice_"..screen, peer_dev_num)
			end
			for line = 1, numLines, lineStep do
				local modeStr = func("Mode_"..screen.."_"..line, peer_dev_num)
				func("Label_"..screen.."_"..line, peer_dev_num)
				func("Font_"..screen.."_"..line, peer_dev_num)
				func("Align_"..screen.."_"..line, peer_dev_num)
				if modeStr then
					local mode = ParseModeString(modeStr)
					if mode.prefix >= "2" and mode.prefix <= "9" then
						local numStates = tonumber(mode.prefix)
						for state=2, numStates do
							local virtualButton = line + (state-1)*1000
							func("Mode_"..screen.."_"..virtualButton, peer_dev_num)
							func("Label_"..screen.."_"..virtualButton, peer_dev_num)
							func("Font_"..screen.."_"..virtualButton, peer_dev_num)
							func("Align_"..screen.."_"..virtualButton, peer_dev_num)
						end
					end
				end
			end
		end
	end
end

-- Remove the old Z-Wabe scene Id from the actuator configuration list and add the new Z-Wave scene Id.
-- This also actually sets the actuator configuration.
function UpdateActConfList(actConfList, oldZWaveSceneId, newZWaveSceneId, controller_dev_num, target, virtualButton, level, screen, act)
	DEntry()
	local zWaveSceneIdCache = ZWaveSceneIdCacheList[controller_dev_num]
	if not zWaveSceneIdCache then
		zWaveSceneIdCache = {}
		ZWaveSceneIdCacheList[controller_dev_num] = zWaveSceneIdCache
	end
	local oldCache = zWaveSceneIdCache[oldZWaveSceneId]
	if not oldCache then
		oldCache = {}
	end 
	if oldZWaveSceneId ~= newZWaveSceneId or oldCache.level ~= level or oldCache.dimmingDuration ~= target.dimmingDuration then
		if oldZWaveSceneId and actConfList[oldZWaveSceneId] and actConfList[oldZWaveSceneId].controller == controller_dev_num then
			actConfList[oldZWaveSceneId] = nil
			zWaveSceneIdCache[oldZWaveSceneId] = nil
	   	end
		if newZWaveSceneId then
			local target_node_id = GetZWaveNode(target.device)
			actConfList[newZWaveSceneId]={controller=controller_dev_num, screen=screen, button=virtualButton, level=level, dimmingDuration=target.dimmingDuration}
			zWaveSceneIdCache[newZWaveSceneId]={screen=screen, button=virtualButton, act=act}
			EnqueueZWaveMessage("UpdateActConfList("..newZWaveSceneId..","..level..","..target.dimmingDuration..")"..target_node_id, target_node_id,  "44 1 ".. newZWaveSceneId .. " ".. target.dimmingDuration .. " 128 ".. level, target.device, 0);
		end
	end
end

-- Select a zWaveSceneId and possibly an off zWaveSceneId for a given button and screen which is
-- controlling only scene-capable devices. The same scene ID is multicast to all devices
-- associated with that group (button) so the scene ID must be unique for all screens
-- and buttons of this controller and all scenes used by any controllers operating on this
-- device.
function SelectZWaveSceneId(peer_dev_num, screen, virtualButton, physicalButton, modeStr)
	DEntry("SelectZWaveSceneId")
	local mode = ParseModeString(modeStr)
	local controller_node_id, controller_dev_num = GetZWaveNode(peer_dev_num)
	local oldZWaveSceneId = mode.zWaveSceneId
	local oldOffZWaveSceneId = mode.offZWaveSceneId
	if #mode == 0 then
		mode.sceneControllable = false
		mode.zWaveSceneId = nil
		mode.offZWaveSceneId = nil
	elseif mode.sceneControllable then	
		local needSceneId = false;
		local defaultSceneId = physicalButton;
		local sceneSet = {max=SCObj.LastFixedSceneId}
		-- First mark off all scene IDs used for any screens of this controller
		ForAllModes(peer_dev_num, function(mode2, screen2, virtualButton2)
			if screen ~= screen2 or virtualButton ~= virtualButton2 then
				MarkZWaveSceneIdUsed(mode2.zWaveSceneId, sceneSet)
				MarkZWaveSceneIdUsed(mode2.offZWaveSceneId, sceneSet)
				VLog("  SelectZWaveSceneId->ForAllModes: Marked ", mode2.zWaveSceneId, " and ", mode2.offZWaveSceneId, " used. SceneSet now: ", sceneSet)
			end
		end )
		-- Now mark off all scene IDs used by other controllers associated with this target
		for target = 1, #mode do
			if mode[target].dimmingDuration then
				needSceneId = true;
				local actConfList = ReadDeviceActuatorConfList(mode[target].device)
				DLog("  actConfList for device ", mode[target].device, " is ", actConfList)
				local changed = false
				for zWaveSceneId, data in pairs(actConfList) do
					if not luup.devices[data.controller] then
						log("Removing Z-Wave Scene ID ", zWaveSceneId, " actuatior configuration for non-existant controller:", data.controller)
						actConfList[zWaveSceneId] = nil
						changed = true;
					elseif data.controller == controller_dev_num and data.button == virtualButton and data.screen == screen then
						if data.level > 0 or mode.prefix ~= "T" or not SCObj.HasOffSceness then
							if not mode.zWaveSceneId then
								mode.zWaveSceneId = zWaveSceneId
							elseif mode.zWaveSceneId ~= zWaveSceneId then
								log("Removing Z-Wave Scene ID ", zWaveSceneId, " actuator configuration for duplicate entry:", mode.zWaveSceneId)
								actConfList[zWaveSceneId] = nil
								changed = true
							end
						else
							if not mode.offZWaveSceneId then
								mode.offZWaveSceneId = zWaveSceneId
							elseif mode.offZWaveSceneId ~= zWaveSceneId then
								log("Removing Z-Wave Off Scene ID ", zWaveSceneId, " actuator configuration for duplicate entry:", mode.offZWaveSceneId)
								actConfList[zWaveSceneId] = nil
								changed = true
							end
						end
					else
						MarkZWaveSceneIdUsed(zWaveSceneId, sceneSet)
						DLog("  ActConfList: (device=", mode[target].device, ") Marked ", zWaveSceneId, " used. SceneSet now: ", sceneSet)
					end
				end
				if changed then
					WriteDeviceActuatorConfList(mode[target].device, actConfList)
				end
			end
		end
		-- The set of available scene IDs is now completed. Pick a new scene ID and perhaps a new off scene ID in case of a toggle.
		DLog("  oldZWaveSceneId=", oldZWaveSceneId, " oldOffZWaveSceneId=", oldOffZWaveSceneId, " sceneSet=", sceneSet, " defaultSceneId=", defaultSceneId)
		local newZWaveSceneId =  pickSceneId(mode.zWaveSceneId, sceneSet, needSceneId, defaultSceneId)
		local newOffZWaveSceneId
		if mode.prefix == "T" and SCObj.HasOffScenes then
			newOffZWaveSceneId = pickSceneId(mode.offZWaveSceneId, sceneSet, needSceneId, defaultSceneId+SCObj.NumButtons)
		end
		DLog("  newZWaveSceneId=", newZWaveSceneId, " newOffZWaveSceneId=", newOffZWaveSceneId, " sceneSet=", sceneSet)
		-- If either of the two scene IDs changed, then update all of the target devices
		mode.zWaveSceneId = newZWaveSceneId
		mode.offZWaveSceneId = newOffZWaveSceneId
	end
	local prevModeStr =luup.variable_get(SID_SCENECONTROLLER, "Mode_"..screen.."_"..virtualButton, peer_dev_num)
	local newModeStr = GenerateModeString(mode)
	if prevModeStr ~= newModeStr then
		for i = 1, #mode do
			if mode[i].dimmingDuration then
				local actConfList = ReadDeviceActuatorConfList(mode[i].device)
				UpdateActConfList(actConfList, oldZWaveSceneId, mode.zWaveSceneId, controller_dev_num, mode[i], virtualButton, mode[i].level, screen, true)
				UpdateActConfList(actConfList, oldOffZWaveSceneId, mode.offZWaveSceneId, controller_dev_num, mode[i], virtualButton+1000, 0, screen, false)
				WriteDeviceActuatorConfList(mode[i].device, actConfList)
			end
		end
		luup.variable_set(SID_SCENECONTROLLER, "Mode_"..screen.."_"..virtualButton, newModeStr, peer_dev_num)
	end
	return mode
end

function ReadDeviceActuatorConfList(dev_num)
	local actConfStr = luup.variable_get(SID_SCENECONTROLLER, ACTUATOR_CONF, dev_num)
	if not actConfStr then
		return {}, false
	end
	local actConfList = {}
	for sc, ct, scbt, lv, dd in string.gmatch(actConfStr, "(%d+):(%d+),([^,]+),(%d+),(%d+);") do
		local scr, bt = string.match(scbt,"^(.*)_(%d+)$")
		if not scr then -- legacy, did not have screen
			scr = ""
			bt = scbt
		end
		actConfList[tonumber(sc)]={controller=tonumber(ct), screen=scr, button=tonumber(bt), level=tonumber(lv), dimmingDuration=tonumber(dd)}
	end
	return actConfList, true
end

function WriteDeviceActuatorConfList(dev_num, actConfList)
	DLog()
	local str = ""
	for k, v in pairs(actConfList) do
		str = str .. k .. ":" .. v.controller .. "," .. v.screen.."_"..v.button .. "," .. v.level .. "," .. v.dimmingDuration .. ";"
	end
	local oldActConfStr = luup.variable_get(SID_SCENECONTROLLER, ACTUATOR_CONF, dev_num)
	if str ~= oldActConfStr then
		luup.variable_set(SID_SCENECONTROLLER, ACTUATOR_CONF, str, dev_num)
		return true
	end
	return false
end

-- The DeviceAcuatorConf functions cannot be cached because they may act globally across different Lua instances
function GetDeviceActuatorConf(dev_num, zWaveSceneId)
	local actConfList=ReadDeviceActuatorConfList(dev_num)
	return actConfList[zWaveSceneId]
end

function SetDeviceActuatorConf(controller_dev_num, target_dev_num, target_node_id, zWaveSceneId, screen, button, level, dimmingDuration)
	DEntry()
	local actConfList=ReadDeviceActuatorConfList(target_dev_num)
	actConfList[zWaveSceneId]={controller=controller_dev_num, screen=screen, button=button, level=level, dimmingDuration=dimmingDuration}
	if WriteDeviceActuatorConfList(target_dev_num, actConfList) then
		EnqueueZWaveMessage("SceneActuatorConf("..zWaveSceneId..","..level..","..dimmingDuration..")"..target_node_id, target_node_id,  "44 1 ".. zWaveSceneId .. " ".. dimmingDuration .. " 128 ".. level, target_dev_num, 0);
	end
end

function RemoveDeviceActuatorConf(dev_num, zWaveSceneId, offZWaveSceneId)
	local actConfList, exists = ReadDeviceActuatorConfList(dev_num)
	if not exists then
		return
	end
	actConfList[zWaveSceneId]=nil
	if offZWaveSceneId then
		actConfList[offZWaveSceneId]=nil
	end
	WriteDeviceActuatorConfList(dev_num,actConfList)
end

function RemoveDeviceActuatorConfForController(controller_dev_num, target_dev_num)
	local actConfList, exists = ReadDeviceActuatorConfList(target_dev_num)
	if not exists then
		return
	end
	local changed = false
	for k, v in pairs(actConfList) do
		if v.controller == controller_dev_num then
		  	actConfList[k] = nil
			changed = true;
		end
	end
	if changed then
		WriteDeviceActuatorConfList(target_dev_num,actConfList)
	end
end

function RemoveAllDeviceActuatorConf(dev_num)
	local actConfStr = luup.variable_get(SID_SCENECONTROLLER, ACTUATOR_CONF, dev_num)
	if actConfStr then
		luup.variable_set(SID_SCENECONTROLLER, ACTUATOR_CONF, "", dev_num)
	end
end

function UnassociateDevice(zwave_dev_num, target_dev_num_list, firstGroup, lastGroup, groupStep, delay)
	DEntry()
	if not delay then
		delay = param.SCENE_CTRL_AssociationDelay
	end
	local targets = ""
	local label = ""
	local zwave_node_id = GetZWaveNode(zwave_dev_num);
	if target_dev_num_list then
		local count = 0
		for k, v in pairs(target_dev_num_list) do
			local target_node_id = GetZWaveNode(k)
			if target_node_id then
				targets = targets .. " " .. tostring(target_node_id)
				if count > 0 then
					label = label .. ","
				end
				label = label .. tostring(k).."("..tostring(target_node_id)..")"
				count = count + 1
			else
				ELog("UnassociateDevice: Unknown target device: ", k)
			end
		end
		if count == 0 then
			return
		end
	else
		label = "All"
	end
	-- COMMAND_CLASS_ASSOCIATION ASSOCIATION_REMOVE
	for group = firstGroup, lastGroup, groupStep do
		EnqueueZWaveMessage("RemoveAssociation("..group..")"..zwave_node_id.."-x->"..label, zwave_node_id,  "0x85 0x04 "..group..targets, zwave_dev_num, delay)
	end
end

function AssociateDevice(zwave_dev_num, target_dev_num_list, firstGroup, lastGroup, groupStep, delay)
	DEntry()
	if not delay then
		delay = param.SCENE_CTRL_AssociationDelay
	end
	local targets = ""
	local label = ""
	local count = 0
	local zwave_node_id = GetZWaveNode(zwave_dev_num);
	for k, v in pairs(target_dev_num_list) do
		local target_node_id = GetZWaveNode(k)
		if target_node_id then
			SetReturnRoute(zwave_dev_num, zwave_node_id, target_node_id)
			targets = targets .. " " .. tostring(target_node_id)
			if count > 0 then
				label = label .. ","
			end
			label = label .. tostring(k).."("..tostring(target_node_id)..")"
			count = count + 1
		else
		    -- This is actually an important error that can occur if a directly associated device is removed.
			ELog("AssociateDevice: Unknown target device: ", k, " Group=", firstGroup, " Controlling device=", zwave_dev_num, "(", luup.devices[zwave_dev_num].description, ")")
		end
	end
	if count == 0 then
		return
	end
	-- COMMAND_CLASS_ASSOCIATION ASSOCIATION_REMOVE
	for group = firstGroup, lastGroup, groupStep do
		EnqueueZWaveMessage("SetAssociation("..group..")"..zwave_node_id.."->"..label, zwave_node_id, "0x85 0x01 "..group..targets, zwave_dev_num, delay)
	end
end

local SceneController_ReturnRoutes = {}
function SetReturnRoute(zwave_dev_num, lcd_node_id, target_node_id)
  	local veraZWaveNode, ZWaveNetworkDeviceId = GetVeraIDs()
	if target_node_id ~= veraZWaveNode then
		if SceneController_ReturnRoutes[lcd_node_id] == nil then
			local returnRouteList = luup.variable_get(SID_SCENECONTROLLER, RETURN_ROUTES, zwave_dev_num)
			SceneController_ReturnRoutes[lcd_node_id] = {}
			if returnRouteList then
				for d in string.gmatch(returnRouteList, "%d+") do
	       			SceneController_ReturnRoutes[lcd_node_id][tonumber(d)] = true;
	     		end
			end
		end
		if not  SceneController_ReturnRoutes[lcd_node_id][target_node_id] then
			EnqueueZWaveControllerMessage("AssignReturnRoute_"..lcd_node_id.."->"..target_node_id, lcd_node_id,  "0x00 0x46 ".. lcd_node_id .. " " .. target_node_id .. " " .. veraZWaveNode, zwave_dev_num, param.SCENE_CTRL_ReturnRouteDelay)
			SceneController_ReturnRoutes[lcd_node_id][target_node_id] = true
			local returnRouteList = ""
			for k,v in pairs(SceneController_ReturnRoutes[lcd_node_id]) do
			   returnRouteList = returnRouteList.. tostring(k)..","
			end
	   		luup.variable_set(SID_SCENECONTROLLER, RETURN_ROUTES, returnRouteList, zwave_dev_num)
		end
	end
end

function ClearReturnRouteCache(zwave_dev_num)
	local node_id = GetZWaveNode(zwave_dev_num);
	SceneController_ReturnRoutes[node_id] = nil;
	luup.variable_set(SID_SCENECONTROLLER, RETURN_ROUTES, "", zwave_dev_num)
end

function UpdateAssociationForPhysicalButton(zwave_dev_num, screen, force, prevModeStr, modeStr, physicalButton, virtualButton)
	DEntry("UpdateAssociationForPhysicalButton")
	if SCObj.HasCooperConfiguration then -- Cooper RFWC5 cannot update associations incrementally
		force = true
	end
	if force or prevModeStr ~= modeStr then
		local node_id = GetZWaveNode(zwave_dev_num)
		local peer_dev_num = GetPeerDevNum(zwave_dev_num)
		local mode = SelectZWaveSceneId(peer_dev_num, screen, virtualButton, physicalButton, modeStr)
		DLog("  newMode=", mode)
		if force then
			prevModeStr = mode.prefix
		end
		local prevMode = ParseModeString(prevModeStr)
  		local veraZWaveNode, ZWaveNetworkDeviceId = GetVeraIDs()
		local groupId, offGroupId, SceneControllerConfGroupId, SceneControllerConfOffGroupId = SCObj.PhysicalButtonToGroupIds(physicalButton, mode)
		local zWaveSceneId = mode.zWaveSceneId or groupId
		local offZWaveSceneId = SCObj.HasOffScenes and (mode.offZWaveSceneId or offGroupId)
		local prevZWaveSceneId = prevMode.zWaveSceneId or groupId
		local prevOffZWaveSceneId = SCObj.HasOffScenes and (prevMode.offZWaveSceneId or offGroupId)
		local associateList = {}
		local unassociateList = {}
		if force then
			UnassociateDevice(zwave_dev_num, nil, groupId, groupId, 1, param.SCENE_CTRL_UnassociateDelay) -- Unassociate activate with everything
			if offGroupId then
				UnassociateDevice(zwave_dev_num, nil, offGroupId, offGroupId, 1, param.SCENE_CTRL_UnassociateDelay) -- Unassociate deactivate with everything
			end
		else
			for i = 1, #prevMode do
				unassociateList[prevMode[i].device] = true;
			end
			if #mode >= SCObj.MaxDirectAssociations then
				unassociateList[ZWaveNetworkDeviceId] = true
			end
		end
		for i = 1, #mode do
			unassociateList[mode[i].device] = nil
			if mode[i].level then
				associateList[mode[i].device] = mode[i]
			else
				associateList[mode[i].device] = {level=255}
			end
		end
		if force then
			if #mode < SCObj.MaxDirectAssociations then
				associateList[ZWaveNetworkDeviceId] = {level=255, dimmingDuration=255}
			end
		else
			for i = 1, #prevMode do
			    -- For Scene controllable and basic set, no need to reassociate
				associateList[prevMode[i].device] = nil;
			end
			if #prevMode >= SCObj.MaxDirectAssociations and #mode < SCObj.MaxDirectAssociations then
				associateList[ZWaveNetworkDeviceId] = {level=255, dimmingDuration=255}
			end
		end
		DLog("  prevMode=", prevMode)
		DLog("  mode=", mode)
		DLog("  unassociateList=", unassociateList)
		DLog("  associateList=", associateList)
		if force or zWaveSceneId ~= prevZWaveSceneId then
			-- Set on scene controller configuration, group id, sceneid
			EnqueueZWaveMessage("SetSceneControllerConfig_On("..tostring(physicalButton)..","..zWaveSceneId..")"..node_id, node_id,  "0x2d 0x01 "..SceneControllerConfGroupId.." "..zWaveSceneId.." 0xFF", zwave_dev_num, param.SCENE_CTRL_SceneControllerConfDelay)
		end
		if SCObj.HasOffScenes and mode.prefix == "T" then
			if force or offZWaveSceneId ~= prevOffZWaveSceneId or prevMode.prefix ~= "T" then
				-- Set off scene controller configuration, group id, sceneid
				EnqueueZWaveMessage("SetSceneControllerConfig_Off("..physicalButton..","..offZWaveSceneId..")"..node_id, node_id,  "0x2d 0x01 "..SceneControllerConfOffGroupId.." "..offZWaveSceneId.." 0xFF", zwave_dev_num, param.SCENE_CTRL_SceneControllerConfDelay)
			end
		end
		if mode.sceneControllable then
			for i = 1, #mode do
				if mode[i].dimmingDuration then
					local target_node_id = GetZWaveNode(mode[i].device);
					-- 	COMMAND_CLASS_SCENE_ACTUATOR_CONF SET zWaveSceneId dimmingDuration overrideFlag level
					--- Groups 1 to SCObj.NumButtons are On, Groups SCObj.NumButtons+1 to SCObj.NumButtons*2 are off.
					if target_node_id then
						local onActConf = GetDeviceActuatorConf(mode[i].device, mode.zWaveSceneId)
						if onActConf and
						   (onActConf.controller ~= zwave_dev_num or onActConf.button ~= virtualButton) and
						   (onActConf.level ~= mode[i].level or onActConf.dimmingDuration ~= mode[i].dimmingDuration) then
						   log("Warning: ON Z-Wave Scene ID conflict. Controller: zwave_dev_num=", zwave_dev_num, "slave zwave_dev_num=", mode[i].device, " ZWaveSceneId=", mode.zWaveSceneId)
						   log("         Old controller dev_num=", onActConf.controller, " Old button=", onActConf.button, " New button=", virtualButton)
						   log("         Old level=", onActConf.level, " new level=", mode[i].level)
						   log("         Old dimmingDuration=", onActConf.dimmingDuration, " New dimmingDuration=", mode[i].dimmingDuration)
						end
						if force or not onActConf or onActConf.level ~= mode[i].level or onActConf.dimmingDuration ~= mode[i].dimmingDuration then
							SetDeviceActuatorConf(zwave_dev_num, mode[i].device, target_node_id, mode.zWaveSceneId, screen, virtualButton, mode[i].level, mode[i].dimmingDuration);
						end
						if SCObj.HasOffScenes and mode.prefix == "T" then
							local offActConf = GetDeviceActuatorConf(mode[i].device, mode.offZWaveSceneId)
							if offActConf and
							   (offActConf.controller ~= zwave_dev_num or offActConf.button ~= virtualButton+1000) and
							   (offActConf.level ~= 0 or offActConf.dimmingDuration ~= mode[i].dimmingDuration) then
							   log("Warning: OFF Z-Wave Scene ID conflict. Controller: controller dev_num=, zwave_dev_num, slave dev_num=", mode[i].device, " ZWaveSceneId=", mode.zWaveSceneId)
							   log("         Old controller dev_num=", offActConf.controller, " Old button=", offActConf.button, " New button=", virtualButton+1000)
							   log("         Old level=", offActConf.level, " new level=0")
							   log("         Old dimmingDuration=", offActConf.dimmingDuration, " New dimmingDuration=", mode[i].dimmingDuration)
							end
							if force or not offActConf or offActConf.level ~= 0 or offActConf.dimmingDuration ~= mode[i].dimmingDuration then
								SetDeviceActuatorConf(zwave_dev_num, mode[i].device, target_node_id, mode.offZWaveSceneId, screen, virtualButton, 0, mode[i].dimmingDuration);
							end
						end
					else
						ELog("UpdateAssociationForPhysicalButton: bad SceneActuatorConfOn: bad associated device=", mode[i].device, " peer_dev_num=", peer_dev_num, " screen=", screen, " physicalButton=", physicalButton, " i=", i)
					end
				end
			end	-- for i = 1, #mode
		end	-- if mode.sceneControllable

		UnassociateDevice(zwave_dev_num, unassociateList, groupId, groupId, 1, param.SCENE_CTRL_AssociationDelay) -- Unassociate activate with everything
		if offGroupId then
			UnassociateDevice(zwave_dev_num, unassociateList, offGroupId, offGroupId, 1, param.SCENE_CTRL_AssociationDelay) -- Unassociate activate with everything
		end
		
		if SCObj.HasCooperConfiguration then
			-- Special Cooper RFWC5 configuration
			-- First set associations with scene-capable devices (including the controller) but wait for the 5-second timeout.
			-- Then set association for non-scene-capable devices and set the configuration for that button to the level within the 5 second time-out.
			local sceneList = {}
			for k, v in pairs(associateList) do 
				if v.dimmingDuration then
					sceneList[k] = true
				end
			end
			AssociateDevice(zwave_dev_num, sceneList, groupId, groupId, 1, 5000)
			local levels = {}
			for k, v in pairs(associateList) do
				if not v.dimmingDuration then
					if not levels[v.level] then
						levels[v.level] = true
						local list = {}
						for k2, v2 in pairs(associateList) do
							if not v2.dimmingDuration then
								if v2.level == v.level then
									list[k2] = true;
								end
							end
						end
						AssociateDevice(zwave_dev_num, list, groupId, groupId, 1, 0)
						SetConfigurationOption("CooperConfiguration", zwave_dev_num, node_id, physicalButton, v.level, param.SCENE_CTRL_AssociationDelay)
					end
				end
			end
		else
			-- Regular association. Can associate all devices regardless of level
			AssociateDevice(zwave_dev_num, associateList, groupId, groupId, 1, param.SCENE_CTRL_AssociationDelay)
		end
		if offGroupId then
			AssociateDevice(zwave_dev_num, associateList, offGroupId, offGroupId, 1, param.SCENE_CTRL_AssociationDelay)
		end	-- if SCObj.HasOffScenes
	end	-- if force or prevModeStr ~= modeStr
end

function GetModeStr(peer_dev_num, screen, virtualButton)
	local modeStr
	local state = 1
	if screen then
		modeStr  = luup.variable_get(SID_SCENECONTROLLER,"Mode_"..screen.."_"..virtualButton,peer_dev_num)
		if not modeStr then
			modeStr = SCObj.DefaultModeString
		end
	else
		modeStr =  SCObj.DefaultModeString
	end
	local modePrefix = modeStr:sub(1,1)
	if modePrefix >= "2" and modePrefix <= "9" then
		local states = tonumber(modePrefix)
		state = luup.variable_get(SID_SCENECONTROLLER,"State_"..screen.."_"..virtualButton,peer_dev_num)
		if state == nil then
			state = 1
		else
			state = tonumber(state)
		end
		state = (state % states) + 1
		modeStr  = luup.variable_get(SID_SCENECONTROLLER,"Mode_"..screen.."_"..virtualButton+(state-1)*1000,peer_dev_num)
		if modeStr == nil then
			modeStr = "M"
		end
	end
	return modeStr, state
end

function SetButtonMode(peer_dev_num, prevModeStr, screen, force, temperatureSettable, physicalButton)
	local modeStr 
	local state = 1
	local node_id, zwave_dev_num = GetZWaveNode(peer_dev_num)
	if not node_id then
		ELog("SetButtonMode: bad peer_dev_num=", peer_dev_num, "  screen=", screen)
		return
	end
	local numLines, scrollOffset = GetNumLinesAndScrollOffset(peer_dev_num, screen)
	local virtualButton = physicalButton + scrollOffset
	if physicalButton >= 2 and physicalButton <= 4 and screen:sub(1,1) == "T" then
		if temperatureSettable or physicalButton == 3 then
			modeStr = "H";
		else
			modeStr = "M";
		end
		if screen then
			-- Need to do this here so that code that calls to GetModeStr will be correct later.
			oldModeStr  = luup.variable_get(SID_SCENECONTROLLER,"Mode_"..screen.."_"..physicalButton,peer_dev_num)
			if modeStr ~= oldModeStr then
				luup.variable_set(SID_SCENECONTROLLER, "Mode_"..screen.."_"..physicalButton, modeStr, peer_dev_num)
			end
		end
	elseif numLines > SCObj.NumButtons and
           ((physicalButton == 1 and scrollOffset > 0) or
            (physicalButton == SCObj.NumButtons and scrollOffset < numLines - SCObj.NumButtons)) then
		modeStr = "M"
		if not prevModeStr then
			prevModeStr = "M"
		end
	else
		modeStr, state = GetModeStr(peer_dev_num, screen, virtualButton)
	end
	local oldType
	local newType = SCObj.ModeType(ParseModeString(modeStr))
	if not force then
		oldType = SCObj.ModeType(ParseModeString(prevModeStr))
	end
	DLog("SetButtonMode: peer_dev_num=", peer_dev_num, " prevModeStr=", prevModeStr, " screen=", screen, " force=", force, " temperatureSettable=", temperatureSettable, " pysicalButton=", physicalButton,
	     " oldType=", oldType, " modeStr=", modeStr, " newType=", newType, " NumLines=", numLines, " scrollOffset=", scrollOffset, " virtualButton=", virtualButton, " state=",state)
	SCObj.SetButtonType(peer_dev_num, node_id, physicalButton, newType, force, oldType)
	UpdateAssociationForPhysicalButton(zwave_dev_num, screen, force, prevModeStr, modeStr, physicalButton, virtualButton+(state-1)*1000)
end

function SceneController_UpdateCustomLabel(peer_dev_num, screen, virtualButton, label, font, align, modeStr)
	DEntry("SceneController_UpdateCustomLabel")
	if IsVeraPrimaryController() then
		if label == nil then
			label = ""
		end
		local numLines, scrollOffset = GetNumLinesAndScrollOffset(peer_dev_num, screen)
		virtualButton = tonumber(virtualButton)
		local physicalButton = (virtualButton % 1000) - scrollOffset
		local prevModeStr = GetModeStr(peer_dev_num, screen, virtualButton)
		if SCObj.HasScreen then
			luup.variable_set(SID_SCENECONTROLLER, "Label_" .. screen .. "_" .. virtualButton, label, peer_dev_num)
			luup.variable_set(SID_SCENECONTROLLER, "Font_" .. screen .. "_" .. virtualButton, font, peer_dev_num)
			luup.variable_set(SID_SCENECONTROLLER, "Align_" .. screen .. "_" .. virtualButton, align, peer_dev_num)
		end
		SelectZWaveSceneId(peer_dev_num, screen, virtualButton, physicalButton, modeStr)
		local currentScreen = luup.variable_get(SID_SCENECONTROLLER, CURRENT_SCREEN, peer_dev_num)
		if not SCObj.HasMultipleScreens or currentScreen == screen then
			if physicalButton >= 1 and
               physicalButton <= SCObj.NumButtons and
               (numLines <= SCObj.NumButtons or
                ((physicalButton > 1 or scrollOffset == 0) and
                 (physicalButton < SCObj.NumButtons or scrollOffset == numLines-SCObj.NumButtons))) then
				if SCObj.HasScreen then
				    local node_id, zwave_dev_num = GetZWaveNode(peer_dev_num)
					if not node_id then
						ELog("SceneController_UpdateCustomLabel: Bad peer_dev_num=", peer_dev_num, " label=", label)
						return
					end
					local s = label:gsub("\\r",      "\r")
					      s =     s:gsub("-([^\r])", "-\r%1")
				    EVLCDWrapStrings({s}, {font}, {align}, node_id, zwave_dev_num, physicalButton, physicalButton, SCREEN_MD.NoChange)
				end
				SetButtonMode(peer_dev_num, prevModeStr, screen, false, true, physicalButton)
			end
		else
		    -- not dotimeout, no force, not indicatorOnly
			SetScreen(peer_dev_num,screen,false,false,false);
		end
		RunZWaveQueue("UpdateCustomLabel", 0);
	end
end

local UserModeMap = {
	[USERMODE_HEAT]={label="Heat", next=USERMODE_COOL},
	[USERMODE_COOL]={label="Cool", next=USERMODE_AUTO},
	[USERMODE_AUTO]={label="Auto", next=USERMODE_OFF},
	[USERMODE_OFF] ={label="Off",  next=USERMODE_HEAT}
}

local EnergyModeMap = {
	[ENERGYMODE_NORMAL]={label="Normal", next=ENERGYMODE_SAVING},
	[ENERGYMODE_SAVING]={label="Energy Saving", next=ENERGYMODE_NORMAL}
}

function ChooseLabelFontAndAlign(peer_dev_num, screen, line, virtualButton, stateOverride, labels, fonts, aligns)
	if SCObj.HasScreen then
		local modeStr = luup.variable_get(SID_SCENECONTROLLER, "Mode_" .. screen .. "_" .. virtualButton, peer_dev_num)
		if modeStr == nil then
			modeStr = SCObj.DefaultModeString
		end
		local mode = ParseModeString(modeStr)
		local label, font, align
		if mode.prefix == "P" or mode.prefix == "E" then
			local temperatureDevice = luup.variable_get(SID_SCENECONTROLLER, "TemperatureDevice_"  .. screen, peer_dev_num);
			if temperatureDevice and temperatureDevice ~= "0" then
				temperatureDevice = tonumber(temperatureDevice)
				if mode.prefix == "P" then	
					local userMode = luup.variable_get(SID_USERMODE, USERMODE_VAR, temperatureDevice)
					if userMode and UserModeMap[userMode] then
						label = UserModeMap[userMode].label
					end
				else
					local energyMode = luup.variable_get(SID_USERMODE, ENERGYMODE_VAR, temperatureDevice)
					if energyMode and EnergyModeMap[energyMode] then
						label = EnergyModeMap[energyMode].label
					end
				end
			end
		else
			if mode.prefix >= "2" and mode.prefix <= "9" then
				local states = tonumber(mode.prefix)
				if stateOverride ~= nil then
					if stateOverride < 1 then
						stateOverride = states
					elseif stateOverride > states then
					    stateOverride = 1
					end
				else
					stateOverride = ChooseBestFromMultiState(peer_dev_num, screen, virtualButton, mode)
				end
				virtualButton = virtualButton + ((stateOverride-1) * 1000)
			end
			label = luup.variable_get(SID_SCENECONTROLLER,"Label_"..screen.."_"..virtualButton,peer_dev_num)
			font = luup.variable_get(SID_SCENECONTROLLER,"Font_"..screen.."_"..virtualButton,peer_dev_num)
			align = luup.variable_get(SID_SCENECONTROLLER,"Align_"..screen.."_"..virtualButton,peer_dev_num)
		end
		if label == nil then
			label = ""
		end
		if font == nil then
			font = "Normal"
		end
		if align == nil then
			align = "Center"
		end
		labels[line] = label;
		fonts[line] = font;
		aligns[line] = align;
	end
	return stateOverride
end

function SetCustomScreen(peer_dev_num, screenNum, doTimeout, forceClear, indicatorOnly)
	DEntry("SetCustomScreen")
	if not SCObj.HasScreen then
		SetPresetScreen(peer_dev_num, screenNum, doTimeout, forceClear, indicatorOnly)
		return
	end
	local screen = "C"..tostring(screenNum)
	local node_id, zwave_dev_num = GetZWaveNode(peer_dev_num)
	local prevScreen = luup.variable_get(SID_SCENECONTROLLER, CURRENT_SCREEN, peer_dev_num)
	if SCObj.HasMultipleScreens and (not prevScreen or SCObj.ScreenPage(prevScreen) ~= SCObj.ScreenPage(screen)) then
		forceClear = true
		indicatorOnly = false
		if not prevScreen then
			prevScreen = ""
		end
	end
	if (not indicatorOnly) and (forceClear or (SCObj.ScreenPage(screen) ~= SCObj.ScreenPage(prevScreen))) then
		SCObj.SetDeviceScreen(peer_dev_num, screen)
	end
	local prevNumLines, prevScrollOffset
	if prevScreen == nil then
		prevNumLines, prevScrollOffset = SCObj.NumButtons, 0
		forceClear = true
		indicatorOnly = false
	else
		prevNumLines, prevScrollOffset = GetNumLinesAndScrollOffset(peer_dev_num, prevScreen)
	end
	local numLines, scrollOffset = GetNumLinesAndScrollOffset(peer_dev_num, screen)
	if not indicatorOnly and forceClear then
		if scrollOffset ~= 0 then
			scrollOffset = 0
			luup.variable_set(SID_SCENECONTROLLER, SCROLLOFFSET_VAR.."_"..screen, scrollOffset, peer_dev_num)
		end
	end
	DLog("  SetCustomScreen: numLines=", numLines, " scrollOffset=", scrollOffset)
	local earlyButtonConfig = false;
	if not indicatorOnly then
		SetIndicatorValue(peer_dev_num, 0, forceClear)
		if prevScreen and prevScreen:sub(1,1) == "T" then
			earlyButtonConfig = true;
			forceClear = true;
			for i = 2,4 do
				SetButtonMode(peer_dev_num, "T", screen, forceClear, false, i);
			end
		end
		local labels = {};
		local fonts = {};
		local aligns = {};
		for i = 1,SCObj.NumButtons do
			if numLines > SCObj.NumButtons and i == SCObj.NumButtons and i + scrollOffset < numLines then
				labels[i] = "\nvvvvvv";
				fonts[i] = "Inverted";
				aligns[i] = "Center";
			elseif numLines > SCObj.NumButtons and i == 1 and scrollOffset > 0 then
				labels[i] = "^^^^^^";
				fonts[i] = "Inverted";
				aligns[i] = "Center";
			else
				ChooseLabelFontAndAlign(peer_dev_num, screen, i, i+scrollOffset, nil, labels, fonts, aligns)
			end
		end
		if SCObj.HasMultipleScreens then
			luup.variable_set(SID_SCENECONTROLLER, CURRENT_SCREEN, screen, peer_dev_num)
		end
		local screenFlags
		if param.SCENE_CTRL_UseClearScreen > 0 or forceClear then
			screenFlags = SCREEN_MD.ClearScreen
		else
			screenFlags = SCREEN_MD.NoChange
		end
		EVLCDWrapStrings(labels, fonts, aligns, node_id, zwave_dev_num, 1, SCObj.NumButtons, screenFlags)
		for i = 1, SCObj.NumButtons do
			if not earlyButtonConfig or i == 1 or i == SCObj.NumButtons then
				local prevModeStr = GetModeStr(peer_dev_num, prevScreen, i+prevScrollOffset)
				SetButtonMode(peer_dev_num, prevModeStr, screen, forceClear, false, i);
			end
		end
	end
	SetIndicator(peer_dev_num, screen, forceClear)
    SetScreenTimeout(peer_dev_num, screen, doTimeout)
end

function SetPresetScreen(peer_dev_num, screenNum, doTimeout, forceClear, indicatorOnly)
	DEntry("SetCustomScreen")
	local screen = "P"..tostring(screenNum)
   	local node_id = GetZWaveNode(peer_dev_num)
	local prevScreen
	if SCObj.HasMultipleScreens then
		prevScreen = luup.variable_get(SID_SCENECONTROLLER, CURRENT_SCREEN, peer_dev_num)
	else
		prevScreen = screen
	end
	local prevNumLines, prevScrollOffset
	if prevScreen == nil then
		prevNumLines, prevScrollOffset = SCObj.NumButtons, 0
		forceClear = true;
		indicatorOnly = false
	else
		prevNumLines, prevScrollOffset = GetNumLinesAndScrollOffset(peer_dev_num, prevScreen)
	end
	if SCObj.HasMultipleScreens then
		luup.variable_set(SID_SCENECONTROLLER, CURRENT_SCREEN, screen, peer_dev_num)
	end
	if not indicatorOnly and (forceClear or prevScreen ~= screen) then
		SetIndicatorValue(peer_dev_num, 0, forceClear)
		SCObj.SetDeviceScreen(peer_dev_num, screen)
		for i = 1, SCObj.NumButtons do
			local prevModeStr = GetModeStr(peer_dev_num, prevScreen, i+prevScrollOffset)
			SetButtonMode(peer_dev_num, prevModeStr, screen, forceClear, false, i);
		end
	end
	SetIndicator(peer_dev_num, screen, forceClear)
    SetScreenTimeout(peer_dev_num, screen, doTimeout)
end

function SceneController_SetPresetLanguage(peer_dev_num, language)
	if SCObj.HasPresetLanguages and IsVeraPrimaryController() then
	   	luup.variable_set(SID_SCENECONTROLLER, PRESET_LANGUAGE, language, peer_dev_num)
		SCObj.SetLanguage(peer_dev_num, language)
		RunZWaveQueue("SetPresetLanguage", 0);
	end
end

function GetSetPoint(temperatureDevice, isHeat)
	local sid
	if isHeat then
		sid = SID_HEATLSETPOINT
	else
		sid = SID_COOLSETPOINT
	end
	local setPointString = luup.variable_get(sid, SETPOINT_VAR, temperatureDevice)
	if not setPointString then
		local allSetpointString = luup.variable_get(SID_SETPOINT, ALLSETPOINTS_VAR, temperatureDevice)
		if allSetpointString then
			local heat, cool, auto = string.match(allSetpointString,"(%d+),(%d+),(%d+)")
			if isHeat then
				if heat then
					setPointString = heat
				end
			else
				if cool then
					setPointString = cool
				end
			end
		end
	end 
	if setPointString then
		return math.floor(tonumber(setPointString) + 0.5);
	end
	return nil
end

function SetTemperatureLCDParameters(peer_dev_num, temperatureDevice)
	DEntry()
	local lcd_node_id = GetZWaveNode(peer_dev_num);

	local temperatureString
	if temperatureDevice > 0 then
		temperatureString = luup.variable_get(SID_TEMPSENSOR, TEMPSENSOR_VAR, temperatureDevice)
	end
	if not temperatureString then
		temperatureString = "72" -- Default if no associated temperature device
	end	
	local temperature = math.floor(tonumber(temperatureString) + 0.5);
	-- COMMAND_CLASS_SENSOR_MULTILEVEL SENSOR_MULTILEVEL_REPORT Sensor Type = Temperature Level = Size=1 | Scale=1 | Precision=0
	EnqueueZWaveMessage("SetLCDTemperature", lcd_node_id,  "0x31 0x5 0x1 0x9 ".. temperature, peer_dev_num, 0)

	if temperatureDevice > 0 and TemperatureDeviceIsSettable(temperatureDevice) then
		local userMode = luup.variable_get(SID_USERMODE, USERMODE_VAR, temperatureDevice)
		local choice, setPoint
		if userMode == USERMODE_COOL then
			choice = USERMODE_COOL
			setPoint = GetSetPoint(temperatureDevice, false)
		elseif userMode == USERMODE_HEAT then
			choice = USERMODE_HEAT
			setPoint = GetSetPoint(temperatureDevice, true)
		else
			local coolSetPoint = GetSetPoint(temperatureDevice, false)
			local heatSetPoint = GetSetPoint(temperatureDevice, true)
			if coolSetPoint then
				if heatSetPoint then
					local coolDiff = (coolSetPoint - temperature) ^ 2
					local heatDiff = (heatSetPoint - temperature) ^ 2
					if heatDiff <= coolDiff then
						choice = USERMODE_HEAT
						setPoint = heatSetPoint
					else
						choice = USERMODE_COOL
						setPoint = coolSetPoint 
					end
				else
					choice = USERMODE_COOL
					setPoint = coolSetPoint 
				end
			else
				if heatSetPoint then
					choice = USERMODE_HEAT
					setPoint = heatSetPoint
				end
			end
		end
		if choice then
			temperatureAutoChoices[peer_dev_num] = choice
			if setPoint then
				if choice == USERMODE_COOL then
					-- COMMAND_CLASS_THERMOSTAT_SETPOINT THERMOSTAT_SETPOINT_REPORT  SetPoint = Cooling 1 Level = Size=1 | Scale=1 | Precision=0
					EnqueueZWaveMessage("SetLCDSetpointCool", lcd_node_id, "0x43 0x03 0x02 0x9 ".. setPoint, peer_dev_num, 0)
				else
					-- COMMAND_CLASS_THERMOSTAT_SETPOINT THERMOSTAT_SETPOINT_REPORT  SetPoint = Heating 1 Level = Size=1 | Scale=1 | Precision=0
					EnqueueZWaveMessage("SetLCDSetpointHeat", lcd_node_id, "0x43 0x03 0x01 0x9 ".. setPoint, peer_dev_num, 0)
				end
			end
		end

		-- COMMAND_CLASS_THERMOSTAT_FAN_MODE  THERMOSTAT_FAN_MODE_SUPPORTED_REPORT
		-- mode supportd  Z-Wave      LCD1   Vera
		--  0     1       Auto/Low    Auto   Auto
		--  1     2       On/Low      Low    Cycle
		--  2     4       Auto/High
		--  3     8       On/High     High   On
		--  4    16       Auto/Medium
		--  5    32       On/Medium   Medium   
		local supported = 11 -- upported 1 + 2 + 4 from table above
		EnqueueZWaveMessage("SetLCDFanModeSupported", lcd_node_id, "0x44 0x5 ".. supported, peer_dev_num, 0)

		local fanModeString = luup.variable_get(SID_FANMODE, FANMODE_VAR, temperatureDevice)
		if fanModeString ~= nil then
			local fanMode = 3 -- high
			if fanModeString == FANMODE_AUTO then
				fanMode = 0
			elseif fanModeString == FANMODE_CYCLE then
				fanMode = 1
			end
			-- COMMAND_CLASS_THERMOSTAT_FAN_MODE  THERMOSTAT_FAN_MODE_REPORT
			EnqueueZWaveMessage("SetLCDFanMode", lcd_node_id, "0x44 0x3 ".. fanMode, peer_dev_num, 100)
		end
	end
end

-- This is called by the GUI to change the thermostat associated with this controller.
function SceneController_UpdateTemperatureDevice(peer_dev_num, screen, temperatureDevice)
	DEntry()
	if SCObj.HasThremostatControl and IsVeraPrimaryController() then
		temperatureDevice = tonumber(temperatureDevice);
		local curTemperatureDevice = luup.variable_get(SID_SCENECONTROLLER, "TemperatureDevice_"  .. screen, peer_dev_num);
		DLog("  Previous temperature device = ", curTemperatureDevice);
		curTemperatureDevice = tonumber(curTemperatureDevice)
		if temperatureDevice ~= curTemperatureDevice then
			luup.variable_set(SID_SCENECONTROLLER, "TemperatureDevice_"  .. screen, temperatureDevice,  peer_dev_num)
			local currentScreen = luup.variable_get(SID_SCENECONTROLLER, CURRENT_SCREEN, peer_dev_num);
			if currentScreen == screen then
				SetTemperatureLCDParameters(peer_dev_num, temperatureDevice);
			end
		end
		RunZWaveQueue("UpdateTemperatureDevice", 0);
	end
end

-- A work-around for the "bug" which clears rows 1 and 5 of a custom temperature screen
function SceneController_TemperatureDeviceChanged(temperatureDevice, service, variable, old_val, new_val, context)
	DEntry()
	local peer_dev_num = tonumber(context)
	local screen = luup.variable_get(SID_SCENECONTROLLER, CURRENT_SCREEN, peer_dev_num)
	if not screen then
		return
	end
	local prefix = screen:sub(1,1)
	if prefix ~= "T" then
		return
	end
	local screenNum = tonumber(screen:sub(2))
	SetTemperatureScreen(peer_dev_num, screenNum, nil, false, false)
	RunZWaveQueue("TemperatureDeviceChanged", 0)
end

function TemperatureDeviceIsSettable(temperatureDevice)
	if temperatureDevice <= 0 then
		DLog("TemperatureDeviceIsSettable: return true because temperatureDevice=", temperatureDevice)
		return true  -- Dummy - No attached device. Show the arrows even if they don't do anything.
	end
	local category_num = luup.attr_get("category_num", temperatureDevice);
	if category_num ~= "5" then  -- HVAC category num
		DLog("TemperatureDeviceIsSettable: return false because category_num=", category_num)
		return false  -- Temperature sensor only
	end
	local parent = luup.attr_get("id_parent", temperatureDevice);
	if parent ~= "1" then  -- Z-Wave controller
		DLog("TemperatureDeviceIsSettable: return false because parent=", parent)
		return false  -- Non-Z-Wave thermostat
	end
	local userMode = luup.variable_get(SID_USERMODE, USERMODE_VAR, temperatureDevice)
	local result = userMode ~= USERMODE_OFF;
	DLog("TemperatureDeviceIsSettable: return ", result, " because userMode=", userMode)
	return result;
end

function ClearScreen(dev_num, node_id)
	if SCObj.HasScreen then
		EnqueueZWaveMessage("ClearScreen", node_id, "146 2 0 0 0 0 0 0 0", dev_num, param.SCENE_CTRL_ClearDelay);
	end
end

WatchedTemperatureDevices = {};

function SetTemperatureScreen(peer_dev_num, screenNum, doTimeout, forceClear, indicatorOnly)
	local screen = "T"..screenNum;
	local node_id, zwave_dev_num = GetZWaveNode(peer_dev_num)
	local screenNum = tonumber(screenNum)
	local lcdPage = SCObj.ScreenPage(screen);
	local prevScreen = luup.variable_get(SID_SCENECONTROLLER, CURRENT_SCREEN, peer_dev_num)
	local prevNumLines, prevScrollOffset
	if prevScreen == nil then
		prevScreen = "";
		prevNumLines, prevScrollOffset = SCObj.NumButtons, 0
		forceClear = true;
		indicatorOnly = false;
	else
		prevNumLines, prevScrollOffset = GetNumLinesAndScrollOffset(peer_dev_num, prevScreen)
	end
	local prevLcdPage = SCObj.ScreenPage(prevScreen);
	DEntry("SetTemperatureScreen")

	local temperatureDevice = luup.variable_get(SID_SCENECONTROLLER, "TemperatureDevice_"  .. screen, peer_dev_num)
	if temperatureDevice == nil then
		temperatureDevice = 0
	end
	temperatureDevice = tonumber(temperatureDevice);
	local settable = TemperatureDeviceIsSettable(temperatureDevice)

	SetTemperatureLCDParameters(peer_dev_num, temperatureDevice)

	if not indicatorOnly then
		if screenNum > SCObj.NumTemperatureScreens then
		    SetIndicatorValue(peer_dev_num, 0, forceClear)
			if prevScreen:sub(1,1) ~= "T" then
				ClearScreen(peer_dev_num, node_id)
			end
			local labels = {};
			local fonts = {};
			local aligns = {};

			if not settable then
				-- Cover up the up/down arrows that don't work if the device is not settable
				for i = 2,4,2 do
					labels[i] = " \r ";
					fonts[i] = "Normal";
					aligns[i] = "Raw";
				end
				EVLCDWrapStrings(labels, fonts, aligns, node_id, zwave_dev_num, 1, SCObj.NumButtons, SCREEN_MD.NoChange)
				labels = {};
				fonts = {};
				aligns = {};
			end

			for i = 1, SCObj.NumButtons do
				local prevModeStr = GetModeStr(peer_dev_num, prevScreen, i+prevScrollOffset)
				SetButtonMode(peer_dev_num, prevModeStr, screen, forceClear, settable, i);
			end

			local temperatureString = luup.variable_get(SID_TEMPSENSOR, TEMPSENSOR_VAR, temperatureDevice)
			if temperatureString == nil then
				temperatureString = "72";
			end

			for i = 1, SCObj.NumButtons, SCObj.NumButtons-1 do
				ChooseLabelFontAndAlign(peer_dev_num, screen, i, i, nil, labels, fonts, aligns)
			end
			EVLCDWrapStrings(labels, fonts, aligns, node_id, zwave_dev_num, 1, SCObj.NumButtons, SCREEN_MD.NoChange)
		else
			for i = 1, SCObj.NumButtons do
				local prevModeStr = GetModeStr(peer_dev_num, prevScreen, i+prevScrollOffset)
				SetButtonMode(peer_dev_num, prevModeStr, screen, forceClear, settable, i);
			end
		end

		if prevLcdPage ~= lcdPage or forceClear then
			SetConfigurationOption("SetTemperatureScreen", peer_dev_num, node_id, 17, lcdPage, 1000)
			prevLcdPage = lcdPage;
		end
	end

	SetIndicator(peer_dev_num, screen, forceClear)
	luup.variable_set(SID_SCENECONTROLLER, CURRENT_SCREEN, screen, peer_dev_num)
    SetScreenTimeout(peer_dev_num, screen, doTimeout)

	if screenNum > SCObj.NumTemperatureScreens and temperatureDevice > 0 then
		-- Work-around to redisplay the custom labels if they get cleared
		DLog("Watching temperature variables for temperatureDevice: ", temperatureDevice);
		VariableWatch("SceneController_TemperatureDeviceChanged", SID_TEMPSENSOR,   TEMPSENSOR_VAR,   temperatureDevice, tostring(peer_dev_num))
		VariableWatch("SceneController_TemperatureDeviceChanged", SID_COOLSETPOINT, SETPOINT_VAR,     temperatureDevice, tostring(peer_dev_num))
		VariableWatch("SceneController_TemperatureDeviceChanged", SID_HEATSETPOINT, SETPOINT_VAR,     temperatureDevice, tostring(peer_dev_num))
		VariableWatch("SceneController_TemperatureDeviceChanged", SID_FANMODE,      FANMODE_VAR,      temperatureDevice, tostring(peer_dev_num))
		VariableWatch("SceneController_TemperatureDeviceChanged", SID_USERMODE,     USERMODE_VAR,     temperatureDevice, tostring(peer_dev_num))
		VariableWatch("SceneController_TemperatureDeviceChanged", SID_USERMODE,     ENERGYMODE_VAR,   temperatureDevice, tostring(peer_dev_num))
	end
end

setScreenTable = {
	C=SetCustomScreen,
	P=SetPresetScreen,
	T=SetTemperatureScreen,
}

function SetScreen(peer_dev_num, screen, doTimeout, forceClear, indicatorOnly)
	DEntry()
	if IsVeraPrimaryController() then
		local func = setScreenTable[screen:sub(1,1)]
		if func ~= nil then
			func(peer_dev_num, screen:sub(2), doTimeout, forceClear, indicatorOnly)
		else
			ELog("SetScreen: Unknown screen type: ", screen)
		end
	end
end

function SceneController_SetScreen(peer_dev_num, screen, doTimeout, forceClear, indicatorOnly)
	DEntry()
	if IsVeraPrimaryController() then
		SetScreen(peer_dev_num, screen, doTimeout, forceClear, indicatorOnly)
		RunZWaveQueue("SetScreen", 0);
	end
end

local timeout_count = 0
function SceneController_SetBacklight(peer_dev_num, timeout)
	DEntry()
	if IsVeraPrimaryController() then
		if not peer_dev_num then
			ELog("SceneController_SetBacklight: bad peer_dev_num=", peer_dev_num)
		end
		timeout_count = timeout_count + 1
		if timeout_count <= 1 then
			SCObj.SetBacklight(peer_dev_num, true)
		end
		luup.call_delay("SceneController_BacklightTimeout", timeout, peer_dev_num, true);
		RunZWaveQueue("SetBacklight", 0);
	end
end

function SceneController_BacklightTimeout(peer_dev_num_string)
	DEntry()
	if IsVeraPrimaryController() then
		timeout_count = timeout_count - 1
		if timeout_count <= 0 then
			local peer_dev_num = tonumber(peer_dev_num_string)
			SCObj.SetBacklight(peer_dev_num, false)
		end
		RunZWaveQueue("BacklightTimeout", 0);
	end
end

-- commfailure flags change on the Z-Wave device, copy it to the peer device
function SceneController_CommFailureChanged(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new, context)
	DEntry()
	local zwave_dev_num = tonumber(lul_device);
  	local peer_dev_num = GetPeerDevNum(luup.device)
	PropagateCommFailure(zwave_dev_num, peer_dev_num)
end

function PropagateCommFailure(zwave_dev_num, peer_dev_num)
	DEntry()
	for index, keyword in ipairs {"CommFailure", "CommFailureTime", "CommFailureAlarm"} do
		local zValue = luup.variable_get(SID_HADEVICE, keyword, zwave_dev_num)
		local pValue = luup.variable_get(SID_HADEVICE, keyword, peer_dev_num)
		if zValue ~= pValue then
			luup.variable_set(SID_HADEVICE, keyword, zValue, peer_dev_num)
		end
	end
end

-- This re-associates all of the scene activation buttons after Vera has reconfigured the Z-Wave device.
-- It also possibly re-associates the thermostat if the current page is a temperature screen.
-- This is called as a watch trigger whenever the Z-Wave device is reconfigured
function SceneController_ConfiguredChanged(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new, context)
	DEntry()
	if IsVeraPrimaryController() then
		if tonumber(lul_value_new) == 1 or tonumber(lul_value_new) == -3 then
			local dev_num = tonumber(lul_device);
			local node_id, zwave_dev_num = GetZWaveNode(dev_num)
			-- 10 scenes - 5 activation, 5 deactivation
			ClearReturnRouteCache(zwave_dev_num)
	  		local veraZWaveNode, ZWaveNetworkDeviceId = GetVeraIDs()
			local peer_dev_num_str = luup.variable_get(SID_SCENECONTROLLER,"PeerID",zwave_dev_num)
			local peer_dev_num = tonumber(peer_dev_num_str)
			local currentScreen = GetCurrentScreen(peer_dev_num)
			local prefix = currentScreen:sub(1,1)
			-- If this is the first event which occurred since startup, and this is a battery device,
			-- then it is already awake but we have not yet set up the monitor
			if SCObj.HasBattery then
				EnqueueInitWakeupMonitorMessage("WakeUpInit_ConfiguredChanged", node_id, peer_dev_num)
			end
			-- Force all scene actuator configurations to be re-sent eventually.
			-- We gather up a set of all direct associations and then clear
			-- the actuator configuration cache for each device associated with this controller.
			local associateList = {}
			ForAllModes(peer_dev_num, function(mode2, screen2, virtualButton2)
				for i = 1, #mode2 do
					associateList[mode2[i].device] = true
				end
			end )
			DLog("  ConfiguredChanged: associateList=", associateList, " zwave_dev_num=", zwave_dev_num)
			for k, v in pairs(associateList) do
				RemoveDeviceActuatorConfForController(zwave_dev_num, k)
			end
			SCObj.DoDeviceConfiguration(peer_dev_num, node_id, zwave_dev_num)
			-- DoTimeout, force, not indicatorOnly
			SetScreen(peer_dev_num, currentScreen, true, true, false)
		end
		-- If LuaUPnP does not know how to configure the device, we do it for it.
		-- and then we set configured to 1 ourselves but don't re-trigger this function
		if tonumber(lul_value_new) == -3 then
    		TempVariableUnwatch(lul_service, lul_variable, lul_device) 
	  		luup.variable_set(lul_service, lul_variable, 1, lul_device)
		end
		RunZWaveQueue("ConfiguredChanged", 0);
	end
end

SceneIds = {}
SceneTimes = {}

function GetCurrentScreen(peer_dev_num)
	local currentScreen
	if SCObj.HasMultipleScreens then
		currentScreen = luup.variable_get(SID_SCENECONTROLLER, CURRENT_SCREEN, peer_dev_num)
	end
	if not currentScreen then
		currentScreen = SCObj.DefaultScreen
	end
	return currentScreen
end

function SceneActivatedMonitorCallback(peer_dev_num, result)
	DEntry("SceneActivatedMonitorCallback")
	local time = tonumber(result.time)
	local receiveStatus = tonumber(result.C1, 16)
	if CheckDups(peer_dev_num, time, receiveStatus, "2B"..result.C2..result.C3) then
		local zWaveSceneId = tonumber(result.C2, 16)
		local dimminDuration = tonumber(result.C3, 16)
		SceneChange(peer_dev_num, true, zWaveSceneId, time)
	end
end

function BasicSetMonitorCallback(peer_dev_num, result)
	DEntry("BasicSetMonitorCallback")
	local time = tonumber(result.time)
	local receiveStatus = tonumber(result.C1, 16)
	if CheckDups(peer_dev_num, time, receiveStatus, "20"..result.C2) then
		local setValue = tonumber(result.C2, 16)
		SceneChange(peer_dev_num, false, setValue, time)
	end
end

function MultiLevelSwitchStopLevelChangeMonitorCallback(peer_dev_num, result)
	DEntry("MultiLevelSwitchStopLevelChangeMonitorCallback")
	local time = tonumber(result.time)
	local receiveStatus = tonumber(result.C1, 16)
	if CheckDups(peer_dev_num, time, receiveStatus, "2605") then
		local mode = lastChangedModes[peer_dev_num]
		if mode then
			for i = 1, #mode do
				luup.call_action(SID_HADEVICE, "Poll", {}, mode[i].device)
			end
		end
	end
end

function ThermostatSetPointMonitorCallback(peer_dev_num, result)
	DEntry("ThermostatSetPointMonitorCallback")
	local time = tonumber(result.time)
	local receiveStatus = tonumber(result.C1, 16)
	if CheckDups(peer_dev_num, time, receiveStatus, "4301" .. result.C2 .. result.C3 .. result.C4) then
		local setPointType = tonumber(result.C2, 16)
		local levelScalePrecision = tonumber(result.C3, 16)
		local setPoint = tonumber(result.C4, 16)
		local screen = luup.variable_get(SID_SCENECONTROLLER, CURRENT_SCREEN, peer_dev_num)
		if not screen then
			return
		end
		SetScreenTimeout(peer_dev_num, screen, true);
		local prefix = screen:sub(1,1)
		if prefix ~= "T" then
			return
		end
		local temperatureDevice = luup.variable_get(SID_SCENECONTROLLER, "TemperatureDevice_"  .. screen, peer_dev_num);
		if not temperatureDevice then
			temperatureDevice = "0"
		end
		temperatureDevice = tonumber(temperatureDevice)
		local choice = temperatureAutoChoices[peer_dev_num]
		if not choice then
			choice = USERMODE_HEAT
		end
		if 	temperatureDevice <= 0 then
			return
		end
		local sid
		if choice == USERMODE_COOL then
			sid = SID_COOLSETPOINT
		else
			sid = SID_HEATSETPOINT
		end
		luup.call_action(sid, "SetCurrentSetpoint", {NewCurrentSetpoint = setPoint}, temperatureDevice)
	end
end

function ThermostatFanModeMonitorCallback(peer_dev_num, result)
	DEntry("ThermostatFanModeMonitorCallback")
	local time = tonumber(result.time)
	local receiveStatus = tonumber(result.C1, 16)
	if CheckDups(peer_dev_num, time, receiveStatus, "4401" .. result.C2) then
		local fanModeNum = tonumber(result.C2, 16)
		local screen = luup.variable_get(SID_SCENECONTROLLER, CURRENT_SCREEN, peer_dev_num)
		if not screen then
			return
		end
		SetScreenTimeout(peer_dev_num, screen, true);
		local prefix = screen:sub(1,1)
		if prefix ~= "T" then
			return
		end
		local temperatureDevice = luup.variable_get(SID_SCENECONTROLLER, "TemperatureDevice_"  .. screen, peer_dev_num);
		if not temperatureDevice then
			temperatureDevice = "0"
		end
		temperatureDevice = tonumber(temperatureDevice)
		if 	temperatureDevice <= 0 then
			return
		end
		local oldMode = luup.variable_get(SID_FANMODE, FANMODE_VAR, temperatureDevice)
		local fanMode
		if fanModeNum == 0 then
			fanMode = FANMODE_AUTO
		elseif fanModeNum == 1 then
			fanMode = FANMODE_CYCLE
		elseif fanModeNum == 3 then
			fanMode = FANMODE_ON
		else
			ELog("Unexpected fan mode:", fanModeNum)
			return
		end 
		if oldMode ~= fanMode then
			luup.call_action(SID_FANMODE, "SetMode", {NewMode = fanMode}, temperatureDevice)
		end
	end
end

-- This monitor callback triggers when we get an Evolve LCD controller is first
-- powered on to get its screen metadata. We respond by triggering a reconfiguration.
function ScreenMDGetMonitorCallback(peer_dev_num, result)
	DEntry("ScreenMDGetMonitorCallback")
	local time = tonumber(result.time)
	local receiveStatus = tonumber(result.C1, 16)
	if CheckDups(peer_dev_num, time, receiveStatus, "9201") then
		local node_id, zwave_dev_num = GetZWaveNode(peer_dev_num)
		luup.call_action(SID_HADEVICE,"Reconfigure", {}, zwave_dev_num)
	end
end

function SceneButtonPressed(peer_dev_num, activate, physicalButton, indicatorUpdated)
	local node_id, zwave_dev_num = GetZWaveNode(peer_dev_num)
	local currentScreen = GetCurrentScreen(peer_dev_num)
	local numLines, scrollOffset = GetNumLinesAndScrollOffset(peer_dev_num, currentScreen)
	local virtualButton = physicalButton + scrollOffset
	DEntry("SceneButtonPressed")
	-- Handle scroll up and scrolll down events if numLines > SCObj.NumButtons
	-- Using the ScrollUp and ScrollDown commands, labels, indicators, and button modes all scroll together but not associations.
	-- We also need to handle to top and bottom ^^^^ and vvvv scrolling indicators which always use momentary buttons.
	if numLines > SCObj.NumButtons and physicalButton == 1 and scrollOffset > 0 then
		local labels = {}
		local fonts = {}
		local aligns = {}
		scrollOffset = scrollOffset - 1;
	  	luup.variable_set(SID_SCENECONTROLLER, "ScrollOffset_" .. currentScreen, tostring(scrollOffset), peer_dev_num)
		for i = 1, 2 do
			if i == 1 and scrollOffset > 0 then
				labels[i] = "^^^^^^"
				fonts[i] = "Inverted";
				aligns[i] = "Center";
			else
				ChooseLabelFontAndAlign(peer_dev_num, currentScreen, i, i+scrollOffset, nil, labels, fonts, aligns)
			end
		end
		EVLCDWrapStrings(labels, fonts, aligns, node_id, zwave_dev_num, 1, 2, SCREEN_MD.ScrollDown)
		SetIndicatorValue(peer_dev_num, 0, false)
		if scrollOffset == 0 then
			SetButtonMode(peer_dev_num, "M", currentScreen, false, false, 1)
		end
		SetButtonMode(peer_dev_num, "M", currentScreen, false, false, 2)
		for i = 3, SCObj.NumButtons-1 do
			local prevModeStr = GetModeStr(peer_dev_num, currentScreen, scrollOffset+i+1)
			local modeStr, state = GetModeStr(peer_dev_num, currentScreen, scrollOffset+i)
			UpdateAssociationForPhysicalButton(zwave_dev_num, currentScreen, false, prevModeStr, modeStr, i, (scrollOffset+i)+(state-1)*1000)
		end
		local prevModeStr = GetModeStr(peer_dev_num, currentScreen, scrollOffset+SCObj.NumButtons)
		SetButtonMode(peer_dev_num, prevModeStr, currentScreen, false, false, SCObj.NumButtons)
		EVLCDWrapStrings({"\nvvvvvv"}, {"Inverted"}, {"Center"}, node_id, zwave_dev_num, SCObj.NumButtons, SCObj.NumButtons, SCREEN_MD.NoChange)
		SetIndicator(peer_dev_num, currentScreen, false)
		luup.sleep(param.SCENE_CTRL_SwitchScreenDelay) -- Avoid a CAN when LCD1 sends the second scene activation message
		SetScreenTimeout(peer_dev_num, currentScreen, true);
		return
	elseif numLines > SCObj.NumButtons and physicalButton == SCObj.NumButtons and scrollOffset < numLines - SCObj.NumButtons then
		local labels = {}
		local fonts = {}
		local aligns = {}
		scrollOffset = scrollOffset + 1;
	  	luup.variable_set(SID_SCENECONTROLLER, "ScrollOffset_" .. currentScreen, tostring(scrollOffset), peer_dev_num)
		for i = SCObj.NumButtons-1, SCObj.NumButtons do
			if i == SCObj.NumButtons and scrollOffset < numLines-SCObj.NumButtons then
				labels[2] = "\nvvvvvv"
				fonts[2] = "Inverted";
				aligns[2] = "Center";
			else
				ChooseLabelFontAndAlign(peer_dev_num, currentScreen, i-(SCObj.NumButtons-2), i+scrollOffset, nil, labels, fonts, aligns)
			end
		end
		EVLCDWrapStrings(labels, fonts, aligns, node_id, zwave_dev_num, SCObj.NumButtons-1, SCObj.NumButtons, SCREEN_MD.ScrollUp)
		SetIndicatorValue(peer_dev_num, 0, false)
		if scrollOffset == numLines-SCObj.NumButtons then
			SetButtonMode(peer_dev_num, "M", currentScreen, false, false, SCObj.NumButtons)
		end
		SetButtonMode(peer_dev_num, "M", currentScreen, false, false, SCObj.NumButtons-1)
		for i = SCObj.NumButtons-2, 2, -1 do
			local prevModeStr = GetModeStr(peer_dev_num, currentScreen, scrollOffset+i-1)
			local modeStr, state     = GetModeStr(peer_dev_num, currentScreen, scrollOffset+i)
			UpdateAssociationForPhysicalButton(zwave_dev_num, currentScreen, false, prevModeStr, modeStr, i, scrollOffset+i+(state-1)*1000)
		end
		local prevModeStr = GetModeStr(peer_dev_num, currentScreen, scrollOffset+1)
		SetButtonMode(peer_dev_num, prevModeStr, currentScreen, false, false, 1)
		EVLCDWrapStrings({"^^^^^^"}, {"Inverted"}, {"Center"}, node_id, zwave_dev_num, 1, 1, SCREEN_MD.NoChange)
		SetIndicator(peer_dev_num, currentScreen, false)
		luup.sleep(param.SCENE_CTRL_SwitchScreenDelay) -- Avoid a CAN when LCD1 sends the second scene activation message
		SetScreenTimeout(peer_dev_num, currentScreen, true);
		return
	end

	local oldIndicator_string = luup.variable_get(SID_SCENECONTROLLER, CURRENT_INDICATOR, peer_dev_num)
	local oldIndicator = 0
	if oldIndicator_string then
		oldIndicator = tonumber(oldIndicator_string)
	end
	local newIndicator = oldIndicator
	local modeStr = luup.variable_get(SID_SCENECONTROLLER,"Mode_"..currentScreen.."_"..virtualButton, peer_dev_num)
	if modeStr == nil then
		modeStr = SCObj.DefaultModeString
	end
	DLog("  SceneButtonPressed: modeStr=", modeStr)
	local mode = ParseModeString(modeStr)
	local state = 1

	if SCObj.ModeMap[mode.prefix] == SCObj.ModeMap["T"] then
		-- A toggle button was pushed. Change our local shadow of the indicator to reflect what the device already did
	  	if activate then
	    	newIndicator = bit.bor(oldIndicator,SCObj.PhysicalButtonToIndicator(physicalButton, true))
	  	else
	    	newIndicator = bit.band(oldIndicator,SCObj.PhysicalButtonToIndicator(physicalButton, false))
	  	end
	elseif SCObj.ModeMap[mode.prefix] == SCObj.ModeMap["M"] then
		newIndicator = bit.band(oldIndicator,SCObj.PhysicalButtonToIndicator(physicalButton, false))
		if not SCObj.HasButtonModes then
			-- For "Fake" Momentary buttons, force-reset the indicator
			SetIndicatorValue(peer_dev_num, newIndicator, true);
		end
	end
	if newIndicator ~= oldIndicator then
  		luup.variable_set(RFWC5_SID, CURRENT_INDICATOR, tostring(newIndicator), peer_dev_num)
	end

	if mode.prefix == "P" or mode.prefix == "E" then
		activate = true;
		local temperatureDevice = luup.variable_get(SID_SCENECONTROLLER, "TemperatureDevice_"  .. currentScreen, peer_dev_num);
		if temperatureDevice then
			temperatureDevice = tonumber(temperatureDevice)
			if mode.prefix == "P" then	
				local userMode = luup.variable_get(SID_USERMODE, USERMODE_VAR, temperatureDevice)
				if userMode and UserModeMap[userMode] then
					local nextMode = UserModeMap[userMode].next
					if nextMode == USERMODE_AUTO then
						local autoMode = luup.variable_get(SID_USERMODE, "AutoMode", temperatureDevice)
						if autoMode == "0" then
							nextMode = UserModeMap[nextMode].next
						end
					end
					luup.call_action(SID_USERMODE, "SetModeTarget", {NewModeTarget=nextMode}, temperatureDevice)
				end
			else
				local energyMode = luup.variable_get(SID_USERMODE, ENERGYMODE_VAR, temperatureDevice)
				if energyMode and EnergyModeMap[energyMode] then
					luup.call_action(SID_USERMODE, "SetEnergyModeTarget", {NewModeTarget=EnergyModeMap[energyMode].next}, temperatureDevice)
				end
			end
		end
	elseif mode.prefix >= "2" and mode.prefix <= "9" then
		activate = true;
		local states = tonumber(mode.prefix)
		state = luup.variable_get(SID_SCENECONTROLLER,"State_"..currentScreen.."_"..virtualButton,peer_dev_num)
		if state == nil then
			state = "1"
		end
		state = tonumber(state)
		local oldLabels = {}
		local oldFonts = {}
		local oldAligns = {}
		if SCObj.HasScreen then
			ChooseLabelFontAndAlign(peer_dev_num, currentScreen, 1, virtualButton, state, oldLabels, oldFonts, oldAligns)
		end
		state = state % states + 1
		luup.variable_set(SID_SCENECONTROLLER,"State_"..currentScreen.."_"..virtualButton,tostring(state),peer_dev_num)
		modeStr = luup.variable_get(SID_SCENECONTROLLER,"Mode_"..currentScreen.."_"..(virtualButton+(state-1)*1000), peer_dev_num)
		if modeStr == nil then
			modeStr = "M"
		end
		DLog("  SceneButtonPressed: modeStr for state ", state, " = ", modeStr)
		if mode.prefix == "T" then -- Fix legacy multi-state for Cooper.
			mode.prefix = "M"
		end
		mode = ParseModeString(modeStr)
		local labels = {}
		local fonts = {}
		local aligns = {}
		if SCObj.HasScreen then
			ChooseLabelFontAndAlign(peer_dev_num, currentScreen, 1, virtualButton, state, labels, fonts, aligns)
		end
		local nextState = state % states + 1
		local newModeStr = luup.variable_get(SID_SCENECONTROLLER,"Mode_"..currentScreen.."_"..(virtualButton+(nextState-1)*1000), peer_dev_num)
		if newModeStr == nil then
			newModeStr = "M"
		end
		DLog("  SceneButtonPressed: modeStr for next state ", nextState, " = ", newModeStr)
		UpdateAssociationForPhysicalButton(zwave_dev_num, currentScreen, false, modeStr, newModeStr, physicalButton, virtualButton+(nextState-1)*1000)
		if SCObj.HasScreen and (oldLabels[1] ~= labels[1] or oldFonts[1] ~= fonts[1] or oldAligns[1] ~= aligns[1]) then
			EVLCDWrapStrings(labels, fonts, aligns, node_id, zwave_dev_num, physicalButton, physicalButton, SCREEN_MD.NoChange)
		end
	end
	-- For direct or toggle direct, we set the status of the target device to whatever the controller
	-- has just sent.
	DLog("  SceneButtonPressed: mode for state ", state, " = ", mode)
	lastChangedModes[peer_dev_num] = mode
	for i = 1, #mode do
		if activate then
			if mode.sceneControllable then
				SetDeviceStatus(mode[i].device, mode[i].level)
			else
				SetDeviceStatus(mode[i].device, 255)
			end
		else
			SetDeviceStatus(mode[i].device, 0)
		end
	end
	-- now calculate the scene ID on for normal Vera scene handling.
	local peer_scene = nil;
	if SCObj.HasMultipleScreens then
		local customScreen = currentScreen:match("C(%d)")
		if customScreen ~= nil then
			local buttonGroup = math.floor((virtualButton - 1) / SCObj.NumButtons)
			local buttonOffset = 0
			if buttonGroup > 0 then
			   buttonOffset = 300 + buttonGroup * 100
			end
			peer_scene = ((tonumber(customScreen) - 1) * SCObj.NumButtons) + ((virtualButton - 1) % SCObj.NumButtons) + 1 + (buttonOffset) + (state-1) * 1000
		else
			local presetScreen = currentScreen:match("P(%d)")
			if presetScreen ~= nil then
				peer_scene = 65 + ((tonumber(presetScreen) - 1) * SCObj.NumButtons) + physicalButton + (state-1) * 1000
			else
				local temperatureScreen = currentScreen:match("T(%d)")
				if temperatureScreen ~= nil then
					peer_scene = 30 + ((tonumber(temperatureScreen) - 1) * SCObj.NumButtons) + physicalButton + (state-1) * 1000
				end
			end
		end
	else
		peer_scene = physicalButton + (state-1) * 1000;
	end
	local act_deact
	if activate then
		act_deact = "sl_SceneActivated"
	else
		act_deact = "sl_SceneDeactivated"
	end
	if peer_scene ~= nil then
    	if mode.prefix == "X" then -- Exclusive
			act_deact = "sl_SceneActivated"
		end
		if mode.prefix == "X" or mode.newScreen or (#ExternalZWaveQueue > 0) then
			luup.sleep(param.SCENE_CTRL_SwitchScreenDelay) -- Avoid a CAN when LCD1 sends the second scene activation message
		end
		luup.variable_set(SID_SCTRL, act_deact, tostring(peer_scene), peer_dev_num)
		local peer_scene_time_str = luup.variable_get(SID_SCTRL, "LastSceneTime", peer_dev_num)
		if not peer_scene_time_str then
			peer_scene_time_str = "0"
		end
		local peer_scene_time = tonumber(peer_scene_time_str);
		local cur_scene_time = os.time()
		if cur_scene_time <= peer_scene_time then
		    cur_scene_time = peer_scene_time + 1
		end
		luup.variable_set(SID_SCTRL, "LastSceneTime", tostring(cur_scene_time), peer_dev_num)
    	if mode.newScreen then -- Switch Screen
		    -- doTimeout, not force, not indicatorOnly
		    SetScreen(peer_dev_num,mode.newScreen,true,false,false);
		else
			SetScreenTimeout(peer_dev_num, currentScreen, true);
	    end
	else
		ELog("Invalid current screen: \"", currentScreen, "\"")
		-- dotimeout, not force, not indicatorOnly
		SetCustomScreen(peer_dev_num, 1, true, false, false)
	end
end

function SceneChange(peer_dev_num, isSceneId, zwave_scene, cur_scene_time)
    DEntry()
	local act_deact
	local physicalButton
	local activate
	local node_id, zwave_dev_num = GetZWaveNode(peer_dev_num)
	if not cur_scene_time then
		cur_scene_time = 0
	end
	local currentScreen = GetCurrentScreen(peer_dev_num)
	local numLines, scrollOffset = GetNumLinesAndScrollOffset(peer_dev_num, currentScreen)
	if not isSceneId then
		-- We just got a BASIC_SET command and we are not sure which button was changed.
		if SCObj.HasIndicator then
		  	local indicator_string = luup.variable_get(SID_SCENECONTROLLER, CURRENT_INDICATOR, peer_dev_num)
		  	local indicator = tonumber(indicator_string)
			activate = zwave_scene > 0
			for i = 0, SCObj.NumButtons do
				if indicator == SCObj.PhysicalButtonToIndicator(i, not activate) then
					physicalButton = i
					break
				end
			end
			if not physicalButton then
				local retry = 0
				local IndicatorReportCallback
				IndicatorReportCallback = function(peer_dev_num, response)
					DEntry("IndicatorReportCallback")
					if response then
						local time = tonumber(response.time)
						local receiveStatus = tonumber(response.C1, 16)
						if CheckDups(peer_dev_num, time, receiveStatus, "87" .. response.C2) then
							local newIndicator = tonumber(response.C2, 16)
							local oldindicator_string = luup.variable_get(SID_SCENECONTROLLER, CURRENT_INDICATOR, peer_dev_num)
							local oldIndicator = tonumber(oldindicator_string)
							DEntry()
							luup.variable_set(SID_SCENECONTROLLER, CURRENT_INDICATOR, tostring(newIndicator), peer_dev_num)
							local anyChange = false
							for physicalButton = 1, SCObj.NumButtons do
								local b = SCObj.PhysicalButtonToIndicator(physicalButton, true);
								if bit.band(b, oldIndicator) ~= bit.band(b, newIndicator) then
									local activate = bit.band(b, newIndicator) ~= 0
									anyChange = true
									SceneButtonPressed(peer_dev_num, activate, physicalButton, true)
								end
							end
							-- Set the indicator here in case any of the other buttons got affected by the changes that we made
							-- This will typically be a no-op but is important for Exclusive modes
							local lock = IndicatorLocks[peer_dev_num]
							IndicatorLocks[peer_dev_num] = 0
							if anyChange or lock > 1 then
								SetIndicator(peer_dev_num, GetCurrentScreen(peer_dev_num), false)
							end
						end
					else
						retry = retry + 1
						if retry < 3 then
							-- Same as below except the label
							EnqueueZWaveMessageWithResponse("IndicatorReportRetry"..retry, -- label
															node_id, 
															"0x87 0x02", -- sendData
															0, -- delay
															"^01 .. 00 04 (..) "..string.format("%02x",node_id).." .. 87 03 (..)", -- responsePattern
															IndicatorReportCallback, -- callback
															true, -- oneShot
															zwave_dev_num, -- dev_num
															3000, -- timeout. 2000 is not long enough for the RFWC5 "All off" operation.
															nil, -- armPattern
															"06") -- autoResponse
						else
							log("IndicatorReportCallback: timeout")
							local lock = IndicatorLocks[peer_dev_num]
							IndicatorLocks[peer_dev_num] = 0
							if lock > 1 then
								SetIndicator(peer_dev_num, GetCurrentScreen(peer_dev_num), false)
							end
						end
					end
				end	-- IndicatorReportCallback
--[[
                                                 C1                   C2
42      12/18/16 13:37:28.574   0x1 0x9 0x0 0x4 0x0 0xc 0x3 0x87 0x3 0x1 0x78 (##########x)
           SOF - Start Of Frame --+   ¦   ¦   ¦   ¦   ¦   ¦    ¦   ¦   ¦    ¦
                     length = 9 ------+   ¦   ¦   ¦   ¦   ¦    ¦   ¦   ¦    ¦
                        Request ----------+   ¦   ¦   ¦   ¦    ¦   ¦   ¦    ¦
FUNC_ID_APPLICATION_COMMAND_HANDLER ----------+   ¦   ¦   ¦    ¦   ¦   ¦    ¦
          Receive Status SINGLE ------------------+   ¦   ¦    ¦   ¦   ¦    ¦
Device 20=Cooper RFWC5 Scene Controller Z-Wave -------+   ¦    ¦   ¦   ¦    ¦
                Data length = 3 --------------------------+    ¦   ¦   ¦    ¦
        COMMAND_CLASS_INDICATOR -------------------------------+   ¦   ¦    ¦
               INDICATOR_REPORT -----------------------------------+   ¦    ¦
                      Value = 1 ---------------------------------------+    ¦
                    Checksum OK --------------------------------------------+
41      12/18/16 13:37:28.574   ACK: 0x6 (#)
--]]
				IndicatorLocks[peer_dev_num] = 1
				EnqueueZWaveMessageWithResponse("IndicatorReport", -- label
												node_id, 
												"0x87 0x02", -- sendData
												0, -- delay
												"^01 .. 00 04 (..) "..string.format("%02x",node_id).." .. 87 03 (..)", -- responsePattern
												IndicatorReportCallback, -- callback
												true, -- oneShot
												zwave_dev_num, -- dev_num
												3000, -- timeout. 2000 is not long enough for the RFWC5 "All off" operation.
												nil, -- armPattern
												"06") -- autoResponse
				return
			end
		else
			-- Without indicator feedback, we cannot determine which button was pressed from a Basic Set command.
			return
		end
	elseif zwave_scene > SCObj.LastFixedSceneId then
		local zWaveSceneIdCache = ZWaveSceneIdCacheList[zwave_dev_num]
		if not zWaveSceneIdCache or not zWaveSceneIdCache[zwave_scene] then
			zWaveSceneIdCache = {}
			ForAllModes(peer_dev_num, function(mode, screen, virtualButton)
				VLog("SceneChange->ForAllModes: mode=", mode, " screen=", screen, " virtualButton=", virtualButton)
				if mode.zWaveSceneId then
					zWaveSceneIdCache[mode.zWaveSceneId] = {screen=screen, button=virtualButton, act=true}
					if mode.offZWaveSceneId then
						zWaveSceneIdCache[mode.offZWaveSceneId] = {screen=screen, button=virtualButton+1000, act=false}
					end
				end
			end )
			ZWaveSceneIdCacheList[zwave_dev_num] = zWaveSceneIdCache
		end
		local cacheEntry = zWaveSceneIdCache[zwave_scene]
		if not cacheEntry then
			ELog("SceneChange: Received unknown scene ID: ", zwave_scene, " peer_dev_num=", peer_dev_num, " cur_scene_time=", cur_scene_time)
			printTable(ZWaveSceneIdCacheList)
			return
		end
		activate = cacheEntry.act;
		physicalButton = (cacheEntry.button % 1000) - scrollOffset
	elseif zwave_scene > SCObj.NumButtons then
		activate = false;
		physicalButton = zwave_scene - SCObj.NumButtons
	else
		activate = true;
		physicalButton = zwave_scene
	end
	SceneButtonPressed(peer_dev_num, activate, physicalButton, false)
	-- See comment above regarding SetIndicator here.
	SetIndicator(peer_dev_num, GetCurrentScreen(peer_dev_num), false)
end

---
--- External device interface
---

-- Returns on%, lastUpdate, service, variable if the given device is on or off. (In the case of a binary device, retun 0 or 100%
-- Returns nil if the device does not exist or is not settable
function GetDeviceStatus(device_num)
  local device = luup.devices[device_num]
  if not device then
    return nil
  end
  if device.device_type == DEVTYPE_BINARY then
    local service = SID_SWITCHPOWER
	local variable = "Status"
    local result, lastUpdate = luup.variable_get(service, variable, device_num)
    if result == "1" or result == "0" then
      return tonumber(result)*100, lastUpdate, service, variable
    end
    return nil
  end
  if device.device_type == DEVTYPE_DIMMABLE or device.device_type == DEVTYPE_WINDOWCOVERING then
    local service = SID_DIMMING
	local variable = "LoadLevelStatus"
    local result, lastUpdate = luup.variable_get(service, variable, device_num)
	local value = tonumber(result)
	if value == nil then
	  return nil
	end
	return value, lastUpdate, service, variable
  end
  return nil
end

-- Set the device's status without sending any Z-Wave messages when we know what the controller set it to.
function SetDeviceStatus(device_num, value)
  DEntry()
  local device = luup.devices[device_num]
  if not device then
	DLog("  SetDeviceStatus: Device not found");
    return
  end
  local service, variable, status
  if device.device_type == DEVTYPE_BINARY then
	if value > 0 then
		status = "1"
	else
	    status = "0"
	end
	-- leave service as null since binary devices only have 1 status
  elseif device.device_type == DEVTYPE_DIMMABLE or device.device_type == DEVTYPE_WINDOWCOVERING then
    service = SID_DIMMING
	variable = "LoadLevelStatus"
	if value > 0 then
		status = "1"
	else
	    status = "0"
	end
	value = tostring(value)
  else
	DLog("  SetDeviceStatus: ", device.device_type, " not one of ", DEVTYPE_BINARY, ", ", DEVTYPE_DIMMABLE, " or ", DEVTYPE_WINDOWCOVERING);
    return
  end
  if service then
	  local oldValue = luup.variable_get(service, variable, device_num)
	  DLog("  SetDeviceStatus: service=", service, " variable=", variable, " oldValue=", oldValue, " value=", value)
	  if oldValue ~= value then
	    -- Temporarily unwatch the variable to avoid a loop which can cause problems if more than one device is attached to a button.
	    TempVariableUnwatch(service, variable, device_num) 
	  	luup.variable_set(service, variable, tostring(value), device_num)
	  end
  end
  service = SID_SWITCHPOWER
  variable = "Status"
  local oldStatus = luup.variable_get(service, variable, device_num)
  DLog("  SetDeviceStatus: service=", service, " variable=", variable, " oldStatus=", oldStatus, " status=", status)
  if oldStatus ~= status then
    -- Temporarily unwatch the variable to avoid a loop which can cause problems if more than one device is attached to a button.
    TempVariableUnwatch(service, variable, device_num) 
  	luup.variable_set(service, variable, tostring(status), device_num)
  end
end
