SURV_MAX_HEALTH = 10
SURV_MAX_OXYGEN = 10

SURV_ACT_NONE  = -1
SURV_ACT_BREAK = 1

SURV_DMG_PLAYER = 1
SURV_DMG_FALL = 2
SURV_DMG_WATER = 3
SURV_DMG_LAVA = 4
SURV_DMG_FIRE = 5

CMD_GIVE = '%d %s block(-s) given to &a%s'

local survBlocknames = {
	'Stone', 'Grass', 'Dirt', 'Cobblestone',
	'Planks', 'Sapling', 'Bedrock', 'Water',
	'Water', 'Lava', 'Lava', 'Sand', 'Gravel',
	'Gold ore', 'Iron ore', 'Coal ore', 'Log',
	'Leaves', 'Sponge', 'Glass', 'Red wool',
	'Orange wool', 'Yellow wool', 'Lime wool',
	'Green wool', 'Teal wool', 'Aqua wool',
	'Cyan wool', 'Blue wool', 'Indigo wool',
	'Violet wool', 'Magenta wool', 'Pink wool',
	'Black wool', 'Gray wool', 'White wool',
	'Dandelion', 'Rose', 'Brown mushroom',
	'Red mushroom', 'Gold block', 'Iron block',
	'Double slab', 'Slab', 'Brick', 'TNT',
	'Bookshelf', 'Mossy stone', 'Obsidian',
	'Cobblestone slab', 'Rope', 'Sandstone',
	'Snow', 'Fire', 'Light pink wool',
	'Forest green wool', 'Brown wool',
	'Deep blue', 'Turquoise wool', 'Ice',
	'Ceramic tile', 'Magma', 'Pillar',
	'Crate', 'Stone brick'
}

local survBlockDrop = {
	[1] = 4,
	[18] = function()
		return (math.random(0, 100) < 20 and 6)or 18
	end
}

local survMiningSpeed = {
	[-1] =  1,
	[1]  =  7.5,
	[2]  =  0.9,
	[3]  =  0.75,
	[4]  =  10,
	[5]  =  3,
	[6]  =  0,
	[12] =  0.75,
	[13] =  0.9,
	[14] =  15,
	[15] =  15,
	[16] =  15,
	[17] =  3,
	[18] =  0.35,
	[20] =  0.45,

	[41] = 15,
	[42] = 25,
	[43] = 10,
	[44] = 10,
	[45] = 10,
	[46] = 0,
	[47] = 3,
	[48] = 10,
	[49] = 250,
	[50] = 10,
	[51] = 0,
	[54] = 0
}

local survMiningSpeedWithTool = {
	[1]  =  1.15,
	[4]  =  1.5,
	[5]  =  3,
	[14] =  2.25,
	[15] =  2.25,
	[16] =  2.25,

	[41] = 2.25,
	[42] = 3.75,
	[43] = 3,
	[44] = 3,
	[45] = 3,
	[48] = 3,
	[50] = 3,
}

local survCraft = {
	[1] = {
		needs = {
			[54] = 1,
			[4] = 1
		},
		count = 1
	},
	[5] = {
		needs = {
			[17] = 1
		},
		count = 4
	},
	[6] = {
		needs = {
			[18] = 1
		},
		count = 1
	},
	[13] = {
		needs = {
			[3] = 1,
			[12] = 1
		},
		count = 1
	},
	[20] = {
		needs = {
			[54] = 1,
			[12] = 1
		},
		count = 1
	},
	[41] = {
		needs = {
			[5] = 1,
			[14] = 3
		},
		count = 1
	},
	[42] = {
		needs = {
			[5] = 1,
			[15] = 3
		},
		count = 1
	},
	[43] = {
		needs = {
			[5] = 1,
			[1] = 3
		},
		count = 1
	},
	[47] = {
		needs = {
			[5] = 4
		}
	},
	[50] = {
		needs = {
			[4] = 1
		},
		count = 2
	}
}

for i = 21, 36 do
	survMiningSpeed[i] = 1.15
end
for i = 37, 40 do
	survMiningSpeed[i] = 0
end

local function distance(x1, y1, z1, x2, y2, z2)
	return math.sqrt( (x2 - x1) ^ 2 + (y2 - y1) ^ 2 + (z2 - z1) ^ 2 )
end

