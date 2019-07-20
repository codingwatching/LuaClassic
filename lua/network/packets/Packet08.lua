--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

return function(player, id, x, y, z, yaw, pitch)
	player:setPos(x / 32, y / 32, z / 32)
	player:setEyePos((yaw / 255) * 360, (pitch / 255) * 360)

	if player:isSupported('HeldBlock')then
		if not isValidBlockID(id)then
			id = 0
		end
		
		if player.heldBlock ~= id then
			player.heldBlock = id
			hooks:call('onHeldBlockChange', player, id)
		end
	end

	local pid = player:getID()
	local pck, cpepck

	playersForEach(function(ply)
		if not ply.isSpawned then return end
		if ply:isInWorld(player)then
			if ply:isSupported('ExtEntityPositions')then
				cpepck = cpepck or cpe:generatePacket(0x08, pid, x, y, z, yaw, pitch)
				ply:sendNetMesg(cpepck, #cpepck)
			else
				pck = pck or generatePacket(0x08, pid, x, y, z, yaw, pitch)
				ply:sendNetMesg(pck, #pck)
			end
		end
	end)
end
