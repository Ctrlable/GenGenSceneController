// User interface for GenGeneric Scene Controller Version 1.05
// Copyright 2016-2017 Gustavo A Fernandez. All Rights Reserved

var SID_SCENECONTROLLER   = "urn:gengen_mcv-org:serviceId:SceneController1"

	// Evolve LCD1
var EVOLVELCD1 = {
	Id						: "EVOLVELCD1",
	Name                    : "Evolve LCD1",
	DefaultLcdVersion		: 39,
	HasScreen               : true,
	HasPresetLanguages      : true,
	HasThremostatControl    : true,
    NumButtons              : 5,
	MaxScroll	        	: 10,
    LastFixedSceneId        : 10,
	HasOffScenes            : true,
	HasCooperConfiguration  : false,
	MaxDirectAssociations   : 29, // 30 direct associations but 1 reserved for Vera.
	DefaultScreen           : "C1",
	DefaultModeString       : "M",
	DevType                 : "urn:schemas-gengen_mcv-org:device:SceneControllerEvolveLCD:1",
	ServiceId				: SID_SCENECONTROLLER,
	DviceXml                : "D_EvolveLCD1.xml",
	ImplementationXml       : "I_EvolveLCD1.xml",
	NumTemperaturScrens     : 3, // Preset Pages 8, 16, and 40
	ScreenTypes 			: [
		{ prefix: "C", name: "Custum",      num: 9 },
		{ prefix: "T", name: "Temperature", num: 9 },
		{ prefix: "P", name: "Preset",      num: 41 }
		// { prefix: "W", name: "Welcome",     num: 1 },
	],
	CustomModeList 			: [
		"M", "T", "3", "4", "5", "6", "7", "8", "9", "X", "N", "P", "E"
	],
	SceneBases              : {
		C: 1,	// Custom      screen scenes start at base 1
		T: 31,	// Temperature screen scenes start at base C + 5 buttons * 6 custom screens
		W: 61,	// Welcome     screen scenes start at base T + 5 buttons * (2 + 4) temperature screens
		P: 66	// Preset      screen scenes start at base W + 5 buttons * 1 welcome screen
	},
	// Returns true if the screen/version combination is supported at least in English
	ScreenIsCompatible		: function(SCObj, screenType, screenNum, version) {
		if (screenType == "C") {
			return true;
		}
		if (screenType == "T") {
			if (version >= 55) {
				return screenNum != 2; // Version 55 does not support temperature page 16
			}
			return screenNum != 3; // Older versions don't include temperature page 40
		}
		if (screenType != "P") {
			return false;
		}
		if (!SCObj.PresetScreens[screenNum]) {
			return false;
		}
		if (version <= 37) {
			return screenNum <= 18;
		}
		if (version <= 39) {
			return screenNum <= 26;
		}
		/* Version 55 */
		return screenNum == 1 || screenNum == 8 || screenNum == 10 || screenNum == 13 || screenNum == 17 || (screenNum >= 19 && screenNum <= 26) || screenNum >= 31;
	},
	// Return a list of languages supported for the screen type/number/version combination
	// indexed into SceneController_PresetLanguages
	LanguagesSupported      : function(screenType, screenNum, version) {
		if (screenType == "T" && screenNum > 3) {
			return [1];	// Custom termperature screens don't have a language.
		}
		if (screenType == "P" || screenType == "T") {
			if (version <= 37) {
				return [1, 2, 3, 4, 5, 6, 7];
			}
			if (version <= 39) {
				return [1];
			}
			/* Version 55 */
			if (screenType == "P" && screenNum >= 37 && screenNum <= 40) {
				return [1, 3];
			}
			if (screenType == "T" && screenNum == 3) {
				return [1, 3];
			}
			return [1];
		}
		return [1];
	},
    PresetScreens           : [
		  /* 0  */ null,
		  /* 1  */ ["All On","Low","All Off","Privacy Please","Service Room"],
		  /* 2  */ ["All On","Medium","Low","Night Light","All Off"],
		  /* 3  */ null,
		  /* 4  */ ["All On","Medium","Low","Mood","All Off"],
		  /* 5  */ ["All On","Medium","Low","Mood","All Off"],
		  /* 6  */ null,
		  /* 7  */ ["All On","Medium","Low","Night Light","All Off"],
		  /* 8  */ null,	/* Temperature */
		  /* 9  */ null,
		  /* 10 */ ["Drapery Open","Drapery Closed","Stop","Sheers Open","Sheers Closed"],
		  /* 11 */ ["Vanity","Shower","Night Light","All On","All Off"],
		  /* 12 */ ["Entry","Sconce","Bed Left","Bed Right","Good Night"],
		  /* 13 */ ["Vanity","Shower","Night Light","All On","All Off"],
		  /* 14 */ ["Entry","Kitchen","LivingRoom","BedRoom","MasterOff"],
		  /* 15 */ ["Welcome","Overhead","Bedroom","Privacy","All Off"],
		  /* 16 */ null, /* Temperature */
		  /* 17 */ null, /* Custom */
		  /* 18 */ ["Morning","Day","Evening","Night","Sleep"],
		  /* 19 */ ["All On","Living Room","Bed Room","Bath Room","All Off"],
		  /* 20 */ ["All On","Living Room","Bed Room","Low","All Off"],
		  /* 21 */ ["All On","Mood","All Off","Privacy Please","Service Room"],
		  /* 22 */ ["On/Off","Mood","Drapery","Reading","Night Light"],
		  /* 23 */ ["LR On/Off","LR Mood","BR On/Off","BR Mood","Drapery"],
		  /* 24 */ ["BO On/Off","BR Mood","LR On/Off","LR Mood","Drapery"],
		  /* 25 */ ["All On","All Off","Entry","Low","Mood"],
		  /* 26 */ ["All On","TurnDown","All Off","Service Please","Privacy Please"],
		  /* 27 */ null,
		  /* 28 */ null,
		  /* 29 */ null,
		  /* 30 */ null,
		  /* 31 */ ["All On","Entry","Bedside","Low","All Off"],
		  /* 32 */ ["Lighting","Drapery","Climate","Privacy Please","Service Room"],
		  /* 33 */ ["Lighting","Climate","Shades","Service Room","Privacy Please"],
		  /* 34 */ ["Lighting","Climate","Drapery","Master On","Master Off"],
		  /* 35 */ ["Lighting","Climate","Drapery","Bath On","Bath Off"],
		  /* 36 */ ["Lighting","Climate","Shading","Master On","Master Off"],
		  /* 37 */ ["All On","All Off","Privacy Please","Service Room","Language"],
		  /* 38 */ ["All On","Vanity","Toilet","Shower","All Off"],
		  /* 39 */ ["Sheers Open","Sheers Closed","Stop","Shade Open","Shade Closed"],
		  /* 40 */ null, /* temperature */
		  /* 41 */ ["Lighting","Climate","","All On","All Off"]
	]
};

// Cooper RFWC5-Specific
var COOPERRFWC5 = {
	Id						: "COOPERRFWC5",
	Name                    : "Cooper RFWC5",
	DefaultLcdVersion       : 1,
	HasScreen               : false,
	HasPresetLanguages      : false,
	HasThremostatControl    : false,
    NumButtons              : 5,
	MaxScroll               : 5,
    LastFixedSceneId        : 5,
	HasOffScenes            : false,
	HasCooperConfiguration  : true,
	MaxDirectAssociations   : 4, // 5 direct associations but 1 reserved for Vera.
	DefaultScreen           : "P1",
	DefaultModeString       : "T",
	DevType                 : "urn:schemas-gengen_mcv-org:device:SceneControllerCooperRFWC5:1",
	ServiceId               : SID_SCENECONTROLLER,
	DviceXml                : "D_CooperRFWC5.xml",
	ImplementationXml       : "I_CooperRFWC5.xml",
	NumTemperaturScrens     : 0,
	ScreenTypes 			: [
		{ prefix: "P", name: "Preset",      num: 1 }
	],
	CustomModeList 			: [
		"T", "M", "3", "4", "5", "6", "7", "8", "9"
	],
	SceneBases              : {
		P: 1	// Preset screen scenes start at base 1
	},
	// Returns true if the screen/version combination is supported at least in English
	ScreenIsCompatible		: function(SCObj, screenType, screenNum, version) {
		return screenType == "P";
	},
	// Return a list of languages supported for the screen type/number/version combination
	// indexed into SceneController_PresetLanguages
	LanguagesSupported      : function(screenType, screenNum, version) {
		return [1];
	},
    PresetScreens           : [
		  /* 0  */ null,
		  /* 1  */ ["Button 1","Button 2","Button 3","Button 4","Button 5"]
	]
};

// Nexia One-Touch-Specific
var NEXIAONETOUCH = {
	Id						: "NEXIAONETOUCH",
	Name                    : "Nexia One Touch",
	DefaultLcdVersion       : 1,
	HasScreen               : true,
	HasPresetLanguages      : false,
	HasThremostatControl    : true,
    NumButtons              : 15,
	MaxScroll               : 15,
    LastFixedSceneId        : 46,
	HasOffScenes            : false,
	HasCooperConfiguration  : false,
	MaxDirectAssociations   : 2, // 2 direct associations. Vera uses the Lifeline/Central Scene
	DefaultScreen           : "C1",
	DefaultModeString       : "M",
	DevType                 : "urn:schemas-gengen_mcv-org:device:SceneControllerNexiaOneTouch:1",
    ServiceId               : SID_SCENECONTROLLER,
	DviceXml                : "D_NexiaOneTouch.xml",
	ImplementationXml       : "I_NexiaOneTouch.xml",
	NumTemperaturScrens     : 0,
	ScreenTypes 			: [
		{ prefix: "C", name: "Custum",      num: 3 }
	],
	CustomModeList 			: [
		"M", "2", "3", "4", "5", "6", "7", "8", "9"
	],
	SceneBases              : {
		C: 1	// Custom screen scenes start at base 1
	},
	// Returns true if the screen/version combination is supported at least in English
	ScreenIsCompatible		: function(SCObj, screenType, screenNum, version) {
		return screenType == "C";
	},
	// Return a list of languages supported for the screen type/number/version combination
	// indexed into SceneController_PresetLanguages
	LanguagesSupported      : function(screenType, screenNum, version) {
		return [1];
	},
    PresetScreens           : [ ]
};


var ZWDEVICE_SID        = "urn:micasaverde-com:serviceId:ZWaveDevice1";
var PEER_ID             = "PeerID";
var CURRENT_SCREEN      = "CurrentScreen";
var SHOW_SINGLE_DEVICE  = "ShowSingleDevice";
var VERSION_INFO        = "VersionInfo";
var PRESET_LANGUAGE     = "PresetLanguage";
var NUM_LINES		    = "NumLines";
var CAPABILITIES        = "Capabilities";
var EVLCD_DefaultName   = "Evolve LCD Controller";

