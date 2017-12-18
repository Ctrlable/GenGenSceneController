#!/bin/sh
Stop_cmh.sh
cp /etc/cmh-ra/cmh-ra.conf.gdb /etc/cmh-ra/cmh-ra.conf
Start_cmh.sh
gdb /usr/bin/LuaUPnP
