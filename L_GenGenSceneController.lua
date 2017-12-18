-- GenGeneric Scene Controller Version 1.00
-- Supports Evolve LCD1, Cooper RFWC5 and Nexia One Touch Controller
-- This software is distributed under the terms of the GNU General Public License 2.0
-- http://www.gnu.org/licenses/gpl-2.0.html

-- VerboseLogging == 0: important logs and errors:    ELog, log
-- VerboseLogging == 1: Includes debug logs:          ELog, log, DLog, DTableToString
-- VerboseLogging == 2: Include extended ZWave Queue  ELog, log, DLog, DTableToString,
-- VerboseLogging == 3:	Includes verbose logs:        ELog, log, DLog, DTableToString, VLog, VTableToString

local VerboseLogging = 3

bit = require "bit"
posix = require "posix"
socket = require "socket"
zwint = require "zwint"

DEVTYPE_EVOLVELCD1    = "urn:schemas-gengen_mcv-org:device:SceneControllerEvolveLCD:1"
DEVTYPE_COOPEREFWC5   = "urn:schemas-gengen_mcv-org:device:SceneControllerCooperRFWC5:1"
DEVTYPE_NEXIAONETOUCH = "urn:schemas-gengen_mcv-org:device:SceneControllerNexiaOneTouch:1"

SID_SCENECONTROLLER   = "urn:gengen_mcv-org:serviceId:SceneController1"
SID_ZWAVEMONITOR      = "urn:gengen_mcv-org:serviceId:ZWaveMonitor1"

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
		HasOffScenes            = true,
		HasIndicator			= true,
		HasButtonModes			= true,
		HasCooperConfiguration  = false,
		DefaultScreen           = "C1",
		DefaultModeString       = "M",
		DevType                 = DEVTYPE_EVOLVELCD1,
		ServiceId               = SID_SCENECONTROLLER,
		DeviceXml               = "D_EvolveLCD1.xml",
		NumTemperaturScrens     = 3, -- Preset Pages 8, 16, and 40
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
		SetTuningParameters = function(zwave_dev_num)
		    VLog("SetTuningParameters("..tostring(zwave_dev_num)..")")
			local versionString
			local retry = 0
			while retry < 10 do
				versionString = luup.variable_get(SID_ZWDEVICE, "VersionInfo", zwave_dev_num)
				if 	versionString == nil then
				    log("waiting for VersionInfo for device #" .. zwave_dev_num)
					luup.sleep(1000)
					retry = retry + 1;
				else
					break
				end
			end
			if not versionString then
				versionString = "1,3,20,0,39";
				log("Could not get versionInfo. Defaulting to "..versionString);
			end
			-- "VersionInfo" returns a string sunch as "1,3,20,0,37" which corresponds to firmware rev 0.37
			local version = tonumber(versionString:match("%d+,%d+,%d+,%d+,(%d+)"))
			if version == nil then
			    version = 39
			end
			if version >= 39 then
				-- This works OK for firmware version 00.00.39
				GetTuningParameter("SCENE_CTRL_BaseDelay"     		, 300 , zwave_dev_num)
				GetTuningParameter("SCENE_CTRL_ClearDelay"    		, 700 , zwave_dev_num)
				GetTuningParameter("SCENE_CTRL_LineDelay"     		, 35  , zwave_dev_num)
				GetTuningParameter("SCENE_CTRL_CharDelay"     		, 8   , zwave_dev_num)
				GetTuningParameter("SCENE_CTRL_ResponseDelay" 		, 30  , zwave_dev_num)
				GetTuningParameter("SCENE_CTRL_BackoffDelay"  		, 50  , zwave_dev_num)
				GetTuningParameter("SCENE_CTRL_MaxParts"      		, 2   , zwave_dev_num)
				GetTuningParameter("SCENE_CTRL_UseClearScreen"		, 1   , zwave_dev_num)
				GetTuningParameter("SCENE_CTRL_Retries"       		, 0   , zwave_dev_num)
			elseif version >= 37 then
				-- This works OK for firmware version 00.00.37
				GetTuningParameter("SCENE_CTRL_BaseDelay"     		, 100 , zwave_dev_num)
				GetTuningParameter("SCENE_CTRL_ClearDelay"    		, 700 , zwave_dev_num)
				GetTuningParameter("SCENE_CTRL_LineDelay"     		, 100 , zwave_dev_num)
				GetTuningParameter("SCENE_CTRL_CharDelay"     		, 10  , zwave_dev_num)
				GetTuningParameter("SCENE_CTRL_ResponseDelay" 		, 30  , zwave_dev_num)
				GetTuningParameter("SCENE_CTRL_BackoffDelay"  		, 50  , zwave_dev_num)
				GetTuningParameter("SCENE_CTRL_MaxParts"      		, 2   , zwave_dev_num)
				GetTuningParameter("SCENE_CTRL_UseClearScreen"		, 1   , zwave_dev_num)
				GetTuningParameter("SCENE_CTRL_Retries"       		, 10  , zwave_dev_num)
			else
				-- From Sig's feedback on forum.micasaverde.com
				-- for version 00.00.31
				-- "I tried a bunch of different settings - none of them, including these, really resulted
				--  in perfectly stable operation - the device still reboots almost every time I do a screen
				--  change.  But as I mentioned in my prior note, the controllers are now set to how I use
				--  them, and I'm not re-drawing screens during normal operation, so they're working just fine."
				GetTuningParameter("SCENE_CTRL_BaseDelay"     		, 3000, zwave_dev_num)
				GetTuningParameter("SCENE_CTRL_ClearDelay"    		, 5   , zwave_dev_num)
				GetTuningParameter("SCENE_CTRL_LineDelay"     		, 5   , zwave_dev_num)
				GetTuningParameter("SCENE_CTRL_CharDelay"     		, 5   , zwave_dev_num)
				GetTuningParameter("SCENE_CTRL_ResponseDelay" 		, 30  , zwave_dev_num)
				GetTuningParameter("SCENE_CTRL_BackoffDelay"  		, 50  , zwave_dev_num)
				GetTuningParameter("SCENE_CTRL_MaxParts"      		, 1   , zwave_dev_num)
				GetTuningParameter("SCENE_CTRL_UseClearScreen"		, 0   , zwave_dev_num)
				GetTuningParameter("SCENE_CTRL_Retries"       		, 10  , zwave_dev_num)
			end
			GetTuningParameter("SCENE_CTRL_SwitchScreenDelay"	    , 50  , zwave_dev_num)
			GetTuningParameter("SCENE_CTRL_InitStaggerSeconds"	    , 15  , zwave_dev_num)
			GetTuningParameter("SCENE_CTRL_MinReinitSeconds"	    , 60 * 60 * 24  , zwave_dev_num)
			GetTuningParameter("SCENE_CTRL_ReturnRouteDelay"		, 500 , zwave_dev_num)
			GetTuningParameter("SCENE_CTRL_UseWithSlaveController"  , 0   , zwave_dev_num)
			GetTuningParameter("SCENE_CTRL_AssociationDelay"        , 0   , zwave_dev_num)
			GetTuningParameter("SCENE_CTRL_SceneControllerConfDelay", 375 , zwave_dev_num)

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
					luup.variable_set(SCObj.ServiceId, "Label_C" .. screen .. "_" .. i, labels[i + (screen - 1) * 5], peer_dev_num)
					luup.variable_set(SCObj.ServiceId, "Mode_C"  .. screen .. "_" .. i, "M",  peer_dev_num)
				end
			end
			local labels2 = {"Forty-one", "Forty-five", "Forty-six", "Fifty",
							 "Fifty-one", "Fifty-five", "Fifty-six", "Sixty"}
			for screen = 1, 4 do
				luup.variable_set(SCObj.ServiceId, "Label_T" .. screen+2 .. "_" .. 1, labels2[1 + (screen - 1) * 2], peer_dev_num)
				luup.variable_set(SCObj.ServiceId, "Mode_T"  .. screen+2 .. "_" .. 1, "M",  peer_dev_num)
				luup.variable_set(SCObj.ServiceId, "Label_T" .. screen+2 .. "_" .. 5, labels2[2 + (screen - 1) * 2], peer_dev_num)
				luup.variable_set(SCObj.ServiceId, "Mode_T"  .. screen+2 .. "_" .. 5, "M",  peer_dev_num)
			end
		end,

		PhysicalButtonToIndicator = function(button)
			-- Bits 0 and 1 are used for "Do Not Disturb" and "Housekeeping"
			return bit.lshift(2,button)
		end,

		SetButtonType = function(peer_dev_num, node_id, physicalButton, newType)
			SetConfigurationOption("SetButtonType", peer_dev_num, node_id, physicalButton, newType)
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
				ELog("ScreenPage: Unknown screen: "..tostring(screen));
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

		SetBackLight = function(peer_dev_num, blackLightOn)
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
		HasOffScenes            = false,
		HasIndicator			= true,
		HasButtonModes			= false,
		HasCooperConfiguration  = true,
		DefaultScreen           = "P1",
		DefaultModeString       = "T",
		DevType                 = DEVTYPE_COOPEREFWC5,
		ServiceId               = SID_SCENECONTROLLER,
		DeviceXml               = "D_CooperRFWC5.xml",
		NumTemperaturScrens     = 0,
	    LargeFontWidths         = {}, -- Empty if not HasScreen
	    SmallFontWidths         = {}, -- Empty if not HasScreen
		screenWidth             = 1,  -- Dummy if not HasScreen
		rightJustifyScreenWidth = 1,
		SetTuningParameters = function(zwave_dev_num)
		    VLog("SetTuningParameters("..tostring(zwave_dev_num)..")")
			GetTuningParameter("SCENE_CTRL_InitStaggerSeconds"	    , 30            , zwave_dev_num)
			GetTuningParameter("SCENE_CTRL_MinReinitSeconds"	    , 60 * 60 * 24  , zwave_dev_num)
			GetTuningParameter("SCENE_CTRL_ReturnRouteDelay"		, 500           , zwave_dev_num)
			GetTuningParameter("SCENE_CTRL_UseWithSlaveController"  , 0             , zwave_dev_num)
			GetTuningParameter("SCENE_CTRL_Retries"       		    , 0             , zwave_dev_num)
			GetTuningParameter("SCENE_CTRL_AssociationDelay"        , 5000          , zwave_dev_num)
			GetTuningParameter("SCENE_CTRL_SceneControllerConfDelay", 0             , zwave_dev_num)
		end,

		SetDefaultLabels = function(peer_dev_num)
			-- Empty if not HasScreen
		end,

		PhysicalButtonToIndicator = function(button)
			return bit.lshift(1,button-1)
		end,

		SetButtonType = function(peer_dev_num, node_id, physicalButton, newType)
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

		SetBackLight = function(peer_dev_num, blackLightOn)
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
		HasOffScenes            = false,
		HasIndicator			= false,
		HasButtonModes			= true,
		HasCooperConfiguration  = false,
		DefaultScreen           = "C1",
		DefaultModeString       = "M",
		DevType                 = DEVTYPE_NEXIAONETOUCH,
		ServiceId               = SID_SCENECONTROLLER,
		DeviceXml               = "D_NexiaOneTouch.xml",
		NumTemperaturScrens     = 0,
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
		SetTuningParameters = function(zwave_dev_num)
		    VLog("SetTuningParameters("..tostring(zwave_dev_num)..")")
			GetTuningParameter("SCENE_CTRL_BaseDelay"     		, 300 , zwave_dev_num)
			GetTuningParameter("SCENE_CTRL_ClearDelay"    		, 700 , zwave_dev_num)
			GetTuningParameter("SCENE_CTRL_LineDelay"     		, 35  , zwave_dev_num)
			GetTuningParameter("SCENE_CTRL_CharDelay"     		, 8   , zwave_dev_num)
			GetTuningParameter("SCENE_CTRL_ResponseDelay" 		, 30  , zwave_dev_num)
			GetTuningParameter("SCENE_CTRL_BackoffDelay"  		, 50  , zwave_dev_num)
			GetTuningParameter("SCENE_CTRL_MaxParts"      		, 2   , zwave_dev_num)
			GetTuningParameter("SCENE_CTRL_UseClearScreen"		, 1   , zwave_dev_num)
			GetTuningParameter("SCENE_CTRL_Retries"       		, 0   , zwave_dev_num)
			GetTuningParameter("SCENE_CTRL_SwitchScreenDelay"	    , 50  , zwave_dev_num)
			GetTuningParameter("SCENE_CTRL_InitStaggerSeconds"	    , 15  , zwave_dev_num)
			GetTuningParameter("SCENE_CTRL_MinReinitSeconds"	    , 60 * 60 * 24  , zwave_dev_num)
			GetTuningParameter("SCENE_CTRL_ReturnRouteDelay"		, 500 , zwave_dev_num)
			GetTuningParameter("SCENE_CTRL_UseWithSlaveController" , 0   , zwave_dev_num)
			GetTuningParameter("SCENE_CTRL_AssociationDelay"       , 0   , zwave_dev_num)
			GetTuningParameter("SCENE_CTRL_SceneControllerConfDelay", 0  , zwave_dev_num)
		end,

		SetDefaultLabels = function(peer_dev_num)
			local labels = {"One", "Two", "Three", "Four", "Five",
							"Six", "Seven", "Eight", "Nine", "Ten",
							"Eleven", "Twelve", "Thir-teen", "Four-teen", "Fifteen",
							"Sixteen", "Seven-teen", "Eight-teen", "Nine-teen", "Twenty",
							"Twenty one", "Twenty two", "Twenty three", "Twenty four", "Twenty five",
							"Twenty six", "Twenty seven", "Twenty eight", "Twenty nine", "Thirty"}
			for i = 1,15 do
				luup.variable_set(SCObj.ServiceId, "Label_C1_" .. i, labels[i], peer_dev_num)
				luup.variable_set(SCObj.ServiceId, "Mode_C1_" .. i, "M",  peer_dev_num)
			end
		end,

		PhysicalButtonToIndicator = function(button)
			-- Nexia One Touch does not support the indicator command class
			return 0
		end,

		SetButtonType = function(peer_dev_num, node_id, physicalButton, newType)
			SetConfigurationOption("SetButtonType", peer_dev_num, node_id, physicalButton + 1, newType)
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

		SetBackLight = function(peer_dev_num, blackLightOn)
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
		},

		-- Convert a mode object to a mode type.
		ModeType = function (mode)
			local result = SCObj.ModeMap[mode.prefix];
			if result == nil then
				result = 0
			end
			if result == 3 and #mode > 0 and not mode.sceneControllable then
			    -- There are non-scene-capable direct associations, so we need to use basic set rather than scene activate/deactivate messages.
				result = 2
			end
			return result
		end,
	}, -- DEVTYPE_NEXIAONETOUCH
} -- Devices

DEVTYPE_ZWN        = "urn:schemas-micasaverde-com:device:ZWaveNetwork:1"
DEVTYPE_BINARY     = "urn:schemas-upnp-org:device:BinaryLight:1"
DEVTYPE_DIMMABLE   = "urn:schemas-upnp-org:device:DimmableLight:1"
DEVTYPE_THERMOSTAT = "urn:schemas-upnp-org:device:HVAC_ZoneThermostat:1"

SID_HADEVICE       = "urn:micasaverde-com:serviceId:HaDevice1"
SID_HAG            = "urn:micasaverde-com:serviceId:HomeAutomationGateway1"
SID_SCTRL          = "urn:micasaverde-com:serviceId:SceneController1"
SID_ZWN       	   = "urn:micasaverde-com:serviceId:ZWaveNetwork1"
SID_ZWDEVICE       = "urn:micasaverde-com:serviceId:ZWaveDevice1"
SID_DIMMING        = "urn:upnp-org:serviceId:Dimming1"
SID_FANMODE        = "urn:upnp-org:serviceId:HVAC_FanOperatingMode1"
SID_USERMODE       = "urn:upnp-org:serviceId:HVAC_UserOperatingMode1"
SID_SWITCHPOWER    = "urn:upnp-org:serviceId:SwitchPower1"
SID_TEMPSENSOR     = "urn:upnp-org:serviceId:TemperatureSensor1"
SID_COOLSETPOINT   = "urn:upnp-org:serviceId:TemperatureSetpoint1_Cool"
SID_HEATSETPOINT   = "urn:upnp-org:serviceId:TemperatureSetpoint1_Heat"

ACTUATOR_CONF	   = "SceneActuatorConf"
CURRENT_INDICATOR  = "CurrentIndicator"
CURRENT_SCREEN     = "CurrentScreen"
FANMODE_AUTO       = "Auto"
FANMODE_ON         = "ContinuousOn"
FANMODE_VAR        = "Mode"
NUMLINES_VAR       = "NumLines"
PRESET_LANGUAGE    = "PresetLanguage"
RETURN_ROUTES      = "ReturnRoutes"
SCROLLOFFSET_VAR   = "ScrollOffset"
SETPOINT_TARG      = "SetpointTarget"
SETPOINT_VAR       = "CurrentSetpoint"
TEMPSENSOR_VAR     = "CurrentTemperature"
USERMODE_VAR       = "ModeStatus"
USERMODE_AUTO      = "AutoChangeOver"
USERMODE_COOL      = "CoolOn"
USERMODE_HEAT      = "HeatOn"
USERMODE_OFF       = "Off"

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

local SceneIdCacheList = {}
local ZWaveQueue = {}
local ExternalZWaveQueue = {}
local ZWaveQueueNext = nil
local ZWaveQueueLastInsert = nil
local ZWaveQueueNodes = 0
local param = {}

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

-- Make sure tha all of the log functions work before even the SCObj global is set.
function GetDeviceName()
  local name = "Scene Controller"
  if SCObj then
	 name = SCObj.Name
  end
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

--
-- Start benchmark code
--
function findBestDelay(labels, node_id, zwave_dev_num, first, last, screenFlags)
	SetFlushLogs(true)
	local save_retries = param.SCENE_CTRL_Retries
	param.SCENE_CTRL_Retries = 1
	local low = 1
	local high = 1000
	while high > low do
	    local test = math.floor((high + low) / 2)
	    local count = 0
		local bad = 0
		for i = 1,10 do
			log("Benchmark Testing " .. tableToString(labels) .. "delay=" .. test .. " iteration=" .. i)
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
			log("Benchmark test " .. tableToString(labels) .. " delay=" .. test .. " passed")
			high = test
		else
			log("Benchmark test " .. tableToString(labels) .. " delay=" .. test .. " failed")
			low = test+1
		end
	end
	log ("Benchmark test " .. tableToString(labels) .. " Best value is " .. high)
	param.SCENE_CTRL_Retries = save_retries
	SetFlushLogs(false)
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

local SceneController_ForceDefaultParameters = true
function GetTuningParameter(name, default_value, zwave_dev_num)
	local value = luup.variable_get(SCObj.ServiceId, name, zwave_dev_num)
	if SceneController_ForceDefaultParameters or value == nil then
		value = default_value
		luup.variable_set(SCObj.ServiceId, name, value, zwave_dev_num)
	else
		value = tonumber(value)
	end
	param[name] = value
	luup.variable_watch("SceneController_ParamChange", SCObj.ServiceId, name, zwave_dev_num)
end

--
-- Z-Wave Queue and job handling
--
function EnqueueActionOrMessage(queueNode)
  local first_peer = GetFirstPeer()
  local peer_dev_num = GetPeerDevNum(luup.device)
  local description = ""
  if peer_dev_num then
	description = luup.devices[peer_dev_num].description
	if queueNode.pattern then
	  queueNode.responseDevice = peer_dev_num
	end
  end
  queueNode.description = description
  if first_peer == peer_dev_num then
	VLog("EnqueueActionOrMessage-Internal: "..VTableToString(queueNode))
	local node_id = queueNode.node_id
	if not node_id then
		node_id = 0
	end
	local newDev = ZWaveQueue[node_id]
	if not newDev then
	  newDev = {node_id=node_id}
	  ZWaveQueue[node_id] = newDev
	  ZWaveQueueNodes = ZWaveQueueNodes + 1
	  if not ZWaveQueueNext then
		newDev.next = newDev
		newDev.prev = newDev
		ZWaveQueueNext = newDev
	  else
		newDev.next = ZWaveQueueNext
		newDev.prev = ZWaveQueueNext.prev
		ZWaveQueueNext.prev.next = newDev
		ZWaveQueueNext.prev = newDev
	  end
 	end
  	table.insert(newDev, queueNode)
  	ZWaveQueueLastInsert = newDev;
	if queueNode.node_id == 0 and ZWaveQueueNext ~= newDev then
		-- Node 0 entries have priority. Bring them to the front of the queue.
		newDev.next.prev = newDev.prev
		newDev.prev.next = newDev.next
		newDev.next = ZWaveQueueNext
		newDev.prev = ZWaveQueueNext.prev
		ZWaveQueueNext.prev.next = newDev
		ZWaveQueueNext.prev = newDev
		ZWaveQueueNext = newDev
	end
  else
	VLog("EnqueueActionOrMessage-External: "..VTableToString(queueNode))
	table.insert(ExternalZWaveQueue, queueNode)
  end