var SceneController_Select_Tab = 0;
var SceneController_Scenes_Tab = 1;
var SceneController_Copy_Tab = 2;

var SceneController_UI7;
var SceneController_Placeholder = 0;

// return true for UI7, false for UI5 or UI6
function SceneController_IsUI7() {
    if (SceneController_UI7 === undefined) {
        SceneController_UI7 = ( "application" in window)	&&
		                 typeof(application) == "object" &&
						 ( "api" in window) &&
						 typeof(api) == "object" &&
		                 typeof(api.cloneObject) == "function";
	}
	return SceneController_UI7;
}

function SceneController_get_device_state(deviceId, service, variable, dynamic) {
	if (SceneController_IsUI7()) {
		return api.getDeviceState(deviceId, service, variable, {dynamic: dynamic});
	} else {
		return get_device_state(deviceId, service, variable, dynamic);
	}
}

function SceneController_get_device_object(deviceID) {
	return SceneController_IsUI7() ? api.getDeviceObject(deviceID) : jsonp.ud.devices[jsonp.udIndex.devices["_"+deviceID]];
}

function SceneController_set_panel_html(html) {
	if (SceneController_IsUI7()) {
		api.setCpanelContent(html);
	} else {
		set_panel_html(html);
	}
}

// Below is mostly the guts of setUserDataDeviceStateModifyUserData in 1.7.148
// except that we don't call sendCommandSaveUserData.
function SceneController_setUserDataDeviceStateModifyUserData_NoReload(deviceId, service, variable, value) {
    try {
        var deviceObject = application.getDeviceById(deviceId);
        if (typeof(deviceObject) == 'undefined') {
            return false;
        }

        var statesNo;
        var stateObj;
        if (typeof(deviceObject.states) != 'undefined') {
            statesNo = deviceObject.states.length;
            for (i = 0; i < statesNo; i+=1) {
                stateObj = deviceObject.states[i];
                if (typeof(stateObj) != 'undefined' && stateObj.service == service && stateObj.variable == variable) {
                    stateObj.value = value;
                    return true;
                }
            }
        }

        if (typeof(deviceObject.states) == 'undefined') {
            deviceObject.states = [];
        }

        var newState = deviceObject.states.length;
        var maxID = 0;
        if (newState > 0) {
            for (i = 0; i < newState; i+=1) {
                maxID = (deviceObject.states[i].id > maxID) ? deviceObject.states[i].id : maxID;
            }
        }

        deviceObject.states[newState] = {};
        deviceObject.states[newState].service = service;
        deviceObject.states[newState].variable = variable;
        deviceObject.states[newState].value = value;
        deviceObject.states[newState].id = (maxID + 1);
    } catch (e) {
        Utils.logError("Error in SceneController_setUserDataDeviceStateModifyUserData_NoReload: " + e + " " + e.stack);
    }

    return false;
}

function SceneController_set_device_state(deviceId, service, variable, value) {
	if (SceneController_IsUI7()) {
		api.setDeviceState(deviceId, service, variable, value, {dynamic:true});
		api.setDeviceState(deviceId, service, variable, value, {dynamic:false});
	} else {
		set_device_state(deviceId, service, variable, value, false);
	}
}

function SceneController_IsZWaveChild(deviceId) {
	if ("is_zwave_child" in window) { // UI5, UI6
		return is_zwave_child(deviceId);
	} else if ("isZWaveChild" in api) { // ui7
		return api.isZWaveChild(deviceId);
	} else { // Alternate UI
        var device = api.getDeviceObject(deviceId);
        if (typeof device == "object" && device.id_parent > 0)	{
			var parent = api.getDeviceObject(device.id_parent);
			return typeof parent == "object" && parent.device_type == "urn:schemas-micasaverde-com:device:ZWaveNetwork:1";
		}
		return false;
	}
}

function SceneController_PassthrougZWaveDevice(SCObj, deviceId, functionName) {
	var id = deviceId;
	if(!SceneController_IsZWaveChild(deviceId)) {
	    var peerId=parseInt(SceneController_get_device_state(deviceId, SCObj.ServiceId,PEER_ID, 0));
	    var ShowSingleDevice = SceneController_get_device_state(peerId, SCObj.ServiceId,SHOW_SINGLE_DEVICE, 0);
		if (ShowSingleDevice != "0") {
			id = peerId;
		}
	}
	if (functionName in window && typeof(window[functionName]) == "function") { // UI5, UI6
		window[functionName](id);
	} else { // UI7
		myInterface[functionName](id);
	}
}

// Screens page
function EvolveLCD1_Screens(deviceId) {
	SceneController_Screens(EVOLVELCD1, deviceId)
}
function CooperRFWC5_Screens(deviceId) {
	SceneController_Screens(COOPERRFWC5, deviceId)
}
function NexiaOneTouch_Screens(deviceId) {
	SceneController_Screens(NEXIAONETOUCH, deviceId)
}

// Simple device page pass-through
function EvolveLCD1_simple_device(deviceId) {
	SceneController_PassthrougZWaveDevice(EVOLVELCD1, deviceId, "simple_device");
}
function CooperRFWC5_simple_device(deviceId) {
	SceneController_PassthrougZWaveDevice(COOPERRFWC5, deviceId, "simple_device");
}
function NexiaOneTouch_simple_device(deviceId) {
	SceneController_PassthrougZWaveDevice(NEXIAONETOUCH, deviceId, "simple_device");
}

// Advanced device page pass-through
function EvolveLCD1_advanced_device(deviceId) {
	SceneController_PassthrougZWaveDevice(EVOLVELCD1, deviceId, "advanced_device");
}
function CooperRFWC5_advanced_device(deviceId) {
	SceneController_PassthrougZWaveDevice(COOPERRFWC5, deviceId, "advanced_device");
}
function NexiaOneTouch_advanced_device(deviceId) {
	SceneController_PassthrougZWaveDevice(NEXIAONETOUCH, deviceId, "advanced_device");
}

// Z-Wave Options page pass-through
function EvolveLCD1_device_zwave_options(deviceId) {
	SceneController_PassthrougZWaveDevice(EVOLVELCD1, deviceId, "device_zwave_options");
}
function CooperRFWC5_device_zwave_options(deviceId) {
	SceneController_PassthrougZWaveDevice(COOPERRFWC5, deviceId, "device_zwave_options");
}
function NexiaOneTouch_device_zwave_options(deviceId) {
	SceneController_PassthrougZWaveDevice(NEXIAONETOUCH, deviceId, "device_zwave_options");
}

// Send an action to the Lua engine
function SceneController_send_action(deviceID,serviceID,action,parameters) {
	if (SceneController_IsUI7()) {
		// why doesn't api.performActionOnDevice automatically escape the parameters?
		var encParams = {};
                var kp = Object.keys(parameters);
                var i;
                var kpl = kp.length;
		for (i = 0; i < kpl; i+=1) {
			encParams[kp[i]] = encodeURIComponent(parameters[kp[i]]);
		}
		api.performActionOnDevice(deviceID, serviceID, action, {actionArguments: encParams});
	} else {
		var baseUrl = data_command_url
	               + (data_command_url.indexOf('/data_request?') > 0 ? '' : '/data_request?');
	               // ui6 data_command_url ends in '/data_request?', ui5 does not.
	    var cmdUrl = baseUrl
	               + 'id=lu_action'
	               + '&DeviceNum='+deviceID
	               + '&serviceId='+serviceID
	               + '&action='+action;
                var param;
		for (param in parameters) {
			cmdUrl += '&' + param + '=' + encodeURIComponent(parameters[param]);
		}
		//console.log("cmdUrl="+cmdUrl);
	    new Ajax.Request(cmdUrl,
	    {
	        method:'get',
	        onSuccess: function(transport){
	            if(transport.responseText.trim() =='' || transport.responseText.indexOf('Error 404')>=0 || transport.responseText.indexOf('ERROR:')>=0) {
					console.log("Scene Controller AJAX error 2: '"+transport.responseText+"' url="+cmdUrl);
	                //show_message("Command failed: '"+transport.responseText+"'",ERROR);
	            }
	        },
	        onFailure: function(transport){
	            if(transport.responseText.indexOf('ERROR:')>=0){
					console.log("Scene Controller AJAX error 2: '"+transport.responseText+"' url="+cmdUrl);
	                //show_message("Command failed: '"+transport.responseText+"'",ERROR);
	            }else{
					console.log("Scene Contoller AJAX error 3: '"+transport.responseText+"' url="+cmdUrl);
	                //show_message("Delivery failed: '"+transport.responseText+"'",ERROR);
	            }
	        }
	    });
	}
}

SceneController_Modes = {
	M:"Momentary",
	D:"Momentary direct",
	T:"Toggle",
	"2":"Two-state",
	"3":"Three-state",
	"4":"Four-state",
	"5":"Five-state",
	"6":"Six-state",
	"7":"Seven-state",
	"8":"Eight-state",
	"9":"Nine-state",
	P:"Mode",
	E:"Energy Mode",
	S:"Toggle Direct",  // Obsolete
	X:"Exclusive",
	N:"Switch Screen",
	H:"Temperature",
	W:"Welcome"
};

SceneController_CustomFontList = [
	"Normal",
	"Compressed",
	"Inverted"
];

SceneController_CustomAlignList = [
	"Left",
	"Center",
	"Right"
];

SceneController_PresetLanguages = [
  /* 0 */ null,
  /* 1 */ "English",
  /* 2 */ "Spanish",
  /* 3 */ "Chinese",
  /* 4 */ "German",
  /* 5 */ "French",
  /* 6 */ "Italian",
  /* 7 */ "Punjabi"
];

SceneController_LanguageMaxPresetScreens = [
  /* 0 */ null,
  /* 1 - English */ 26,
  /* 2 - Spanish */  8,
  /* 3 - Chinese */ 10,
  /* 4 - German  */  8,
  /* 5 - French  */  8,
  /* 6 - Italian */  8,
  /* 7 - Punjabi */  8
];

SceneController_TemperatureScreens = [
  /* Temperature 1 - Page 8  */ ["All On", "\u25B2", "72\u00B0", "\u25BC", "All Off"],
  /* Temperature 2 - Page 16 */ ["Lights", "\u25B2", "72\u00B0", "\u25BC", "Privacy"],
  /* Temperature 3 - Page 40 */ ["All On/Off", "\u25B2", "72\u00B0", "\u25BC", "Reading"]
];