local function survUpdateHealth(player)
	local int, fr = math.modf(player.health)
	local dmg = SURV_MAX_HEALTH - int - ceil(fr)
	local str = '&8' .. ('\3'):rep(dmg)
	if fr ~= 0 then str = str .. '&4\3' end
	str = str .. '&c' ..('\3'):rep(SURV_MAX_HEALTH - dmg - ceil(fr))
	player:sendMessage(str, MT_STATUS2)
end

local function survUpdateBlockInfo(player)
	local id = player:getHeldBlock()
	if id > 0 then
		local quantity = player.inventory[id]
		local name = survBlocknames[id]or'UNKNOWN_BLOCK'
		player:sendMessage('Block: ' .. name, MT_BRIGHT3)
		player:sendMessage('Quantity: ' .. quantity, MT_BRIGHT2)
		player:setBlockPermissions(id, quantity > 0 and (id < 7 or id > 11), false)
	else
		player:sendMessage('', MT_BRIGHT3)
		player:sendMessage('', MT_BRIGHT2)
	end
end

local function survUpdateOxygen(player)
	if player.oxygen == SURV_MAX_OXYGEN then
		player:sendMessage('', MT_BRIGHT1)
		player.oxyshow = false
	else
		local clr = '&a'
		if player.oxygen <= 3 then
			clr = '&c'
		elseif player.oxygen <= 6 then
			clr = '&e'
		end
		player:sendMessage((clr .. 'Oxygen: %.1f'):format(player.oxygen), MT_BRIGHT1)
	end
end

local function survStopBreaking(player)
	if player.action ~= SURV_ACT_BREAK then return end
	player.breakProgress = 0
	player.action = SURV_ACT_NONE
	player:sendMessage('', MT_STATUS3)
	timer.Remove(player:getName() .. '_surv_brk')
end

local function survRespawn(player)
	player.health = SURV_MAX_HEALTH
	player.oxygen = SURV_MAX_OXYGEN
	ffi.fill(player.inventory, 65)
	survUpdateBlockInfo(player)
	survUpdateHealth(player)
	survStopBreaking(player)
	player:moveToSpawn()
end

local function survCanCraft(player, bid, quantity)
	local inv = player.inventory
	local recipe = survCraft[bid]
	local lacks

	if recipe then
		local canCraft = true
		for nId, ammount in pairs(recipe.needs)do
			local cnt = quantity * ammount
			if inv[nId] < cnt then
				canCraft = false
				lacks = lacks or''
				lacks = lacks .. ('%d %s, '):format(cnt - inv[nId], survBlocknames[nId])
			end
		end
		return canCraft, lacks and lacks:sub(1, -3)
	end
	return false
end

local timers = {'_blocksdamage', '_hp_regen'}

local function survPauseTimers(player)
	for i = 1, #timers do
		timer.Pause(timers[i])
	end
end

local function survResumeTimers(player)
	for i = 1, #timers do
		timer.Resume(timers[i])
	end
end

local function survRemoveTimers(player)
	for i = 1, #timers do
		timer.Remove(timers[i])
	end
end

local function getKiller(attacker, dmgtype)
	if dmgtype == SURV_DMG_PLAYER then
		return 'player ' .. attacker:getName()
	elseif dmgtype == SURV_DMG_FALL then
		return 'gravitation'
	elseif dmgtype == SURV_DMG_WATER then
		return 'water'
	elseif dmgtype == SURV_DMG_LAVA then
		return 'lava'
	elseif dmgtype == SURV_DMG_FIRE then
		return 'fire'
	end
	return '&dmysterious killer' -- Why not?
end

local function survDamage(attacker, victim, damage, dmgtype)
	if victim.isInGodmode then return false end
	victim.health = victim.health - damage
	survUpdateHealth(victim)
	victim:setEnvProp(MEP_MAXFOGDIST, 1)
	victim:setEnvColor(EC_FOG, 255, 40, 40)
	timer.Create(victim:getName() .. '_hurt', 1, .07, function()
		victim:setEnvProp(MEP_MAXFOGDIST, 0)
		victim:setEnvColor(EC_FOG, -1, -1, -1)
	end)
	if victim.health <= 0 then
		survRespawn(victim)
		playersForEach(function(ply)
			if ply:isInWorld(victim)then
				ply:sendMessage(('Player %s killed by %s.'):format(victim, getKiller(attacker, dmgtype)))
			end
		end)
	end
	return true
end

