echo -- Auto-generated by MakeUninstaller.bat > L_UninstallerParts.lua

.\pluto-lzo c D_GenGenSceneControllerUninstaller.json D_GenGenSceneControllerUninstaller.json.lzo
echo D_GenGenSceneControllerUninstaller_json_lzo = b642bin([[ >> L_UninstallerParts.lua
base64 < D_GenGenSceneControllerUninstaller.json.lzo >> L_UninstallerParts.lua
echo ]]) >> L_UninstallerParts.lua
del D_GenGenSceneControllerUninstaller.json.lzo

.\pluto-lzo c D_GenGenSceneControllerUninstaller.xml D_GenGenSceneControllerUninstaller.xml.lzo
echo D_GenGenSceneControllerUninstaller_xml_lzo = b642bin([[ >> L_UninstallerParts.lua
base64 < D_GenGenSceneControllerUninstaller.xml.lzo >> L_UninstallerParts.lua
echo ]]) >> L_UninstallerParts.lua
del D_GenGenSceneControllerUninstaller.xml.lzo

.\pluto-lzo c I_GenGenSceneControllerUninstaller.xml I_GenGenSceneControllerUninstaller.xml.lzo
echo I_GenGenSceneControllerUninstaller_xml_lzo = b642bin([[ >> L_UninstallerParts.lua
base64 < I_GenGenSceneControllerUninstaller.xml.lzo >> L_UninstallerParts.lua
echo ]]) >> L_UninstallerParts.lua
del I_GenGenSceneControllerUninstaller.xml.lzo

.\pluto-lzo c L_GenGenSceneControllerUninstaller.lua L_GenGenSceneControllerUninstaller.lua.lzo
echo L_GenGenSceneControllerUninstaller_lua_lzo = b642bin([[ >> L_UninstallerParts.lua
base64 < L_GenGenSceneControllerUninstaller.lua.lzo >> L_UninstallerParts.lua
echo ]]) >> L_UninstallerParts.lua
del L_GenGenSceneControllerUninstaller.lua.lzo

.\pluto-lzo c S_GenGenSceneControllerUninstaller.xml S_GenGenSceneControllerUninstaller.xml.lzo
echo S_GenGenSceneControllerUninstaller_xml_lzo = b642bin([[ >> L_UninstallerParts.lua
base64 < S_GenGenSceneControllerUninstaller.xml.lzo >> L_UninstallerParts.lua
echo ]]) >> L_UninstallerParts.lua
del S_GenGenSceneControllerUninstaller.xml.lzo


