--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

function survInvAddBlock(player, id, quantity)
	if not id or id < 1 or id > 65 then return 0 end

	quantity = quantity or 1
	quantity = math.max(math.min(quantity, SURV_MAX_BLOCKS), 0)

	local inv = player.inventory
	if inv[id] >= SURV_MAX_BLOCKS then
		return 0
	end

	local dc = inv[id] + quantity

	if dc > SURV_MAX_BLOCKS then
		quantity = quantity - (dc - SURV_MAX_BLOCKS)
		dc = SURV_MAX_BLOCKS
	end

	if inv[id] == 0 then
		player:setInventoryOrder(id, id)
	end

	inv[id] = dc
	survUpdateBlockInfo(player)

	return quantity
end

saveAdd('inventory', 'tbl:>BB', function(player, id, quantity)
	player.inventory[id] = quantity
end, function(inv, i)
	if i > 0 and inv[i] > 0 then
		return i, inv[i]
	end
end, function(inv)
	local cnt = 0
	for i = 1, ffi.sizeof(inv) - 1 do
		if inv[i] > 0 then
			cnt = cnt + 1
		end
	end
	return cnt
end)
