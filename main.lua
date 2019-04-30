io.output():setvbuf('no')
require('lng')

do
	local function vermismatch()
		print(CON_LJVER)
		os.exit(1)
	end

	if not (jit or jit.version)then
		vermismatch()
	elseif jit.version_num == 20000 then
		local ver = jit.version
		local beta = ver:match('.+%-beta(%d+)')
		beta = tonumber(beta)
		if beta and beta<11 then
			vermismatch()
		end
	elseif jit.version_num < 20000 then
		vermismatch()
	end
end

require('utils')
gz = require('gzip')
lfs = require('lfs')
sql = require('sqlite3')
struct = require('struct')
newWorld = require('world')
newPlayer = require('player')
lanes = require('lanes').configure()
do
	local path = package.searchpath('socket.core', package.cpath)
	if path then
		local lib = package.loadlib(path, 'luaopen_socket_core')
		if not lib then
			lib = package.loadlib(path, 'luaopen_lanes_core')
		end
		if lib then
			socket = lib()
		end
	end
	if not socket then
		error('Can\'t load socket library')
	end
end

require('cpe')
require('conh')
require('hooks')
require('timer')
require('config')
require('packets')
require('commands')
require('permissions')

CTIME = socket.gettime()

function onConnectionAttempt(ip, port)
end

function postPlayerSpawn(player)
	cpe:extCallHook('postPlayerSpawn', player)
	hooks:call('postPlayerSpawn', player)
	local world = worlds[player.worldName]
	world.players = world.players + 1
	world.emptyfrom = nil
end

function prePlayerSpawn(player)
	cpe:extCallHook('prePlayerSpawn', player)
	hooks:call('prePlayerSpawn', player)
end

function onPlayerDespawn(player)
	cpe:extCallHook('postPlayerDespawn', player)
	hooks:call('onPlayerDespawn', player)
	local world = worlds[player.worldName]
	world.players = world.players - 1
	if world.players==0 then
		world.emptyfrom = CTIME
	end
end

function onPlayerDestroy(player)
	local msg = printf(MESG_DISCONN, player:getName(), player.leavereason)
	newChatMessage(msg)
	cpe:extCallHook('onPlayerDestroy', player)
	hooks:call('onPlayerDestroy', player)
	if player.handshaked then
		local x, y, z = player:getPos()
		local ay, ap = player:getEyePos()
		local world = player.worldName
		local otime
		if player.lastOnlineTime then
			otime = floor(player.lastOnlineTime + (CTIME-player.connectTime))
		end
		if x and world and otime then
			assert(sql.insertData(player:getVeriKey(), {'spawnX', 'spawnY', 'spawnZ', 'spawnYaw', 'spawnPitch', 'lastWorld', 'onlineTime'}, {x, y, z, ay, ap, world, otime}))
		end
	end
end

function onPlayerHandshakeDone(player)
	local msg = printf(MESG_CONN, player:getName())
	newChatMessage(msg)
end

function onPlayerChatMessage(player, message)
	local prt = hooks:call('onPlayerChat', player, message)
	if prt~=nil then
		message = tostring(prt)
	end
	message = message:gsub('%%(%x)','&%1')
	printf(os.date('[%H:%M:%S] %%s: %%s'), player:getName(), mc2ansi(message))
	local starts = message:sub(1,1)
	if starts=='#'then
		if player:checkPermission('server.luaexec')then
			local code = message:sub(2)
			if code:sub(1,1)=='='then
				code = 'return '..code:sub(2)
			end
			local chunk, err = loadstring(code)
			if chunk then
				world = worlds[player.worldName]
				self = player
				local ret = {pcall(chunk)}
				self = nil
				world = nil
				for i=2,#ret do
					ret[i] = tostring(ret[i])
				end
				if ret[1] then
					if #ret>1 then
						return MESG_EXECRET%table.concat(ret, ', ', 2)
					else
						return MESG_EXEC
					end
				else
					return MESG_ERROR%ret[2]
				end
			else
				return MESG_ERROR%err
			end
		else
			return err
		end
	elseif starts=='/'then
		local args = message:split(' ')
		if #args>0 then
			local cmd = table.remove(args, 1):sub(2)
			cmd = cmd:lower()
			local cmf = commands[cmd]
			if cmf then
				if player:checkPermission('commands.'+cmd)then
					local out = cmf(player, unpack(args))
					if out~= nil then
						player:sendMessage(out)
					end
				end
			else
				player:sendMessage(MESG_UNKNOWNCMD)
			end
		end
	elseif starts=='>'then
		local wname = message:sub(2)
		wname = wname:lower()
		local succ, msg = player:changeWorld(wname)
		if not succ then
			if msg == 0 then
				player:sendMessage(WORLD_NE)
			end
		end
	elseif starts=='!'then
		newChatMessage(player:getName()+': '+message:sub(2))
	else
		local cmsg = player:getName()+': '+message
		playersForEach(function(ply)
			if ply:isInWorld(player)then
				ply:sendMessage(cmsg)
			end
		end)
	end
