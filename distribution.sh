#!/bin/sh

dozip()
{
	rm -f "GenGenSceneController_$1.zip"
	zip -q "GenGenSceneController_$1.zip" \
		D_CooperRFWC5.json \
		D_CooperRFWC5.xml \
		D_EvolveLCD1.json \
		D_EvolveLCD1.xml \
		D_GenGenSceneControllerInstaller.json \
		D_GenGenSceneControllerInstaller.xml \
		D_NexiaOneTouch.json \
		D_NexiaOneTouch.xml \
		I_GenGenSceneController.xml \
		I_GenGenSceneControllerInstaller.xml \
		J_GenGenSceneController.js \
		L_GenGenSceneController.lua \
		L_GenGenSceneControllerInstaller.lua \
		L_GenGenSceneControllerShared.lua \
		S_GenGenSceneController.xml \
		S_GenGenSceneControllerInstaller.xml \
		S_GenGenZWaveMonitor.xml
	echo created "GenGenSceneController_$1.zip"
}

if [ -z "$1" ]
 then
    echo "Usage $0 version"
	exit 1
fi

installerversion=${1/./}

sed -i.originaln -r -e "1 s/Version .*/Version ${1}/" -f nodebug.sed L_GenGenSceneController.lua
sed -i.originaln -r -e "1 s/Version .*/Version ${1}/" \
				 -e "s/local GenGenInstaller_Version = [0-9]+/local GenGenInstaller_Version = ${installerversion}/" \
												   -f nodebug.sed L_GenGenSceneControllerInstaller.lua
sed -i.originaln -r -e "1 s/Version .*/Version ${1}/" -f nodebug.sed L_GenGenSceneControllerShared.lua
sed -i.originaln -e "1 s/Version .*/Version ${1}/"                J_GenGenSceneController.js
dozip $1

sed -i.originald -e "1 s/Version .*/Version ${1}d/" -f debug.sed L_GenGenSceneController.lua
sed -i.originald -e "1 s/Version .*/Version ${1}d/" -f debug.sed L_GenGenSceneControllerInstaller.lua
sed -i.originald -e "1 s/Version .*/Version ${1}d/" -f debug.sed L_GenGenSceneControllerShared.lua
sed -i.originald -e "1 s/Version .*/Version ${1}d/"              J_GenGenSceneController.js
dozip ${1}d

rm -rf "../GenGenericSceneController $1"
cp -a ../GenGenericSceneController "../GenGenericSceneController $1"
rm -f "../GenGenericSceneController $1"/*.originaln
rm -f "../GenGenericSceneController $1"/*.originald
rm -f "../GenGenericSceneController $1"/*.bak
rm -f "../GenGenericSceneController $1"/*~
echo created `cygpath -a -w "../GenGenericSceneController $1"`
