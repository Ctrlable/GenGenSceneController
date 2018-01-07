#!/bin/sh

sed -i.originald -e "1 s/Version \([0-9.]\+\)$/Version \1d/" -f debug.sed \
	L_GenGenSceneController.lua \
	L_GenGenSceneControllerInstaller.lua \
	L_GenGenSceneControllerShared.lua
