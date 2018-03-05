#!/bin/sh

sed -r -i.originaln -e '1 s/Version (.*)d$/Version \1/' \
    -f nodebug.sed \
	L_GenGenSceneController.lua \
	L_GenGenSceneControllerInstaller.lua \
	L_GenGenSceneControllerShared.lua