function SceneController_GetPresetLanguage(SCObj, peerId) {
	if (!SCObj.HasPresetLanguages) {
		return 1;
	}
	var presetLanguage = SceneController_get_device_state(peerId, SCObj.ServiceId, PRESET_LANGUAGE, 0);
	if (!presetLanguage) {
		presetLanguage = "1";	// English
	}
	return parseInt(presetLanguage);
}

function SceneController_SetPresetLanguage(SCObj, peerId) {
	if (!SCObj.HasPresetLanguages) {
		return;
	}
	var presetLanguage=document.getElementById("PresetLanguage_"+peerId).value;
	SceneController_send_action(peerId,SID_SCENECONTROLLER,"SetPresetLanguage",{Language:presetLanguage});
	SceneController_set_device_state(peerId, SCObj.ServiceId, PRESET_LANGUAGE,presetLanguage);
}


// Called after the user selects an item from the screens pop-up menu
function SceneController_SetScreen(SCObj, peerId) {
	if (!SCObj.HasScreen) {
		return;
	}
	var curScreen=document.getElementById("CurScreen_"+peerId).value;
	if (!curScreen || typeof curScreen != "string") {
		curScreen = SCObj.DefaultScreen;
	}
	var screenType = curScreen.charAt(0);
	var screenNum = curScreen.slice(1);
	if (SCObj.HasPresetLanguages && (screenType == "P" || screenType == "T")) {
		presetLanguage = SceneController_GetPresetLanguage(SCObj, peerId);
		if (presetLanguage > SceneController_LanguageMaxPresetScreens[screenNum]) {
			presetLanguage = 1;
			SceneController_send_action(peerId,SID_SCENECONTROLLER,"SetPresetLanguage",{Language:presetLanguage});
			SceneController_set_device_state(peerId, SCObj.ServiceId, PRESET_LANGUAGE,presetLanguage);
		}
	}
	SceneController_send_action(peerId,SID_SCENECONTROLLER,"SetScreen", {Screen:curScreen, Timeout:"false", ForceClear:"false"});
	SceneController_set_device_state(peerId, SCObj.ServiceId, CURRENT_SCREEN, curScreen);
	SceneController_Screens(SCObj, peerId);
}

// Called after the user has edited a single label
function SceneController_ChangeCustomLabel(SCObj, peerId, screen, labelIndex)
{
	var text;
        var font;
        var align;
	if (SCObj.HasScreen) {
		text  = document.getElementById( "Text_"+peerId+"_"+screen+"_"+labelIndex);
		font  = document.getElementById( "Font_"+peerId+"_"+screen+"_"+labelIndex);
		align = document.getElementById("Align_"+peerId+"_"+screen+"_"+labelIndex);
	    text = text   ? text.value  : "";
		font = font   ? font.value  : "Normal";
		align = align ? align.value : "Center";
	}
	var modePrefixObj  = document.getElementById( "Mode_"+peerId+"_"+screen+"_"+labelIndex);
	var modePrefix = modePrefixObj &&  modePrefixObj.value && typeof  modePrefixObj.value == "string" ? modePrefixObj.value   : SCObj.DefaultModeString;
	var oldModeStr  = SceneController_get_device_state(peerId, SCObj.ServiceId, "Mode_"+screen+"_"+labelIndex, 0);
	oldModeStr = oldModeStr ? oldModeStr : SCObj.DefaultModeString;
	var mode = SceneController_ParseModeString(SCObj, oldModeStr);
	if (modePrefix == "N") {
		var switchObj = document.getElementById("SwitchScreen_"+peerId+"_"+screen+"_"+labelIndex);
		mode.newScreen = (switchObj ? switchObj.value : (screen == SCObj.DefaultScreen ? "C2" : SCObj.DefaultScreen));
		mode.prefix = "M";
	} else {
		mode.newScreen=null;
		mode.prefix = modePrefix;
	}
	var newModeStr=SceneController_GenerateModeString(SCObj, mode);
	if (SCObj.HasScreen) {
		console.log("SceneController_ChangeCustomLabel: text="+text+" font="+font+" align="+align+" nmode="+newModeStr);
		SceneController_send_action(peerId,SID_SCENECONTROLLER,"UpdateCustomLabel",{Screen:screen,Button:labelIndex,Label:text,Font:font,Align:align,Mode:newModeStr});
		SceneController_set_device_state(peerId, SCObj.ServiceId, "Label_"+screen+"_"+labelIndex, text);
		SceneController_set_device_state(peerId, SCObj.ServiceId, "Font_"+screen+"_"+labelIndex, font);
		SceneController_set_device_state(peerId, SCObj.ServiceId, "Align_"+screen+"_"+labelIndex, align);
	} else {
		console.log("SceneController_ChangeCustomLabel: mode="+newModeStr);
		SceneController_send_action(peerId,SID_SCENECONTROLLER,"UpdateCustomLabel",{Screen:screen,Button:labelIndex,Mode:newModeStr});
	}
	SceneController_set_device_state(peerId, SCObj.ServiceId,  "Mode_"+screen+"_"+labelIndex, newModeStr);
}

function SceneController_ChangeCustomMode(SCObj, peerId, screen, labelIndex)
{
    console.log("SceneController_ChangeCustomMode: peerId="+peerId+" screen="+screen+" labelIndex="+labelIndex);
	SceneController_ChangeCustomLabel(SCObj, peerId, screen, labelIndex);
	SceneController_Screens(SCObj, peerId);
}

function SceneController_ChangeCustomFont(SCObj, peerId, screen, labelIndex)
{
    console.log("SceneController_ChangeCustomFont: peerId="+peerId+" screen="+screen+" labelIndex="+labelIndex);
	SceneController_ChangeCustomLabel(SCObj, peerId, screen, labelIndex);
	SceneController_Screens(SCObj, peerId);
}

function SceneController_ChangeCustomAlign(SCObj, peerId, screen, labelIndex)
{
    console.log("SceneController_ChangeCustomAlign: peerId="+peerId+" screen="+screen+" labelIndex="+labelIndex);
	SceneController_ChangeCustomLabel(SCObj, peerId, screen, labelIndex);
	SceneController_Screens(SCObj, peerId);
}

function SceneController_SetPlaceholder(SCObj, peerId, button)
{
	SceneController_Placeholder = button;
	SceneController_Screens(SCObj, peerId);
}

function SceneController_GetDevice(id)
{
	var i
	for (i = 0; i < jsonp.ud.devices.length; ++i) {
		if (jsonp.ud.devices[i].id == id) {
			return jsonp.ud.devices[i];
		}
	}
	return null
}

// Mode strings consist or Prefix {newScreen:+}? {(S|C{SceneId@}?{offSceneId@}?)}? {entry}+
// Prefix is M for momentary, T for Toggle, etc.
// newScreen is a letter/digit such as C3 for Custom 3 or P4 for Preset 4
// The S or C flags indicates that all subsequent associated devices are scene capable
//   and is optinally followed by a sceneId @ which is optional followed by an offSceneId @
// The C flag indicates to use Cooper configuration for non-secene capable devices
// Scene-capable modes are a ; separated list of 0 or more deviceNum,level,dimmingDuration triplets
// Cooper condiguration modes are a ; separate list of 0 or more deviceNum,level pairs
// Non-scene capabile modes are a ; separated list of 0 or more deviceNums
function SceneController_ParseModeString(SCObj, str) {
	var mode = [];
	var reResult;
	if (!str) {
		mode.prefix = SCObj.DefaultModeString;
	} else {
		mode.prefix = str.charAt(0);
		str = str.slice(1);
		var matchArray = str.match(/([A-Z][0-9]):+(.*)$/)  // :+ to deal with an old bug
		if (matchArray) {
			mode.newScreen = matchArray[1];
			str = matchArray[2];
		} else if (mode.prefix == "N") {
			// Legacy switch screen.
			mode.newScreen = str;
			return mode;
		}
		if (str.charAt(0) == "S" || str.charAt(0) == "C") {
			mode.sceneControllable = true;
			if ((reResult = /^.(\d+)@(\d+)@(.*)$/.exec(str)) != null) {
				mode.sceneId = parseInt(reResult[1]);
		 		mode.offSceneId = parseInt(reResult[2]);
				str = reResult[3];
			} else if ((reResult = /^.(\d+)@(.*)$/.exec(str)) != null) {
				mode.sceneId = parseInt(reResult[1]);
				str = reResult[2];
			}
		}
		if (!/;$/.exec(str)) {
			str += ";"
		}
		var re = /(\d+)(?:,(\d+)(?:,(\d+))?)?,?;/g
		while ((reResult = re.exec(str))) {
			var device = parseInt(reResult[1])
			if (SceneController_GetDevice(device)) {
				var level = reResult[2] ? parseInt(reResult[2]) : null; 
				var dimmingDuration = reResult[3] ? parseInt(reResult[3]) : null; 
				mode.push({device: device,
			           	   level: level,
			           	   dimmingDuration: dimmingDuration})
			}
		}
	}
	return mode;
}

function SceneController_GenerateModeString(SCObj, mode) {
	if (!mode) {
		mode = [];
	}
	if (!mode.prefix) {
		mode.prefix = SCObj.DefaultModeString;
	}
	var str=mode.prefix;
	if (mode.newScreen) {
		str += mode.newScreen + ":"
	}
	if (mode.sceneControllable) {
		str += "S";
		if (mode.sceneId) {
			str += mode.sceneId + "@"
			if (mode.offSceneId) {
				str += mode.offSceneId + "@"
			}
		}
	}
	var first = true;
	for (var i = 0; i < mode.length; ++i) {
		if (mode[i] && mode[i].device) {
			if (!first) {
				str += ";"
			}
			if (mode[i].dimmingDuration || mode[i].dimmingDuration == 0) {
				str += mode[i].device + "," + mode[i].level + "," + mode[i].dimmingDuration
			} else if (mode[i].level || mode[i].level == 0) {
				str += mode[i].device + "," + mode[i].level
			} else {
				str += mode[i].device
			}
			first = false;
		}
	}
	return str;
}