local function survBreakBlock(player, x, y, z)
	local world = getWorld(player)
	local bid = world:getBlock(x, y, z)
	bid = survBlockDrop[bid]or bid
	if type(bid) == 'function'then
		bid = bid()
	end

	if bid ~= 0 then
		local heldBlock = player:getHeldBlock()
		if heldBlock ~= bid and (41 > heldBlock or heldBlock > 43) then
			player:holdThis(bid)
		end

		player.inventory[bid] = math.min(player.inventory[bid] + 1, 64)
		survUpdateBlockInfo(player)
	end
	survStopBreaking(player)
	hooks:call('onPlayerPlaceBlock', player, x, y, z, 0)
	world:setBlock(x, y, z, 0)
end

local function survBlockAction(player, button, action, x, y, z)
	local world = getWorld(player)
	local bid = world:getBlock(x, y, z)
	if bid > 6 and bid < 12 then
		return
	end
	local cb = player.currClickedBlock
	cb.x, cb.y, cb.z = x, y, z

	if action == 0 and player.inventory[bid] < 255 then
		if player.action == SURV_ACT_NONE then
			if button == 0 then
				player.action = SURV_ACT_BREAK
				player.breakProgress = 0
				local lb = player.lastClickedBlock
				lb.x, lb.y, lb.z = x, y, z
				local tmSpeed = (survMiningSpeed[bid]or survMiningSpeed[-1])
				if tmSpeed <= 0 then
					survBreakBlock(player, x, y, z)
					return
				end
				if player:getFluidLevel() > 1 then
					tmSpeed = tmSpeed * 5
				end
				for i = 1, 3 do
					if player:getHeldBlock() == 40 + i and player.inventory[40 + i] > 0 then
						if survMiningSpeedWithTool[bid] then
							tmSpeed = survMiningSpeedWithTool[bid] / 6 * i
						else
							tmSpeed = tmSpeed / 12 * i
						end
						break
					end
				end

				timer.Create(player:getName() .. '_surv_brk', 11, tmSpeed / 10, function()
					local lb = player.lastClickedBlock
					if lb.x ~= cb.x or lb.y ~= cb.y or lb.z ~= cb.z then
						survStopBreaking(player)
						return
					end

					if player.breakProgress == 100 then
						survBreakBlock(player, x, y, z)
					else
						player.breakProgress = math.min(player.breakProgress + 10, 100)
						player:sendMessage(('Mining block: %d%%...'):format(player.breakProgress), MT_STATUS3)
					end
				end)
			end
		end
	elseif action == 1 then
		if player.action == SURV_ACT_BREAK then
			survStopBreaking(player)
		end
	end
end

local p_mt = getPlayerMT()

p_mt.survDamage = function(player, attacker, dmg, dmgtype)
	survDamage(attacker, player, dmg, dmgtype)
end

p_mt.survRespawn = survRespawn