end

function onUpdate(dt)
	cpe:extCallHook('onUpdate', dt)
	hooks:call('onUpdate', dt)
	timer.Update(dt)

	if uwa>0 then
		for _, world in pairs(worlds)do
			if world.emptyfrom then
				if CTIME-world.emptyfrom>uwa then
					world:unload()
					world.emptyfrom = nil
				end
			end
		end
	end
end

function onPlayerMove(player, dx, dy, dz)
	hooks:call('onPlayerMove', player, dx, dy, dz)
	local world = getWorld(player)
	local portals = world.data.portals
	if portals then
		local x, y, z = player:getPos()
		for _, portal in pairs(portals)do
			if portal then
				y = floor(y)
				if portal.pt1[1]>=x and portal.pt2[1]<=x then
					if portal.pt1[2]>=y and portal.pt2[2]<=y then
						if portal.pt1[3]>=z and portal.pt2[3]<=z then
							player:changeWorld(portal.tpTo, true)
							return
						end
					end
				end
			end
		end
	end
end

function onPlayerRotate(player, dy, dp)
	hooks:call('onPlayerRotate', player, dy, dp)
end

function onPlayerPlaceBlock(player, x, y, z, id)
	local world = getWorld(player)
	if world.data.readonly then
		player:sendMessage(WORLD_RO, 100)
		return true
	end
	local prt = hooks:call('onPlayerPlaceBlock', player, dy, dp)
	if prt~=nil then
		return prt
	end
	if player.onPlaceBlock then
		return player.onPlaceBlock(x, y, z, id)
	end
end

function wsAcceptClients()
	local cl = wsServer:accept()
	if not cl then return end
	cl:settimeout(0)
	wsHandshake[cl] = {
		state = 'initial',
		headers = {}
	}
end

function wsDoHandshake()
	for cl, data in pairs(wsHandshake)do
		local _, status = cl:receive(0)
		if status == 'closed'then
			wsHandshake[cl] = nil
			return
		end

		if data.state == 'initial'then
			local req = cl:receive()
			if req and req:find('GET%s(.+)%sHTTP/1.1')then
				data.state = 'headers'
			else
				data.state = 'badrequest'
				data.emsg = 'Not a HTTP request'
			end
		elseif data.state == 'headers'then
			local ln = cl:receive()
			if ln==''then
				data.state = 'genresp'
			elseif ln then
				local k, v = ln:match('(.+): (.+)')
				if k then
					data.headers[k] = v
				else
					data.state = 'badrequest'
					data.emsg = 'Invalid header'
				end
			end
		elseif data.state == 'genresp'then
			local hdr = data.headers
			local wskey = hdr['Sec-WebSocket-Key']
			local wsver = hdr['Sec-WebSocket-Version']
			local conn = hdr['Connection']
			local upgrd = hdr['Upgrade']

			if upgrd and wskey and conn and
			upgrd:lower()=='websocket'and
			conn:lower():find('upgrade')and
			tonumber(wsver) == 13 then
				wskey = wskey+WSGUID
				wskey = b64enc(sha1(wskey))
				local response =
				'HTTP/1.1 101 Switching Protocols\r\n'+
				'Upgrade: websocket\r\nConnection: Upgrade\r\n'+
				'Sec-WebSocket-Accept: '+wskey+'\r\n\r\n'
				cl:send(response)
				wsHandshake[cl] = nil
				createPlayer(cl, true)
			else
				data.state = 'badrequest'
			end
		elseif data.state == 'badrequest'then
			local msg = data.emsg or MESG_NOTWSCONN
			local response =
			'HTTP/1.1 400 Bad request\r\n'+
			'Content-Length: %d\r\n\r\n'%#msg+
			msg
			cl:send(response)
			cl:close()
			wsHandshake[cl] = nil
		end
	end
end

function createPlayer(cl,isWS)
	local ip = cl:getpeername()
	if not onConnectionAttempt(ip)then
		local player = newPlayer(cl)
		player.isWS = isWS
		player.ip = ip
		local nid = setID(player)
		if nid>0 then
			player:init()
			player:setID(nid)
			IDS[nid] = player
			players[player] = nid
		else
			player:kick(KICK_SFULL)
		end
	else
		local rawPacket = generatePacket(0x0e, KICK_CONNREJ)
		if isWS then
			cl:send(encodeWsFrame(rawPacket, 0x02))
		else
			cl:send(rawPacket)
		end
	end
