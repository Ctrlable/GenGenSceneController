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


--configuration_get
for i = 1, 5 do
	luup.call_action("urn:micasaverde-com:serviceId:ZWaveNetwork1", "SendData", {Node = 0x10, Data = "0x70 0x05 "..i}, 1)
	luup.sleep(1000)
end

--Association get
for i = 1, 50 do
	luup.call_action("urn:micasaverde-com:serviceId:ZWaveNetwork1", "SendData", {Node = 0xdf, Data = "0x85 0x02 "..i}, 1)
	luup.sleep(200)
end

--Association specific group get
	luup.call_action("urn:micasaverde-com:serviceId:ZWaveNetwork1", "SendData", {Node = 0xdf, Data = "0x85 0x0B"}, 1)

--Association group info group name, group info get
for i = 1, 50 do
	luup.call_action("urn:micasaverde-com:serviceId:ZWaveNetwork1", "SendData", {Node = 0xdf, Data = "0x59 0x01 "..i}, 1)
	luup.sleep(300)
	luup.call_action("urn:micasaverde-com:serviceId:ZWaveNetwork1", "SendData", {Node = 0xdf, Data = "0x59 0x03 0x00 "..i}, 1)
	luup.sleep(300)
end

--Configuration get
for i = 1, 50 do
	luup.call_action("urn:micasaverde-com:serviceId:ZWaveNetwork1", "SendData", {Node = 0xdf, Data = "0x70 0x05 "..i}, 1)
	luup.sleep(200)
end

--Association get, Association group group name get, Association group info get, configuration get.
local delay = 1000
for i = 1, 16 do
	luup.call_action("urn:micasaverde-com:serviceId:ZWaveNetwork1", "SendData", {Node = 0xdf, Data = "0x59 0x01 "..i}, 1)
	luup.sleep(delay)
	luup.call_action("urn:micasaverde-com:serviceId:ZWaveNetwork1", "SendData", {Node = 0xdf, Data = "0x85 0x02 "..i}, 1)
	luup.sleep(delay)
	luup.call_action("urn:micasaverde-com:serviceId:ZWaveNetwork1", "SendData", {Node = 0xdf, Data = "0x85 0x02 "..i+15}, 1)
	luup.sleep(delay)
	luup.call_action("urn:micasaverde-com:serviceId:ZWaveNetwork1", "SendData", {Node = 0xdf, Data = "0x85 0x02 "..i+30}, 1)
	luup.sleep(delay)
	if i > 1 then
		luup.call_action("urn:micasaverde-com:serviceId:ZWaveNetwork1", "SendData", {Node = 0xdf, Data = "0x70 0x05 "..i}, 1)
		luup.sleep(delay)
	end
	luup.sleep(delay)
end


-- Configuration set
luup.call_action("urn:micasaverde-com:serviceId:ZWaveNetwork1", "SendData", {Node = 0xdf, Data = "0x70 0x04 15 1 0"}, 1)

	luup.call_action("urn:micasaverde-com:serviceId:ZWaveNetwork1", "SendData", {Node = 0xdf, Data = "0x85 0x01 31 1"}, 1)

-- Central scene supported get
luup.call_action("urn:micasaverde-com:serviceId:ZWaveNetwork1", "SendData", {Node = 0xdf, Data = "0x5B 0x01"}, 1)
