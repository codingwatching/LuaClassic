-- WIP
local cb = {}

function cb:load()
	registerClPacket(0x13, 'b', function(player, b)
	end)
	registerSvPacket(0x13, 'bb')
end

function cb:prePlayerSpawn(player)
	player:sendPacket(false, 0x13, 1)
end

return cb