end

function handleConsoleCommand(cmd)
	args = cmd:split('%s')
	cmd = table.remove(args, 1)
	if not cmd then return end
	argstr = table.concat(args,' ')
	cmd = cmd:lower()

	if cmd == 'stop'then
		_STOP = true
	elseif cmd == 'restart'then
		_STOP = 'restart'
	elseif cmd == 'loadworld'then
		if #args == 1 then
			local succ, err = loadWorld(args[1])
			if not succ then
				print(err)
			end
		end
	elseif cmd == 'unloadWorld'then
		if #args == 1 then
			local succ, err = unloadWorld(args[1])
			if not succ then
				print(err)
			end
		end
	elseif cmd == 'list'then
		print(CMD_WORLDLST)
		for wn, world in pairs(worlds)do
			if wn~='default'then
				local dfld = (worlds['default']==world and' (default)')or''
				print('   - '+wn+dfld)
			end
		end
	elseif cmd == 'say'then
		if #args > 0 then
			newChatMessage(argstr)
		else
			print(CON_USE%CU_SAY)
		end
	elseif cmd == 'addperm'then
		if #args == 2 then
			permissions:addFor(args[1], args[2])
		else
			print(CON_USE%CU_ADDPERM)
		end
	elseif cmd == 'delperm'then
		if #args == 2 then
			permissions:addFor(args[1], args[2])
		else
			print(CON_USE%CU_DELPERM)
		end
	elseif cmd == 'put'then
		if #args == 2 then
			local player = getPlayerByName(args[1])
			if player then
				player:changeWorld(args[2])
			else
				print(MESG_PLAYERNF)
			end
		else
			print(CON_USE%CU_PUT)
		end
	elseif cmd == 'kick'then
		if #args > 0 then
			local p = getPlayerByName(args[1])
			local reason = KICK_NOREASON
			if p then
				if #args > 1 then
					reason = table.concat(args, ' ', 2)
				end
				p:kick(reason)
			else
				print(MESG_PLAYERNF)
			end
		else
			print(CON_USE%CU_KICK)
		end
	elseif cmd == 'regen'then
		if #args >= 1 then
			local world = getWorld(args[1])
			local gen = args[2]or'default'
			local seed = tonumber(args[3]or os.time())
			local ret, tm = regenerateWorld(world, gen, seed)
			if not ret then
				print(CMD_GENERR%tostring(tm))
			else
				print(MESG_DONEIN%(tm*1000))
			end
		else
			print(CON_USE%CU_REGEN)
		end
	elseif cmd == 'tp'then
		if #args == 2 then
			local pn1 = args[1]
			local pn2 = args[2]
			local p1 = getPlayerByName(pn1)
			local p2 = getPlayerByName(pn2)
			if not p1 then
				print(MESG_PLAYERNFA%pn1)
				return
			end
			if not p2 then
				print(MESG_PLAYERNFA%pn2)
				return
			end
			local wp2 = getWorld(p2)
			if getWorld(p1)~=wp2 then
				p1:changeWorld(wp2, false, p2:getPos())
			else
				p1:teleportTo(p2:getPos())
			end
		else
			print(CON_USE%CU_TP)
		end
	elseif cmd == 'help' or cmd == '?'then
		for k, v in pairs(_G)do
			if k:sub(1,3) == 'CU_'then
				print(v)
			end
		end
	elseif cmd:sub(1,1) == '#'then
		local code = cmd:sub(2)
		if code:sub(1,1)=='='then
			code = 'return '..code:sub(2)
		end
		local chunk, err = loadstring(code)
		if chunk then
			local ret = {pcall(chunk)}
			for i=2,#ret do
				ret[i] = tostring(ret[i])
			end
			if ret[1] then
				print(table.concat(ret, ', ', 2))
			else
				print(MESG_ERROR%ret[2])
			end
		else
			print(MESG_ERROR%err)
		end
	else
		print(MESG_UNKNOWNCMD)
	end
end

function acceptClients()
	local cl = server:accept()
	if not cl then return end
	cl:settimeout(0)
	createPlayer(cl, false)
end

function serviceMessages()
	playersForEach(function(player)
		player:serviceMessages()
	end)
end

