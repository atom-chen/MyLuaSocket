package.path = "lib/?.lua;lib/socket/?.lua;" .. package.path
package.cpath = "clib/?.dll;" .. package.cpath

require "sllib_base"

local socket = require "socket"

print(_VERSION)
print("Socket Version: ", socket._VERSION)


function isIpv6Only()
	local addrinfo, err = socket.dns.getaddrinfo(host)
	if addrinfo then
		for _, addr in ipairs(addrinfo) do
			if addr.family == "inet" then
				return false
			else
				return true
			end
		end
	end
	return false
end

function createClient(host, port)
	local client = nil
	local errMsg = nil
	local mode = 1
	if mode == 1 then
		client, errMsg = socket.connect(host, port)
		if nil == client then
			return nil, errMsg
		end
	else
		if isIpv6Only(host) then
			client = new socket.tcp6()
		else
			client = new socket.tcp()
		end
		local status, errMsg = client:connect(host, port)
		local suc = status == 1 or errMsg == "already connected"
		if not suc then
			return nil, errMsg
		end
	end

	return client
end


function runClient(client)
	client:settimeout(0)
	  
	print("Press enter after input something:")
	local input, recvt, sendt, status
	local closed = false
	while true do
		if closed then
			return true
		end

		input = io.read()
		if input == "close" then
			return true --end app
		end

		if #input > 0 then
			-- idxSuc是个浮点数 且长度和发送字符相同
			-- send("aa\n") ==> idxSuc:3.0
			local idxSuc, errMsg, idxLastSuc = client:send(input .. "\n")
			print("send", #input, idxSuc, errMsg, idxLastSuc)
			if errMsg == "closed" then
				print("server is closed")
				break
			end
		end
		 
		recvt, sendt, status = socket.select({client}, nil, 1)
		while #recvt > 0 do
			local response, errMsg = client:receive("*l")
			if response then
				print(response)
				recvt, sendt, status = socket.select({client}, nil, 1)
			else
				print("receive failed", errMsg)
				if errMsg == "closed" then
					closed = true
					break
				end
			end
		end
	end
	return false
end


local host = "127.0.0.1"
local port = 8888

while true do
	local client, err = createClient(host, port)
	if client == nil then
		print("connect failed", host, port, err)
		print("input any key to retry!")
		io.read()
	else
		print("Connected to " .. host .. ":" .. port) 
		if runClient(client) then
			client:close()
			break
		end
	end
end


