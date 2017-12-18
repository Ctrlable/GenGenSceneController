--SetDefault
luup.call_action("urn:micasaverde-com:serviceId:ZWaveNetwork1", "SendData", {Data = "0x00 0x42 0x01"}, 1)
luup.call_action("urn:micasaverde-com:serviceId:HomeAutomationGateway1", "Reload", {}, 0)

--RequestNetWorkUpdate
luup.call_action("urn:micasaverde-com:serviceId:ZWaveNetwork1", "SendData", {Data = "0x00 0x53 0x01"}, 1)

--NVM_get_id
luup.call_action("urn:micasaverde-com:serviceId:ZWaveNetwork1", "SendData", {Data = "0x00 0x29"}, 1)

--GetControllerCapabilities
luup.call_action("urn:micasaverde-com:serviceId:ZWaveNetwork1", "SendData", {Data = "0x00 0x05"}, 1)

--RequestNodeNeighborUpdate
delay = 0
for device_num, device in pairs(luup.devices) do
  if device.device_num_parent and
       device_num > 2 and
	luup.devices[device.device_num_parent] and
	luup.devices[device.device_num_parent].device_type == "urn:schemas-micasaverde-com:device:ZWaveNetwork:1" then
    luup.call_delay("NodeNeighborUpdate", delay, tostring(device.id))
    delay = delay + 10
  end
end

function NodeNeighborUpdate(device_string)
  luup.call_action("urn:micasaverde-com:serviceId:ZWaveNetwork1", "SendData", {Data = "0x00 0x48 "..device_string.." "..device_string}, 1)
end

--LockRoute
luup.call_action("urn:micasaverde-com:serviceId:ZWaveNetwork1", "SendData", {Data = "0x00 0x90 0x00"}, 1)


--Delete return route
luup.call_action("urn:micasaverde-com:serviceId:ZWaveNetwork1", "SendData", {Data = "0x0 0x47 0xbd 0x2"}, 1)
luup.sleep(2000)
--Assign return route
luup.call_action("urn:micasaverde-com:serviceId:ZWaveNetwork1", "SendData", {Data = "0x0 0x46 0xbd 0x1 0x2"}, 1)
luup.sleep(2700)
--Manufacturer Specifc Get
luup.call_action("urn:micasaverde-com:serviceId:ZWaveNetwork1", "SendData", {Node = 0xbd, Data = "0x72 0x04"}, 1)