return function()
	log.info('Survival Test gamemode Loaded!')
	hooks:add('onPlayerCreate', 'survival', function(player)
		player.lastClickedBlock = newVector(0, 0, 0)
		player.currClickedBlock = newVector(0, 0, 0)
		player.inventory = ffi.new('uint8_t[65]')
		player.health = SURV_MAX_HEALTH
		player.oxygen = SURV_MAX_OXYGEN
		player.action = SURV_ACT_NONE
		player.oxyshow = false
	end)

	hooks:add('onPlayerHandshakeDone', 'survival', function(player)
		if not player:isSupported('PlayerClick')or
		not player:isSupported('FullCP437')or
		not player:isSupported('HackControl')or
		not player:isSupported('EnvColors')or
		not player:isSupported('EnvMapAspect')or
		not player:isSupported('HeldBlock')then
			player:kick('Your client does not support required CPE exts.', true)
			return
		end
		for i = 1, 65 do
			player:setBlockPermissions(i, false, false)
		end

		local name = player:getName()
		timer.Create(name .. '_hp_regen', -1, 5, function()
			local int, fr = math.modf(player.health)
			if fr ~= 0 and fr ~= .5 then fr = .5 end
			local ahp = math.min(SURV_MAX_HEALTH, int + fr + .5)
			player.health = ahp
			survUpdateHealth(player)
		end)

		timer.Create(name .. '_blocksdamage', -1, .4, function()
			local x, y, z = player:getPos()
			x, y, z = floor(x), floor(y - 1), floor(z)
			local world = getWorld(player)

			if world:getBlock(x, y, z) == 54
			or world:getBlock(x, y + 1, z) == 54 then
				survDamage(nil, player, .5, SURV_DMG_FIRE)
			end

			local level, isLava = player:getFluidLevel()
			if isLava then
				survDamage(nil, player, 1, SURV_DMG_LAVA)
				return
			end
			if level > 1 then
				player.oxygen = math.max(player.oxygen - .2, 0)
				if player.oxygen == 0 then
					survDamage(nil, player, 1, SURV_DMG_WATER)
				end
				survUpdateOxygen(player)
				player.oxyshow = true
			else
				if player.oxyshow then
					player.oxygen = math.min(player.oxygen + .05, SURV_MAX_OXYGEN)
					survUpdateOxygen(player)
				end
			end
		end)
	end)

	hooks:add('onPlayerDestroy', 'survival', function(player)
		survStopBreaking(player)
		survRemoveTimers(player)
	end)
	hooks:add('onPlayerLanded', 'survival', function(player, speedY)
		local blocks = speedY ^ 2 / 250
		if blocks > 3.5 then
			survDamage(nil, player, blocks / 2 - 0.5, SURV_DMG_FALL)
		end
	end)

	hooks:add('postPlayerFirstSpawn', 'survival', function(player)
		player:sendMessage('LuaClassic Survival Dev', MT_STATUS1)
	end)

	hooks:add('postPlayerSpawn', 'survival', function(player)
		survUpdateHealth(player)
		local h = (player:checkPermission('player.hacks', true)and 1)or 0
		player:hackControl(h, h, h, h, h, -1)
		survResumeTimers(player)
	end)

	hooks:add('onPlayerDespawn', 'survival', function(player)
		survStopBreaking(player)
		survPauseTimers(player)
	end)

	hooks:add('onPlayerClick', 'survival', function(player, ...)
		local button  = select(1, ...)
		local action  = select(2, ...)
		local tgent   = select(5, ...)
		local x, y, z = select(6, ...)

		if action == 1 then
			survStopBreaking(player)
			return
		end

		local dist_player = 9999
		local dist_block = 9999
		local tgplayer

		if x ~= -1 and y ~= -1 and z ~= -1 then
			dist_block = distance(x + .5, y + .5, z + .5, player:getPos())
		else
			survStopBreaking(player)
		end

		if tgent > 0 then
			tgplayer = getPlayerByID(tgent)
			if tgplayer then
				dist_player = distance(x, y, z, tgplayer:getPos())
			end
		end

		if dist_block < dist_player then
			survBlockAction(player, button, action, x, y, z)
		elseif dist_player < dist_block then
			if button == 0 and action == 0 then
				if not player.nextHit then
					player.nextHit = 0
				end
				if tgplayer and CTIME > player.nextHit then
					-- critical damage
					local blocks = player.speedY2 and player.speedY2 ^ 2 / 250 or 0
					
					survDamage(player, tgplayer, 1 + blocks, SURV_DMG_PLAYER)
					survStopBreaking(player)
					
					-- knockback
					local x, y, z = player:getPos()
					local tx, ty, tz = tgplayer:getPos()
					local dx, dy, dz = tx - x, ty - y, tz - z
					local length = math.sqrt(dx^2 + dy^2 + dz^2)
					dx, dy, dz = dx / length, dy / length, dz / length
					
					tgplayer:teleportTo(tx + dx, ty + 0.5, tz + dz)
					
					-- timeout
					player.nextHit = CTIME + 0.5
				end
			end
		end
	end)

	hooks:add('onPlayerPlaceBlock', 'survival', function(player, x, y, z, id)
		if id > 0 and player.inventory[id] < 1 then
			player:sendMessage('&cNot enough blocks')
			return true
		else
			player.inventory[id] = player.inventory[id] - 1
			survUpdateBlockInfo(player)

			if player.inventory[id] == 0 then
				player:holdThis(0)
			end
		end
	end)

	hooks:add('onHeldBlockChange', 'survival', function(player, id)
		survUpdateBlockInfo(player)
	end)

	addCommand('give', function(isConsole, player, args)
		local id, count
		if isConsole then
			if #args < 2 then return false end
			player = getPlayerByName(args[1])
			id = args[2]
			count = args[3]
		else
			if #args == 2 then
				id = args[1]
				count = args[2]
			elseif #args > 2 then
				player = getPlayerByName(args[1])
				id = args[2]
				count = args[3]
			end
		end
		if not player then return MESG_PLAYERNF end

		id = tonumber(id)
		count = tonumber(count)or 64
		count = math.min(math.max(count, 1), 64)

		if id and id > 0 and id < 65 then
			player:holdThis(id)
			player.inventory[id] = math.min(64, player.inventory[id] + count)
			survUpdateBlockInfo(player)
			return (CMD_GIVE):format(count, survBlocknames[id], player)
		else
			return 'Invalid block id'
		end
	end)

	addCommand('heal', function(isConsole, player, args)
		if isConsole and #args < 1 then return false end
		player = getPlayerByName(args[1])or player
		if not player then return MESG_PLAYERNF end

		player.health = SURV_MAX_HEALTH
		survUpdateHealth(player)
		return ('Player &a%s&f healed.'):format(player)
	end)

	addCommand('craft', function(isConsole, player, args)
		if isConsole then return CON_INGAMECMD end

		local quantity = tonumber(args[1])or 1
		local bId = player:getHeldBlock()
		local recipe = survCraft[bId]
		local inv = player.inventory

		if recipe then
			local oQuantity = recipe.count * quantity
			local bName = survBlocknames[bId]
			if(64 - inv[bId]) < (quantity * recipe.count)then
				return 'You can\'t take more than 64 blocks of ' .. bName
			end
			local canBeCrafted, lacks = survCanCraft(player, bId, quantity)
			if canBeCrafted then
				for nId, ammount in pairs(recipe.needs)do
					inv[nId] = inv[nId] - ammount * quantity
				end
				inv[bId] = inv[bId] + oQuantity
				survUpdateBlockInfo(player)
				return ('%d block(-s) of %s crafted'):format(oQuantity, bName)
			else
				return ('You need %s to craft %s'):format(lacks, bName)
			end
		else
			return 'Selected block can\'t be crafted. Choose block from inventory and write /craft to craft it.'
		end
	end)

	addCommand('drop', function(isConsole, player, args)
		if isConsole then return CON_INGAMECMD end

		local bId = player:getHeldBlock()
		if bId < 1 or bId > 65 then
			return
		end

		if #args > 1 then
			local target = getPlayerByName(args[1])
			local quantity = tonumber(args[2])or 1
			local x, y, z = player:getPos()

			if not target then
				return MESG_PLAYERNF
			end
			if distance(x, y, z, target:getPos()) > 6 then
				return 'This player is too far away from you.'
			end

			local inv1 = player.inventory
			local inv2 = target.inventory
			quantity = math.min(quantity, 64 - inv2[bId])
			if quantity < 1 then
				return
			end
			if inv1[bId] >= quantity then
				inv1[bId] = inv1[bId] - quantity
				inv2[bId] = inv2[bId] + quantity
				survUpdateBlockInfo(player)
				survUpdateBlockInfo(target)
				return ('Dropped %d %s blocks to %s'):format(quantity, survBlocknames[bId], target)
			end
		else
			local inv = player.inventory
			local quantity = tonumber(args[1])or 1
			if inv[bId] >= quantity then
				inv[bId] = inv[bId] - quantity
				survUpdateBlockInfo(player)
				return ('Dropped %d %s blocks'):format(quantity, survBlocknames[bId])
			end
		end
	end)

	addCommand('kill', function(isConsole, player, args)
		if #args < 1 then return false end
		player = getPlayerByName(args[1])
		if player then
			if not player:survDamage(nil, SURV_MAX_HEALTH, 0)then
				return 'This player cannot be damaged'
			end
		else
			return MESG_PLAYERNF
		end
	end)

	addCommand('god', function(isConsole, player, args)
		if isConsole and #args < 1 then return false end
		player = getPlayerByName(args[1])or player
		if not player then return MESG_PLAYERNF end

		player.isInGodmode = not player.isInGodmode
		local state = (player.isInGodmode and ST_ON)or ST_OFF
		return ('Player &a%s&f godmode %s.'):format(player, state)
	end)

	addCommand('full', function(isConsole, player, args)
		local bid
		if isConsole then
			if #args < 1 then return false end
			player = getPlayerByName(args[1])
			bid = args[2]
		end
		if not player then return MESG_PLAYERNF end
		bid = bid or player:getHeldBlock()

		if bid > 0 and bid < 66 then
			player.inventory[bid] = 64
			survUpdateBlockInfo(player)
			return (CMD_GIVE):format(64, survBlocknames[bid], player)
		else
			return 'Invalid block ID'
		end
	end)

	saveAdd('health', '>f')
	saveAdd('oxygen', '>f')
	saveAdd('isInGodmode', 'b', function(player, val)
		return val == 1
	end, function(val)
		return val and 1 or 0
	end)

	saveAdd('inventory', 'c65', function(player, data)
		ffi.copy(player.inventory, data, 65)
	end, function(inventory)
		return ffi.string(inventory, 65)
	end)
end
