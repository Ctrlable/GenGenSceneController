# GenGenSceneController
Generic Scene Controller plug-in for Vera smart home controllers.

This is the original source code for the GenGeneric Scene controller plug-in. It currently supports three didderent devices:
* [Evolve LCD1](http://www.evolvecontrols.com/wp-content/uploads/2016/05/Evolve-Controls-Scene-Controllers.pdf "Evolve LCD1 specification")
* [Cooper Eaton RFWC5](http://www.cooperindustries.com/content/public/en/wiring_devices/products/lighting_controls/aspire_rf_wireless/aspire_rf_5_button_scene_control_keypad_rfwdc_rfwc5.html "RFWC5 product page") (Sometimes know as RFWDC)
* [Nexia One-Touch](http://www.nexiahome.com/certified-products/nexia-one-touch "Nexia One-Touch product page")

The Plug-in is designed to eak out as much functionality from these devices as possible but it alwo does this with as much common code as practical.

The Evolve LCD1 and Nexia One-Touch, especially, are similar in appearance as they both have the same programmable LCD screen and 5 button arrangement. They also respond to some of the same Z-Wave command-classes. However the implementation details are quite different. The plug-in exploits these similarities and separates device-specific code into three separate objects - one deditcated to each device.

The Vera plug-in API is not very friendly to new Z-Wave devices which are not fully supported by Vera Controls. That said, this plug-in has overcome these hurdles using several novel techniques

## Peer Devices

Vera Z-Wave devices are child devices of the Z-Wave network scene controller. Unfortunately, they do not receive action events from the Vera GUI as do non-Z-Wave devices. For this reason, the Plug-In makes the Z-Wave device invisible but creates a new peer device which has no device parent. The device that you actually see in the Vera Web GUI is the peer device, but some of the advanced control panel pages link directly to the Z-Wave device. The Z-Wave device is linke to its peer using the "PeerID" variable. The Peer device is linked to the Z-Wave device using the AltID variable. If you exclude the Z-Wave devine from your network, the peer device will aso be automatically removed. If you add a new recognized device to your network, the plug-in will automatically "adopt" the device by making it invisible and creating a peer.

## The Z-Wave Interceptor (Zwint)

Although Vera includes a "SendData" action which is crucial for sending arbitrary Z-Wave commands to various devices, there is no easy way to receive responses from external devices. The Z-Wave interceptior (Zwint for short) solves this problem by intercepting all data going over the Z-Wave serial protocol between Vera's main controller chip and its Z-Wave module. Zwint is a Lua plug-in written in C. Once installed, it normally passes through all data going in either direction but it can monitor (Z-Wave to main SOC) or intercept (main SOC to Z-Wave) any Z-Wave commands. Monitored/interceted commands can be sent as Vera luup requests over the internal HTTP: interface. A monitored command can either be forwarded to the LuaUPnP engine either modifified or unmodified or it can be immediately replied to and thus LuaUPnP will not see that command. However the event can still be received by the plug-in as a Luup request. Similarly, commands from LuaUPnP can be intercepted and forwarded (modified or unmodified) or responded to immedediately. As such, it is possible to fix inappropriate LuaUPnP behavior for specific devices. 

Interception is used to prevent the battery-operated Nexia One-Touch from going to sleep when it wakes up but LuaUPnP tries to send a No_More_Information command. If the plug-in has information to send to the Nexia One-Touch (for example, to change the screen display), it will wait until it wakes up, intercept LuaUPnP's No_More_Information command, send its own commands and then send the No_More_Information command allowing the device to go back to sleep.

Zwint accepts Monitor and Intercept objects from the Lua code. Each object has a "trigger" regular expression which is applied to the hexified Z-Wave command. You can use all of the Linux C Library's extended regular expression features to parse the Z-Wave command and extract inportant information. Any (captures) are passed as a luup action with parameter names C1 through C9. These captures can also be used in a replacement hex string using \1 through \9. The replacement string is converted back into binary with XX replaced by the Z-Wave checksum and sent in the appropriate direction. The XX also marks the end of a Z-Wave command before a response is expected. The actual response string may contain several such commands (typically 2 or 3) concatenated with the internal responses (typically ACK) ignored.

Z-Wave messages may be duplicated in a mesh network. The same message may be received several times. Deciding which message is original and which is a duplicate is actually fairly tricky and specific to each message. A Lua function, CheckDups centralizes the common parts of duplicate detection but also includes parameters which can be used to customize this behavior.

There are many examples in the code of monitors and intercepts which are well commented. You need a deep understanding of the Z-Wave protocol in order to effectively use Zwint, but it has proven to be extremely powerful not only for supporting device-specific features but also for fixing bugs or misbehaviors in LuaUPnP.

## The GenGeneric Scene Controller installer and Uninstaller

UI5 and UI7 use completely different methods to detect specific Z-Wave devices and assign them differenct device types, etc. UI5 using an XML file whereas UI7 uses several JSON files. The one device which is created when you install the Vera plug-in is the installer. It adds information as appropriate to UI5 and UI7 so that newly added Z-Wave devices which the plug-in recoginizes will get the correct behavior and icons. The installer also creates an uninstaller device. If you remove the plug-in, the uninstaller detects that the installer has been deleted and it cleans up all files created by the installer and "un-adopts" all devices which were adopted by the installer by deleting the peer devices and making the original Z-Wave devices visible again. The Uninstaller also removes the Z-Wave interceptor. Vera should once again behave exactly as it did before the plug-in was installed.

## The Z-Wave queue

The Installer device also acts as a master Z-Wave queue. It coordinates the Z-Wave messages sent by the peer Vera devices to the physical controllers to which they are assigned, but also so other devices controlled by them. Some of these commands cannot be sent back-to-back and must be performed with an adequate delay. The Z-Wave queue coordinates and prioritizes such commands, and also handles waiting for commands to be sent to battery-operated devices such as the Nexia One-Touch.

## The "Failed to get lock" bug

As of December, 2017, Vera Controls has yet to completely resolve a long-standing bug in LuaUPnP which is the root cause of many Vera crashes. The LuaUPnP engine will suddenly freeze for one minute and then restart with any pending operations lost. This seems to be a race condition in some of LuaUPnP's internal threads and happens at random times, especially when the engine is performing several tasks concurrently. Veral Controls has been made well aware of this bug and hopefully, they will fix it soon.

The Z-Wave queue con be considered as a huge work-around for this bug. It has been designed to coordinate all Z-Wave activity from the plug-in in one place even when several different devices are being handled simultaneously.