/* ItemChanged: 1=Device Menu, 2=Level Checkbox, 3=Level Input, 4=DimmingDuration Checkbox, 5=DimmingDuration Input */
function SceneController_SelectDirectDevice(SCObj, prefix, peerId, screen, labelIndex, associationNum, itemChanged) {
	var modeStr  = SceneController_get_device_state(peerId, SCObj.ServiceId, "Mode_"+screen+"_"+labelIndex, 0);
	if (!modeStr || typeof modeStr != "string") {
		modeStr = prefix;
	}

	var mode = SceneController_ParseModeString(SCObj, modeStr);
	var assocDevice = document.getElementById('SmartToggle_'+peerId+'_'+screen+'_'+labelIndex+'_'+associationNum).value;
    console.log("SceneController_SelectDirectDevice: peerId="+peerId+" screen="+screen+" associationNum="+associationNum+" assocDevice="+assocDevice);
	if (!assocDevice) {
		assocDevice = "0";
	}

	// If we are changing the first device in the list, it may switch from a scene-capable to a none-scene capable
	// device (or no device) or vice versa. This affects the treatment of the remaining devices on the list.
	if (SCObj.HasCooperConfiguration) {
		mode.sceneControllable = true
	} else if (associationNum == 0) {
		var oldsceneControllable = mode.sceneControllable;
		var affectStart = 1;
		var masterDevice = Number(assocDevice);
		if (assocDevice == "0" && mode.length > 1) {
			masterDevice = mode[1].device;
			affectStart = 2;
		}
		if (masterDevice) {
			var masterObj = SceneController_get_device_object(masterDevice);
			mode.sceneControllable = SceneController_GetDeviceProperties(masterObj).scene;
		}
		else {
			mode.sceneControllable = true;
		}

		if (oldsceneControllable && !mode.sceneControllable) {
			var numAffected = 0;
			var lastName = ""
			for (var i = affectStart; i < mode.length; ++i) {
				if (mode[i] && ((mode[i].level != undefined && mode[i].level != 255) || (mode[i].dimmingDuration != undefined && mode[i].dimmingDuration != 255))) {
					++numAffected;
					var obj = SceneController_get_device_object(mode[i].device);
					lastName = obj.name;
				}
			}
			if (numAffected > 0) {
				var levelAnd = SCObj.HasCooperConfiguration ? "" : " level and"
				if (!confirm("You are changing the first device in a direct association list to a non-scene capable device. Are you sure you want to lose all" + levelAnd + " dimming duration settings,"
			                                + " including the " + lastName + "?")) {
					SceneController_Screens(SCObj, peerId);
					return;
				}
			}
		} else if (!oldsceneControllable && mode.sceneControllable) {
			// If we switched from non-scene capable to scene-capable, then remove all non-scene-capable devices.
			var numDelete = 0;
			var lastName = ""
			for (var i = affectStart; i < mode.length; ++i) {
				if (mode[i]) {
					var obj = SceneController_get_device_object(mode[i].device);
					if (SceneController_GetDeviceProperties(obj).basicSetOnly) {
						numDelete++;
						lastName = obj.name;
					}
				}
			}

			if (numDelete > 0 && !confirm("You are changing the first device in a direct association list to a scene capable device. Are you sure you want to remove all non-scene capable devices from the list,"
			                              + " including the "+lastName+"?")){
				SceneController_Screens(SCObj, peerId);
				return;
			}

			for (var i = 0; i < mode.length; ++i) {
				if (mode[i]) {
					var obj = SceneController_get_device_object(mode[i].device);
					if (SceneController_GetDeviceProperties(obj).basicSetOnly) {
						mode[i] = null;
					}
				}
			}
		}
	}

	var level = 255
	if (itemChanged == 2) { // Level Checkbox toggled.
		var levelCheckbox = document.getElementById('LevelSelect_'+peerId+'_'+screen+'_'+labelIndex+'_'+associationNum);
		if (levelCheckbox) {
			var levelSelected = levelCheckbox.checked;
			if 	(levelSelected) {
				level = 99;
			}
		}
	}
	else {
		var levelObject = document.getElementById('Level_'+peerId+'_'+screen+'_'+labelIndex+'_'+associationNum);
		if (levelObject) {
			var levelValue = levelObject.value;
			if (levelValue == "") {
				level = 255;
			} else {
				var num = Number(levelValue);
				if (num == NaN || num < 0 || num > 99 || num != Math.floor(num)) {
					window.alert("Level must be a number between 0 and 99");
					if (mode[associationNum] && mode[associationNum].level) {
						level = mode[associationNum].level;
					}
				}
				else {
					level = num;
				}
			}
		}
	}

	var dimmingDuration = 255
	if (itemChanged == 4) { // Dimming duration Checkbox toggled.
		var dimmingCheckbox = document.getElementById('DimmingDurationSelect_'+peerId+'_'+screen+'_'+labelIndex+'_'+associationNum);
		if (dimmingCheckbox) {
			var dimmingSelected = dimmingCheckbox.checked;
			if 	(dimmingSelected) {
				dimmingDuration = 0;
			}
		}
	}
	else {
		var dimmingObject = document.getElementById('DimmingDuration_'+peerId+'_'+screen+'_'+labelIndex+'_'+associationNum);
		if (dimmingObject) {
			var dimmingValue = dimmingObject.value;
			if (dimmingValue == "") {
				dimmingDuration = 255;
			} else {
				var num = Number(dimmingValue);
				if (num == NaN || num < 0 || num > 254 || num != Math.floor(num)) {
					window.alert("Dimming duration must be a number between 0 and 254");
					if (mode[associationNum] && mode[associationNum].dimmingDuration) {
						dimmingDuration = mode[associationNum].dimmingDuration;
					}
				}
				else {
					dimmingDuration = num;
				}
			}
		}
	}

	if (!mode.sceneControllable) {
		dimmingDuration = null;
		if (!SCObj.HasCooperConfiguration) {
			level = null;
		}
	}
	assocDevice = parseInt(assocDevice)
	var props = SceneController_GetDeviceProperties(SceneController_get_device_object(assocDevice))
	if (props && !props.scene) {
		dimmingDuration = null;
	}
	
	mode[parseInt(associationNum)] = {device: assocDevice, level:level, dimmingDuration:dimmingDuration};
	modeStr = SceneController_GenerateModeString(SCObj, mode);

	if (SCObj.HasScreen) {
		var text  = document.getElementById( "Text_"+peerId+"_"+screen+"_"+labelIndex);
		var font  = document.getElementById( "Font_"+peerId+"_"+screen+"_"+labelIndex);
		var align = document.getElementById("Align_"+peerId+"_"+screen+"_"+labelIndex);
	    text = text   ? text.value  : "";
		font = font   ? font.value  : "Normal";
		align = align ? align.value : "Center";
		SceneController_send_action(peerId,SID_SCENECONTROLLER,"UpdateCustomLabel",{Screen:screen,Button:labelIndex,Label:text,Font:font,Align:align,Mode:modeStr});
	} else {
		SceneController_send_action(peerId,SID_SCENECONTROLLER,"UpdateCustomLabel",{Screen:screen,Button:labelIndex,Mode:modeStr});
	}
	SceneController_set_device_state(peerId, SCObj.ServiceId,  "Mode_"+screen+"_"+labelIndex, modeStr);
	SceneController_Screens(SCObj, peerId);
}

function SceneController_SelectTemperatureDevice(SCObj, peerId, screen)
{
	var temperatureDevice = document.getElementById('TemperatureDevice_'+peerId+'_'+screen).value;
    console.log("SceneController_SelectTemperatureDevice: peerId="+peerId+" screen="+screen+" temperatureDevice="+temperatureDevice);
	if (!temperatureDevice) {
		temperatureDevice = "0";
	}
	SceneController_send_action(peerId,SID_SCENECONTROLLER,"UpdateTemperatureDevice",{Screen:screen,TemperatureDevice:temperatureDevice});
	SceneController_set_device_state(peerId, SCObj.ServiceId, "TemperatureDevice_"+screen, temperatureDevice);
}

function SceneController_ScreenMenu(SCObj, selected, disabled, lcdVersion) {
	var html = "";
	for (var i = 0; i < SCObj.ScreenTypes.length; ++i) {
		var screen_type = SCObj.ScreenTypes[i];
		html += '    <optgroup label="' + screen_type.name + '" screens>'
		for (var j = 1; j <= screen_type.num; ++j) {
			if (SCObj.ScreenIsCompatible(SCObj, screen_type.prefix, j, lcdVersion)) {
				var short_name = screen_type.prefix + j;
				html += '     <option value="' + short_name + '"' + (short_name == disabled ? ' disabled' : '') +
												 					(short_name == selected ? ' selected' : '') + '>' + screen_type.name + ' ' + j + '</option>';
			}
		}
		html += '    </optgroup>';
	}
	return html;
}

function SceneController_SortByName(a, b) {
	var x = a.name.toLowerCase();
	var y = b.name.toLowerCase();
	return ((x < y) ? -1 : ((x > y) ? 1 : 0));
}

// Return a sorted menu grouped by room containing all devices that pass the given filter.
// If the filter returns 1, then the device is flagged with a *
function SceneController_DeviceMenu(objectID, selectedValue, extraCode, zeroLabel, filter){
    var html='';
    var orderedDevices  = JSON.parse(JSON.stringify(jsonp.ud.devices));
    orderedDevices.sort(SceneController_SortByName);
    var orderedRooms  = JSON.parse(JSON.stringify(jsonp.ud.rooms));
    orderedRooms.sort(SceneController_SortByName);

    var devicesNO = orderedDevices.length;
    if(devicesNO>0){
        html='<select id="'+objectID+'" class="styled" '+extraCode+'>'

        if(zeroLabel){
            html+='<option value="0"' + (selectedValue==0 ? " selected" : "") + '>- '+zeroLabel+' -</option>';
        }
        var roomDevices = {};
		var filterResult;
        for(var i=0;i<devicesNO;i++){
            if(orderedDevices[i].invisible!=1 && (filterResult = filter(orderedDevices[i]))) {
                if(typeof(roomDevices[orderedDevices[i].room])=='undefined'){
                    roomDevices[orderedDevices[i].room] = '';
                }
                roomDevices[orderedDevices[i].room] += '<option value="'+orderedDevices[i].id+'" '+((orderedDevices[i].id==selectedValue)?'selected':'')+'>'+orderedDevices[i].name+(filterResult===1?" *":"")+'</option>';
            }
        }

        var roomsNO = orderedRooms.length;
        if(typeof(roomDevices[0])!='undefined'){
        	html += '<optgroup label="'+"no room"+'">';
            html += roomDevices[0];
        	html += '</optgroup>';
        }

        for(var i=0;i<roomsNO;i++){
            if(typeof(roomDevices[orderedRooms[i].id])!='undefined'){
            	html += '<optgroup label="'+orderedRooms[i].name+'">';
                html += roomDevices[orderedRooms[i].id];
            	html += '</optgroup>';
            }
        }

        html+='</select>';
    }

    return html;
}


function SceneController_DecodeLabel(label, font, align) {
	if (!font) {
		font = "Normal";
	}
	if (!align) {
		align = "Center";
	}
	return {text: label, font: font, align: align};
}

