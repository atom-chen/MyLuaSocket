package.path = "lib/?.lua;lib/socket/?.lua;" .. package.path
package.cpath = "clib/?.dll;" .. package.cpath

require "sllib_base"

local socket = require "socket"

print(_VERSION)
print("Socket Version: ", socket._VERSION)



function createServer(host, port)
	local server, err = socket.bind(host, port, 1024)
	if nil == server then
		print("create server failed:" .. err)
		return nil, err
	end
	server:settimeout(0)
	return server
end

function monitorClient(server)
	local client, err = server:accept()
	if nil == client then
		if err ~= "timeout" then
			print("accept err:" .. err)
		end
		return nil
	end
	--注意：不能设置为0 会导致远程退出后收不到close状态
	client:settimeout(0.01)
	return client
end

function removeClient(name, reason, clients)
	local client = clients[name]
	client:close()
	clients[name] = nil
	print(name .. " removed by " .. reason)
end

function sendMsg(msg, client, name, clients)
    -- 1 成功 idxSuc == data.length
	-- 2 失败 idxSuc == nil; idxLastSuc最后成功的索引 剩下的部分 需要重新发送
    --      errMsg可能返回 "closed"  "timeout"
    -- 测试验证：一次发送最大长度为65536  当data超长时返回 nil,"timeout",65536
    --         所以不用考虑发送截断的情况  游戏数据包没这么长的需求
    --        这也是之前项目一直没发现问题的原因
	local idxSuc, err, idxLastSuc = client:send(msg)
	
	print("send", #msg, msg, idxSuc, err, idxLastSuc)
	if nil == idxSuc then
		if err == "closed" then
			removeClient(name, "send", clients)
			return false
		elseif err == "timeout" then
			-- do nothing
		else
			print("send left msg")
			sendMsg(string.sub(msg, idxLastSuc+1), client, name, clients)
		end 
	end
	return true
end

-- 不带select
function dealMsg2(clients)
	if table.empty(clients) then
		print("wait client to connect")
		socket.sleep(1)
	end

	for name, client in pairs(clients) do
		local recv, err = client:receive("*a")
		--print("receive", recv, err)
		if nil == recv then
			if err == "closed" then
				removeClient(name, "receive", clients)
			elseif err == "timeout" then
				--do nothing
			else
				print("receive", recv, err)
			end
		else
			print(name .. " receive data:" .. recv)
			sendMsg("server back " .. recv .. "\n", client, name, clients)
		end
	end
end

-- 带select版本
function dealMsg(clients)
	if table.empty(clients) then
		print("wait client to connect")
		socket.sleep(1)
	end

	for name, client in pairs(clients) do
		-- 缺陷：远程客户端关闭后 依然可以获取到recv对象 无法知道关闭状态
		-- 解决：通过receive 可以得到 "closed"状态 无论对方是否发送了数据
        local recvt, sendt, status = socket.select({client}, nil, 1)
		--print("select", status, table.size(clients))
		--table.print(recvt)
		--table.print(sendt)

		--status: "select failed" "timeout" nil

		while #recvt > 0 do
		--官方文档说明 partial原功能废弃  等价于body  实测并非如此
		--1   
		-- 	*l 成功 得到数据body 必须以'\n'结尾的字节流  收到时body保留了\n
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
				removeClient(name, "receive", clients)
				break
			end

			if (body and string.len(body) == 0) or
			   (partial and string.len(partial) == 0) then 
			   break
			end

			print(name, body, errMsg, partial)
			if body and partial then 
				body = body .. partial 
			else
				body = body or partial
			end

			sendMsg("server back " .. body .. "\n", client, name, clients)
			recvt, sendt, status = socket.select({client}, nil, 1)
		end
	end
end

function runServer(server)
	local clients = {}
	local idx = 1
	while true do
		local client = monitorClient(server)
		if client then
            local clientIp = client:getpeername()
            
			local name = "client:" .. idx .. " " .. clientIp
			idx = idx + 1
			clients[name] = client
			print("new client connected:" .. name, tostring(client), 
                        " all:" .. table.size(clients))
		end

		dealMsg(clients)
		socket.sleep(1)
	end
end

local host = "127.0.0.1"
local port = "8888"

local server, err = createServer(host, port)
if nil == server then
	return
end

print("Server Start " .. host .. ":" .. port) 
runServer(server)



