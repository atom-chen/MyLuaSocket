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
	client:settimeout(0.1)
	return client
end

function removeClient(name, reason, clients)
	local client = clients[name]
	client:close()
	clients[name] = nil
	print(name .. " removed by " .. reason)
end

function sendMsg(msg, client, name, clients)
	local idxSuc, err, idxLastSuc = client:send(msg)
	--print("send", #msg, idxSuc, err, idxLastSuc)
	if nil == idxSuc then
		if err == "closed" then
			removeClient(name, "send", clients)
			return false
		elseif err == "timeout" then
			-- do nothing
		else
			print("send left msg")
			sendMsg(string.sub(msg, idxLastSuc+1), client, name, clients)
		end end
	return true
end

-- 不带select
function dealMsg(clients)
	if table.empty(clients) then
		print("wait client to connect")
		socket.sleep(1)
	end

	for name, client in pairs(clients) do
		local recv, err = client:receive("*l")
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
function dealMsg2(clients)
	if table.empty(clients) then
		print("wait client to connect")
		socket.sleep(1)
	end

	for name, client in pairs(clients) do
		-- 缺陷：远程客户端关闭后 依然可以获取到recv对象 无法知道关闭状态
		-- 解决：通过receive 可以得到 "closed"状态 无论对方是否发送了数据
        local recvt, sendt, status = socket.select({client}, nil, 1)
		--print("select", status, table.size(clients))
		table.print(recvt)
		table.print(sendt)

		--status: "select failed" "timeout" nil
		if #recvt > 0 then
            local recv, err = client:receive("*l")
			if nil == recv then
				if err == "closed" then
					removeClient(name, "receive", clients)
				end
			else
				print(name .. " receive data:" .. recv)
				sendMsg("server back " .. recv .. "\n", client, name, clients)
			end
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