end

-- Enqueue a Z-Wave message. No response is expected. Wait <delay> milliseconds
-- before sending a Z-Wave command to the same device
function EnqueueZWaveMessage(name, node_id, data, delay)
  EnqueueActionOrMessage({
  	type=1,
  	name=name,
  	node_id=node_id,
  	data=data,
  	delay=delay})
end

-- Enqueue a Lua action within the Z-Wave queue
function EnqueueLuupAction(name, device, service, action, arguments, delay)
  EnqueueActionOrMessage({
  	type=2,
  	name=name,
  	device=device,
  	node_id=-1,
  	service=service,
  	action=action,
  	arguments=arguments,
  	delay=delay})
end

local ResponseContextList = {}
local ResponseContextNum = 0

-- Enqueue a Z-Wave message, expecting a response.
-- pattern is a Linux externed refular expression which will be matched against the hexified incoming Z-Wave data.
-- Callback is a function which is passed the peer device number and any captures
-- from the regex. The capture array is nil if a timeout occurred.
-- If callback is nil, then this can be used to wait until the response is receviced without regard to its value.
-- Oneshot is true if the monitor should be canceled as soon as it matches.
-- Timeout and delay are in milliseconds.
-- If timeeout is 0 then the monitor will be active until canceled with CancelZWaveMonitor 
-- Delay is applied after the response is received but ignored in case of a timeout.
-- Returns a context which can be passed to CancelZWaveMonitor.
function EnqueueZWaveMessageWithResponse(name, node_id, data, delay, pattern, callback, oneshot, timeout)
  local context
  if callback then
  	ResponseContextNum = ResponseContextNum + 1
  	context = "M" .. node_id.."_"..ResponseContextNum
  	ResponseContextList[context] = {callback=callback, oneshot=oneshot} 
  end
  EnqueueActionOrMessage({
  	type=1,
  	name=name,
  	node_id=node_id,
  	data=data,
  	delay=delay,
  	pattern=pattern,
  	context=context,
	oneshot=oneshot,
  	timeout=timeout})
  return context
end

-- Intervepts a Z-Wave message sent by LuaUPnP and sends an expected response back to LuaUPnP
-- Arm_regex is an optional Linux extended regular expression which will be matched 
--   against the hexified incoming data from the Z-Wave controller. A match will arm the intercept.
--   If arm_pattern is nil then the intercept is always armed. 
-- Intercept_regex is a Linux externed regular expression which will be matched 
--   against the hexified outgoing Z-Wave data from LuaUPnP. A match will prevent this message to
--   be sent to the Z-Wave controller. The response string is sent back to LuaUPnP as if it had
--   come from the controller.
-- Response is a hex string which will be returned to the LuaUPnP engine (after converting into
--   binary) when intercept_regex is matched and the intercept is armed.
--   The response string can also include \1 .. \9 captures from the intercept regex (but not the
--   arm regex) and can also include XX to calculate the Z-Wave checksum. 
-- Callback is a function which is passed the peer device number and any captures from
--   the intercept regex. The capture array is nil if a timeout occurred.
--   Callback must not be nil.
-- Oneshot is true if the intercept should be canceled as soon as it matches.
--   If OneShot is false and arm_regex is not nil, then the intercept is disarmed when it triggers.
-- Timeout and delay are in milliseconds.
--   If timeeout is 0 then the monitor will be active until canceled with CancelZWaveMonitor 
-- Returns a context which can be passed to CancelZWaveMonitor or nil if error.
function InterceptZWaveData(arm_regex, intercept_regex, response, callback, owneshot, timeout)
  VLog("InterceptZWaveData: arm_regex="..tostring(arm_regex).." intercept_regex="..tostring(intercept_regex).." response="..tostring(response).." callback="..tostring(callback).." owneshot="..tostring(owneshot).." timeout="..tostring(timeout)) 
  if not callback then
	ELog("Callback is nil")
	return nil
  end
  local peer_dev_num = GetPeerDevNum(luup.device)
  ResponseContextNum = ResponseContextNum + 1
  context = "I" .. peer_dev_num.."_"..ResponseContextNum
  ResponseContextList[context] = {callback=callback, oneshot=oneshot}
  local result, errcode, errmessage = zwint.intercept(peer_dev_num, context, intercept_regex, owneshot, timeout, arm_regex, response)
  if not result then
	ELog("InterceptZWaveData: zwint.intercept failed. error code="..tostring(errcode).." error message="..tostring(errmessage))
	ResponseContextList[context] = nil;
	return nil;
  end 
  return context;   
end

function RemoveHeadFromZWaveQueue()
	if not ZWaveQueueNext then
		return false
	end
	table.remove(ZWaveQueueNext,1)
	if #ZWaveQueueNext == 0 then
		ZWaveQueue[ZWaveQueueNext.node_id] = nil
		ZWaveQueueNodes = ZWaveQueueNodes - 1
		if ZWaveQueueNext.next == ZWaveQueueNext then
			ZWaveQueueNext = nil
			return false
		else
			ZWaveQueueNext.next.prev = ZWaveQueueNext.prev
			ZWaveQueueNext.prev.next = ZWaveQueueNext.next
			ZWaveQueueNext = ZWaveQueueNext.next
			return true
		end
	end
	if ZWaveQueueNext.node_id ~= 0 then
		ZWaveQueueNext = ZWaveQueueNext.next
	end
	return true;
end

-- Always run the Z-Wave queue in a delay task to avoid any deadlocks.
function RunZWaveQueue(fromWhere, delay_ms)
	DLog("RunZWaveQueue: fromWhere="..tostring(fromWhere).." delay_ms="..tostring(delay_ms))
	local delay = math.floor((delay_ms + 500) / 1000)
	if ZWaveQueueNext then
		local delay = delay_ms/ 1000
		--if ZWaveQueueNext ~= ZWaveQueueLastInsert then
		--	delay = 0
		--end
		VLog("RunZWaveQueue: Calling delayed RunInternalZWaveQueue. Delay="..tostring(delay))
		luup.call_delay("RunInternalZWaveQueue", delay,fromWhere,true)
	end
	if #ExternalZWaveQueue > 0 then
		VLog("RunZWaveQueue: Calling delayed RunExternalZWaveQueue. Delay="..tostring(delay))
		luup.call_delay("RunExternalZWaveQueue", delay,fromWhere,true)
	end
end