function SceneController_IsZWaveObject(obj) {
	if (!obj || !obj.id_parent) {
		return false;
	}
	if (obj.id_parent == 1) {
		return true;
	}
	obj = SceneController_get_device_object(obj.id_parent);
	return  obj && obj.id_parent == 1;
}

// This will return:
// zWave: Boolean - Device is Z-Wave
// scene: Boolean - Device is Scene Controllable
// basicSetOnly: Boolean - Device is not scene controllable but Basic Set contrllable
// multiLevel: Boolean - Device is multiLevel
// binary: Boolean - Device is binary
function SceneController_GetDeviceProperties(obj) {
	var result = {
		zWave: false,
		scene: false,
		basicSetOnly: false,
		multiLevel: false,
		binary: false
	}
	if (!SceneController_IsZWaveObject(obj)) {
		return result;
	}
	result.zWave = true;
	var capabilities = SceneController_get_device_state(obj.id, ZWDEVICE_SID, CAPABILITIES, 0);
	if (!capabilities) {
		return result;
	}
	var splitresult = /^[^\|]+\|([\d:,]+)$/.exec(capabilities)
	if (!splitresult || !splitresult[1]) {
		return result;
	}
	var classesString = splitresult[1];
	var re = /(\d+):?(\d*),/g;
	var supportedClasses = {};
	var reResult
	while ((reResult = re.exec(classesString)) != null) {
	   supportedClasses[Number(reResult[1])] = reResult[2] ? Number(reResult[2]) : 1;
	}
	if (supportedClasses[43] && // COMMAND_CLASS_SCENE_ACTIVATION
		supportedClasses[44]) { // COMMAND_CLASS_SCENE_ACTUATOR_CONF) {
		result.scene = true;
	} else {
		result.basicSetOnly = true; // Every Z-Wave device should implicitly support Basic Get/Set.
	}
	if (supportedClasses[38]) { // COMMAND_CLASS_SWITCH_MULTILEVEL
		result.multiLevel = true
	} else if (supportedClasses[37]) {	// COMMAND_CLASS_SWITCH_BINARY
		result.binary = true
	}
	return result
}