function init()
	players, IDS = {}, {}
	worlds, generators = {}, {}

	hooks:create('onPlayerRotate')
	hooks:create('onPlayerMove')
	hooks:create('onPlayerChat')
	hooks:create('onPlayerPlaceBlock')
	hooks:create('onPlayerDespawn')
	hooks:create('prePlayerSpawn')
	hooks:create('postPlayerSpawn')
	hooks:create('onUpdate')

	permissions:parse()

	config
	:registerTypeFor('generator-threads-count', 'number')
	:registerTypeFor('gzip-compression-level', 'number')
	:registerTypeFor('allow-websocket', 'boolean')
	:registerTypeFor('websocket-port', 'number')
	:registerTypeFor('player-timeout', 'number')
	:registerTypeFor('server-port', 'number')
	:registerTypeFor('server-name', 'string')
	:registerTypeFor('server-motd', 'string')
	:registerTypeFor('max-players', 'number')
	:registerTypeFor('level-names', 'string')
	:registerTypeFor('level-types', 'string')
	:registerTypeFor('level-sizes', 'string')
	:registerTypeFor('level-seeds', 'string')
	:registerTypeFor('cpe-force', 'boolean')
	:registerTypeFor('server-ip', 'string')
	:parse()

	uwa = config:get('unload-world-after', 600)
	local ip = config:get('server-ip', '0.0.0.0')
	local port = config:get('server-port', 25565)
	server = bindSock(ip, port)

	local ws = config:get('allow-websocket', true)
	if ws then
		WSGUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'
		wsPort = config:get('websocket-port', port+1)
		wsServer = bindSock(ip, wsPort)
		wsHandshake = {}
		require('helper')
	end

	io.write(CON_WLOAD)
	local sdlist = config:get('level-seeds', '')
	sdlist = sdlist:split(',')

	local wlist = config:get('level-names', 'world')
	wlist = wlist:split(',')

	local tlist = config:get('level-types', 'default')
	tlist = tlist:split(',')

	local slist = config:get('level-sizes', '256x256x256')
	slist = slist:split(',')

	for num, wn in pairs(wlist)do
		wn = wn:lower()
		io.write('\n\t',wn,': ')
		local st = socket.gettime()
		local world
		local lvlh = io.open('worlds/'+wn+'.map', 'rb')
		if lvlh then
			world = newWorld(lvlh, wn)
		else
			local gtype = tlist[num]or'default'
			local dims = slist[num]or'256x256x256'
			local generator = generators[gtype]or loadGenerator(gtype)
			local x, y, z = dims:match('(%d+)x(%d+)x(%d+)')
			x = tonumber(x)
			y = tonumber(y)
			z = tonumber(z)
			if not(x and y and z and generator)then
				error(CON_PROPINVALID)
			end
			world = newWorld()
			world:setName(wn)
			if world:createWorld({dimensions={x,y,z}})then
				generator(world,sdlist[num]or CTIME)
			end
		end
		if world then
			worlds[wn] = world
			world.emptyfrom = CTIME
			if num==1 then
				worlds['default'] = world
			end
			io.write(MESG_DONEIN%{(socket.gettime()-st)*1000})
		end
	end
	io.write('\r\n')
	if not worlds['default']then
		print(CON_WLOADERR)
		os.exit(1)
	end
	cpe:init()
	local add = ''
	if wsServer then
		add = CON_WSBINDSUCC%wsPort
	end
	printf(CON_BINDSUCC, ip, port, add)
	cmdh = initCmdHandler(handleConsoleCommand)
	print(CON_HELP)
	CTIME = socket.gettime()
end

succ, err = xpcall(function()
	while not _STOP do
		if not INITED then INITED=true init()end
		ETIME = CTIME
		CTIME = socket.gettime()
		if ETIME then
			dt = CTIME-ETIME
			dt = math.min(.1, dt)
			onUpdate(dt)
		end
		acceptClients()
		serviceMessages()
		if wsServer then
			wsAcceptClients()
			wsDoHandshake()
		end
		if cmdh then
			cmdh()
		end
		socket.sleep(.01)
	end
end,debug.traceback)

ecode = 0
print(CON_SVSTOP)
playersForEach(function(ply)
	if _STOP == 'restart'then
		ply:kick(KICK_SVRST)
	else
		ply:kick(KICK_SVSTOP)
	end
end)
if config:save()and permissions:save()then
	print(CON_SAVESUCC)
else
	print(CON_SAVEERR)
end
for wname, world in pairs(worlds)do
	if wname ~= 'default'then
		io.write(CON_WSAVE%wname)
		local s = socket.gettime()
		if world:save()then
			printf(MESG_DONEIN, (socket.gettime()-s)*1000)
		else
			print(IE_UE)
		end
	end
end
sql.close()
if server then server:close()end
if wsServer then wsServer:close()end

if not succ then
	err = tostring(err)
	if not err:find('interrupted')then
		print(err)
		ecode = 1
	end
end
if _STOP=='restart'then
	os.execute(arg[-1]..' '..arg[0])
end
os.exit(ecode)
