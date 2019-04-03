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
		--官方文档说明 partial原功能废弃  等价于body  实测并非如此
		--1   
		-- 	*l 成功 得到数据body  必须以'\n'结尾的字节流  收到时body保留了\n
		-- 	*a 成功 body:nil errMsg:"timeout" partial:data  竟然是这种方式获取的数据
		-- 	*n 正确获取数据的方法  根据协议定义获取消息长度
		--2 失败 body == nil;  partial 空字符串
		--      errMsg可能返回 "closed"  "timeout"  
		--      "Socket is not connected" 这个情况文档没说 不确定什么情况
		--
		-- *a 测试数据  "body:"nil     "errMsg:""timeout"  "partial:" xxxx
		-- 				"body:"nil     "errMsg:""closed"   "partial:" ""
			local body, errMsg, partial = client:receive("*a")
			if errMsg == "closed" or errMsg == "Socket is not connected" then
				break
			end

			if (body and string.len(body) == 0) or
			   (partial and string.len(partial) == 0) then 
			   break
			end

			print(body, errMsg, partial)
			if body and partial then 
				body = body .. partial 
			else
				body = body or partial
			end

			recvt, sendt, status = socket.select({client}, nil, 1)
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