function RunExternalZWaveQueue(fromWhere)
	VLog("RunExternalZWaveQueue: fromWhere="..tostring(fromWhere).."Queue size="..#ExternalZWaveQueue)
	if #ExternalZWaveQueue == 0 then
		return
	end
	local data = {}
	for i,v in ipairs(ExternalZWaveQueue) do
		local ix = "E" .. i;
		data["E"..i] = tableToString(v);
		data.NumEntries = #ExternalZWaveQueue
	end
	ExternalZWaveQueue = {}
  	luup.call_action(SID_SCENECONTROLLER, "RunZWaveQueue", data, GetFirstPeer())
end

function SceneController_RunZWaveQueue(device, settings)
	DLog("SceneController_RunZWaveQueue: device="..tostring(device).." numEntries="..tostring(settings.NumEntries))
	for i = 1, tonumber(settings.NumEntries) do
		if VerboseLogging == 1 then -- VerboseLogging > 1 already has a similar display.
			DLog("  Setting #"..i.."="..tostring(settings["E"..i]))
		end
		EnqueueActionOrMessage(assert(loadstring("return "..settings["E"..i],"E"..i))())
	end
	RunZWaveQueue("External", 0)
end

local taskHandle = -1;
function RunInternalZWaveQueue(fromWhere)
local iter = 0
  while true do
iter = iter + 1
VLog("RunInternalZWaveQueue("..tostring(fromWhere)..") iter="..iter)
  	if not ZWaveQueueNext then
      VLog("RunInternalZWaveQueue: fromWhere="..tostring(fromWhere).." queue is empty")
	  return
  	end

  	if ZWaveQueueNext[1].pending then
	  VLog("RunInternalZWaveQueue("..tostring(fromWhere)..") Job still pending: job="..VTableToString(ZWaveQueueNext[1]))
	  return
  	end

  	if ZWaveQueueNext[1].waitingForResponse then
	  VLog("RunInternalZWaveQueue("..tostring(fromWhere)..") Job still waiting for a response: job="..VTableToString(ZWaveQueueNext[1]))
	  return
  	end

  	-- If the head of the queue is in a time delay, look around for another jobe which we can perform
  	-- in the meantime.
  	if not ZWaveQueueNext[1].waitingForJob then
   	  local now = socket.gettime()
      local nextTime = nil
      local nextQueue = nil
      local ZWaveQueueFirst = ZWaveQueueNext
  	  while ZWaveQueueNext[1].waitUntil do
  	    if ZWaveQueueNext[1].waitUntil > now then
  		  if not nextTime or nextTime > ZWaveQueueNext[1].waitUntil then
  		    nextTime = ZWaveQueueNext[1].waitUntil
  		    nextQueue = ZWaveQueueNext
  		  end
  		  if ZWaveQueueNext.node_id ~= 0 and ZWaveQueueNext.next ~= ZWaveQueueFirst then
  		    ZWaveQueueNext = ZWaveQueueNext.next
  		  else
  		    ZWaveQueueNext = nextQueue
  		    local waitTime = nextTime - now
  		    if waitTime >= 1 then
			  VLog("RunInternalZWaveQueue: Delaying for "..waitTime.." seconds using luup.call_delay.")
  			  luup.call_delay("RunInternalZWaveQueue", waitTime, fromWhere.." DelayFor ".. waitTime, true)
  			  return
  		    else
			  VLog("RunInternalZWaveQueue: Delaying for "..waitTime.." seconds using luup.sleep.")
  			  luup.sleep(waitTime*1000)
  			  if not RemoveHeadFromZWaveQueue() then
  			  	return
  			  end
  			  break
  		    end
  		  end
  	    elseif not RemoveHeadFromZWaveQueue() then
  	  	  return
  	    end
  	  end
    end

  	if VerboseLogging >= 2 then
      local curDev = ZWaveQueueNext
	  local count = 1;
	  repeat
		DLog  ("RunInternalZWaveQueue("..tostring(fromWhere)..")   Node_id: " .. curDev.node_id .. "  Next: " .. curDev.next.node_id .. "  Prev: " .. curDev.prev.node_id)
	    for i = 1, #curDev do
	      DLog("RunInternalZWaveQueue("..tostring(fromWhere)..")     Entry "..count..": "..DTableToString(curDev[i]))
		  count = count + 1;
	    end
	    curDev = curDev.next
	  until curDev == ZWaveQueueNext
	elseif VerboseLogging > 0 then
  	  local count = 0
  	  local curDev = ZWaveQueueNext
	  local nodelist = ""
	  repeat
	  	nodelist = nodelist .. curDev.node_id .. "("..#curDev..") "
		curDev = curDev.next;
		count = count + 1
	  until curDev == ZWaveQueueNext or count > 10
	  DLog("RunInternalZWaveQueue("..tostring(fromWhere).."): Nodes: "..ZWaveQueueNodes.." ( " .. nodelist .. ")")
	end

	local veraZWaveNode, ZWaveNetworkDeviceId = GetVeraIDs()
    local j = ZWaveQueueNext[1];
	if j.pattern and not j.patternSet then
--[==[
	  	-- If the context (callback) is nil, assume that we are just waiting for timing synchronization
	  	-- Set the response device to the first peer (the device running the Z-Wave queue) so it can
	  	-- unblock when the response is received. If the context is non-nil then assume that the
	  	-- device needs the result of the response before issuing other callse. We do not implement
	  	-- a "relay" between the Z-Wave monitor and a non-first peer.
	  	if not j.context then
			j.responseDevice = GetFirstPeer()
	  	end
	  	VLog("RunInternalZWaveQueue("..fromWhere.."): Calling MonitorZWave: "..tableToString(j))
	  	luup.call_action(SID_ZWAVEMONITOR, "MonitorZWave", {
        			   	 responseDevice=j.responseDevice,
        			     pattern=j.pattern,
        				 context=j.context,
        				 timeout=j.timeout},
        			     GetZWabeMonitor())
	  	VLog("RunInternalZWaveQueue("..fromWhere.."): Finished calling MonitorZWave: "..tableToString(j))
--]==]
	  	VLog("RunInternalZWaveQueue("..fromWhere.."): Calling zwint.monitor: "..tableToString(j))
	 	zwint.monitor(j.responseDevice,j.context,j.pattern,j.oneshot,j.timeout); 
	  	j.patternSet = true
	end
	if not j.waitingForJob then
	  if j.type == 1 then
		if j.node_id > 0 then
		  VLog("RunInternalZWaveQueue: type=ZWave, Node=Device name="..j.name..": " .. SID_ZWN .. " SendData " .. VTableToString({Node = j.node_id, Data = j.data}) .. " " .. ZWaveNetworkDeviceId);
		  j.err_num, j.err_msg, j.job_num, j.arguments = luup.call_action(SID_ZWN, "SendData", {Node = j.node_id, Data = j.data}, ZWaveNetworkDeviceId)
		else
		  VLog("RunInternalZWaveQueue: type=ZWave, Node=Controller name="..j.name..": " .. SID_ZWN .. " SendData " .. VTableToString({Data = j.data}) .. " " .. ZWaveNetworkDeviceId);
		  j.err_num, j.err_msg, j.job_num, j.arguments = luup.call_action(SID_ZWN, "SendData", {                  Data = j.data}, ZWaveNetworkDeviceId)
		end
	  else
		VLog("RunInternalZWaveQueue: type=LuaAction: name=" .. j.name)
		j.err_num, j.err_msg, j.job_num, j.arguments = luup.call_action(j.service, j.action, j.arguments, j.device)
	  end
	  VLog("RunInternalZWaveQueue: call_action returned err_num="..tostring(j.err_num).." err_msg="..tostring(j.err_msg).." job_num="..tostring(j.job_num).." arguments="..VTableToString(j.arguments))
	  if j.err_num ~= 0 or j.job_num == 0 then
	    log("RunInternalZWaveQueue("..tostring(fromWhere).."): call_action failed, retrying in 5 seconds." ..tableToString(j));
	    luup.call_delay("RunInternalZWaveQueue", 5, fromWhere.." retry", true)
	    return
	  end
	else
		VLog("RunInternalZWaveQueue: Still waiting for job: "..tableToString(j))
	end
	if j.responseDevice == GetFirstPeer() then
	  j.waitingForResponse = true
	end
	if luup.job_watch then
	  j.pending = true
	  return
	end

	-- From here down is for UI5 only

	j.waitingForJob = true
	if not j.slept then
	  j.slept = 0
	end
    if j.slept < 100 then
  	  luup.sleep(100 - j.slept)
	  j.slept = 100
    end
	while j.slept < 60000 and (j.err_num < 2 or j.err_num > 4) do
      j.err_num, j.err_msg = luup.job.status(j.job_num, 1)
	  if not j.err_msg then
		j.err_msg = ""
	  end
	  if j.err_num == 0 then
	    j.err_msg = j.err_msg .. "Waiting to start"
	  end
	  if j.slept > 100 then
	    j.err_msg = j.err_msg .. " after " .. math.floor(j.slept/100)/10 .. " seconds"
		if j.err_num ~= 4 then
          VLog("Job ".. j.job_num .. ":" .. j.description .. " - " .. j.name.." status:" .. j.err_num .. " - " .. j.err_msg)
        end
        taskHandle = luup.task(j.description .. ' - ' .. j.name, j.err_num, j.err_msg .. " at " .. os.date(), taskHandle)
	  end
	  local delay
      if j.slept < 600	then
		delay = math.random() * 200
	  else
		delay = math.random() * j.slept / 3
	  end
      j.slept = j.slept + delay
	  if delay < 1000 then
		VLog("sleeping for " .. delay .. " ms")
        luup.sleep(delay)
	  else
	    local seconds = math.floor(delay/1000 + .5)
		--  luup.call_delay and loo.call_timer(1=interval) is not always delaying correctly.
		--  So, use absolute time to delay at least 1 second.
		--luup.call_delay("RunInternalZWaveQueue", idelay, fromWhere, true)
		--luup.call_timer("RunInternalZWaveQueue", 1, tostring(seconds), "", fromWhere)
		local next = os.time() + seconds
		local timestr = os.date("%Y-%m-%d %H:%M:%S", next)
		VLog("delaying for " .. seconds .. " seconds until " .. timestr)
		luup.call_timer("RunInternalZWaveQueue", 4, timestr, "", fromWhere)
	    return
	  end
	end

	-- At this point, the UI5 job completed, one way or another.
	j.waitingForJob = false
    if j.err_num ~= 4 then
      ELog("RunInternalZWaveQueue: Job ".. j.job_num..":".. j.name.." failed. err_num=".. j.err_num.." err_msg=".. j.err_msg.." job_num=".. j.job_num.." arguments="..tableToString(j.arguments))
      j.waitingForResponse = false -- Let the response time out since the request failed.
    end
    if j.waitingForResponse then
      return
    elseif j.delay > 0 then
      local now = socket.gettime()
      j.waitUntil = now + j.delay / 1000
    elseif not RemoveHeadFromZWaveQueue() then
	  return
	end

  end -- while true
end -- RunInternalZWaveQueue

function SceneController_JobWatchCallBack(lul_job)
	VLog("SceneController_JobWatchCallBack: lul_job="..VTableToString(lul_job).." ZWaveQueueNodes="..tostring(ZWaveQueueNodes))
	if not ZWaveQueueNext then
		VLog("SceneController_JobWatchCallBack: ZWaveQueue is empty.");
		return
	end
	local j = ZWaveQueueNext[1]
	local expectedJobType, expectedName
	if j.node_id == 0 then
		expectedJobType = "ZWJob_GenericSendFrame"
		expectedName = "send_code"
	else
		expectedJobType = "ZWJob_SendData"
		expectedName = "childcmd node "..j.node_id
	end
	if lul_job.type ~= expectedJobType then
		VLog("SceneController_JobWatchCallBack: Job type expected " .. expectedJobType .. " but got " .. lul_job.type)
		return
	end
	if lul_job.name ~= expectedName then
		VLog("SceneController_JobWatchCallBack: Expected " .. expectedName .. " but got " .. lul_job.name)
		return
	end
	if lul_job.status < 2 or lul_job.status > 4 then
		VLog("SceneController_JobWatchCallBack: status is still " .. lul_job.status .. ". notes:" .. lul_job.notes)
		return
	end
	if lul_job.status == 2 then -- error
		if not j.retry then
			j.retry = 1
		else
			j.retry = j.retry + 1
		end
		ELog("SceneController_JobWatchCallBack: Job failed. retry=" .. j.retry)
		if j.retry <= 3 then
			RunZWaveQueue("Retry_Job", 0)
			return
		end
	end
	if lul_job.status ~= 4 then
		ELog("SceneController_JobWatchCallBack: Job failed. Skipping to next job. Final status was ".. lul_job.status .. " notes:" .. lul_job.notes)
		j.delay = 0
		j.waitingForResponse = false
	end
	if j.waitingForResponse then
		return
	end
	if j.delay > 0 then
		local now = socket.gettime()
		j.waitUntil = now + j.delay / 1000
		RunZWaveQueue("Delay_Job", 0)
	elseif RemoveHeadFromZWaveQueue() then
		RunZWaveQueue("Next_Job", job_delay)
	end
end

function SceneController_ZWaveMonitorResponse(device, response, context, is_intercept)
	local now = socket.gettime()
	VLog("SceneController_ZWaveMonitorResponse: device="..tostring(device).." response="..tableToString(response).." context="..tostring(context).." is_intercept="..tostring(is_intercept))
	if context then
		local obj = ResponseContextList[context]
		if obj.oneshot then
			ResponseContextList[context] = nil;
		end
		if obj.callback then
			obj.callback(device, response.C1, response.C2, response.C3, response.C4, response.C5, response.C6, response.C7, response.C8, response.C9)
		else
			ELog("SceneController_ZWaveMonitorResponse: Response context "..tostring(context).." not found in context list: "..tableToString(ResponseContextList))
		end
	end
	if device == GetFirstPeer() then
		if ZWaveQueueNext and ZWaveQueueNext[1].waitingForResponse then
			local j = ZWaveQueueNext[1]
			j.waitingForResponse = false
			if j.delay > 0 then
				j.waitUntil = now + j.delay / 1000
				RunZWaveQueue("Delay_Job_after_response", 0)
			elseif RemoveHeadFromZWaveQueue() then
				RunZWaveQueue("Next_Job_after_response", 0)
			end
		else
			ELOG("SceneController_ZWaveMonitorResponse: ZWave queuwe not waiting for response")
		end
	end
end

--
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
	if param.SCENE_CTRL_CharDelay == nil then
		SCObj.SetTuningParameters(zwave_dev_num)
	end
	local data = "146 2 " .. tostring(screenFlags) -- COMMAND_CLASS_SCREEN_META_DATA version 1 REPORT
	local part = 1
	local delay = param.SCENE_CTRL_BaseDelay
	if bit.band(screenFlags,SCREEN_MD.ScreenMask) ~= SCREEN_MD.NoChange then
		delay = delay + param.SCENE_CTRL_ClearDelay
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
			EnqueueZWaveMessage("SetLabel_"..node_id, node_id, data, delay);
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
						DLog("Adding line \"" .. label .. "\" entryNum=" .. entryNum .. " lnum=" .. lnum .. " part=" .. part .. " word=" .. word .. " wordWidth=" .. wordWidth .. " font=" .. font .. " align=" .. align)
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
	if param.SCENE_CTRL_Retries > 0 then
		SetFlushLogs(true)
	end
	if screenFlags == SCREEN_MD.NoChange then
		result = EVLCDLabel(screenFlags, lineArray, node_id, zwave_dev_num, delay_override)
	else
		result = EVLCDLabel(bit.bor(SCREEN_MD.MoreData, screenFlags), lineArray, node_id, zwave_dev_num, delay_override)
	end
	if param.SCENE_CTRL_Retries > 0 then
		SetFlushLogs(false)
	end
	return result
end

--
-- Initialization, primary controller and peer handling
--

-- GetDeviceCounter returns 1 for the lowest numbered contoller, 2 for the second, etc.
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
		ELog("GetDeviceCounter: Error device " .. our_zwave_dev_num .. "not found.")
	end
	return count
end

firstPeer = nil
function GetFirstPeer()
	if not firstPeer then
		local min
		for dev_num, v in pairs(luup.devices) do
			if Devices[v.device_type] and v.device_num_parent ~= 1 then
				if not firstPeer or firstPeer > dev_num then
					firstPeer = dev_num
				end
			end
		end
	end
	return firstPeer
end

function BatteryNoMoreInformationCallback(peer_dev_num, captures)
	VLog("BatteryNoMoreInformationCallback: peer_dev_num="..tostring(peer_dev_num).." captures="..tableToString(captures))
	local currentScreen
	if SCObj.HasMultipleScreens then
		currentScreen = luup.variable_get(SCObj.ServiceId, CURRENT_SCREEN, peer_dev_num)
	else
		currentScreen = SCObj.DefaultScreen
	end
	if currentScreen then
		log("SceneController_InitScreen starting for peer device " .. peer_dev_num .. " currentScreen=" .. currentScreen);
		-- Use the ForceClear flag in SetScreen to reset the display regardless of its previous state.
		SetScreen(peer_dev_num, currentScreen, true, true, false);
		-- Set LastInitTime to mark the time of the last successful InitScreen at LuaUPnP reload.
	end
	local node_id = GetZWaveNode(peer_dev_num)
    EnqueueZWaveMessage("BatteryNoMoreInformation", node_id, "0x84 0x8", 0);
	RunZWaveQueue("BatteryNoMoreInformation", 0);
end

function SceneController_Init(lul_device)
	DLog("Initializing LUA device " .. tostring(lul_device))
	log("ZWInt instance is "..zwint.instance())
	if lul_device == 1 then
		CreatePeerDevices()
	else
		ConnectPeerDevice(lul_device)
		local zwave_node, zwave_dev = GetZWaveNode(lul_device)
		if luup.job_watch then
			if lul_device == GetFirstPeer() then
	 			luup.job_watch("SceneController_JobWatchCallBack") -- Watch jobs on all devices.
			end
		else
			DLog("luup.job_watch does not exist")
		end
		local veraZWaveNode, ZWaveNetworkDeviceId = GetVeraIDs()
	    local ComPort = luup.variable_get(SID_ZWN, "ComPort", ZWaveNetworkDeviceId)
		VLog("SceneController_Init: calling zwint.register("..tostring(ComPort)..")");
		local result, errcode, errmsg = zwint.register(ComPort);
		VLog("SceneController_Init: zwint.register("..tostring(ComPort)..") returned result="..tostring(result).." errcode="..tostring(errcode).." errmsg="..tostring(errmsg));
		if SCObj.HasBattery then
			VLog("Calling InterceptZWaveData for battery device");
			InterceptZWaveData(
--[==[
42      12/04/16 20:05:26.449   0x1 0x8 0x0 0x4 0x4 0x9 0x2 0x84 0x7 0x7f (##########) 
           SOF - Start Of Frame --+   ¦   ¦   ¦   ¦   ¦   ¦    ¦   ¦    ¦
                     length = 8 ------+   ¦   ¦   ¦   ¦   ¦    ¦   ¦    ¦
                        Request ----------+   ¦   ¦   ¦   ¦    ¦   ¦    ¦
FUNC_ID_APPLICATION_COMMAND_HANDLER ----------+   ¦   ¦   ¦    ¦   ¦    ¦
           Receive Status BROAD ------------------+   ¦   ¦    ¦   ¦    ¦
Device 12=Nexia One Touch Scene Controller Z-Wave ----+   ¦    ¦   ¦    ¦
                Data length = 2 --------------------------+    ¦   ¦    ¦
          COMMAND_CLASS_WAKE_UP -------------------------------+   ¦    ¦
           WAKE_UP_NOTIFICATION -----------------------------------+    ¦
                    Checksum OK ----------------------------------------+
--]==]
			"^01 .. 00 04 .. " .. string.format("%02X", zwave_node) .. " .. 84 07",
--[==[
41      12/04/16 20:05:27.515   0x1 0xd 0x0 0x19 0x9 0x2 0x84 0x8 0x5 0x0 0x0 0x0 0x0 0x4 0x6d (#\r############m) 
           SOF - Start Of Frame --+   ¦   ¦    ¦   ¦   ¦    ¦   ¦   ¦ +-------------+   ¦    ¦
                    length = 13 ------+   ¦    ¦   ¦   ¦    ¦   ¦   ¦        ¦          ¦    ¦
                        Request ----------+    ¦   ¦   ¦    ¦   ¦   ¦        ¦          ¦    ¦
   FUNC_ID_ZW_SEND_DATA_GENERIC ---------------+   ¦   ¦    ¦   ¦   ¦        ¦          ¦    ¦
Device 12=Nexia One Touch Scene Controller Z-Wave -+   ¦    ¦   ¦   ¦        ¦          ¦    ¦
                Data length = 2 -----------------------+    ¦   ¦   ¦        ¦          ¦    ¦
          COMMAND_CLASS_WAKE_UP ----------------------------+   ¦   ¦        ¦          ¦    ¦
    WAKE_UP_NO_MORE_INFORMATION --------------------------------+   ¦        ¦          ¦    ¦
Xmit options = ACK | AUTO_ROUTE ------------------------------------+        ¦          ¦    ¦
           Routing data ignored ---------------------------------------------+          ¦    ¦
                   Callback = 4 --------------------------------------------------------+    ¦
                    Checksum OK -------------------------------------------------------------+
--]==]
			"^01 .. 00 (..) " .. string.format("%02X", zwave_node) .. " .. 84 08 .+ (..) ..$",
--[==[
42      12/04/16 20:05:27.538   0x6 0x1 0x4 0x1 0x19 0x1 0xe2 (#######) 
              ACK - Acknowledge --+   ¦   ¦   ¦    ¦   ¦    ¦
           SOF - Start Of Frame ------+   ¦   ¦    ¦   ¦    ¦
                     length = 4 ----------+   ¦    ¦   ¦    ¦
                       Response --------------+    ¦   ¦    ¦
   FUNC_ID_ZW_SEND_DATA_GENERIC -------------------+   ¦    ¦
                     RetVal: OK -----------------------+    ¦
                    Checksum OK ----------------------------+
42      12/04/16 20:05:27.539   got expected ACK -- removed 

        ACK: 0x6 (#) 

42      12/04/16 20:05:27.778   0x1 0x5 0x0 0x19 0x4 0x0 0xe7 (#######) 
           SOF - Start Of Frame --+   ¦   ¦    ¦   ¦   ¦    ¦
                     length = 5 ------+   ¦    ¦   ¦   ¦    ¦
                        Request ----------+    ¦   ¦   ¦    ¦
   FUNC_ID_ZW_SEND_DATA_GENERIC ---------------+   ¦   ¦    ¦
                   Callback = 4 -------------------+   ¦    ¦
           TRANSMIT_COMPLETE_OK -----------------------+    ¦
                    Checksum OK ----------------------------+
41      12/04/16 20:05:27.779   ACK: 0x6 (#) -- removed 
--]==]
			"06 01 04 01 \\1 01 XX 01 05 00 \\1 \\2 00 XX",
			BatteryNoMoreInformationCallback, false, 0); 
		end
	end
	RunZWaveQueue("Init", 0)
	return true, "ok", SCObj.Name
end

-- SceneController_InitScreen gets called once for each device a variable delay after initialization.
function SceneController_InitScreen(peer_dev_num_string)
	DLog("SceneController_InitScreen: "..tostring(peer_dev_num_string));
	local peer_dev_num = tonumber(peer_dev_num_string)
	local currentScreen
	if SCObj.HasMultipleScreens then
		currentScreen = luup.variable_get(SCObj.ServiceId, CURRENT_SCREEN, peer_dev_num)
	else
		currentScreen = SCObj.DefaultScreen
	end
	if currentScreen then
		log("SceneController_InitScreen starting for peer device " .. peer_dev_num .. " currentScreen=" .. currentScreen);
		-- Use the ForceClear flag in SetScreen to reset the display regardless of its previous state.
		SetScreen(peer_dev_num, currentScreen, true, true, false);
		-- Set LastInitTime to mark the time of the last successful InitScreen at LuaUPnP reload.
		local curTime = os.time()
		luup.variable_set(SCObj.ServiceId, "LastInitTime", tostring(curTime), peer_dev_num)
		RunZWaveQueue("InitScreen", 0);
	end
end

--
-- 	Called at initialization to possibly create the peer (Lua) device for the Z-Wave device.
--  If a device is created, then the luup engine is reloaded and the two-way linke between
--  two devices is formed.
--
function CreatePeerDevices()
    DLog("CreatePeerDevices()")
	local count = 0;
	for zwave_dev_num,v in pairs(luup.devices) do
		local candidate = Devices[v.device_type]
		if candidate and v.device_num_parent == 1 then
			SCObj = candidate
			DLog("CreatePeerDevices: Found device: " .. tostring(SCObj.Name))
	       	local peerID = luup.variable_get(SCObj.ServiceId,"PeerID",zwave_dev_num);
			local peer_dev_num = tonumber(peerID)
			if peer_dev_num ~= nil and peer_dev_num > 0 and luup.devices[peer_dev_num] == nil then
			   	log("Peer Device" .. peer_dev_num .. " Deleted. Also deleting Z-Wave device" .. zwave_dev_num .. ", ZWave node ID " .. v.id)
			   	luup.variable_set(SCObj.ServiceId,"PeerID","",zwave_dev_num)
		   		luup.call_action(SID_HAG,"DeleteDevice", {DeviceNum = zwave_dev_num}, 0);
			elseif peerID == nil or peerID == "" or (peerID ~= "Pending" and luup.devices[tonumber(peerID)] == nil) then
			   	log("Creating peer device for Vera device ID " .. zwave_dev_num .. " ZWave node ID " .. v.id)
			   	count = count + 1
			   	luup.variable_set(SCObj.ServiceId,"PeerID","Pending",zwave_dev_num)
		   		luup.variable_set(SCObj.ServiceId,"ShowSingleDevice","1",zwave_dev_num)
				luup.attr_set("invisible","1",zwave_dev_num)
				luup.attr_set("Invisible","1",zwave_dev_num)
			    luup.call_action(SID_HAG,"CreateDevice", {
				   	deviceType = SCObj.DevType;
				   	internalID = zwave_dev_num;
					Description = SCObj.Name .. " Scene Controller";
				   	UpnpDevFilename = SCObj.DeviceXml;
				   	UpnpImplFilename =  "I_GenGenSceneController.xml";
					RoomNum = v.room_num;
					StateVariables = SCObj.ServiceId .. ",PeerID=" .. zwave_dev_num .. "\n" ..
					                 SCObj.ServiceId .. ",ShowSingleDevice=1" },0)
			end
		end
	end
	if count > 0 then
		log("Peer devices created: " .. count .. " reloading.")
		luup.call_action(SID_HAG, "Reload", {}, 0)
	end
	VLog("Finish CreatePeerDevices()")
end


function CheckInvisible(devNumString)
    VLog("CheckInvisible("..tostring(devNumString)..")")
	local zwave_dev_num = tonumber(devNumString)
	local retry = false
	if zwave_dev_num < 0 then
		zwave_dev_num = -zwave_dev_num
		retry = true
	end
	local ShowSingleDevice = luup.variable_get(SCObj.ServiceId,"ShowSingleDevice",zwave_dev_num)
	if type(ShowSingleDevice) ~= "string" or (ShowSingleDevice ~= "1" and ShowSingleDevice ~= "0") then
		ShowSingleDevice = "1"
		DLog("CheckInvisible: Setting ShowSingleDevice for the first time.")
		luup.variable_set(SCObj.ServiceId,"ShowSingleDevice",ShowSingleDevice,zwave_dev_num)
	end
	local invisible = luup.attr_get("invisible",zwave_dev_num)
	local Invisible = luup.attr_get("Invisible",zwave_dev_num)
    DLog("CheckInvisible: zwave_dev_num="..zwave_dev_num.." ShowSingleDevice="..ShowSingleDevice.." invisible="..invisible.." Invisible="..Invisible.." retry="..tostring(retry))
	if ShowSingleDevice == "0" then
  		if luup.version_major < 7 then
			ShowSingleDevice = "" -- invisible should be 1 or empty in UI5
		end
		retry = false -- no need to retry below if we are allowing the z-wayve device to be seen.
	end
	if invisible ~= ShowSingleDevice then
		-- UI5 bug has capitalization issues with "I/invisible" so set it both ways.
		DLog("CheckInvisible: zwave_dev_num="..zwave_dev_num..": Setting invisible and Invisible to "..ShowSingleDevice)
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
	local v2 = luup.devices[peer_dev_num]
	local candidate = Devices[v2.device_type]
	if candidate then
		SCObj = candidate
		DLog("ConnectPeerDevice: peer_dev_num="..tostring(peer_dev_num).." Found device: " .. tostring(SCObj.Name))
	else
		ELog("ConnectPeerDevice: Device" .. tostring(peer_dev_num).." type "..tostring(v2.device_type).. " not supported.")
		return
	end
	DLog("ConnectPeerDevce: peer_dev_num=" .. tostring(peer_dev_num))
	local newDevice = false;
	if v2.device_type == SCObj.DevType and v2.device_num_parent == 0 then
		local zwave_dev_num = tonumber(v2.id);
		local v = luup.devices[zwave_dev_num]
		if v == nil then
			log("Device " .. zwave_dev_num .. " for peer device " .. peer_dev_num .. " no longer exists. Deleting")
			ForAllModes(peer_dev_num, function(mode, screen, virtualButton)
				if mode.sceneId then
					for i = 1, #mode do
						RemoveDeviceActuatorConf(mode[i].device, mode.sceneId, mode.offSceneId)
					end
				end
			end )
			SceneIdCacheList[zwave_dev_num] = nil
		   	luup.call_action(SID_HAG,"DeleteDevice", {DeviceNum = peer_dev_num}, 0);
		else
			CheckInvisible(-zwave_dev_num)
			SCObj.SetTuningParameters(zwave_dev_num)
			peerID = luup.variable_get(SCObj.ServiceId,"PeerID",zwave_dev_num)
		    if peerID == "Pending" then
				log("Connecting Device " .. zwave_dev_num .. "(ZWave node " .. v.id .. ") to peer device " .. peer_dev_num)
		   		luup.variable_set(SCObj.ServiceId,"PeerID",peer_dev_num,zwave_dev_num)
				if IsVeraPrimaryController() then
					SCObj.SetDefaultLabels(peer_dev_num);
				end
				newDevice = true;
			elseif tonumber(peerID) ~= peer_dev_num then
				ELog("ZWave device " .. zwave_dev_num .. " PeerID is " .. tostring(peerID) .. ", should have been " .. peer_dev_num .. ". Deleting peer device " .. peer_dev_num)
		   		luup.call_action(SID_HAG,"DeleteDevice", {DeviceNum = peer_dev_num}, 0);
				return;
			end
		    -- Devices are connected. Perform normal initialization on reload.
			VariableWatch("SceneController_LastSceneIDChange",SID_SCTRL,"LastSceneID",zwave_dev_num,"")
			VariableWatch("SceneController_LastSceneTimeChange",SID_SCTRL,"LastSceneTime",zwave_dev_num,"")
			if IsVeraPrimaryController() then
--HACK_HACVK				luup.variable_watch("SceneController_ConfiguredChanged",SID_HADEVICE,"Configured",zwave_dev_num)
				if param.SCENE_CTRL_Retries > 0 then
					EnableZWaveReceiveLogging()
				end
			end
			-- Rename the Z-Wave device to match the peer device
			local zwave_name = luup.attr_get("name",zwave_dev_num);
			local peer_name = luup.attr_get("name",peer_dev_num);
			local desired_name = peer_name .. " Z-Wave";
			if zwave_name ~= desired_name then
				luup.attr_set("name", desired_name, zwave_dev_num);
			end
			local currentScreen = luup.variable_get(SCObj.ServiceId, CURRENT_SCREEN, peer_dev_num)
			if not currentScreen then
				currentScreen = SCObj.DefaultScreen
			end
			if IsVeraPrimaryController() then
				if newDevice then
					-- doTimeout, force, not indicatorOnly
					SetScreen(peer_dev_num,currentScreen,true,true,false);
				else
				    -- Stagger the re-initialization of each controller so that they all don't try to initialize at the same time and thus causing a LuaUPnP crash.
					local nthDelay = GetDeviceCounter(zwave_dev_num) * param.SCENE_CTRL_InitStaggerSeconds
					local lastInitTime = luup.variable_get(SCObj.ServiceId,"LastInitTime",peer_dev_num)
					local curTime = os.time()
					if not lastInitTime or os.difftime(curTime, tonumber(lastInitTime)) > param.SCENE_CTRL_MinReinitSeconds then
						DLog("  ConnectPeerDevice: Waiting " ..  nthDelay .. " seconds to init screen for peer device " .. peer_dev_num)
						--HACK_HACK luup.call_delay("SceneController_InitScreen", nthDelay, tostring(peer_dev_num), true);
					else
						DLog("  ConnectPeerDevice: Difftime="..os.difftime(curTime, tonumber(lastInitTime)).." seconds. Setting indicator immediately.")
						-- doTimeout, force, indicatorOnly
						SetScreen(peer_dev_num,currentScreen,true,true,true);
					end
				end
			end
		end
	else
		ELog("Incorrect peer device " .. peer_dev_num)
	end
	VLog("Finish ConnectPeerDevce()")
end

-- Given either the Z-Wave or the peer device number, GetZWaveNode returns the Z-Wave node ID and the Z-Wave device number.
function GetZWaveNode(peer_dev_num)
  	local veraZWaveNode, ZWaveNetworkDeviceId = GetVeraIDs()
	if peer_dev_num == ZWaveNetworkDeviceId then
		return veraZWaveNode, ZWaveNetworkDeviceId
	end
	peer_dev_num = tonumber(peer_dev_num)
	local v2 = luup.devices[peer_dev_num]
	if v2 == nil then
	    ELog("GetZWaveNode: cannot find device for peer_dev_num="..tostring(peer_dev_num))
		return nil, nil
	end
	local zwave_dev_num = tonumber(v2.id);
	if tonumber(v2.device_num_parent) == ZWaveNetworkDeviceId then
	    -- Caller passed the ZWave device number.
		return zwave_dev_num, peer_dev_num
	end
	-- caller passed the peer device number
	local v = luup.devices[zwave_dev_num]
	if v == nil then
	    ELog("GetZWaveNode: cannot find device for zwave_dev_num="..tostring(peer_dev_num))
		return nil, nil
	end
	local node_id = tonumber(v.id)
	return node_id, zwave_dev_num
end

-- Given either the Z-Wave or the peer device number, GetPeerDevNum returns the peer device number.
function GetPeerDevNum(dev_num)
	local v2 = luup.devices[dev_num]
	if v2 == nil then
	    ELog("GetPeerDevNum: cannot find device for dev_num="..tostring(dev_num))
		return nil
	end
	if tonumber(v2.device_num_parent) == 1 then
	    -- Caller passed the ZWave device number.
		local peer_dev_num_str = luup.variable_get(SCObj.ServiceId,"PeerID",dev_num)
		local peer_dev_num = tonumber(peer_dev_num_str)
		return peer_dev_num
	end
	-- caller passed the peer device number
	return dev_num
end

function SetConfigurationOption(name, dev_num, node_id, option, value, delay)
	if not delay then
		delay = 0
	end
	local data = "112 4 " .. tostring(option) .. " 1 " .. tostring(value)
    EnqueueZWaveMessage("SetConfigurationOption("..name..":"..tostring(option).."="..tostring(value)..")"..node_id, node_id, data, delay)
end

if luup.device ~= nil then
	timeoutSequenceNumber = luup.device * 1000
	timeoutDevice = luup.device
	timeoutScreen = ""
end
function SceneController_ScreenTimeout(data)
	if IsVeraPrimaryController() then
		local ix1, ix2, peer, seq = data:find("(%d+),(%d+)")
		if timeoutSequenceNumber == tonumber(seq) then
			DLog("ScreenTimeout: peer_dev_num="..peer.." timeoutSequenceNumber="..timeoutSequenceNumber.." timeoutDevice="..timeoutDevice.." timeoutScreen="..timeoutScreen);
			SetScreen(timeoutDevice, timeoutScreen, true, false, false);
			RunZWaveQueue("ScreenTimeout", 0)
		else
			DLog("ScreenTimeout: Ignore stale ScreenTimeout("..data..") Current timeoutSequenceNumber="..timeoutSequenceNumber);
		end
	end
end

function SceneController_SetScreenTimeout(peer_dev_num, screen, timeoutEnable, timeoutScreen, timeoutSeconds)
	if IsVeraPrimaryController() then
		DLog("SceneController_SetScreenTimeout: peer_dev_num="..tostring(peer_dev_num).." screen="..tostring(screen).. " timeoutEnable="..tostring(timeoutEnable).." timeoutScreen=="..tostring(timeoutScreen).." timeoutSeconds="..tostring(timeoutSeconds));
		local enable = timeoutEnable == 1 or timeoutEnable == "1" or timeoutEnable == "true" or timeoutEnable == "yes" or timeoutEnable == true	-- FOr UPnP boolean spec compatibility
		luup.variable_set(SCObj.ServiceId, "TimeoutEnable_" .. screen, tostring(enable), peer_dev_num)
		luup.variable_set(SCObj.ServiceId, "TimeoutScreen_" .. screen, timeoutScreen, peer_dev_num)
		luup.variable_set(SCObj.ServiceId, "TimeoutSeconds_" .. screen, tostring(timeoutSeconds), peer_dev_num)
		local currentScreen = luup.variable_get(SCObj.ServiceId, CURRENT_SCREEN, peer_dev_num)
		if currentScreen == screen then
			SetScreenTimeout(peer_dev_num, screen)
			RunZWaveQueue("SetScreenTimeout", 0);
		end
	end
end

function SceneController_SetNumLines(peer_dev_num, screen, lines)
	if IsVeraPrimaryController() then
		DLog("SceneController_SetNumLines: peer_dev_num="..tostring(peer_dev_num).." screen="..tostring(screen).. " lines="..tostring(lines));
		local enable = timeoutEnable == 1 or timeoutEnable == "1" or timeoutEnable == "true" or timeoutEnable == "yes" or timeoutEnable == true	-- FOr UPnP boolean spec compatibility
		local oldLines = luup.variable_get(SCObj.ServiceId, "NumLines_" .. screen, peer_dev_num)
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
		luup.variable_set(SCObj.ServiceId, "NumLines_" .. screen, tostring(lines), peer_dev_num)
		local currentScreen = luup.variable_get(SCObj.ServiceId, CURRENT_SCREEN, peer_dev_num)
		if currentScreen == screen and oldLines ~= lines then
			-- doTimeout, force, not indicatorOnly
			SetScreen(peer_dev_num, currentScreen, true, true, false);
			RunZWaveQueue("SetNumLines", 0);
		end
	end
end

function SetScreenTimeout(peer_dev_num, screen)
	DLog("SetScreenTimeout: peer_dev_num="..peer_dev_num.." screen="..screen);
	timeoutSequenceNumber = timeoutSequenceNumber + 1;
	if luup.variable_get(SCObj.ServiceId, "TimeoutEnable_" .. screen, peer_dev_num) == "true" then
		timeoutDevice = peer_dev_num
		timeoutScreen = luup.variable_get(SCObj.ServiceId, "TimeoutScreen_" .. screen, peer_dev_num);
		local seconds = luup.variable_get(SCObj.ServiceId, "TimeoutSeconds_" .. screen, peer_dev_num);
		if seconds == nil then
			seconds = 0
		end
		seconds = tonumber(seconds)
		if seconds > 0 then
			DLog("SetScreenTimeout: Setting timeout timer for "..seconds.." seconds. peer_dev_num="..peer_dev_num.." current screen="..screen.." timeoutScreen="..timeoutScreen.." timeoutSequenceNumber="..timeoutSequenceNumber);
			luup.call_delay("SceneController_ScreenTimeout", tonumber(seconds), tostring(peer_dev_num)..","..tostring(timeoutSequenceNumber), true);
		else
			DLog("Not setting timeout timer. peer_dev_num="..peer_dev_num.." current screen="..screen.." timeoutSequenceNumber="..timeoutSequenceNumber.." because seconds="..seconds);
		end
	else
		DLog("Not setting timeout timer. peer_dev_num="..peer_dev_num.." current screen="..screen.." timeoutSequenceNumber="..timeoutSequenceNumber);
	end
end

-- Mode strings consist or Prefix {newScreen:}? S?{sceneId @ {offSceneId @}?}|C? {entry}*
-- Prefix is M for momentary, T for Toggle, etc.
-- S prefix is legacy "direct toggle" and should not be confused with S as the second character.
-- newScreen is a letter/digit such as C3 for Custom 3 or P4 for Preset 4
-- The S flag indicates that all associated devices are scene capable
--   and is optionally followed by sceneId@ and offSceneId@
-- The C flag indicats Cooper RFCW-style Scen/Config pair setting
-- Scene-capable modes are a ; separated list of 0 or more deviceNum,level,dimmingDuration triplets
-- Cooper configuration modes are a ; separated list of 0 or more deviceNum,level pairs
-- Non-scene capabile modes are a ; separated list of 0 or more deviceNums
function ParseModeString(str)
	local mode = {};
	if not str or (str == "") then
	    mode.prefix = "M"
	else
	    mode.prefix = str:sub(1,1)
		if mode.prefix == "S" then
			-- Legacy direct toggle. Change into T
			mode.prefix = "T"
		end
		str = str:sub(2)
		local newScreen = str:match("^%a%d:")
		if newScreen then
			mode.newScreen = newScreen
			str = str:sub(4)
		elseif mode.prefix == "N" then
		    -- Legacy newScreen without :
			mode.prefix = "M"
			mode.newScreen = str
			return mode
		end
		local i = 1;
		if (str:sub(1,1) == "S") then
			mode.sceneControllable = true
			str = str:sub(2)
			local sceneIdStr, rest = string.match(str, "^(%d+)@(.*)$")
			if sceneIdStr then
				mode.sceneId = tonumber(sceneIdStr)
				str = rest;
				local offSceneIdStr, offRest = string.match(str, "^(%d+)@(.*)$")
				if offSceneIdStr then
					mode.offSceneId = tonumber(offSceneIdStr)
					str = offRest;
				end
			end
		    for device, level, dimmingDuration in string.gmatch(str, "(%d+),(%d+),(%d+)") do
		    	mode[i] = {device=tonumber(device), level=tonumber(level), dimmingDuration=tonumber(dimmingDuration)};
				i = i + 1;
		    end
		elseif (str:sub(1,1) == "C") then
			if SCObj.HasCooperConfiguration then
				mode.cooperConfiguration = true
			end
			str = str:sub(2)
		    for device, level in string.gmatch(str, "(%d+),(%d+)") do
		    	mode[i] = {device=tonumber(device), level=tonumber(level)};
				i = i + 1;
		    end
		else
		    for device in string.gmatch(str, "%d+") do
		    	mode[i] = {device=tonumber(device)};
			   	i = i + 1;
		    end
		end
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
			if mode.sceneId then
				str = str .. mode.sceneId .. "@"
				if mode.offSceneId then
					str = str .. mode.offSceneId .. "@"
				end
			end
		elseif mode.cooperConfiguration then
			str = str .. "C"
		end
		local first = true
		for i = 0, #mode do
			if mode[i] and mode[i].device then
				if not first then
					str = str .. ";"
				end
				first = false
				if mode.sceneControllable then
					local level = mode[i].level
					if not level then
						level = 255
					end
					local dim = mode[i].dimmingDuration
					if not dim then
						dim = 255
					end
					str = str .. mode[i].device .. "," .. level .. "," .. dim
				elseif mode.cooperConfiguration then
					local level = mode[i].level
					if not level then
						level = 255
					end
					str = str .. mode[i].device .. "," .. level
				else
					str = str .. mode[i].device
				end
			end
		end
	end
	return str;
end

function SetIndicatorValue(peer_dev_num, indicator, force, delay)
	if SCObj.HasIndicator then
	    DLog("SetIndicatorValue peer_dev_num="..tostring(peer_dev_num).." indicator="..tostring(indicator).." force="..tostring(force).." delay="..tostring(delay))
		local node_id, zwave_dev_num = GetZWaveNode(peer_dev_num)
		if not node_id then
			ELog("SetIndicatorValue: bad peer_dev_num=" .. peer_dev_num)
			return
		end
		local previous_indicator_string = luup.variable_get(SCObj.ServiceId, CURRENT_INDICATOR, peer_dev_num)
		if force or tonumber(previous_indicator_string) ~= indicator then
			EnqueueZWaveMessage("SetIndicator("..indicator..")"..node_id, node_id,  "0x87 0x01 "..indicator, delay);
			luup.variable_set(SCObj.ServiceId, CURRENT_INDICATOR, tostring(indicator), peer_dev_num)
		end
	end
end

function ChooseBestState(peer_dev_num, screen, virtualButton, mode)
	if not SCObj.HasScreen then
		return 1
	end
    DLog("ChooseBestState: peer_dev_num="..tostring(peer_dev_num).." screen="..tostring(screen).." virtualButton="..tostring(virtualButton))
	local states = tonumber(mode.prefix)
	local bestState = 1
	local bestScore
	for state = 1, states do
		local curButton = virtualButton+(state-1)*1000
		if state > 1 then
			modeStr = luup.variable_get(SCObj.ServiceId,"Mode_"..screen.."_"..curButton,peer_dev_num)
			if modeStr == nil then
				modeStr = "M"
			end
			mode = ParseModeString(modeStr)
		end
		local score = 0
		for i = 1, #mode do
			local device = mode[i].device
			local status, lastUpdate, service, variable = GetDeviceStatus(device)
			DLog("ChooseBestState:    monitored device="..tostring(device).." status="..tostring(status).." lastUpdate="..tostring(lastUpdate).." service="..tostring(service).." variable="..tostring(variable))
			if status ~= nil then
				local target = 100;
				if mode[i].level ~= nil then
					target = mode[i].level
				end
				score = score + ((target - status) ^ 2)
				local context = tostring(peer_dev_num) .. "," .. screen
				VariableWatch("SceneController_WatchedIndicatorDeviceChanged", service, variable, device, context)
			end
		end
		DLog("ChooseBestState:    state="..tostring(state).." curButton="..tostring(curButton).." mode="..DTableToString(mode).." score="..tostring(score))
		if #mode > 0 and (bestScore == nil or score < bestScore) then
			bestState = state
		    bestScore = score
		end
	end
	DLog("ChooseBestState: bestState="..tostring(bestState).." bestScore="..tostring(bestScore))
	luup.variable_set(SCObj.ServiceId,"State_"..screen.."_"..virtualButton,tostring(bestState),peer_dev_num)
	return bestState
end

function SetIndicator(peer_dev_num, screen, force, delay)
	if SCObj.HasIndicator then
	    DLog("SetIndicator peer_dev_num="..tostring(peer_dev_num).." screen="..tostring(screen).." force="..tostring(force).." delay="..tostring(delay))
	    local indicator = 0
		local threshold = 5
		local numLines, scrollOffset = GetNumLinesAndScrollOffset(peer_dev_num, screen)
		local node_id, zwave_dev_num = GetZWaveNode(peer_dev_num)
		for button = 1, 5 do
			local virtualButton = button+scrollOffset
		    local highlighted = false;
			if numLines == 5 or ((button ~= 1 or scrollOffset == 0) and (button ~= SCObj.NumButtons or scrollOffset == numLines-SCObj.NumButtons)) then
				local modeStr = luup.variable_get(SCObj.ServiceId,"Mode_"..screen.."_"..virtualButton,peer_dev_num)
				local mode  = ParseModeString(modeStr)
				if mode.prefix >= "2" and mode.prefix <= "9" then
					local oldState = luup.variable_get(SCObj.ServiceId,"State_"..screen.."_"..virtualButton,peer_dev_num)
					if not oldState then
						oldState = "1"
					end
					oldState = tonumber(oldState)
					local oldLabels, oldFonts, oldAligns = {}, {}, {}
					ChooseLabelFontAndAlign(peer_dev_num, screen, 1, virtualButton, oldState, oldLabels, oldFonts, oldAligns)
					local newLabels, newFonts, newAligns = {}, {}, {}
					ChooseLabelFontAndAlign(peer_dev_num, screen, 1, virtualButton, nil, newLabels, newFonts, newAligns)
					if oldLabels[1] ~= newLabels[1] or oldFonts[1] ~= newFonts[1] or oldAligns[1] ~= newAligns[1] then
						EVLCDWrapStrings(newLabels, newFonts, newAligns, node_id, zwave_dev_num, button, button, SCREEN_MD.NoChange)
					end
				elseif mode.prefix == "T" then
					local num_off = 0
					local num_on = 0
					for i = 1, #mode do
						local device = mode[i].device
						local status, lastUpdate, service, variable = GetDeviceStatus(device)
						DLog("    monitored device="..tostring(device).." threshold="..tostring(threshold).." status="..tostring(status).." lastUpdate="..tostring(lastUpdate).." service="..tostring(service).." variable="..tostring(variable))
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
					if num_on > num_off and num_on > 0 then
						highlighted = true
					end
				    DLog("  button="..button.." mode="..tostring(modeStr).." num_on="..num_on.." num_off="..num_off.." highlighted="..tostring(highlighted))
				elseif mode.prefix == "X" then
			   		local scene = luup.variable_get(SID_SCTRL, "sl_SceneActivated", peer_dev_num)
					if scene then
						scene = tonumber(scene)
						local sceneButton = ((scene-1) % SCObj.NumButtons) + 1
						if scene >= 300 then
							sceneButton = math.floor((scene-200)/100) * SCObj.NumButtons
						end
						highlighted = sceneButton == virtualButton
					else
						highlighted = false
					end
				end
			end
			if highlighted then
				indicator = bit.bor(indicator,SCObj.PhysicalButtonToIndicator(button))
			end
		end
		DLog("New indicator value="..indicator)
		SetIndicatorValue(peer_dev_num, indicator, force, delay)
	end
end

-- This is a variable watch trigger which gets called whenever a device status changes which
-- may affect the highlighting on the screen. It is called in a call_delay since it may call SendData
function SceneController_WatchedIndicatorDeviceChanged(device, service, variable, value_old, value_new, context)
	VLog("SceneController_WatchedIndicatorDeviceChanged: device=" .. tostring(device) .. "service=" .. tostring(service) .. "variable=" .. tostring(variable) ..
		 "value_old=" .. tostring(value_old) .. " value_new=" .. tostring(value_new) .. " context=" .. tostring(context))
	if IsVeraPrimaryController() then
		local ix1, ix2, peer_string, screen = context:find("(%d+),(%w+)")
		local peer_dev_num = tonumber(peer_string)
		DLog("WatchedIndicatorDeviceChanged: context="..context.." peer_dev_num="..peer_dev_num.." screen="..screen);
		if luup.variable_get(SCObj.ServiceId, CURRENT_SCREEN, peer_dev_num) == screen then
			SetIndicator(peer_dev_num, screen, false, 100)
		end
		-- 3 second delay here to allow a large scene to run before changing the indicators
		-- in order to avoid a "cannot obtain lock" crash in UI5.
		RunZWaveQueue("WatchedIndicatorDeviceChanged", 3000)
	end
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
					DLog("IsVeraPrimaryController: Found Z-Wave network="..k.. " Role=" .. tostring(role).." masterslave="..tostring(masterslave).." sis="..tostring(sis).." pri="..tostring(pri).." IsPrimaryController="..tostring(IsPrimaryController))
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

local veraZWaveNode
local ZWaveNetworkDeviceId
function GetVeraIDs()
	if veraZWaveNode == nil then
		local zwave_device = 1
		local node_id = "1"
		for k,v in pairs(luup.devices) do
			if v.device_type == DEVTYPE_ZWN then
				local homeID = luup.variable_get(SID_ZWN, "HomeID", k)
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

function GetNumLinesAndScrollOffset(peer_dev_num, screen)
	local numLines = luup.variable_get(SCObj.ServiceId, "NumLines_"  .. screen, peer_dev_num)
	local scrollOffset = 0
	if numLines then
		numLines = tonumber(numLines)
		scrollOffset = luup.variable_get(SCObj.ServiceId, "ScrollOffset_"  .. screen, peer_dev_num)
		if scrollOffset then
			scrollOffset = tonumber(scrollOffset)
		else
			scrollOffset = 0
		end
	else
		numLines = SCObj.NumButtons
	end
	return numLines, scrollOffset
end

-- Halper function for SelectSceneID to mark an existing scene ID as already being used
-- either by another screen or button in this controller or by another controller
-- operating on the same target device. We only create a set of unused sceneID up until
-- the maximum seen so far. If the given scenId is greter than the current max, then
-- we mark the next N scenes up to the new sceneId-1 as unused. Otherwise, we mark
-- the given scene used.
-- Note. The first 10 scene IDs are "default" scene IDs matching the button if the
-- selection algorithm fails.
function MarkSceneIdUsed(sceneId, sceneSet)
	if sceneId and sceneId > 10 then
		if sceneId > sceneSet.max then
			for i = sceneSet.max+1, sceneId-1 do
				sceneSet[i] = true
			end
			sceneSet.max = sceneId
		else
			sceneSet[sceneId] = nil
		end
	end
end

-- Helper function for SelectSceneId to choose an available scene ID from the remaining sceneSet
-- Take the current scene ID as a hint and reuse it if it is still available. Otherwise, if the
-- scene ID's have not reached the max of 255, then use the next higher number, otherwise choose
-- one scene ID from the set
function pickSceneId(current, sceneSet, defaultScene)
	if current and current > 10 then
		if current > sceneSet.max then
			sceneSet.max = current
			return current
		end
		if sceneSet[current] then
			sceneSet[current] = nil;
			return current
		end
	end
	if sceneSet.max < 255 then
		sceneSet.max = sceneSet.max + 1
		return sceneSet.max
	end
	for k, v in pairs(sceneSet) do
		if k ~= "max" then
			sceneSet[k] = nil
			return k
		end
	end
	return defaultScene
end

-- Iterate through all existing modes in all screens of a given device.
-- Pass the mode(object), the screen(string) and the virtual button(number) to the function.
function ForAllModes(peer_dev_num, func)
	local ScreenList = {C=6,T=6,P=41}
	for prefix, numScreens in pairs(ScreenList) do
		for screenNum = 1, numScreens do
			local screen = prefix .. screenNum
			local numLines = SCObj.NumButtons
			local lineStep = 1
			if prefix == "C" then
				local numLinesStr = luup.variable_get(SCObj.ServiceId, "NumLines_" .. screen, peer_dev_num)
				if numLinesStr then
					numLines = tonumber(numLinesStr)
				end
			elseif prefix == "T" then
				lineStep = 4 -- Just do lines 1 and 5 for temperature screens
			end
			for line = 1, numLines, lineStep do
				local modeStr = luup.variable_get(SCObj.ServiceId,"Mode_"..screen.."_"..line, peer_dev_num)
				if modeStr then
					local mode = ParseModeString(modeStr)
					func(mode, screen, line)
					if mode.prefix >= "2" and mode.prefix <= "9" then
						local numStates = tonumber(mode.prefix)
						for state=2, numStates do
							local virtualButton = line + (state-1)*1000
							local modeStr2 = luup.variable_get(SCObj.ServiceId,"Mode_"..screen.."_"..virtualButton, peer_dev_num)
							if modeStr2 then
								func(ParseModeString(modeStr2), screen, virtualButton)
							end
						end
					end
				else
					break -- Skip the rest of the screen if the mode for line 1 does not exist.
				end
			end
		end
	end
end

-- Remove the old scene ID from the actuator configuration list and add the new scene ID.
-- This also actually sets the actuator configuration.
function UpdateActConfList(actConfList, oldSceneId, newSceneId, controller_dev_num, target, virtualButton, level, scren, act)
	if oldSceneId ~= newSceneId then
		local sceneIdCache = SceneIdCacheList[controller_dev_num]
		if not sceneIdCache then
			sceneIdCache = {}
			SceneIdCacheList[controller_dev_num] = sceneIdCache
		end
		if oldSceneId and actConfList[oldSceneId] and actConfList[oldSceneId].controller == controller_dev_num then
			actConfList[oldSceneId] = nil
			sceneIdCache[oldSceneId] = nil
	   	end
		if newSceneId then
			local target_node_id = GetZWaveNode(target.device)
			actConfList[newSceneId]={controller=controller_dev_num, button=virtualButton, level=level, dimmingDuration=target.dimmingDuration}
			sceneIdCache[newSceneId]={screen=screen, button=virtualButton, act=act}
			EnqueueZWaveMessage("SelectSceneId_SceneActuatorConf("..newSceneId..","..level..","..target.dimmingDuration..")"..target_node_id, target_node_id,  "44 1 ".. newSceneId .. " ".. target.dimmingDuration .. " 128 ".. level, 0);
		end
	end
end

-- Select a sceneId and possibly an off sceneId for a given button and screen which is
-- controlling only scene-capable devices. The same scene ID is multicast to all devices
-- associated with that group (button) so the scene ID must be unique for all screens
-- and buttons of this controller and all scenes used by any controllers operating on this
-- device.
function SelectSceneId(peer_dev_num, screen, virtualButton)
	local modeStr = luup.variable_get(SCObj.ServiceId, "Mode_"..screen.."_"..virtualButton, peer_dev_num)
	DLog("SelectSceneId: peer_dev_num="..tostring(peer_dev_num).." screen="..tostring(screen).." virtualButton="..tostring(virtualButton).." modeStr="..tostring(modeStr))
	if not modeStr then
		return nil
	end
	local mode = ParseModeString(modeStr)
	if not mode.sceneControllable then
		return nil
	end
	local sceneSet = {max=10}
	local controller_node_id, controller_dev_num = GetZWaveNode(peer_dev_num)
	-- First mark off all scene IDs used for any screens of this controller
	ForAllModes(peer_dev_num, function(mode2, screen2, virtualButton2)
		if screen ~= screen2 or virtualButton ~= virtualButton2 then
			MarkSceneIdUsed(mode2.sceneId, sceneSet)
			MarkSceneIdUsed(mode2.offSceneId, sceneSet)
		end
	end )
	-- Now mark off all scene IDs used by other controllers associated with this target
	for target = 1, #mode do
		local actConfList = ReadDeviceActuatorConfList(mode[target].device)
		for sceneId, data in pairs(actConfList) do
			if sceneId ~= mode.sceneId and sceneId ~= mode.offSceneId then
				MarkSceneIdUsed(sceneId, sceneSet)
			end
		end
	end
	-- The set of available scene IDs is now completed. Pick a new scene ID and perhaps a new off scene ID in case of a toggle.
	defaultSceneId = (virtualButton - 1) % SCObj.NumButtons + 1;
	DLog("  oldSceneId="..tostring(mode.sceneId).." oldOffSceneId="..tostring(mode.offSceneId).." sceneSet="..DTableToString(sceneSet).." defaultSceneId="..tostring(defaultSceneId))
	local newSceneId =  pickSceneId(mode.sceneId, sceneSet, defaultSceneId)
	local newOffSceneId
	if mode.prefix == "T" and SCObj.HasOffScenes then
		newOffSceneId = pickSceneId(mode.offSceneId, sceneSet, defaultSceneId+SCObj.NumButtons)
	end
	DLog("  newSceneId="..tostring(newSceneId).." newOffSceneId="..tostring(newOffSceneId).." sceneSet="..DTableToString(sceneSet))
	-- If either of the two scene IDs changed, then update all of the target devices
	if mode.sceneId ~= newSceneId or mode.offSceneId ~= newOffSceneId then
		for i = 1, #mode do
			local actConfList = ReadDeviceActuatorConfList(mode[i].device)
			UpdateActConfList(actConfList, mode.sceneId, newSceneId, controller_dev_num, mode[i], virtualButton, mode[i].level, screen, true)
			UpdateActConfList(actConfList, mode.offSceneId, newOffSceneId, controller_dev_num, mode[i], virtualButton+1000, 0, screen, false)
			WriteDeviceActuatorConfList(mode[i].device, actConfList)
		end
		mode.sceneId = newSceneId
		mode.offSceneId = newOffSceneId
		luup.variable_set(SCObj.ServiceId, "Mode_"..screen.."_"..virtualButton, GenerateModeString(mode), peer_dev_num)
	end
	return mode
end

function ReadDeviceActuatorConfList(dev_num)
	local actConfStr = luup.variable_get(SCObj.ServiceId, ACTUATOR_CONF, dev_num)
	if not actConfStr then
		return {}, false
	end
	local actConfList = {}
	for sc, ct, bt, lv, dd in string.gmatch(actConfStr, "(%d+):(%d+),(%d+),(%d+),(%d+);") do
		actConfList[tonumber(sc)]={controller=tonumber(ct), button=tonumber(bt), level=tonumber(lv), dimmingDuration=tonumber(dd)}
	end
	return actConfList, true
end

function WriteDeviceActuatorConfList(dev_num, actConfList)
	local str = ""
	for k, v in pairs(actConfList) do
		str = str .. k .. ":" .. v.controller .. "," .. v.button .. "," .. v.level .. "," .. v.dimmingDuration .. ";"
	end
	luup.variable_set(SCObj.ServiceId, ACTUATOR_CONF, str, dev_num)
end

-- The DeviceAcuatorConf functions cannot be cached because they may act globally across different Lua instances
function GetDeviceActuatorConf(dev_num, sceneId)
	local actConfList=ReadDeviceActuatorConfList(dev_num)
	return actConfList[sceneId]
end

function SetDeviceActuatorConf(controller_dev_num, target_dev_num, target_node_id, sceneId, button, level, dimmingDuration)
	DLog("SetDeviceActuatorConf: controller_dev_num="..tostring(controller_dev_num).." target_dev_num="..tostring(target_dev_num)..
	        " target_node_id="..tostring(target_node_id).." sceneId="..tostring(sceneId).." button="..button.." level="..tostring(level).." dimmingDuration="..tostring(dimmingDuration))
	local actConfList=ReadDeviceActuatorConfList(target_dev_num)
	actConfList[sceneId]={controller=controller_dev_num, button=button, level=level, dimmingDuration=dimmingDuration}
	EnqueueZWaveMessage("SceneActuatorConf("..sceneId..","..level..","..dimmingDuration..")"..target_node_id, target_node_id,  "44 1 ".. sceneId .. " ".. dimmingDuration .. " 128 ".. level, 0);
	WriteDeviceActuatorConfList(target_dev_num, actConfList)
end

function RemoveDeviceActuatorConf(dev_num, sceneId, offSceneId)
	local actConfList, exists = ReadDeviceActuatorConfList(dev_num)
	if not exists then
		return
	end
	actConfList[sceneId]=nil
	if offSceneId then
		actConfList[offSceneId]=nil
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
	local actConfStr = luup.variable_get(SCObj.ServiceId, ACTUATOR_CONF, dev_num)
	if actConfStr then
		luup.variable_set(SCObj.ServiceId, ACTUATOR_CONF, "", dev_num)
	end
end

function UpdateAssociationForPhysicalButton(zwave_dev_num, screen, force, prevModeStr, modeStr, physicalButton, virtualButton)
	DLog("  UpdateAssociationForPhysicalButton: zwave_dev_num="..tostring(zwave_dev_num).." screen="..tostring(screen).." force="..tostring(force).." prevModeStr="..tostring(prevModeStr).." modeStr="..tostring(modeStr)..
	        " physicalButton="..tostring(physicalButton).." virtualButton="..tostring(virtualButton))
	if force or prevModeStr ~= modeStr then
		local node_id = GetZWaveNode(zwave_dev_num)
		local mode = ParseModeString(modeStr)
		if SCObj.HasCooperConfiguration then
			-- Cooper RFWC5 cannot set associations incrementally. Start from scratch each time
			-- but we can still cache the return routes
			force = true
		end
		if force then
			prevModeStr = mode.prefix
		end
		local prevMode = ParseModeString(prevModeStr)
  		local veraZWaveNode, ZWaveNetworkDeviceId = GetVeraIDs()
		if force then
			UnassociateDevice(zwave_dev_num, nil, physicalButton, physicalButton, 1) -- Unassociate activate with everything
			if SCObj.HasOffScenes then
				UnassociateDevice(zwave_dev_num, nil, physicalButton+SCObj.NumButtons, physicalButton+SCObj.NumButtons, 1) -- Unassociate activate with everything
			end
		end
		local associateList = {}
		local unassociateList = {}
		for i = 1, #prevMode do
			unassociateList[prevMode[i].device] = true;
		end
		for i = 1, #mode do
			unassociateList[mode[i].device] = nil
			if mode.sceneControllable or mode.cooperConfiguration then
				associateList[mode[i].device] = mode[i].level
			else
				associateList[mode[i].device] = 255
			end
		end
		for i = 1, #prevMode do
			associateList[prevMode[i].device] = nil
		end
		if force then
			associateList[ZWaveNetworkDeviceId] = 255
		end
		if not mode.cooperConfiguration then
			local peer_dev_num = GetPeerDevNum(zwave_dev_num)
			if mode.sceneControllable and ((not mode.sceneId) or (SCObj.HasOffScenes and mode.prefix == "T" and not mode.offSceneId)) then
				mode = SelectSceneId(peer_dev_num, screen, virtualButton)
			end
			local sceneId = virtualButton
			if mode.sceneId then
				sceneId = mode.sceneId
			end
			local prevSceneId = virtualButton
			if prevMode and prevMode.sceneId then
				prevSceneId = prevMode.sceneId
			end
			if force or sceneId ~= prevSceneId then
				-- Set scene controller configuration, group id, sceneid, dimming Duration
				EnqueueZWaveMessage("SetSceneControllerConfig_On("..tostring(physicalButton)..","..sceneId..")"..node_id, node_id,  "0x2d 0x01 "..physicalButton.." "..sceneId.." 0xFF", param.SCENE_CTRL_SceneControllerConfDelay)
			end
			if SCObj.HasOffScenes and mode.prefix == "T" then
				local offSceneId = virtualButton
				if mode.offSceneId then
					offSceneId = mode.offSceneId
				end
				local prevOffSceneId = virtualButton
				if prevMode and prevMode.offSceneId then
					prevOffSceneId = prevMode.offSceneId
				end
				if force or offSceneId ~= prevOffSceneId then
					-- Set scene controller configuration, group id, sceneid, dimming Duration
					EnqueueZWaveMessage("SetSceneControllerConfig_Off("..(physicalButton+SCObj.NumButtons)..","..offSceneId..")"..node_id, node_id,  "0x2d 0x01 "..(physicalButton+SCObj.NumButtons).." "..offSceneId.." 0xFF", param.SCENE_CTRL_SceneControllerConfDelay)
				end
			end
			if mode.sceneControllable then
				for i = 1, #mode do
					local target_node_id = GetZWaveNode(mode[i].device);
					-- 	COMMAND_CLASS_SCENE_ACTUATOR_CONF SET sceneId dimmingDuration overrideFlag level
					--- Groups 1 to SCObj.NumButtons are On, Groups SCObj.NumButtons+1 to SCObj.NumButtons*2 are off.
					if target_node_id then
						local onActConf = GetDeviceActuatorConf(mode[i].device, mode.sceneId)
						if onActConf and
						   (onActConf.controller ~= zwave_dev_num or onActConf.button ~= virtualButton) and
						   (onActConf.level ~= mode[i].level or onActConf.dimmingDuration ~= mode[i].dimmingDuration) then
						   log("Warning: ON Scene ID conflict. Controller: zwave_dev_num="..tostring(zwave_dev_num).."slave zwave_dev_num="..tostring(mode[i].device).." Scene ID="..tostring(mode.sceneId))
						   log("         Old controller dev_num="..tostring(onActConf.controller).." Old button="..tostring(onActConf.button).." New button="..tostring(virtualButton))
						   log("         Old level="..tostring(onActConf.level).." new level="..tostring(mode[i].level))
						   log("         Old dimmingDuration="..tostring(onActConf.dimmingDuration).." New dimmingDuration="..tostring(mode[i].dimmingDuration))
						end
						if force or not onActConf or onActConf.level ~= mode[i].level or onActConf.dimmingDuration ~= mode[i].dimmingDuration then
							SetDeviceActuatorConf(zwave_dev_num, mode[i].device, target_node_id, mode.sceneId, virtualButton, mode[i].level, mode[i].dimmingDuration);
						end
						if SCObj.HasOffScenes and mode.prefix == "T" then
							local offActConf = GetDeviceActuatorConf(mode[i].device, mode.offSceneId)
							if offActConf and
							   (offActConf.controller ~= zwave_dev_num or offActConf.button ~= virtualButton+1000) and
							   (offActConf.level ~= 0 or offActConf.dimmingDuration ~= mode[i].dimmingDuration) then
							   log("Warning: OFF Scene ID conflict. Controller: controller dev_num="..tostring(zwave_dev_num).."slave dev_num="..tostring(mode[i].device).." Scene ID="..tostring(mode.sceneId))
							   log("         Old controller dev_num="..tostring(offActConf.controller).." Old button="..tostring(offActConf.button).." New button="..tostring(virtualButton+1000))
							   log("         Old level="..tostring(offActConf.level).." new level="..tostring(0))
							   log("         Old dimmingDuration="..tostring(offActConf.dimmingDuration).." New dimmingDuration="..tostring(mode[i].dimmingDuration))
							end
							if force or not offActConf or offActConf.level ~= 0 or offActConf.dimmingDuration ~= mode[i].dimmingDuration then
								SetDeviceActuatorConf(zwave_dev_num, mode[i].device, target_node_id, mode.offSceneId, virtualButton, 0, mode[i].dimmingDuration);
							end
						end
					else
						ELog("UpdateAssociationForPhysicalButton: bad SceneActuatorConfOn: bad associated device=" .. mode[i].device .. " peer_dev_num=".. peer_dev_num.. " screen=" .. screen .. " physicalButton=" .. physicalButton .. " i=" .. i)
					end
				end	-- for i = 1, #mode
			end	-- if mode.sceneControllable
		end -- if not mode.cooperConfiguration
		UnassociateDevice(zwave_dev_num, unassociateList, physicalButton, physicalButton, 1);
		if mode.cooperConfiguration then
			-- Special Cooper RFCW5 configuration for non-scene controllable devices.
			-- Set association for 1 or more devices and then ser the configuration for that button to the lable
			local levels = {}
			for k,v in pairs(associateList) do
				if not levels[v] then
					levels[v] = true
					local list = {}
					for k2, v2 in pairs(assocList) do
						if v2 == v then
							list[k2] = true;
						end
					end
					AssociateDevice(zwave_dev_num, list, physicalButton, physicalButton, 1)
					SetConfigurationOption("CooperConfiguration", zwave_dev_num, node_id, physicalButton, v)
				end
			end
		else
			-- Regular association. Can associate all devices regardless of level
			AssociateDevice(zwave_dev_num, associateList, physicalButton, physicalButton, 1)
		end
		if SCObj.HasOffScenes then
			if prevMode.prefix == "T" then
				UnassociateDevice(zwave_dev_num, unassociateList, physicalButton+SCObj.NumButtons, physicalButton+SCObj.NumButtons, 1);
			end
			if mode.prefix == "T" then
				AssociateDevice(zwave_dev_num, associateList, physicalButton+SCObj.NumButtons, physicalButton+SCObj.NumButtons, 1)
			elseif force then
				AssociateDevice(zwave_dev_num, {[ZWaveNetworkDeviceId]=true}, physicalButton+SCObj.NumButtons, physicalButton+SCObj.NumButtons, 1)
			end
		end	-- if SCObj.HasOffScenes
	end	-- if force or prevModeStr ~= modeStr
end

function GetModeStr(peer_dev_num, screen, virtualButton, next)
	local modeStr
	local state = 1
	if screen then
		modeStr  = luup.variable_get(SCObj.ServiceId,"Mode_"..screen.."_"..virtualButton,peer_dev_num)
		if not modeStr then
			modeStr = SCObj.DefaultModeString
		end
	else
		modeStr =  SCObj.DefaultModeString
	end
	local modePrefix = modeStr:sub(1,1)
	if modePrefix >= "2" and modePrefix <= "9" then
		local states = tonumber(modePrefix)
		state = luup.variable_get(SCObj.ServiceId,"State_"..screen.."_"..virtualButton,peer_dev_num)
		if state == nil then
			state = 1
		else
			state = tonumber(state)
		end
		state = (state % states) + 1
		modeStr  = luup.variable_get(SCObj.ServiceId,"Mode_"..screen.."_"..virtualButton+(state-1)*1000,peer_dev_num)
		if modeStr == nil then
			modeStr = "M"
		end
	end
	return modeStr, state
end

function SetButtonMode(peer_dev_num, prevModeStr, screen, force, temperatureSettable, physicalButton)
	local modeStr, state = 1, newType;
	local node_id, zwave_dev_num = GetZWaveNode(peer_dev_num)
	if not node_id then
		ELog("SetButtonMode: bad peer_dev_num=" .. peer_dev_num .. "  screen=" .. screen)
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
	elseif numLines > SCObj.NumButtons and
           ((physicalButton == 1 and scrollOffset > 0) or
            (physicalButton == SCObj.NumButtons and scrollOffset < numLines - SCObj.NumLines)) then
		modeStr = "M"
		if not prevModeStr then
			prevModeStr = "M"
		end
	else
		modeStr, state = GetModeStr(peer_dev_num, screen, virtualButton)
	end
	newType = SCObj.ModeType(ParseModeString(modeStr))
	if not force then
		oldType = SCObj.ModeType(ParseModeString(prevModeStr))
	end
	DLog("SetButtonMode: peer_dev_num=" .. tostring(peer_dev_num) .. " prevModeStr=" .. tostring(prevModeStr) ..
	        " screen=" .. tostring(screen) .. " force=" .. tostring(force) .. " temperatureSettable=" .. tostring(temperatureSettable) ..
	        " pysicalButton=" .. tostring(physicalButton) .. " oldType=" .. tostring(oldType) .. " modeStr=" .. tostring(modeStr) .. " newType=" .. tostring(newType)	..
			" NumLines=" .. tostring(numLines) .. " scrollOffset=" .. tostring(scrollOffset).. " virtualButton=" .. tostring(virtualButton).." state="..tostring(state))
	if force or oldType ~= newType then
		SCObj.SetButtonType(peer_dev_num, node_id, physicalButton, newType)
	end
	UpdateAssociationForPhysicalButton(zwave_dev_num, screen, force, prevModeStr, modeStr, physicalButton, virtualButton+(state-1)*1000)
end

function SceneController_UpdateCustomLabel(peer_dev_num, screen, virtualButton, label, font, align, mode)
	if IsVeraPrimaryController() then
		DLog("UpdateCustomLabel: peer_dev_num="..tostring(peer_dev_num).." screen="..tostring(screen).." virtualButton="..tostring(virtualButton).." label="..tostring(label).." font="..tostring(font).." align="..tostring(align).." mode="..tostring(mode));
		if label == nil then
			label = ""
		end
		local numLines, scrollOffset = GetNumLinesAndScrollOffset(peer_dev_num, screen)
		virtualButton = tonumber(virtualButton)
		local physicalButton = virtualButton - scrollOffset
		local prevModeStr = GetModeStr(peer_dev_num, screen, virtualButton)
		if SCObj.HasScreen then
			luup.variable_set(SCObj.ServiceId, "Label_" .. screen .. "_" .. virtualButton, label, peer_dev_num)
			luup.variable_set(SCObj.ServiceId, "Font_" .. screen .. "_" .. virtualButton, font, peer_dev_num)
			luup.variable_set(SCObj.ServiceId, "Align_" .. screen .. "_" .. virtualButton, align, peer_dev_num)
		end
		luup.variable_set(SCObj.ServiceId, "Mode_"  .. screen .. "_" .. virtualButton, mode,  peer_dev_num)
		SelectSceneId(peer_dev_num, screen, virtualButton)
		local currentScreen = luup.variable_get(SCObj.ServiceId, CURRENT_SCREEN, peer_dev_num)
		if not SCObj.HasMultipleScreens or currentScreen == screen then
			if physicalButton >= 1 and
               physicalButton <= SCObj.NumButtons and
               (numLines <= SCObj.NumButtons or
                ((physicalButton > 1 or scrollOffset == 0) and
                 (physicalButton < SCObj.NumButtons or scrollOffset == numLines-SCObj.NumButtons))) then
				if SCObj.HasScreen then
				    local node_id, zwave_dev_num = GetZWaveNode(peer_dev_num)
					if not node_id then
						ELog("SceneController_UpdateCustomLabel: Bad peer_dev_num="..peer_dev_num.. " label=" .. label)
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

function ChooseLabelFontAndAlign(peer_dev_num, screen, line, virtualButton, stateOverride, labels, fonts, aligns)
	if not SCObj.HasScreen then
		return
	end
	local modeStr = luup.variable_get(SCObj.ServiceId,"Mode_"..screen.."_"..virtualButton,peer_dev_num)
	if modeStr == nil then
		modeStr = SCObj.DefaultModeString
	end
	local mode = ParseModeString(modeStr)
	if mode.prefix >= "2" and mode.prefix <= "9" then
		local states = tonumber(mode.prefix)
		if stateOverride ~= nil then
			if stateOverride < 1 then
				stateOverride = states
			elseif stateOverride > states then
			    stateOverride = 1
			end
		else
			stateOverride = ChooseBestState(peer_dev_num, screen, virtualButton, mode)
		end
		virtualButton = virtualButton + ((stateOverride-1) * 1000)
	end
	local label = luup.variable_get(SCObj.ServiceId,"Label_"..screen.."_"..virtualButton,peer_dev_num)
	if label == nil then
		label = ""
	end
	labels[line] = label;
	local font = luup.variable_get(SCObj.ServiceId,"Font_"..screen.."_"..virtualButton,peer_dev_num)
	if font == nil then
		font = "Normal"
	end
	fonts[line] = font;
	local align = luup.variable_get(SCObj.ServiceId,"Align_"..screen.."_"..virtualButton,peer_dev_num)
	if align == nil then
		font = "Center"
	end
	aligns[line] = align;
end

function SetCustomScreen(peer_dev_num, screenNum, timeout, forceClear, indicatorOnly)
	if not SCObj.HasScreen then
		SetPresetScreen(peer_dev_num, screenNum, timeout, forceClear, indicatorOnly)
		return
	end
	local screen = "C"..tostring(screenNum)
	local node_id, zwave_dev_num = GetZWaveNode(peer_dev_num)
	local prevScreen = luup.variable_get(SCObj.ServiceId, CURRENT_SCREEN, peer_dev_num)
	DLog("SetCustomScreen: peer_dev_num="..tostring(peer_dev_num).." prevScreen="..tostring(prevScreen).." screen="..tostring(screen).." timeout="..tostring(timeout).." forceClear="..tostring(forceClear).." indicatorOnly="..tostring(indicatorOnly))
	if SCObj.HasMultipleScreens and (not prevScreen or SCObj.ScreenPage(prevScreen) ~= SCObj.ScreenPage(screen)) then
		forceClear = true
		indicatorOnly = false
		if not prevScreen then
			prevScreen = ""
		end
	end
	if forceClear and not indicatorOnly then
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
	if not indicatorOnly then
		scrollOffset = 0
		if not forceClear and prevScrollOffset ~= scrollOffset then
			luup.variable_set(SCObj.ServiceId, SCROLLOFFSET_VAR.."_"..screen, scrollOffset, peer_dev_num)
		end
	    DLog("  SetCustomScreen: numLines=" .. numLines .. " scrollOffset=" .. scrollOffset)
	end
	local earlyButtonConfig = false;
	if not indicatorOnly then
		SetIndicatorValue(peer_dev_num, 0, forceClear, 100)
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
			if numLines > SCObj.NumButtons and i == SCObj.NumButtons then
				labels[i] = "\nvvvvvv";
				fonts[i] = "Inverted";
				aligns[i] = "Center";
			else
				ChooseLabelFontAndAlign(peer_dev_num, screen, i, i, nil, labels, fonts, aligns)
			end
		end
		if SCObj.HasMultipleScreens then
			luup.variable_set(SCObj.ServiceId, CURRENT_SCREEN, screen, peer_dev_num)
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
	SetIndicator(peer_dev_num, screen, forceClear, 0)
	if timeout then
    	SetScreenTimeout(peer_dev_num, screen)
	end
end

function SetPresetScreen(peer_dev_num, screenNum, timeout, forceClear, indicatorOnly)
	local screen = "P"..tostring(screenNum)
   	local node_id = GetZWaveNode(peer_dev_num)
	local prevScreen
	if SCObj.HasMultipleScreens then
		prevScreen = luup.variable_get(SCObj.ServiceId, CURRENT_SCREEN, peer_dev_num)
	else
		prevScreen = screen
	end
	DLog("SetPresetScreen: peer_dev_num="..tostring(peer_dev_num).." prevScreen="..tostring(prevScreen).." screen="..tostring(screen).." timeout="..tostring(timeout).." forceClear="..tostring(forceClear).." indicatorOnly="..tostring(indicatorOnly))
	local prevNumLines, prevScrollOffset
	if prevScreen == nil then
		prevNumLines, prevScrollOffset = SCObj.NumButtons, 0
		forceClear = true;
		indicatorOnly = false
	else
		prevNumLines, prevScrollOffset = GetNumLinesAndScrollOffset(peer_dev_num, prevScreen)
	end
	if SCObj.HasMultipleScreens then
		luup.variable_set(SCObj.ServiceId, CURRENT_SCREEN, screen, peer_dev_num)
	end
	if not indicatorOnly and (forceClear or prevScreen ~= screen) then
		SetIndicatorValue(peer_dev_num, 0, forceClear, 100)
		SCObj.SetDeviceScreen(peer_dev_num, screen)
		for i = 1, SCObj.NumButtons do
			local prevModeStr = GetModeStr(peer_dev_num, prevScreen, i+prevScrollOffset)
			SetButtonMode(peer_dev_num, prevModeStr, screen, forceClear, false, i);
		end
	end
	SetIndicator(peer_dev_num, screen, forceClear, 100)
	if timeout then
    	SetScreenTimeout(peer_dev_num, screen)
	end
end

function SceneController_SetPresetLanguage(peer_dev_num, language)
	if SCObj.HasPresetLanguages and IsVeraPrimaryController() then
	   	luup.variable_set(SCObj.ServiceId, PRESET_LANGUAGE, language, peer_dev_num)
		SCObj.SetLanguage(peer_dev_num, language)
		RunZWaveQueue("SetPresetLanguage", 0);
	end
end

curTemperatureDevice = 0;

function SetTemperatureLCDParameters(zwave_dev_num, temperatureDevice)
	local lcd_node_id = GetZWaveNode(zwave_dev_num);

	local temperatureString = "72" -- Default if no associated temperature device.
	if temperatureDevice > 0 then
		temperatureString = luup.variable_get(SID_TEMPSENSOR, TEMPSENSOR_VAR, temperatureDevice)
	end
	if temperatureString ~= nil then
		local temperature = math.floor(tonumber(temperatureString) + 0.5);
		-- COMMAND_CLASS_SENSOR_MULTILEVEL SENSOR_MULTILEVEL_REPORT Sensor Type = Temperature Level = Size=1 | Scale=1 | Precision=0
		EnqueueZWaveMessage("SetDisplayTemperature", lcd_node_id,  "0x31 0x5 0x1 0x9 ".. temperature, 0)
	end

	if temperatureDevice == 0 then
		return
	end

	local userMode = luup.variable_get(SID_USERMODE, USERMODE_VAR, temperatureDevice)
	if userMode == USERMODE_COOL then
		local coolSetPointString = luup.variable_get(SID_COOLSETPOINT, SETPOINT_VAR, temperatureDevice)
		if coolSetPointString ~= nil then
			local coolSetPoint = math.floor(tonumber(coolSetPointString) + 0.5);
			-- COMMAND_CLASS_THERMOSTAT_SETPOINT THERMOSTAT_SETPOINT_REPORT  SetPoint = Cooling 1 Level = Size=1 | Scale=1 | Precision=0
			EnqueueZWaveMessage("SetDisplaySetpoint", lcd_node_id, "0x43 0x03 0x02 0x9 ".. coolSetPoint, 0)
		end
	elseif userMode == USERMODE_HEAT then
		local heatSetPointString = luup.variable_get(SID_HEATSETPOINT, SETPOINT_VAR, temperatureDevice)
		if heatSetPointString ~= nil then
			local heatSetPoint = math.floor(tonumber(heatSetPointString) + 0.5);
			-- COMMAND_CLASS_THERMOSTAT_SETPOINT THERMOSTAT_SETPOINT_REPORT  SetPoint = Heating 1 Level = Size=1 | Scale=1 | Precision=0
			EnqueueZWaveMessage("SetDisplaySetpoint", lcd_node_id, "0x43 0x03 0x01 0x9 ".. heatSetPoint, 0)
		end
	else
		if temperatureString ~= nil then
			local temperature = math.floor(tonumber(temperatureString) + 0.5);
			-- COMMAND_CLASS_THERMOSTAT_SETPOINT THERMOSTAT_SETPOINT_REPORT  SetPoint = Heating 1 Level = Size=1 | Scale=1 | Precision=0
			EnqueueZWaveMessage("SetDisplaySetpoint", lcd_node_id, "0x43 0x03 0x01 0x9 ".. temperature, 0)
		end
	end

	local fanModeString = luup.variable_get(SID_FANMODE, FANMODE_VAR, temperatureDevice)
	if fanModeString ~= nil then
		local fanMode = 1
		if 	fanModeString == FANMODE_AUTO then
			fanMode = 0
		end
		-- COMMAND_CLASS_THERMOSTAT_FAN_MODE  THERMOSTAT_FAN_MODE_REPORT
		EnqueueZWaveMessage("SetDisplayFanMode", lcd_node_id, "0x44 0x3 ".. fanMode, 0)
	end
end

function UnassociateDevice(zwave_dev_num, target_dev_num_list, firstGroup, lastGroup, groupStep)
	DLog("    UnassociateDevice zwave_dev_num="..tostring(zwave_dev_num).." target_dev_num_list="..DTableToString(target_dev_num_list).." firstGroup="..tostring(firstGroup).." lastGroup="..tostring(lastGroup).." groupStep="..tostring(groupStep))
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
				ELog("UnassociateDevice: Unknown target device: "..tostring(k))
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
		EnqueueZWaveMessage("RemoveAssociation("..group..")"..zwave_node_id.."-x->"..label, zwave_node_id,  "0x85 0x04 "..group..targets, param.SCENE_CTRL_AssociationDelay)
	end
end

function AssociateDevice(zwave_dev_num, target_dev_num_list, firstGroup, lastGroup, groupStep)
	DLog("    AssociateDevice zwave_dev_num="..tostring(zwave_dev_num).." target_dev_num_list="..DTableToString(target_dev_num_list).." firstGroup="..tostring(firstGroup).." lastGroup="..tostring(lastGroup).." groupStep="..tostring(groupStep))
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
			ELog("AssociateDevice: Unknown target device: "..tostring(k).." Group="..firstGroup.." Controlling device="..zwave_dev_num.."("..tostring(luup.devices[zwave_dev_num].description)..")")
		end
	end
	if count == 0 then
		return
	end
	-- COMMAND_CLASS_ASSOCIATION ASSOCIATION_REMOVE
	for group = firstGroup, lastGroup, groupStep do
		EnqueueZWaveMessage("SetAssociation("..group..")"..zwave_node_id.."->"..label, zwave_node_id, "0x85 0x01 "..group..targets, param.SCENE_CTRL_AssociationDelay)
	end
end

local SceneController_ReturnRoutes = {}
function SetReturnRoute(zwave_dev_num, lcd_node_id, target_node_id)
  	local veraZWaveNode, ZWaveNetworkDeviceId = GetVeraIDs()
	if target_node_id ~= veraZWaveNode then
		if SceneController_ReturnRoutes[lcd_node_id] == nil then
			local returnRouteList = luup.variable_get(SCObj.ServiceId, RETURN_ROUTES, zwave_dev_num)
			SceneController_ReturnRoutes[lcd_node_id] = {}
			if returnRouteList then
				for d in string.gmatch(returnRouteList, "%d+") do
	       			SceneController_ReturnRoutes[lcd_node_id][tonumber(d)] = true;
	     		end
			end
		end
		if not  SceneController_ReturnRoutes[lcd_node_id][target_node_id] then
			EnqueueZWaveMessage("AssignReturnRoute_"..lcd_node_id.."->"..target_node_id, 0,  "0x00 0x46 ".. lcd_node_id .. " " .. target_node_id .. " " .. veraZWaveNode, param.SCENE_CTRL_ReturnRouteDelay)
			SceneController_ReturnRoutes[lcd_node_id][target_node_id] = true
			local returnRouteList = ""
			for k,v in pairs(SceneController_ReturnRoutes[lcd_node_id]) do
			   returnRouteList = returnRouteList.. tostring(k)..","
			end
	   		luup.variable_set(SCObj.ServiceId, RETURN_ROUTES, returnRouteList, zwave_dev_num)
		end
	end
end

function ClearReturnRouteCache(zwave_dev_num)
	local node_id = GetZWaveNode(zwave_dev_num);
	SceneController_ReturnRoutes[node_id] = nil;
	luup.variable_set(SCObj.ServiceId, RETURN_ROUTES, "", zwave_dev_num)
end

-- This is called by the GUI to change the thermostat associated with this controller.
function SceneController_UpdateTemperatureDevice(peer_dev_num, screen, temperatureDevice)
	if SCObj.HasThremostatControl and IsVeraPrimaryController() then
		DLog("UpdateTemperatureDevice: peer_dev_num="..tostring(peer_dev_num).." screen="..tostring(screen).." temperatureDevice="..tostring(temperatureDevice));
		local curTemperatureDevice = luup.variable_get(SCObj.ServiceId, "TemperatureDevice_"  .. screen, peer_dev_num);
		curTemperatureDevice = tonumber(curTemperatureDevice)
		luup.variable_set(SCObj.ServiceId, "TemperatureDevice_"  .. screen, temperatureDevice,  peer_dev_num)
		local currentScreen = luup.variable_get(SCObj.ServiceId, CURRENT_SCREEN, peer_dev_num);
		temperatureDevice = tonumber(temperatureDevice);
		DLog("Previous temperature device = "..tostring(curTemperatureDevice));
		if currentScreen == screen and curTemperatureDevice ~= temperatureDevice then
			local zwave_node_id, zwave_dev_num = GetZWaveNode(peer_dev_num);
			if curTemperatureDevice then
				UnassociateDevice(zwave_dev_num, {[curTemperatureDevice]=true}, 2, 4, 1);
			end
			SetTemperatureLCDParameters(zwave_dev_num, temperatureDevice);
			AssociateDevice(zwave_dev_num, {[temperatureDevice]=true}, 2, 4, 1);
			curTemperatureDevice = temperatureDevice
		end
		RunZWaveQueue("UpdateTemperatureDevice", 0);
	end
end

RedrawCustomTemperatureScreenRecursion = 0;

-- A work-around for the "bug" which clears rows 1 and 5 of a custom temperature screen
function TemperatureDeviceChanged(temperatureDevice, service, variable, old_val, new_val)
	local peer_dev_num = EvolveSCENE_CTRL_peer_dev_num;
	DLog("TemperatureDeviceChanged: temperatureDevice="..tostring(temperatureDevice).." service="..tostring(service).." variable="..tostring(variable).." old_val="..tostring(old_val).." new_val="..tostring(new_val).." peer_dev_num="..tostring(peer_dev_num));
	if RedrawCustomTemperatureScreenRecursion > 0 then
		DLog("TemperatureDeviceChanged returning quickly");
		return
	end
	local screen = luup.variable_get(SCObj.ServiceId, CURRENT_SCREEN, peer_dev_num)
	local prefix = screen:sub(1,1)
	if prefix ~= "T" then
		return
	end
	RedrawCustomTemperatureScreenRecursion=1;

	SetScreenTimeout(peer_dev_num, screen);
	TemperatureDeviceChanged2(1, peer_dev_num, temperatureDevice, service, variable, old_val, new_val)
end

-- The second part of the custom temperature redraw hack is done in a
-- deferred task since it calls sendData. It must be called recursively
-- several times with call_delay in order to avoid a luaupnp "Failed to get lock" error.
function TemperatureDeviceChanged2(part, peer_dev_num, temperatureDevice, service, variable, old_val, new_val)
	DLog("TemperatureDeviceChanged2: part="..tostring(part).." peer_dev_num="..tostring(peer_dev_num).." temperatureDevice="..tostring(temperatureDevice).." service="..tostring(service).." variable="..tostring(variable).." old_val="..tostring(old_val).." new_val="..tostring(new_val).." peer_dev_num="..tostring(peer_dev_num));
	local lcd_node_id, lcd_dev_num = GetZWaveNode(peer_dev_num);
	local redraw = true;
	local userMode = luup.variable_get(SID_USERMODE, USERMODE_VAR, temperatureDevice)
	local newHeatSetPoint = nil
	local newCoolSetPoint = nil

	if service == SID_HEATSETPOINT and variable == SETPOINT_VAR then
		-- Evolve LCD1 will send HEAT SETPOINT SET commands to the thermostat even though it is a cool
		-- setpoint. As such, we need to remember the old heat setpoint and set the
		-- cool setpoint to the "new" heat setpoint.
		-- If the setpoint is changed using the web GUI, or via a scene, then setpointTarget will equal the cureent heat setpoint
		-- so we can handle this even if the user changes the heat setpoint in cool mode.
		-- The user can only change the heat setpoint
		local target = luup.variable_get(SID_HEATSETPOINT, SETPOINT_TARG, temperatureDevice)
		local temperatureString = luup.variable_get(SID_TEMPSENSOR, TEMPSENSOR_VAR, temperatureDevice)
		local temperature = tonumber(temperatureString);
		local coolSetPointString = luup.variable_get(SID_COOLSETPOINT, SETPOINT_VAR, temperatureDevice)
		local oldCoolSetPoint = tonumber(coolSetPointString);
		local oldHeatSetPoint = tonumber(old_val)
		if target ~= new_val and (userMode == USERMODE_COOL) then
			EnqueueLuupAction(SID_HEATSETPOINT, temperatureDevice, "SetCurrentSetpoint", {NewCurrentSetpoint = old_val}, 2000)
			EnqueueLuupAction(SID_COOLSETPOINT, temperatureDevice, "SetCurrentSetpoint", {NewCurrentSetpoint = new_val}, 2000)
			local lcdSetPoint = math.floor(tonumber(new_val) + 0.5);
			newCoolSetpoint = lcdSetPoint;
		else
			local lcdSetPoint = math.floor(tonumber(new_val) + 0.5);
			newHeatSetPoint = lcdSetPoint;
		end
	end

	if service == SID_USERMODE and variable == USERMODE_VAR then
		if new_val == USERMODE_COOL then
			local coolSetpoint_string = luup.variable_get(SID_COOLSETPOINT, SETPOINT_VAR, temperatureDevice)
			newCoolSetPoint = math.floor(tonumber(coolSetpoint_string) + 0.5);
		else
			local heatSetpoint_string = luup.variable_get(SID_HEATSETPOINT, SETPOINT_VAR, temperatureDevice);
			newHeatSetPoint = math.floor(tonumber(heatSetpoint_string) + 0.5);
		end
		redraw = false;
	end

	if service == SID_TEMPSENSOR and variable == TEMPSENSOR_VAR then
		local temperature = math.floor(tonumber(new_val) + 0.5);
		-- COMMAND_CLASS_SENSOR_MULTILEVEL SENSOR_MULTILEVEL_REPORT Sensor Type = Temperature Level = Size=1 | Scale=1 | Precision=0
		EnqueueZWaveMessage("SetDisplayTemperature", lcd_node_id, "0x31 0x5 0x1 0x9 ".. temperature, 2000)
	end

	if service == SID_FANMODE and variable == FANMODE_VAR then
		local fanMode = 1
		if 	new_val == FANMODE_AUTO then
			fanMode = 0
		end
		-- COMMAND_CLASS_THERMOSTAT_FAN_MODE  THERMOSTAT_FAN_MODE_REPORT
		EnqueueZWaveMessage("SetDisplayFanMode", lcd_node_id, "0x44 0x3 ".. fanMode, 2000)
	end

	RedrawCustomTemperatureScreenRecursion = 0;

	if redraw then
		local screen = luup.variable_get(SCObj.ServiceId, CURRENT_SCREEN, peer_dev_num)
		local suffix = screen:sub(2)
		local screenNum = tonumber(suffix)
		if screenNum > SCObj.NumTemperatureScreens then
			local labels = {};
			local fonts = {};
			local aligns = {};
			for i = 1, SCObj.NumButtons, SCObj.NumButtons-1 do
				label = luup.variable_get(SCObj.ServiceId,"Label_"..screen.."_"..i,peer_dev_num)
				if label == nil then
					label = ""
				end
				labels[i] = label
				local font = luup.variable_get(SCObj.ServiceId,"Font_"..screen.."_"..i,peer_dev_num)
				if font == nil then
					font = "Normal"
				end
				fonts[i] = font;
				local align = luup.variable_get(SCObj.ServiceId,"Align_"..screen.."_"..i,peer_dev_num)
				if align == nil then
					font = "Center"
				end
				aligns[i] = align;
			end
			EVLCDWrapStrings(labels, fonts, aligns, lcd_node_id, lcd_dev_num, 1, SCObj.NumButtons, SCREEN_MD.NoChange)
		end
	end

	if newCoolSetPont ~= nil then
		TemperatureDeviceChanged3(peer_dev_num, newCoolSetPoint, 2, temperatureDevice)
	elseif newHeatSetPoint ~= nil then
		TemperatureDeviceChanged3(peer_dev_num, newHeatSetPoint, 1, temperatureDevice)
	end
end

function TemperatureDeviceChanged3(peer_dev_num, setpoint, heatOrCool,temperatureDevice)
	local lcd_node_id, lcd_dev_num = GetZWaveNode(peer_dev_num);
	DLog("TemperatureDeviceChanged3: peer_dev_num="..tostring(peer_dev_num).." setpoint="..tostring(setpoint).." heatOrCool="..tostring(heatOrCool).." temperatureDevice="..tostring(temperatureDevice));
	UnassociateDevice(zwave_dev_num, {[temperatureDevice]=true}, 2, 4, 1);
	-- COMMAND_CLASS_THERMOSTAT_SETPOINT THERMOSTAT_SETPOINT_REPORT  SetPoint = Heating 1 Level = Size=1 | Scale=1 | Precision=0
	EnqueueZWaveMessage("SetDisplaySetpoint", lcd_node_id, "0x43 0x03 1 0x9 ".. setpoint, 0)
	AssociateDevice(zwave_dev_num, {[temperatureDevice]=true}, 2, 4, 1);
end

function TemperatureDeviceIsSettable(temperatureDevice)
	if temperatureDevice <= 0 then
		DLog("TemperatureDeviceIsSettable: return true because temperatureDevice="..tostring(temperatureDevice))
		return true  -- Dummy - No attached device. Show the arrows even if they don't do anything.
	end
	local category_num = luup.attr_get("category_num", temperatureDevice);
	if category_num ~= "5" then  -- HVAC category num
		DLog("TemperatureDeviceIsSettable: return false because category_num="..tostring(category_num))
		return false  -- Temperature sensor only
	end
	local parent = luup.attr_get("id_parent", temperatureDevice);
	if parent ~= "1" then  -- Z-Wave controller
		DLog("TemperatureDeviceIsSettable: return false because parent="..tostring(parent))
		return false  -- Non-Z-Wave thermostat
	end
	local userMode = luup.variable_get(SID_USERMODE, USERMODE_VAR, temperatureDevice)
	local result = userMode ~= USERMODE_OFF;
	DLog("TemperatureDeviceIsSettable: return "..tostring(result).." because userMode="..tostring(userMode))
	return result;
end

function ClearScreen(dev_num, node_id)
	if SCObj.HasScreen then
		EnqueueZWaveMessage("ClearScreen", node_id, "146 2 0 0 0 0 0 0 0", param.SCENE_CTRL_ClearDelay);
	end
end

WatchedTemperatureDevices = {};

function SetTemperatureScreen(peer_dev_num, screenNum, timeout, forceClear, indicatorOnly)
	local screen = "T"..screenNum;
	local node_id, zwave_dev_num = GetZWaveNode(peer_dev_num)
	local screenNum = tonumber(screenNum)
	local lcdPage = SCObj.ScreenPage(screen);
	local prevScreen = luup.variable_get(SCObj.ServiceId, CURRENT_SCREEN, peer_dev_num)
	local prevNumLines, prevScrollOffset
	if prevScreen == nil then
		prevScreen = "";
		prevNumLines, prevScrollOffset = SCObj.NumButtons, 0
		forceClear = true;
		indicatorOnly = false;
	else
		prevNumLines, prevScrollOffset = GetNumLinesAndScrollOffset(peer_dev_num, prevScreen)
		prevLcdPage = SCObj.ScreenPage(prevScreen);
	end
	local prevLcdPage = 0

	local temperatureDevice = luup.variable_get(SCObj.ServiceId, "TemperatureDevice_"  .. screen, peer_dev_num)
	if temperatureDevice == nil then
		temperatureDevice = 0
	end
	temperatureDevice = tonumber(temperatureDevice);
	local settable = TemperatureDeviceIsSettable(temperatureDevice)

	SetTemperatureLCDParameters(zwave_dev_num, temperatureDevice)

	if forceClear or prevLcdPage ~= lcdPage then
		SetConfigurationOption("SetTemperatureScreen", peer_dev_num, node_id, 17, lcdPage)
		luup.sleep(500);
		prevLcdPage = lcdPage
	end

	if not indicatorOnly then
		if screenNum > SCObj.NumTemperatureScreens then
		    SetIndicatorValue(peer_dev_num, 0, forceClear, 0)
			ClearScreen(peer_dev_num, node_id)
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
				if i > 1 and i < SCObj.NumButtons then
					luup.sleep(300)
				end
			end

			-- Enable fan mode control on button 3.
			SetConfigurationOption("SetTemperatureScreen", peer_dev_num, node_id, 36, 1)

			local temperatureString = luup.variable_get(SID_TEMPSENSOR, TEMPSENSOR_VAR, temperatureDevice)
			if temperatureString == nil then
				temperatureString = "72";
			end

			for i = 1, SCObj.NumButtons, SCObj.NumButtons-1 do
				label = luup.variable_get(SCObj.ServiceId,"Label_"..screen.."_"..i,peer_dev_num)
				if label == nil then
					label = ""
				end
				labels[i] = label
				local font = luup.variable_get(SCObj.ServiceId,"Font_"..screen.."_"..i,peer_dev_num)
				if font == nil then
					font = "Normal"
				end
				fonts[i] = font;
				local align = luup.variable_get(SCObj.ServiceId,"Align_"..screen.."_"..i,peer_dev_num)
				if align == nil then
					font = "Center"
				end
				aligns[i] = align;
			end
			EVLCDWrapStrings(labels, fonts, aligns, node_id, zwave_dev_num, 1, SCObj.NumButtons, SCREEN_MD.NoChange)
			--luup.sleep(1000);
		end

		if prevLcdPage ~= lcdPage or forceClear then
			SetConfigurationOption("SetTemperatureScreen", peer_dev_num, node_id, 17, lcdPage, 1000)
			prevLcdPage = lcdPage;
		end
	end

	SetIndicator(peer_dev_num, screen, forceClear, 0)
	luup.variable_set(SCObj.ServiceId, CURRENT_SCREEN, screen, peer_dev_num)
	if timeout then
    	SetScreenTimeout(peer_dev_num, screen)
	end

	if (curTemperatureDevice ~= temperatureDevice or forceClear) and not indicatorOnly then
		DLog("screen="..screen.." curTemperatureDevice="..tostring(curTemperatureDevice).." temperatureDevice="..tostring(temperatureDevice).." forceClear="..tostring(forceClear));
		UnassociateDevice(zwave_dev_num, {[curTemperatureDevice]=true}, 2, 4, 1);
		AssociateDevice(zwave_dev_num, {[temperatureDevice]=true}, 2, 4, 1);
		curTemperatureDevice = temperatureDevice
	end

	if screenNum > SCObj.NumTemperatureScreens and curTemperatureDevice > 0 then
		-- Work-around to redisplay the custom labels if they get cleared
		EvolveSCENE_CTRL_peer_dev_num = peer_dev_num;
		DLog("Watching temperature variables for temperatureDevice: "..curTemperatureDevice);
		if WatchedTemperatureDevices[curTemperatureDevice] == nil then
			WatchedTemperatureDevices[curTemperatureDevice] = true;
			luup.variable_watch("TemperatureDeviceChanged", SID_TEMPSENSOR,   TEMPSENSOR_VAR,   curTemperatureDevice)
			luup.variable_watch("TemperatureDeviceChanged", SID_COOLSETPOINT, SETPOINT_VAR,     curTemperatureDevice)
			luup.variable_watch("TemperatureDeviceChanged", SID_HEATSETPOINT, SETPOINT_VAR,     curTemperatureDevice)
			luup.variable_watch("TemperatureDeviceChanged", SID_FANMODE,      FANMODE_VAR,      curTemperatureDevice)
			luup.variable_watch("TemperatureDeviceChanged", SID_USERMODE,     USERMODE_VAR,     curTemperatureDevice)
		end
	end
end

setScreenTable = {
	C=SetCustomScreen,
	P=SetPresetScreen,
	T=SetTemperatureScreen,
}

function SetScreen(peer_dev_num, screen, doTimeout, forceClear, indicatorOnly)
	if IsVeraPrimaryController() then
		DLog("SetScreen: peer_dev_num="..peer_dev_num.." screen="..screen.." doTimeout="..tostring(doTimeout).." forceClear="..tostring(forceClear).. " indicatorOnly=" .. tostring(indicatorOnly))
		local func = setScreenTable[screen:sub(1,1)]
		if func ~= nil then
			func(peer_dev_num, screen:sub(2), doTimeout, forceClear, indicatorOnly)
		else
			ELog("SetScreen: Unknown screen type: " .. screen)
		end
	end
end

function SceneController_SetScreen(peer_dev_num, screen, doTimeout, forceClear, indicatorOnly)
	DLog("SceneController_SetScreen: peer_dev_num="..peer_dev_num.." screen="..screen.." doTimeout="..tostring(doTimeout).." forceClear="..tostring(forceClear).. " indicatorOnly=" .. tostring(indicatorOnly))
	if IsVeraPrimaryController() then
		SetScreen(peer_dev_num, screen, doTimeout, forceClear, indicatorOnly)
		RunZWaveQueue("SetScreen", 0);
	end
end

local timeout_count = 0
function SceneController_SetBacklight(peer_dev_num, timeout)
	if IsVeraPrimaryController() then
		if not peer_dev_num then
			ELog("SceneController_SetBacklight: bad peer_dev_num=" .. tostring(peer_dev_num))
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
	if IsVeraPrimaryController() then
		timeout_count = timeout_count - 1
		if timeout_count <= 0 then
			local peer_dev_num = tonumber(peer_dev_num_string)
			SCObj.SetBacklight(peer_dev_num, false)
		end
		RunZWaveQueue("BacklightTimeout", 0);
	end
end

-- This re-associates all of the scene activation buttons after Vera has reconfigured the Z-Wave device.
-- It also possibly re-associates the thermostat if the current page is a temperature screen.
-- This is called as a watch trigger whenever the Z-Wave device is reconfigured
function SceneController_ConfiguredChanged(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
	VLog("SceneController_ConfiguredChanged: lul_device=" .. tostring(lul_device) .. "lul_service=" .. tostring(lul_service) .. "lul_variable=" .. tostring(lul_variable) .. "lul_value_old=" .. tostring(lul_value_old) .. " lul_value_new=" .. tostring(lul_value_new))
	if IsVeraPrimaryController() then
		if tonumber(lul_value_old) ~= 1 and tonumber(lul_value_new) == 1 then
			local dev_num = tonumber(lul_device);
			local node_id, zwave_dev_num = GetZWaveNode(dev_num)
			-- 10 scenes - 5 activation, 5 deactivation
			ClearReturnRouteCache(zwave_dev_num)
	  		local veraZWaveNode, ZWaveNetworkDeviceId = GetVeraIDs()
			local peer_dev_num_str = luup.variable_get(SCObj.ServiceId,"PeerID",zwave_dev_num)
			local peer_dev_num = tonumber(peer_dev_num_str)
			local currentScreen = GetCurrentScreen(peer_dev_num)
			local prefix = currentScreen:sub(1,1)
			if prefix == "T" then
				local temperatureDevice = luup.variable_get(SCObj.ServiceId, "TemperatureDevice_"  .. currentScreen, peer_dev_num)
				if temperatureDevice == nil then
					temperatureDevice = 0
				end
				temperatureDevice = tonumber(temperatureDevice);
				AssociateDevice(zwave_dev_num, {[temperatureDevice]=true}, 2, 4, 1)
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
			DLog("ConfiguredChanged: associateList="..DTableToString(associateList).." zwave_dev_num="..tostring(zwave_dev_num))
			for k, v in pairs(associateList) do
				RemoveDeviceActuatorConfForController(zwave_dev_num, k)
			end
			DLog("ConfiguredChanged: calling SetButtonMode. peer_dev_num="..tostring(peer_dev_num).." currentScreen="..tostring(currentScreen))
			-- Finally, set the modes for the current screen.
			for i = 1, SCObj.NumButtons do
				SetButtonMode(peer_dev_num, "", currentScreen, true, false, i);
			end
		end
		RunZWaveQueue("ConfiguredChanged", 0);
	end
end

SceneIds = {}
SceneTimes = {}

function GetCurrentScreen(peer_dev_num)
	local currentScreen
	if SCObj.HasMultipleScreens then
		currentScreen = luup.variable_get(SCObj.ServiceId, CURRENT_SCREEN, peer_dev_num)
	end
	if not currentScreen then
		currentScreen = SCObj.DefaultScreen
	end
	return currentScreen
end

function SceneController_LastSceneIDChange(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new, context)
	DLog("SceneController_LastSceneIDChange: lul_device=" .. tostring(lul_device) .. "lul_service=" .. tostring(lul_service) .. "lul_variable=" .. tostring(lul_variable) .. "lul_value_old=" .. tostring(lul_value_old) .. " lul_value_new=" .. tostring(lul_value_new))
	local zwave_dev_num = tonumber(lul_device)
	local peer_dev_num_str = luup.variable_get(SCObj.ServiceId,"PeerID",zwave_dev_num)
	local peer_dev_num = tonumber(peer_dev_num_str)
	local zwave_scene_str, scene_id_update_time = luup.variable_get(SID_SCTRL, "LastSceneID",zwave_dev_num)
	local cur_scene_id = tonumber(lul_value_new)
	SceneTimes[peer_dev_num] = scene_id_update_time
	SceneIds[peer_dev_num] = cur_scene_id
	TempVariableUnwatch(SID_SCTRL, "LastSceneID", zwave_dev_num)
	luup.variable_set(SID_SCTRL, "LastSceneID", "", zwave_dev_num)
	SceneChange(peer_dev_num, cur_scene_id, scene_id_update_time)
end

function SceneController_LastSceneTimeChange(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new, context)
	DLog("SceneController_LastSceneTimeChange: lul_device=" .. tostring(lul_device) .. " lul_service=" .. tostring(lul_service) .. " lul_variable=" .. tostring(lul_variable) .. " lul_value_old=" .. tostring(lul_value_old) .. " lul_value_new=" .. tostring(lul_value_new))
	local zwave_dev_num = tonumber(lul_device)
	local peer_dev_num_str = luup.variable_get(SCObj.ServiceId,"PeerID",zwave_dev_num)
	local peer_dev_num = tonumber(peer_dev_num_str)
	local zwave_scene_str, scene_id_update_time = luup.variable_get(SID_SCTRL, "LastSceneID",zwave_dev_num)
	local zwave_scene = tonumber(zwave_scene_str)
	if not zwave_scene then
		zwave_scene = 0
	end
	local lastTime = SceneTimes[peer_dev_num]
	local lastScene = SceneIds[peer_dev_num]
	TempVariableUnwatch(SID_SCTRL, "LastSceneID", zwave_dev_num)
	luup.variable_set(SID_SCTRL, "LastSceneID", "", zwave_dev_num)
	if lastTime and lastTime >= scene_id_update_time then
		return;
	end
	SceneChange(peer_dev_num, zwave_scene, scene_id_update_time)
end

function SceneButtonPressed(peer_dev_num, activate, physicalButton)
	local act_deact
	local node_id, zwave_dev_num = GetZWaveNode(peer_dev_num)
	local currentScreen = GetCurrentScreen(peer_dev_num)
	local numLines, scrollOffset = GetNumLinesAndScrollOffset(peer_dev_num, currentScreen)
	if activate then
		act_deact = "sl_SceneActivated"
	else
		act_deact = "sl_SceneDeactivated"
	end
	local virtualButton = physicalButton + scrollOffset
	DLog("SceneButtonPressed: act_deact=" .. act_deact .. " activate=" .. tostring(activate) .. " physicalButton=" .. physicalButton .. " currentScreen=" .. currentScreen .. " numLines=" .. numLines ..
	        " scrollOffset=" .. scrollOffset .. " virtualButton=" .. virtualButton .. " node_id=" .. node_id .. " zwave_dev_num=" .. zwave_dev_num);
	-- Handle scroll up and scrolll down events if numLines > SCObj.NumButtons
	-- Using the ScrollUp and ScrollDown commands, labels, indicators, and button modes all scroll together but not associations.
	-- We also need to handle to top and bottom ^^^^ and vvvv scrolling indicators which always use momentary buttons.
	if numLines > SCObj.NumButtons and physicalButton == 1 and scrollOffset > 0 then
		local labels = {}
		local fonts = {}
		local aligns = {}
		scrollOffset = scrollOffset - 1;
	  	luup.variable_set(SCObj.ServiceId, "ScrollOffset_" .. currentScreen, tostring(scrollOffset), peer_dev_num)
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
		SetIndicatorValue(peer_dev_num, 0, false, 0)
		if scrollOffset == 0 then
			SetButtonMode(peer_dev_num, "M", currentScreen, false, false, 1)
		end
		SetButtonMode(peer_dev_num, "M", currentScreen, false, false, 2)
		for i = 3, SCObj.NumButtons-1 do
			local prevModeStr = GetModeStr(peer_dev_num, currentScreen, scrollOffset+i+1)
			local modeStr, state     = GetModeStr(peer_dev_num, currentScreen, scrollOffset+i)
			UpdateAssociationForPhysicalButton(zwave_dev_num, currentScreen, false, prevModeStr, modeStr, i, (scrollOffset+i)+(state-1)*1000)
		end
		local prevModeStr = GetModeStr(peer_dev_num, currentScreen, scrollOffset+SCObj.NumButtons)
		SetButtonMode(peer_dev_num, prevModeStr, currentScreen, false, false, SCObj.NumButtons)
		EVLCDWrapStrings({"\nvvvvvv"}, {"Inverted"}, {"Center"}, node_id, zwave_dev_num, SCObj.NumButtons, SCObj.NumButtons, SCREEN_MD.NoChange)
		SetIndicator(peer_dev_num, currentScreen, false, 0)
		luup.sleep(param.SCENE_CTRL_SwitchScreenDelay) -- Avoid a CAN when LCD1 sends the second scene activation message
		RunZWaveQueue("ScrollDown", 0);
		return
	elseif numLines > SCObj.NumButtons and physicalButton == SCObj.NumButtons and scrollOffset < numLines - SCObj.NumButtons then
		local labels = {}
		local fonts = {}
		local aligns = {}
		scrollOffset = scrollOffset + 1;
	  	luup.variable_set(SCObj.ServiceId, "ScrollOffset_" .. currentScreen, tostring(scrollOffset), peer_dev_num)
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
		SetIndicatorValue(peer_dev_num, 0, false, 0)
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
		SetIndicator(peer_dev_num, currentScreen, false, 0)
		luup.sleep(param.SCENE_CTRL_SwitchScreenDelay) -- Avoid a CAN when LCD1 sends the second scene activation message
		RunZWaveQueue("ScrollUp", 0);
		return
	end

	local modeStr = luup.variable_get(SCObj.ServiceId,"Mode_"..currentScreen.."_"..virtualButton, peer_dev_num)
	if modeStr == nil then
		modeStr = SCObj.DefaultModeString
	end
	DLog("SceneChange: modeStr="..tostring(modeStr))
	local mode = ParseModeString(modeStr)
	local state = 1
	if mode.prefix >= "2" and mode.prefix <= "9" then
		local states = tonumber(mode.prefix)
		state = luup.variable_get(SCObj.ServiceId,"State_"..currentScreen.."_"..virtualButton,peer_dev_num)
		if state == nil then
			state = "1"
		end
		state = tonumber(state)
		local oldLabels = {}
		local oldFonts = {}
		local oldAligns = {}
		ChooseLabelFontAndAlign(peer_dev_num, currentScreen, 1, virtualButton, state, oldLabels, oldFonts, oldAligns)
		state = state % states + 1
		luup.variable_set(SCObj.ServiceId,"State_"..currentScreen.."_"..virtualButton,tostring(state),peer_dev_num)
		modeStr = luup.variable_get(SCObj.ServiceId,"Mode_"..currentScreen.."_"..(virtualButton+(state-1)*1000), peer_dev_num)
		if modeStr == nil then
			modeStr = "M"
		end
		mode = ParseModeString(modeStr)
		local labels = {}
		local fonts = {}
		local aligns = {}
		ChooseLabelFontAndAlign(peer_dev_num, currentScreen, 1, virtualButton, state, labels, fonts, aligns)
		local nextState = state % states + 1
		local newModeStr = luup.variable_get(SCObj.ServiceId,"Mode_"..currentScreen.."_"..(virtualButton+(nextState-1)*1000), peer_dev_num)
		if newModeStr == nil then
			newModeStr = "M"
		end
		UpdateAssociationForPhysicalButton(zwave_dev_num, currentScreen, false, modeStr, newModeStr, physicalButton, virtualButton+(nextState-1)*1000)
		if oldLabels[1] ~= labels[1] or oldFonts[1] ~= fonts[1] or oldAligns[1] ~= aligns[1] then
			EVLCDWrapStrings(labels, fonts, aligns, node_id, zwave_dev_num, physicalButton, physicalButton, SCREEN_MD.NoChange)
		end
	end
	local oldIndicator_string = luup.variable_get(SCObj.ServiceId, CURRENT_INDICATOR, peer_dev_num)
	local oldIndicator = 0
	if oldIndicator_string then
		oldIndicator = tonumber(oldIndicator_string)
	end
	local newIndicator = oldIndicator
	if SCObj.ModeMap[mode.prefix] == SCObj.ModeMap["T"] then
		-- A toggle button was pushed. Change our local shadow of the indicator to reflect what the device already did
	  	if activate then
	    	newIndicator = bit.bor(oldIndicator,SCObj.PhysicalButtonToIndicator(physicalButton))
	  	else
	    	newIndicator = bit.band(oldIndicator,bit.bnot(SCObj.PhysicalButtonToIndicator(physicalButton)))
	  	end
	elseif SCObj.ModeMap[mode.prefix] == SCObj.ModeMap["M"] then
		newIndicator = bit.band(oldIndicator,bit.bnot(SCObj.PhysicalButtonToIndicator(physicalButton)))
		if not SCObj.HasButtonModes then
			-- For "Fake" Momentary buttons, force-reset the indicator
			SetIndicatorValue(peer_dev_num, newIndicator, true, 0);
		end
	end
	if newIndicator ~= oldIndicator then
  		luup.variable_set(RFWC5_SID, CURRENT_INDICATOR, tostring(newIndicator), peer_dev_num)
	end
	-- For direct or toggle direct, we set the status of the target device to whatever the controller
	-- has just sent.
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
	-- Set the indicator here in case any of the other buttons got affected by the changes that we made
	-- This will typically be a no-op.
	SetIndicator(peer_dev_num, currentScreen, false, 0)
	-- now calculate the scene ID on for normal Vera scene handling.
	local peer_scene = nil;
	if SCObj.HasMultipleScreens then
		local customScreen = currentScreen:match("C(%d)")
		if customScreen ~= nil then
			local buttonGroup = math.floor((virtualButton - 1) / SCObj.NumButtons)
			local buttonOffset = 0
			if buttonGroup > 0 then
			   buttonOffset = 200 + buttonGroup * 100
			end
			peer_scene = ((tonumber(customScreen) - 1) * SCObj.NumButtons) + ((virtualButton - 1) % SCObj.NumButtons) + 1 + (buttonOffset) + (state-1) * 1000
		else
			local presetScreen = currentScreen:match("P(%d)")
			if presetScreen ~= nil then
				peer_scene = 60 + ((tonumber(presetScreen) - 1) * SCObj.NumButtons) + physicalButton + (state-1) * 1000
			else
				local temperatureScreen = currentScreen:match("T(%d)")
				if temperatureScreen ~= nil then
					peer_scene = 30 + ((tonumber(temperatureScreen) - 1) * SCObj.NumButtons) + physicalButton + (state-1) * 1000
				end
			end
		end
	else
		peer_scene = physicalButton;
	end
	if peer_scene ~= nil then
    	if mode.prefix == "X" then -- Exclusive
			act_deact = "sl_SceneActivated"
		end
		if mode.prefix == "X" or mode.newScreen or (ZWaveQueueNodes > 0) then
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
		  	if mode.prefix  == "X" then
				-- Clear the other indicators in Exclusive mode.
				SetIndicator(peer_dev_num, currentScreen, false, 0)
			end
			SetScreenTimeout(peer_dev_num, currentScreen);
	    end
	else
		ELog("Invalid current screen: \""..currentScreen.."\"")
		-- dotimeout, not force, not indicatorOnly
		SetCustomScreen(peer_dev_num, 1, true, false, false)
	end
end

function IndicatorChanged(peer_dev_num, newIndicator_str)
	--local newIndicator = tonumber(newIndicator_str)
	local newIndicator = tonumber(newIndicator_str, 16)
	local oldindicator_string = luup.variable_get(SCObj.ServiceId, CURRENT_INDICATOR, peer_dev_num)
	local oldIndicator = tonumber(oldindicator_string)
	log("IIndicatorChanged: peer_dev_num="..tostring(peer_dev_num).." oldIndicator="..tostring(oldIndicator).." newIndicator="..tostring(newIndicator))
	luup.variable_set(SCObj.ServiceId, CURRENT_INDICATOR, tostring(newIndicator), peer_dev_num)
	for physicalButton = 0, SCObj.NumButtons do
		local b = SCObj.PhysicalButtonToIndicator(physicalButton);
		if bit.band(b, oldIndicator) ~= bit.band(b, newIndicator) then
			local acvtivate = bit.band(b, newIndicator) ~= 0
			SceneButtonPressed(peer_dev_num, activate, physicalButton)
		end
	end
	RunZWaveQueue("IndicatorChanged", 0)
end

function SceneChange(peer_dev_num, zwave_scene, cur_scene_time)
    DLog("SceneChange: peer_dev_num="..peer_dev_num.." zwave_scene="..zwave_scene.." cur_scene_time="..cur_scene_time)
	local act_deact
	local physicalButton
	local activate
	local node_id, zwave_dev_num = GetZWaveNode(peer_dev_num)
	if not cur_scene_time then
		cur_scene_time = 0
	end
	local currentScreen = GetCurrentScreen(peer_dev_num)
	local numLines, scrollOffset = GetNumLinesAndScrollOffset(peer_dev_num, currentScreen)
	if zwave_scene == 0 then
		-- We just got a BASIC_SET_OFF command and we are not sure which button was turned off.
	  	local indicator_string = luup.variable_get(SCObj.ServiceId, CURRENT_INDICATOR, peer_dev_num)
	  	local indicator = tonumber(indicator_string)
		for i = 0, SCObj.NumButtons do
			if indicator == SCObj.PhysicalButtonToIndicator(i) then
				activate = false
				physicalButton = i
				break
			end
		end
		if not physicalButton then
--[[42  11/13/16 22:29:56.816   0x1 0x9 0x0 0x4 0x0 0x7 0x3 0x87 0x3 0xb 0x79 (##########y)
           SOF - Start Of Frame â”€â”€â”˜   â”‚   â”‚   â”‚   â”‚   â”‚   â”‚    â”‚   â”‚   â”‚    â”‚
                     length = 9 â”€â”€â”€â”€â”€â”€â”˜   â”‚   â”‚   â”‚   â”‚   â”‚    â”‚   â”‚   â”‚    â”‚
                        Request â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜   â”‚   â”‚   â”‚   â”‚    â”‚   â”‚   â”‚    â”‚
FUNC_ID_APPLICATION_COMMAND_HANDLER â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜   â”‚   â”‚   â”‚    â”‚   â”‚   â”‚    â”‚
          Receive Status SINGLE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜   â”‚   â”‚    â”‚   â”‚   â”‚    â”‚
Device 10=Cooper RFWC5 Scene Controller Z-Wave â”€â”€â”€â”€â”€â”€â”€â”˜   â”‚    â”‚   â”‚   â”‚    â”‚
                Data length = 3 â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜    â”‚   â”‚   â”‚    â”‚
        COMMAND_CLASS_INDICATOR â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜   â”‚   â”‚    â”‚
               INDICATOR_REPORT â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜   â”‚    â”‚
                     Value = 11 â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜    â”‚
                    Checksum OK â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
]]
			EnqueueZWaveMessageWithResponse("GetIndicator()"..node_id, node_id, "0x87 0x02", 0,
--				"^0x1 0x%x+ 0x0 0x4 0x%x+ "..string.format("0x%x",node_id).." 0x%x+ 0x87 0x3 (0x%x+)",
				"^01 .. 00 04 .. "..string.format("%02x",node_id).." .. 87 03 (..)",
				IndicatorChanged, true, 2000)
			RunZWaveQueue("GetIndicator", 0)
			return
		end
	elseif zwave_scene > SCObj.LastFixedSceneId then
		local sceneIdCache = SceneIdCacheList[zwave_dev_num]
		if not sceneIdCache then
			sceneIdCache = {}
			ForAllModes(peer_dev_num, function(mode, screen, virtualButton)
				if mode.sceneId then
					sceneIdCache[mode.sceneId] = {screen=screen, button=virtualButton, act=true}
					if mode.offSceneId then
						sceneIdCache[mode.offSceneId] = {screen=screen, button=virtualButton+1000, act=false}
					end
				end
			end )
			SceneIdCacheList[zwave_dev_num] = sceneIdCache
		end
		local cacheEntry = sceneIdCache[zwave_scene]
		if not cacheEntry then
			ELog("SceneChange: Received unknown scene ID: "..tostring(zwave_scene).." peer_dev_num="..tostring(peer_dev_num).." cur_scene_time="..tostring(cur_scene_time))
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
	SceneButtonPressed(peer_dev_num, activate, physicalButton)
	RunZWaveQueue("SceneChange", 0);
end

-- Sanitize a string converting all non [a-zA-Z0-9_] characters to _
-- This May return a string beginning with a digit
function toidentifier(anything)
  return  string.gsub(tostring(anything),"[^%w_]","_")
end

function WatchedVarHandler(xfunction_name, ufunction_name, context, device, service, variable, value_old, value_new)
  VLog("WatchedVarHandler:" .. xfunction_name .. ": device=" .. device .. " service=" .. service .. " variable=" .. variable .. " value_old=" .. value_old .. " value_new=" .. value_new .. " context=" .. context)
  if WatchedVariables[xfunction_name] then
    if UnwatchedVariables[ufunction_name] then
	  local temp = UnwatchedVariables[ufunction_name] - 1
	  VLog("Skipping Unwatched variable: " .. ufunction_name .. ". Unwatch count now " .. UnwatchedVariables[ufunction_name])
	  if temp <= 0 then
	    temp = nil
	  end
	  UnwatchedVariables[ufunction_name] = temp
	  return false -- Temp unwatch
	end
    return true -- Normal case
  end
  VLog(xfunction_name .. " no longer being watched")
  return false -- Variable no longer watched
end

WatchedVariables = {}
UnwatchedVariables = {}
-- An extended version of luup.variable_watch which takes an extra context (string) parameter
-- function_name is passed  lul_device, lul_service, lul_variable, lul_value_old, lul_value_new, context
-- Returns an object which can be passed to CancelVariableWatch
function VariableWatch(function_name, service, variable, device, context)
  VLog("VariableWatch: function_name=" .. tostring(function_name) .. " service=" .. tostring(service) .. " variable=" .. tostring(variable) .. " device=" .. tostring(device) .. " context=" .. tostring(context))
  local xfunction_name = "VarWatch_" .. function_name .. toidentifier(context) .. "___" .. toidentifier(service) .. variable .. tostring(device)
  local ufunction_name = "VarUnwatch_" .. toidentifier(service) .. variable .. tostring(device)
  if WatchedVariables[xfunction_name] then
    -- Already being watched with the given context.
	WatchedVariables[xfunction_name] = WatchedVariables[xfunction_name] + 1
	return
  end
  WatchedVariables[xfunction_name] = 1;
  if WatchedVariables[ufunction_name] then
	WatchedVariables[ufunction_name] = WatchedVariables[ufunction_name] + 1
  else
	WatchedVariables[ufunction_name] = 1
  end
  local qContext = string.format('%q', context)
  local funcBody="function " .. xfunction_name .. "(device, service, variable, value_old, value_new)\n" ..
                 "  if WatchedVarHandler ('"..xfunction_name.."', '" .. ufunction_name .. "', '" .. qContext .. "', device, service, variable, value_old, value_new) then\n" ..
                 "    " .. function_name .. "(device, service, variable, value_old, value_new, " .. qContext .. ")\n" ..
			     "  end\n" ..
			     "end\n"
  assert(loadstring(funcBody))()
  luup.variable_watch(xfunction_name, service, variable, device)
  return xfunction_name;
end

-- Temporarily "unwatch" a variable which is expected to trigger
function TempVariableUnwatch(service, variable, device)
  VLog("TempVariableUnwatch: service=" .. tostring(service) .. " variable=" .. tostring(variable) .. " device=" .. tostring(device))
  local ufunction_name = "VarUnwatch_" .. toidentifier(service) .. variable .. tostring(device)
  local numWatched = WatchedVariables[ufunction_name]
  if numWatched then
	if UnwatchedVariables[ufunction_name] then
	  UnwatchedVariables[ufunction_name] = UnwatchedVariables[ufunction_name] + numWatched
	else
	  UnwatchedVariables[ufunction_name] = numWatched
	end
  end
end

function CancelVariableWatch(xfunction_name)
	VLog("CancelVariableWatch: xfunction_name=" .. tostring(xfunction_name))
	assert(WatchedVariables[xfunction_name] > 0)
	WatchedVariables[xfunction_name] = WatchedVariables[xfunction_name] - 1

	ufunction_name = "VarUnwatch_" .. xfunction_name:match("___(.*)$")
	assert(WatchedVariables[ufunction_name] > 0)
	WatchedVariables[ufunction_name] = WatchedVariables[ufunction_name] - 1
end

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
  if device.device_type == DEVTYPE_DIMMABLE then
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
  DLog("SetDeviceStatus: device_num=" .. tostring(device_num) .. " value=" .. tostring(value))
  local device = luup.devices[device_num]
  if not device then
	DLog("  SetDeviceStatus: Device not found");
    return
  end
  local service, variable
  if device.device_type == DEVTYPE_BINARY then
    service = SID_SWITCHPOWER
	variable = "Status"
	if value > 0 then
		value = "1"
	else
	    value = "0"
	end
  elseif device.device_type == DEVTYPE_DIMMABLE then
    service = SID_DIMMING
	variable = "LoadLevelStatus"
	value = tostring(value)
  else
	DLog("  SetDeviceStatus: "..tostring(device.device_type).." not one of "..tostring(DEVTYPE_BINARY).." or "..tostring(DEVTYPE_DIMMABLE));
    return
  end
  local oldValue = luup.variable_get(service, variable, device_num)
  DLog("  SetDeviceStatus: oldValue="..tostring(oldValue).."  value="..tostring(value))
  if oldValue ~= value then
    -- Temporarily unwatch the variable to avoid a loop which can cause problems if more than one device is attached to a button.
    TempVariableUnwatch(service, variable, device_num)
  	luup.variable_set(service, variable, tostring(value), device_num)
  end
end