function SceneController_EscapeHTML(string) {
    return string
         .replace(/&/g, "&amp;")
         .replace(/</g, "&lt;")
         .replace(/>/g, "&gt;")
         .replace(/"/g, "&quot;")
         .replace(/'/g, "&#039;");
 }


// Function to draw the Edit screens tab
function SceneController_Screens(SCObj, deviceId) {
	try {
		var peerId
		if(SceneController_IsZWaveChild(deviceId)){
	    	peerId=parseInt(SceneController_get_device_state(deviceId, SCObj.ServiceId, PEER_ID, 0));
		}
		else {
	    	peerId = deviceId;
	    	deviceId=parseInt(SceneController_get_device_state(deviceId, SCObj.ServiceId, PEER_ID, 0));
		}
		var versionInfo = SceneController_get_device_state(deviceId, ZWDEVICE_SID, VERSION_INFO, 0)
		var lcdVersion = versionInfo ? (parseInt(/,(\d+)$/.exec(versionInfo)[1])) : SCObj.DefaultLcdVersion;
		var curScreen = SCObj.HasScreen ? SceneController_get_device_state(peerId, SCObj.ServiceId, CURRENT_SCREEN, 0) : SCObj.DefaultScreen;
		if (!curScreen || typeof curScreen != "string") {
			curScreen = SCObj.DefaultScreen;
		}
		var screenType = curScreen.charAt(0);
		var screenNum = parseInt(curScreen.slice(1));
		var presetLanguage = SceneController_GetPresetLanguage(SCObj, peerId);
		var hasCustomLabels = (screenType == 'C' || (screenType == 'T' && screenNum > 3));
		var extraLines = 0;
		var html='';
		var numLines = SCObj.NumButtons
		if (SCObj.HasScreen) {
			html+= '<table style="padding-left:10px;padding-right:10px;" border="0" align="center" class="m_table skinned-form-controls skinned-form-controls-mac">\n'
			     + ' <tr>\n'
				 + '  <th style="text-align:right;"><b>Screen:</b></th>\n'
		         + '  <td>\n'
	             + '   <select class="styled" id="CurScreen_'+peerId+'" onChange="SceneController_SetScreen('+SCObj.Id+','+peerId+')" style="width:120px;">\n'
		         +       SceneController_ScreenMenu(SCObj, curScreen, null, lcdVersion)
		         + '   </select>\n'
		         + '  </td>\n';
			if (SCObj.MaxScroll > SCObj.NumButtons) {
				if (screenType == "C") {
					var numLinesString = SceneController_get_device_state(peerId, SCObj.ServiceId, "NumLines_"+curScreen, 0);
					if (numLinesString) {
						numLines = parseInt(numLinesString);
						numLines = numLines ? numLines : SCObj.NumButtons;
					}
					if (numLines < SCObj.NumButtons) {
						numLines = SCObj.NumButtons;
					}
					if (numLines > SCObj.MaxScroll) {
						numLines = SCObj.MaxScroll;
					}
		            html += '  <th style="text-align:right;width:80px"><b>Lines:</b></th>\n'
					     +  '  <td style="width:120px;">\n'
			             +  '   <select class="styled" id="NumLines_'+peerId+'_'+curScreen+'" onChange="SceneController_ChangeNumLines('+SCObj.Id+','+peerId+',\''+curScreen+'\')" style="width:100px;">\n';
					for (i = SCObj.NumButtons; i <= SCObj.MaxScroll; ++i) {
						html += '     <option value="' + i + '"' + (i==numLines ? ' selected' : '') + '>' + i + '</option>\n';
					}
				    html += '   </select>\n'
				         +  '  </td>\n';
				} else {
					html += '  <th style="width:80px;"></th><td style="width:120px;"></td>\n';
				}
			}
			var languageList = SCObj.LanguagesSupported(screenType, screenNum, lcdVersion);
			if (languageList.length > 1) {
	            html += '  <th style="text-align:right;width:80px"><b>Language:</b></th>\n'
				     +  '  <td style="width:120px;">\n'
		             +  '   <select class="styled" id="PresetLanguage_'+peerId+'" onChange="SceneController_SetPresetLanguage('+SCObj.Id+','+peerId+')" style="width:100px;">\n';
				for (i = 1; i <= languageList.length; ++i) {
					html += '     <option value="' + i + '"' + (i==presetLanguage ? ' selected' : '') + '>' + SceneController_PresetLanguages[languageList[i-1]] + '</option>\n';
				}
			    html += '   </select>\n'
			         +  '  </td>\n';
			}
			else {
				html += '  <th style="width:80px;"></th><td style="width:120px;"></td>\n';
			}
			html +=  ' </tr>\n'
			     +   '</table>\n'
			     +   '<div class="m_separator_inner"></div>\n';
		}
		html += '<table align="left" style="text-align:center;padding-left:10px;padding-right:10px;" border="0" align="center" class="m_table skinned-form-controls skinned-form-controls-mac">\n';
		if (screenType == "C" || screenType == "P" || screenType == "T") {
			html += ' <tr><th><b>Line</b></th><th style="text-align:center;"><b>Label</b></th>\n';
		    if (hasCustomLabels) {
		    	html += '  <th style="text-align:center;"><b>Font</b></th><th style="text-align:center;"><b>Align</b></th>\n'
		    }
			html += '  <th style="text-align:center;"><b>Type</b></th><th style="text-align:left;padding-left:20px;"><b>Scene</b></th>\n </tr>\n';
			for (var button = 1; button <= numLines; ++button) {
				var label;
				var font = "";
				var align = "";
				var custom = false;
				var modeStr  = SceneController_get_device_state(peerId, SCObj.ServiceId, "Mode_"+curScreen+"_"+button, 0);
				if (!modeStr || typeof modeStr != "string") {
					modeStr = SCObj.DefaultModeString;
				}
				var modePrefix = modeStr.charAt(0)
				var states = 1
				if (modePrefix.match(/[2-9]/)) {
					states = parseInt(modePrefix)
				}
				if (screenType == "C") {
					label = SceneController_get_device_state(peerId, SCObj.ServiceId, "Label_"+curScreen+"_"+button, 0);
					font = SceneController_get_device_state(peerId, SCObj.ServiceId, "Font_"+curScreen+"_"+button, 0);
					align = SceneController_get_device_state(peerId, SCObj.ServiceId, "Align_"+curScreen+"_"+button, 0);
					custom = true;
				} else if (screenType == "T") {
					if (screenNum <= 3) {
						label = SceneController_TemperatureScreens[screenNum-1][button-1];
					}
					else {
						if (button >= 2 && button <= 4) {
							label = SceneController_TemperatureScreens[0][button-1];
						} else if (modePrefix == "P") {
							label = "Heat/Cool/Auto/Off";
						} else if (modePrefix == "E") {
							label = "Normal/Energy Saving"
						} else {
							label = SceneController_get_device_state(peerId, SCObj.ServiceId, "Label_"+curScreen+"_"+button, 0);
							font = SceneController_get_device_state(peerId, SCObj.ServiceId, "Font_"+curScreen+"_"+button, 0);
							align = SceneController_get_device_state(peerId, SCObj.ServiceId, "Align_"+curScreen+"_"+button, 0);
							custom = true;
						}
					}
				} else {
					label = SCObj.PresetScreens[screenNum][button-1];
				}
				if (!label && label !== 0) {
					label = "";
				}
				for (state = 1; state <= states; ++state) {
					var stateButton = button + (state-1) * 1000;
					if (state > 1) {
						label = SceneController_get_device_state(peerId, SCObj.ServiceId, "Label_"+curScreen+"_"+stateButton, 0);
						font = SceneController_get_device_state(peerId, SCObj.ServiceId, "Font_"+curScreen+"_"+stateButton, 0);
						align = SceneController_get_device_state(peerId, SCObj.ServiceId, "Align_"+curScreen+"_"+stateButton, 0);
						if (!label) {
							label = "";
						}
						var modeStr  = SceneController_get_device_state(peerId, SCObj.ServiceId, "Mode_"+curScreen+"_"+stateButton, 0);
						if (!modeStr || typeof modeStr != "string") {
							modeStr = "M";
						}
					}
					var mode = SceneController_ParseModeString(SCObj, modeStr)
					if (state > 1) {
						mode.prefix = "M"
					}
					html += ' <tr>\n';
					if (states > 1) {
						html +=  '  <td>'+(button+state/10)+'</td>\n';
					}
					else {
						html +=  '  <td>'+button+'</td>\n';
					}
					if (custom) {
						var spec = SceneController_DecodeLabel(label, font, align);
						html += '  <td><input style="text-align:'+spec.align + ';'
						     +  ' width:120px;'
						     +  ' letter-spacing:' + (spec.font=='Compressed' ? '-1px' : '1px') + ';'
						     +  ' color:' + (spec.font=='Inverted' ? 'white':'black') + ';'
						     +  ' background-color:' + (spec.font=='Inverted' ? 'black':'white') + ';"'
						     +  ' type="text" id="Text_'+peerId+'_'+curScreen+'_'+stateButton+'" value="'+spec.text/*.replace(/\\/g,'\\\\')*/+'"'
						     +  ' onChange="SceneController_ChangeCustomLabel('+SCObj.Id+','+peerId+',\''+curScreen+'\','+stateButton+')"></td>\n';
						html += '  <td><select class="styled" align="left" style="width:'+(SceneController_IsUI7() ? 120 : 75)+'px; height:22px;"'
						     +  ' id="Font_'+peerId+'_'+curScreen+'_'+stateButton+'" onChange="SceneController_ChangeCustomFont('+SCObj.Id+','+peerId+',\''+curScreen+'\','+stateButton+')">\n';
						for (var j = 0; j < SceneController_CustomFontList.length; ++j) {
							var fontName = SceneController_CustomFontList[j];
							html += '   <option style="height:22px;" value="'+fontName+'" '+(fontName == spec.font ? 'selected' : '')+'>'+fontName+'</option>\n';
						}
						html += '  </select>\n </td>\n';
						html += ' <td>\n  <select class="styled" align="left" style="width:'+(SceneController_IsUI7() ? 90 : 60)+'px; height:22px;" id="Align_'+peerId+'_'+curScreen+'_'+stateButton+'"'
						     +  ' onChange="SceneController_ChangeCustomAlign('+SCObj.Id+','+peerId+',\''+curScreen+'\','+stateButton+')">\n';
						for (var j = 0; j < SceneController_CustomAlignList.length; ++j) {
							var alignName = SceneController_CustomAlignList[j];
							html += '   <option style="height:22px;" value="'+alignName+'" '+(alignName == spec.align ? 'selected' : '')+'>'+alignName+'</option>\n';
						}
						html += '   </select>\n  </td>\n';
					}
					else {
						html += '  <td>'+label+'</td>\n';
						if (hasCustomLabels) {
							html += '  <td/>\n  <td/>';
						}
					}
					if (screenType != "T"  || button == 1 || button == 5) {
						if (state == 1) {
							// Mode-type pop-up
							html += '  <td align="center">\n'
							     +  '   <select class="styled" style="width:'+ (SceneController_IsUI7() ? 135 : 90) + 'px; height:22px;" id="Mode_'+peerId+'_'+curScreen+'_'+button+'" onChange="SceneController_ChangeCustomMode('+SCObj.Id+','+peerId+',\''+curScreen+'\','+button+')">\n';
							for (var j = 0; j < SCObj.CustomModeList.length; ++j) {
								var optionPrefix = SCObj.CustomModeList[j];
								var selected = optionPrefix == (mode.newScreen ? "N" : mode.prefix)
								var enabled = true
								if (optionPrefix == "P" || optionPrefix == "E") {
									enabled = screenType == "T" && screenNum > SCObj.NumTemperaturScrens;
								} else if (screenType == "P") {
									enabled = !SCObj.HasScreen || optionPrefix < "2" || optionPrefix > "9"; // Preset screens don't have 3+state buttons
								}
								if (enabled) {
									html += '    <option style="height:22px;" value="'+optionPrefix+'" '+(selected ? 'selected' : '')+'>'+SceneController_Modes[SCObj.CustomModeList[j]]+'</option>\n';
								}
							}
							html += '   </select>\n  </td>\n';
						}
						else {
							html += '  <td/>\n';
						}
						// Scene buttons
						var buttonGroup = Math.floor((button-1)/SCObj.NumButtons)
						var sceneNum = SCObj.SceneBases[screenType]+((screenNum-1)*SCObj.NumButtons)+((button-1)%SCObj.NumButtons)+(buttonGroup ? (200 + buttonGroup*100):0)+((state-1)*1000);
					    html += '  <td align="left" style="padding-left:3px;"><div style="width:'+ (SceneController_IsUI7() ? 300 : 150) + 'px;'+(SceneController_IsUI7() ? 'padding-top:2px;padding-bottom:2px;': '')+'">\n';
						if (mode.newScreen) {
							var modeParam = mode.newScreen;
							if (!modeParam) {
								modeParam = (curScreen == SCObj.DefaultScreen ? "C2" : SCObj.DefaultScreen);
							}
							html += '   <select class="styled" style="width:120px; height:22px;" id="SwitchScreen_'+peerId+'_'+curScreen+'_'+button+'" onChange="SceneController_ChangeCustomMode('+SCObj.Id+','+peerId+',\''+curScreen+'\','+button+')" style="width:100px;">\n'
							     +       SceneController_ScreenMenu(SCObj, modeParam, curScreen, lcdVersion)
							     +  '   </select>\n';
						}
						// Disable Vera scenes if we have already selected a non-scene-capable direct device. 
						var disableVeraScene = !SCObj.HasCooperConfiguration && 
						    mode.length > 0 && 
						    SceneController_GetDeviceProperties(SceneController_get_device_object(mode[0].device)).basicSetOnly;
						var enableNonSceneDirect = SCObj.HasCooperConfiguration || (SceneController_FindScene(peerId, sceneNum, -1) == null && states == 1);
						switch (mode.prefix) {
						   	case "M":	// Momentary
							case "X":	// EXclusive
							case "N":   // Switch sceNe
							case "P":   // Thermostat oPerating mode
							case "E":	// Thermostat Energy mode
							default:
								html += '   <button type="button" class="btn" '+(disableVeraScene?'disabled ':'')+'style="min-width:10px;'+
								             (SceneController_FindScene(peerId, sceneNum, 2)?';color:orange;':'')+(disableVeraScene?'background-color:#AAAAAA;':'')+
								             '" onClick="SceneController_SetScene('+peerId+','+sceneNum+',2,\''+SceneController_EscapeHTML(label)+'\')">Scene</button>\n';
						      	break;
						   	case "T":  // Toggle
								html += '   <button type="button" class="btn" '+(disableVeraScene?'disabled ':'')+'style="min-width:10px;'+
								             (SceneController_FindScene(peerId, sceneNum, 1)?';color:orange;':'')+(disableVeraScene?'background-color:#AAAAAA;':'')+
								             '" onClick="SceneController_SetScene('+peerId+','+sceneNum+',1,\''+SceneController_EscapeHTML(label)+'\')">On</button>\n';
								if (/*SCObj.HasOffScenes*/ true) {
									html += '    <button type="button" class="btn" '+(disableVeraScene?'disabled ':'')+'style="min-width:10px;'+
									             (SceneController_FindScene(peerId, sceneNum, 0)?';color:orange;':'')+(disableVeraScene?'background-color:#AAAAAA;':'')+
									             '" onClick="SceneController_SetScene('+peerId+','+sceneNum+',0,\''+SceneController_EscapeHTML(label)+'\')">Off</button>';
								}
								break;
						}
						if (mode.length < SCObj.MaxDirectAssociations) {
							html += '    <button type="button" class="btn" style="min-width:10px;'+
								             (mode.length>0?';color:orange;':'')+
								             '" onClick="SceneController_SetPlaceholder('+SCObj.Id+','+peerId+','+stateButton+')">+Direct</button>\n';
							if (SceneController_Placeholder == stateButton) {
								mode.push({device:0});
							}
						}
						html += '   </div>\n  </td>\n </tr>\n';
						// Extra lines for direct association
						for (var j = 0; j < mode.length; ++j) {
							extraLines++;
							html +=  ' <tr><td/><td colspan=' + (hasCustomLabels ? '5' : '3') + ' align="left">Device: ';
							html +=  SceneController_DeviceMenu('SmartToggle_'+peerId+'_'+curScreen+'_'+stateButton+'_'+j,
		  	 					mode[j].device,
		  	 					'style="width:200px; height:22px;" onChange="SceneController_SelectDirectDevice('+SCObj.Id+',\''+mode.prefix+'\','+peerId+',\''+curScreen+'\',\''+stateButton+'\',\''+j+'\',1)"',
		  	 					" ",
		  	 					function(obj) {
									for (var k = 0; k < mode.length; ++k) {
										if (k != j && mode[k].device == obj.id) {
											// Already in the list.
											return 0;
										}
									}
									var controllable = SceneController_GetDeviceProperties(obj);
									if (!controllable.zWave) { // Non-Z-Wave devices cannot be controlled by direct scenes
										return 0
									}
									var result = controllable.scene ? 2 : 1
									if (SCObj.HasCooperConfiguration) {
										return result // Cooper can handle both Scene and non-scene direct devices 
									}
									if (j == 0) {
										return result // The first entry in the list decides scene vs non-scene mode
									}
									if (controllable.basicSetOnly) { // The target device is not scene capable
										if (!enableNonSceneDirect && mode.prefix != "T") {
											return 0  // A vera scene is enabled. We need Scene Activate mode unless we can figure which button was pushed indifectly by reading the toggling indicator.
										}
									}
									return result;
		  	 					});
							var controllable = SceneController_GetDeviceProperties(SceneController_get_device_object(mode[j].device))
							if (mode.sceneControllable && (controllable.scene && controllable.multiLevel) || SCObj.HasCooperConfiguration) {
								html +=  '    <input type="checkbox"'+((mode[j].level || mode[j].level == 0) && mode[j].level != 255 ?' checked':'')+' id="LevelSelect_'+peerId+'_'+curScreen+'_'+stateButton+'_'+j+'"'
								     +   ' style="min-width:10px;margin-left:10px;" onChange="SceneController_SelectDirectDevice('+SCObj.Id+',\''+mode.prefix+'\','+peerId+',\''+curScreen+'\',\''+stateButton+'\',\''+j+'\',2)"><span/>\n'
								     +   'Level: '
								     +   '    <input class="styled" id="Level_'+peerId+'_'+curScreen+'_'+stateButton+'_'+j+'" type="number"'
								     +   ' value="'+((!(mode[j].level || mode[j].level == 0) || mode[j].level == 255)?"":mode[j].level)+'" style="width:40px;" onChange="SceneController_SelectDirectDevice('+SCObj.Id+',\''+mode.prefix+'\','+peerId+',\''+curScreen+'\',\''+stateButton+'\',\''+j+'\',3)">\n';
							}
							if (mode.sceneControllable && controllable.scene && controllable.multiLevel) {
								html +=  '<input type="checkbox"'+((mode[j].dimmingDuration || mode[j].dimmingDuration == 0) && mode[j].dimmingDuration != 255 ?' checked':'')+' id="DimmingDurationSelect_'+peerId+'_'+curScreen+'_'+stateButton+'_'+j+'"'
								     +   ' style="min-width:10px;margin-left:10px;" onChange="SceneController_SelectDirectDevice('+SCObj.Id+',\''+mode.prefix+'\','+peerId+',\''+curScreen+'\',\''+stateButton+'\',\''+j+'\',4)"><span/>\n'
								     +   'Duration: '
								     +   '<input class="styled" id="DimmingDuration_'+peerId+'_'+curScreen+'_'+stateButton+'_'+j+'" type="number"'
								     +   ' value="'+((!(mode[j].dimmingDuration || mode[j].dimmingDuration == 0) || mode[j].dimmingDuration == 255)?"":mode[j].dimmingDuration)+'" style="width:40px;" onChange="SceneController_SelectDirectDevice('+SCObj.Id+',\''+mode.prefix+'\','+peerId+',\''+curScreen+'\',\''+stateButton+'\',\''+j+'\',5)">\n';
							}
						}
					} // ScreenType != T or button == 1 or button == 5
				} // for state
			} // for button
			if (hasCustomLabels) {
				html += ' <tr><td colspan=5>Use a - or \\r for a 2-line label in the normal font</td></tr>\n'
			}
			if (extraLines < 2) {
				html += " <tr><td>&nbsp;</td></tr>\n";
			}
		}
		if (screenType == "T") {
			var temperatureDevice = SceneController_get_device_state(peerId, SCObj.ServiceId, "TemperatureDevice_"+curScreen, 0);
			if (!temperatureDevice) {
				temperatureDevice = 0;
			}
			html += ' <tr>\n'
		         +  '  <td colspan=' + (hasCustomLabels ? '6' : '4') + ' align="left">Choose a Z-Wave thermostat or temperature sensor: '
			  	 + SceneController_DeviceMenu('TemperatureDevice_'+peerId+'_'+curScreen,
			  	 	temperatureDevice,
			  	 	'onChange="SceneController_SelectTemperatureDevice('+SCObj.Id+','+peerId+',\''+curScreen+'\')"' /* + ' style="width:200px;"' */,
			  	 	"none",
			  	 	function(obj) {return (obj.category_num == 5 || obj.category_num == 17) && SceneController_IsZWaveObject(obj);} )
				 +  '   </td>\n'
				 +  ' </tr>\n';
		}
		var timeoutEnable = SceneController_get_device_state(peerId, SCObj.ServiceId, "TimeoutEnable_"+curScreen, 0) == "true";
		var timeoutScreen = SceneController_get_device_state(peerId, SCObj.ServiceId, "TimeoutScreen_"+curScreen, 0);
		if (!timeoutScreen) {
			timeoutScreen = (curScreen == SCObj.DefaultScreen ? "C2" : SCObj.DefaultScreen);
			timeoutEnable = false;
		}
		var timeoutSeconds = SceneController_get_device_state(peerId, SCObj.ServiceId, "TimeoutSeconds_"+curScreen, 0);
		if (!timeoutSeconds) {
			timeoutSeconds = 30;
			timeoutEnable = false;
		}
		if (SCObj.HasScreen) {
			html += ' <tr>\n'
			     +  '  <td align="left" colspan=' + (hasCustomLabels ? '6>' : '4>\n')
				 +  '   <input type="checkbox"'+(timeoutEnable?' checked':'')+' id="TimeoutEnable_'+peerId+'_'+curScreen+'" style="min-width:'+(SceneController_IsUI7() ? 20 : 10)+'px;" onChange="SceneController_ChangeTimeout('+SCObj.Id+','+peerId+',\''+curScreen+'\', false)" /><span></span>\n'
				 +  '   Switch to screen:\n'
		         +  '   <select class="styled" id="TimeoutScreen_'+peerId+'_'+curScreen+'" onChange="SceneController_ChangeTimeout('+SCObj.Id+','+peerId+',\''+curScreen+'\', true)" style="width:100px;">\n'
				 +       SceneController_ScreenMenu(SCObj, timeoutScreen, curScreen, lcdVersion)
			     +  '   </select>\n'
			     +  '   if no button pressed after\n'
			     +  '   <input class="styled" id="TimeoutSeconds_'+peerId+'_'+curScreen+'" type="text" value="'+timeoutSeconds+'" style="width:30px;" onChange="SceneController_ChangeTimeout('+SCObj.Id+','+peerId+',\''+curScreen+'\', true)" />\n'
			     +  '   seconds.\n'
				 + '   </td>\n'
				 +  ' </tr>\n';
		}
		html += '</table>\n';
		SceneController_set_panel_html(html);
		SceneController_Placeholder = 0;
	} catch(e){
		log_message("SceneController_screens error: " + e + " " + e.stack);
	}
}

function SceneController_ChangeTimeout(SCObj, peerId, curScreen, enable) {
	var timeoutEnableObj = document.getElementById("TimeoutEnable_"+peerId+"_"+curScreen);
	var timeoutScreenObj = document.getElementById( "TimeoutScreen_"+peerId+"_"+curScreen);
	var TimeoutSecondsObj = document.getElementById( "TimeoutSeconds_"+peerId+"_"+curScreen);
	var timeoutEnable = timeoutEnableObj.checked;
	var timeoutScreen = timeoutScreenObj.value;
	var timeoutSeconds = TimeoutSecondsObj.value;
	if (enable || timeoutEnable) {
		var seconds = Number(timeoutSeconds);
		if (seconds < 5 || seconds > 3600) {
			window.alert("Timeout must be between five seconds and one hour.");
			return;
		}
	}
	if (enable && !timeoutEnable) {
		timeoutEnable = true;
		timeoutEnableObj.checked = true;
	}
	SceneController_send_action(peerId,SID_SCENECONTROLLER,"SetScreenTimeout",{Screen:curScreen,Enable:String(timeoutEnable),TimeoutScreen:timeoutScreen,TimeoutSeconds:timeoutSeconds});
	SceneController_set_device_state(peerId, SCObj.ServiceId, "TimeoutEnable_"+curScreen, String(timeoutEnable));
	SceneController_set_device_state(peerId, SCObj.ServiceId, "TimeoutScreen_"+curScreen, timeoutScreen);
	SceneController_set_device_state(peerId, SCObj.ServiceId, "TimeoutSeconds_"+curScreen, timeoutSeconds);
}

function SceneController_ChangeNumLines(SCObj, peerId, curScreen) {
	var numLinesObj=document.getElementById("NumLines_"+peerId+"_"+curScreen);
	var numLines = numLinesObj ? parseInt(numLinesObj.value) : 5;
	SceneController_send_action(peerId,SID_SCENECONTROLLER,"SetNumLines",{Screen:curScreen,Lines:numLines});
	SceneController_set_device_state(peerId, SCObj.ServiceId, "NumLines_"+curScreen, numLines);
	SceneController_Screens(SCObj, peerId);
}


function SceneController_FinishScene(peerId, sceneID, doSave, isNew, originalSave, originalCancel, event) {
	document.getElementById("confirm_save_scene").onclick=originalSave;
	document.getElementById("confirm_cancel_scene").onclick=originalCancel;
	if (doSave) {
		originalSave(event);
    	has_changes('new scene');
	}
	else {
		originalCancel(event);
		if (isNew) {
        	jsonp.userdata_remove("scene",get_scene_obj(sceneID));
		}
	}
	jQuery(EVLCD1_SelectedMenuButton).click();

	cpanel.elemDOM.show();	/* Do this double open to avoid select height bug */
    cpanel.open('device', get_device_obj(peerId).device_type, peerId.toString(), SceneController_Scenes_Tab);
}

// Work around UI7's needless 32 character scene name limit.
// In UI5, there is a practical limit to what can be displayed in a tile.
function SceneController_CreateSceneName(devName, label, action, maxLength) {
	label = label.replace(/\\r/g, " ");
	label = label.replace(/-/g, "");
	devName = devName.trim();
	label = label.trim();
	while(1) {
		var name = 	devName + " " + label + action;
		if (maxLength == 0 || maxLength >= name.length) {
			return name;
		}
		if (devName.match(/.+\sController/)) {
			devName = devName.slice(0, -11);
			continue;
		}
		if (devName.match(/Evolve\s.+/)) {
			devName = devName.slice(7);
			continue;
		}
		var lastSpace = devName.lastIndexOf(" ");
		if (lastSpace > 0) {
			devName = devName.slice(0, lastSpace);
			continue;
		}
		lastSpace = label.lastIndexOf(" ");
		if (lastSpace > 0) {
			label = label.slice(0, lastSpace);
			continue;
		}
		var truncLength =  maxLength - (" " + label + action).length;
		if 	(truncLength > 0) {
			devName = devName.slice(0, truncLength);
			continue;
		}
		truncLength =  maxLength - action.length - (devName + " " + label).length;
		return (devName + " " + label).slice(0,truncLength) + action;
	}
}

// Activate is -1 for any, 0 for deactivate toggle, 1 for activate toggle or 2 for momendary.
function SceneController_FindScene(deviceID, scenNum, activate) {
	var triggerTemplate = activate ? 1 : 2;
    var numScenes=jsonp.ud.scenes.length;
    var sceneObj;
    for (var i = 0; i < numScenes; i++) {
        sceneObj = jsonp.ud.scenes[i];
		if (sceneObj.triggers &&
			sceneObj.triggers.length >= 1 &&
			sceneObj.triggers[0].device == deviceID &&
			(sceneObj.triggers[0].template == triggerTemplate || activate < 0) &&
			sceneObj.triggers[0].arguments[0].value == scenNum) {
			return sceneObj;
		}
    }
	return null;
}

function SceneController_GetOrCreateNewScene(deviceID, scenNum, activate, label) {
    var sceneObj = SceneController_FindScene(deviceID, scenNum, activate)
	if (sceneObj) {
		if (sceneObj.groups == undefined) {
			sceneObj.groups =  [{
				delay: 0,
				actions: []
			}];
		}
        return [false, sceneObj, sceneObj.name];
    }
	// The scene was not found. Create a new one
    var sceneID = SceneController_IsUI7() ? application.newSceneId() : new_scene_id();
	var devObj = SceneController_IsUI7() ? application.getDeviceById(deviceID) : get_device_obj(deviceID);
    var sceneName = SceneController_CreateSceneName(devObj.name,
                                               label,
                                               activate >= 2 ? "" : activate ? " On" : " Off",
							                   SceneController_IsUI7() ? 32 : 22);
	var sceneObj = {
    	id: sceneID,
    	name: sceneName,
    	room: devObj.room,
    	// notification_only: deviceID,
    	triggers:  [{
    		name:(sceneName+" Trigger"),
    		enabled: "1",
    		template: activate ? 1 : 2,
    		device: deviceID,
    		arguments: [{
				id: 1,
				value: scenNum
    		}],
    	}],
		groups: [{
			delay: 0,
			actions: []
		}],
        modeStatus: "0"
	};
	if (SceneController_IsUI7()) {
		application.userDataAdd("scene", sceneObj);
	} else {
		jsonp.userdata_add("scene",sceneObj);
	}
    return [true, sceneObj, sceneName];
}

// start_eidt_scene in cpanel_data.js is buggy in 1.5.622
function SceneController_start_edit_scene_UI5(sceneID){
    try{
        sceneToEditId = sceneID;

        // clone might not work in other browsers.Checking it is a must
        sceneBackup = clone(get_node_obj(jsonp.ud.scenes,sceneID));
        sceneReference = get_node_obj(jsonp.ud.scenes,sceneID);
        fStartSceneCreator(false);
    }catch(e){
        log_message("Edit SceneController_start_edit_scene_UI5 error: " + e + " " + e.stack);
    }
}

function SceneController_SetScene(peerId, sceneNum, activate, label)
{
	if (SceneController_IsUI7()) {
	    var t = SceneController_GetOrCreateNewScene(peerId, sceneNum, activate, label);
		var isNew = t[0];
		var sceneObj = t[1];
		var sceneName = t[2];
		myInterface.showCreateScenePage(sceneObj.id);
		myInterface.openCreateSceneStepTwo();
		if (typeof(sceneObj.groups) != "object" || sceneObj.groups.length < 1 || (sceneObj.groups.length == 1 && sceneObj.groups[0].delay == 0)) {
			// Jump directly to immediate actions unless there are already one or more delayed actions.
			myInterface.showCreateSceneSelectDevicesForAction(0);
		}
        var labelEdit = isNew ? 'Create new scene:' : 'Edit Scene:';
        $(View.idForCreateSceneContainerStepsTitle()).html(labelEdit + " " + SceneController_EscapeHTML(sceneName));
		myInterface.SceneController_Save_new_scenes = myInterface.view_scenes;
		myInterface.view_scenes = function() {
			if ('SceneController_Save_new_scenes' in myInterface) {
				myInterface.view_scenes = myInterface.SceneController_Save_new_scenes;
				myInterface.SceneController_Save_new_scenes = undefined;
			}
			myInterface.openDeviceCpanel( application.getDeviceById(peerId), application.getDeviceTemplateById(peerId));
			$("#device_cpanel_top_bottom_element_1").click();
		}
	} else {  // UI5
		//console.log("SceneController_SetScene peerId="+peerId+" sceneNum="+sceneNum+" activate="+activate+" label="+label);
		var saveButton = document.getElementById("confirm_save_scene");
		var cancelButton = document.getElementById("confirm_cancel_scene");
	    EVLCD1_SelectedMenuButton = jQuery("#buttons > .button.selected")[0];

		if (!saveButton || !cancelButton) {
			alert("Incompatible UI: Could not find save and cancel buttons.");
			return;
		}
	    var t = SceneController_GetOrCreateNewScene(peerId, sceneNum, activate, label);
		var isNew = t[0];
		var sceneObj = t[1];
	    cpanel.close();
	    SceneController_start_edit_scene_UI5(sceneObj.id);
	    jQuery(".module_title").html("Define Actions for button labeled: " + SceneController_EscapeHTML(label));
		var originalSave   = saveButton.onclick;
		var originalCancel = cancelButton.onclick;
		saveButton.onclick   = function(event) {SceneController_FinishScene(peerId, sceneObj.id, true,  isNew, originalSave, originalCancel, event);};
		cancelButton.onclick = function(event) {SceneController_FinishScene(peerId, sceneObj.id, false, isNew, originalSave, originalCancel, event);};
	}
}

function SceneController_Copy(SCObj, deviceId) {
	var peerId
	if(SceneController_IsZWaveChild(deviceId)){
    	peerId=parseInt(SceneController_get_device_state(deviceId, SCObj.ServiceId, PEER_ID, 0));
	}
	else {
    	peerId = deviceId;
    	deviceId=parseInt(SceneController_get_device_state(deviceId, SCObj.ServiceId, PEER_ID, 0));
	}
	var curScreen = SceneController_get_device_state(peerId, SCObj.ServiceId, CURRENT_SCREEN, 0);
	if (!curScreen || typeof curScreen != "string") {
		curScreen = SCObj.DefaultScreen;
	}
	if (!CopySwap) {
		CopySwap = {
			"IsCopy": true,
		    "IsRow": true,
		    "SourceRowNum": 1,
		    "SourceScreen": curScreen,
			"SourceDevice": peerId,
		    "DestRowNum": 2,
		    "DestScreen": (curScreen == SCObj.DefaultScreen ? "C2" : SCObj.DefaultScreen),
			"DestDevice": peerId,
		    "CopyScenes": false
		};
	}
	else {
		if (CopySwap.SourceDevice != peerId && CopySwap.DestDevice != peerId) {
			var sameDevice = CopySwap.SourceDevice == CopySwap.DestDevice;
			CopySwap.SourceDevice = peerId;
			if (sameDevice) {
				CopySwap.DestDevice = peerId;
			}
		}
		var bothThisDevice = CopySwap.SourceDevice == CopySwap.DestDevice;
		if (CopySwap.SourceScreen != curScreen && CopySwap.DestScreen != curScreen) {
			var sameScreen = CopySwap.SourceScreen == CopySwap.DestScreen;
			CopySwap.SourceScreen = curScreen;
			if (bothThisDevice && sameScreen) {
			    CopySwap.DestScreen = curScreen;
			}
			else {
			    CopySwap.DestScreen = SceneController_OtherCompatibleScreen(CopySwap.DestScreen, curScreen);
			}
		}
	}
	SceneController_UpdateCopyTab(SCObj, deviceId)
}

// Function to draw the Copy lines/pages tab
function SceneController_UpdateCopyTab(SCObj, deviceId) {
	try {
		var peerId
		if(SceneController_IsZWaveChild(deviceId)){
	    	peerId=parseInt(SceneController_get_device_state(deviceId, SCObj.ServiceId, PEER_ID, 0));
		}
		else {
	    	peerId = deviceId;
	    	deviceId=parseInt(SceneController_get_device_state(deviceId, SCObj.ServiceId, PEER_ID, 0));
		}
		var versionInfo = SceneController_get_device_state(deviceId, ZWDEVICE_SID, VERSION_INFO, 0)
		var lcdVersion = versionInfo ? (parseInt(/,(\d+)$/.exec(versionInfo)[1])) : 39;
		var curScreen = SceneController_get_device_state(peerId, SCObj.ServiceId, CURRENT_SCREEN, 0);
		if (!curScreen || typeof curScreen != "string") {
			curScreen = SCObj.DefaultScreen;
		}
		var screenType = curScreen.charAt(0);
		var screenNum = parseInt(curScreen.slice(1));
		var hasCustomLabels = (screenType == 'C' || (screenType == 'T' && screenNum > 2));
		var extraLines = 0;
		var html="Use this tab to copy or swap lines or whole screens betwen this or other LCD1's in your Z-Wave network.<br>"
		html += '  <select class="styled" align="left" style="width:75px; height:22px;" id="CopySwap_'+peerId+'" onChange="SceneController_ChangeCopySwap('+peerId+')">';
			html += '   <option style="height:22px;" value="Copy" selected>Copy</option>';
			html += '   <option style="height:22px;" value="Swap"         >Swap</option>';
		html += '  </select> ';
		html += '  <select class="styled" align="left" style="width:75px; height:22px;" id="RowPage_'+peerId+'" onChange="SceneController_ChangeRowPage('+peerId+')">';
			html += '   <option style="height:22px;" value="Row"  selected>Row</option>';
			html += '   <option style="height:22px;" value="Page"         >Page</option>';
		html += '  </select> ';
		SceneController_set_panel_html(html);
	} catch(e){
		log_message("SceneController_UpdateCopyTab error: " + e + " " + e.stack);
	}
}

var GenGenSceneController
if (SceneController_IsUI7()) {
  GenGenSceneController = (function (api) {
	return {
		uuid: 'fcdb51b0-36ea-45a1-ba59-191c77fe23db',

		// This is a nasty hack at several levels. We need to have the "Delete Device" button in the top level control panel
		// tab delete the Z-Wave device and not the peer device. In UI7, the "AfterInit" hook is called after the
		// delete device handler is established. We can replace it by using idForDeviceCpanelDeleteDeviceControl
		// but really we only want to change the device its operating on.
		// JQuery does not have a documented API for getting the current handlers of an element and the method to do so
		// changed across versions.
		// Unfortunately, getting the old handler is only half the problem. The click() function takes no
		// parameters and instead relies on the upvalue of the "device" variable in the closure. We need to re-evaluate
		// the handler with the correct Device (and "that" = the Interface object) in order to break lexical scope.
		// Just in case, we put this all in an try/catch as it may be fragile.
	 	AfterInit: function(SCObj, deviceId) {
			try {
				if (!SceneController_IsZWaveChild(deviceId)) {
				    var peerId=parseInt(SceneController_get_device_state(deviceId, SCObj.ServiceId,PEER_ID, 0));
				    var ShowSingleDevice = SceneController_get_device_state(peerId, SCObj.ServiceId,SHOW_SINGLE_DEVICE, 0);
					if (ShowSingleDevice != "0") {
						var device = SceneController_get_device_object(peerId)
						var that = api.ui
						var elem = $(View.idForDeviceCpanelDeleteDeviceControl())
						var oldHandler = jQuery._data(elem[0], "events").click[0].handler
						eval("var newHandler="+oldHandler.toString())
						elem.off("click").on("click", newHandler)
					}
				}
		    } catch (e) {
		        Utils.logError("Error in GenGenSceneController.AfterInit: " + e + " " + e.stack);
		    }
		},

		EvolveLCD1_AfterInit: function(deviceId) {
			 this.AfterInit(EVOLVELCD1, deviceId);
		},

		CooperRFWC5_AfterInit: function(deviceId) {
			 this.AfterInit(COOPERRFWC5, deviceId);
		},

		NexiaOneTouch_AfterInit: function(deviceId) {
			 this.AfterInit(NEXIAONETOUCH, deviceId);
		}
	}
  })(api);
}
//# sourceURL=J_GenGenSceneController.js
