--
-- Created by scaled
-- and Igor
-- for LuaClassic server
--

local GEN_ENABLE_CAVES = true
local GEN_ENABLE_TREES = true
local GEN_ENABLE_ORES = true
local GEN_ENABLE_HOUSES = true

local GEN_CAVE_RADIUS = 3
local GEN_CAVE_MIN_LENGTH = 100
local GEN_CAVE_MAX_LENGTH = 500

local GEN_TREES_COUNT_MULT = 1

local GEN_ORE_VEIN_SIZE = 3

local GEN_BIOME_STEP = 20
local GEN_BIOME_RADIUS = 5

local heightStone
local heightGrass
local heightWater
local heightLava
local heightMap
local biomes

local function biomesGenerate(dx, dz)
	biomes = {}

	-- 1	normal
	-- 2	high
	-- 3	trees
	-- 4	sand
	-- 5	water

	-- Circles
	local biomesSizeX = math.floor(dx / GEN_BIOME_STEP + 1)
	local biomesSizeZ = math.floor(dz / GEN_BIOME_STEP + 1)
	for x = 0, biomesSizeX do
		biomes[x] = {}
		for z = 0, biomesSizeZ do
			biomes[x][z] = 1
		end
	end

	local BIOME_COUNT = dx * dz / GEN_BIOME_STEP / GEN_BIOME_RADIUS / 64 + 1
	local radius2 = GEN_BIOME_RADIUS ^ 2

	for i = 1, BIOME_COUNT do
		local x = math.random(biomesSizeX)
		local z = math.random(biomesSizeZ)
		local biome = math.random(1, 5)

		for dx = -GEN_BIOME_RADIUS, GEN_BIOME_RADIUS do
			for dz = -GEN_BIOME_RADIUS, GEN_BIOME_RADIUS do
				if
				dx*dx + dz*dz < radius2
				and biomes[x + dx] ~= nil and biomes[x + dx][z + dz] ~= nil
				then
					biomes[x + dx][z + dz] = biome
				end
			end
		end
	end
end

local function getBiome(x, z)
	return biomes[math.floor(x/GEN_BIOME_STEP)][math.floor(z/GEN_BIOME_STEP)]
end

local function heightSet(dy)
	heightGrass = dy / 2
	heightWater = heightGrass
	heightLava = 7
end

local function heightMapGenerate(dx, dz)
	heightMap = {}
	for x = 0, dx / GEN_BIOME_STEP + 1 do
		heightMap[x] = {}
		for z = 0, dz / GEN_BIOME_STEP + 1 do
			--local r = math.random(0,80)
			--heightMap[x][z] = heightGrass + math.random(-5, 10) + ((r>77 and 13)or 0)

			local biome = biomes[x][z]
			-- normal
			if biome == 1 then
				if math.random(0, 6) == 0 then
					heightMap[x][z] = heightGrass + math.random(-3, -1)
				else
					heightMap[x][z] = heightGrass + math.random(1, 3)
				end
				-- high
			elseif biome == 2 then
				if math.random(0, 6) == 0 then
					heightMap[x][z] = heightGrass + math.random(20, 30)
				else
					heightMap[x][z] = heightGrass + math.random(-2, 20)
				end
				-- trees
			elseif biome == 3 then
				if math.random(0, 5) == 0 then
					heightMap[x][z] = heightGrass + math.random(-3, -1)
				else
					heightMap[x][z] = heightGrass + math.random(1, 5)
				end
				-- sand
			elseif biome == 4 then
				heightMap[x][z] = heightGrass + math.random(1, 4)
				-- water
			elseif biome == 5 then
				if math.random(0, 10) == 0 then
					heightMap[x][z] = heightGrass + math.random(-20, -3)
				else
					heightMap[x][z] = heightGrass + math.random(-10, -3)
				end
			else
				heightMap[x][z] = heightGrass
			end
		end
	end

	heightStone = heightGrass - 3
end

local function getHeight(x, z)
	local hx, hz = math.floor(x/GEN_BIOME_STEP), math.floor(z/GEN_BIOME_STEP)
	local percentX = x / GEN_BIOME_STEP - hx
	local percentZ = z / GEN_BIOME_STEP - hz

	return math.floor(
		  (heightMap[hx][hz  ] * (1 - percentX) + heightMap[hx+1][hz  ] * percentX) * (1 - percentZ)
		+ (heightMap[hx][hz+1] * (1 - percentX) + heightMap[hx+1][hz+1] * percentX) * percentZ
		+ 0.5
	)
end

-- Generate
local function threadTerrain(mapaddr, dx, dy, dz, startX, endX)
	set_debug_threadname('TerrainGenerator')

	local map = ffi.cast('char*', mapaddr)
	local size = dx * dy * dz + 4

	local SetBlock = function(x, y, z, id)
		map[(y * dz + z) * dx + x + 4] = id
	end

	local height1, heightStone1, biome
	local offsetX, offsetY
	for x = startX, endX do
		local hx = math.floor(x/GEN_BIOME_STEP)
		local percentPosX = x / GEN_BIOME_STEP - hx
		local percentNegX = 1 - percentPosX

		local biomePosX = math.floor(x/GEN_BIOME_STEP)
		local b0 = biomes[biomePosX]
		local b1 = biomes[biomePosX+1]
		local biomePosZOld = nil
		local b00 = nil
		local b01 = b0[0]
		local b10 = nil
		local b11 = b1[0]

		for z = 0, dz - 1 do
			local hz = math.floor(z/GEN_BIOME_STEP)
			local percentZ = z / GEN_BIOME_STEP - hz

			height1 = math.floor(
				  (heightMap[hx][hz  ] * percentNegX + heightMap[hx+1][hz  ] * percentPosX) * (1 - percentZ)
				+ (heightMap[hx][hz+1] * percentNegX + heightMap[hx+1][hz+1] * percentPosX) * percentZ
				+ 0.5
			)

			--[[
			-- Badrock
			SetBlock(x, 0, z, 7)

			-- Stone
			heightStone1 = height1 + math.random(-6, -4)
			for y = 1, heightStone1 - 1 do
				SetBlock(x, y, z, 1)
			end

			-- Dirt
			for y = heightStone1, height1 - 2 do
				SetBlock(x, y, z, 3)
			end
			]]--

			-- Badrock
			local offset = z * dx + x + 4
			--map[offset] = 7

			-- Stone
			heightStone1 = height1 + math.random(-6, -4)

			local step = dz * dx
			--for y = 1, heightStone1 - 1 do
			for y = heightStone, heightStone1 - 1 do
				map[offset + y * step] = 1
			end

			-- Dirt
			for y = heightStone1, height1 - 2 do
				map[offset + y * step] = 3
			end


			-- Biom depend
			local biomePosZ = math.floor(z/GEN_BIOME_STEP)
			if biomePosZ ~= biomePosZOld then
				biomePosZOld = biomePosZ
				b00 = b01
				b01 = b0[biomePosZ+1]
				b10 = b11
				b11 = b1[biomePosZ+1]

				if b01 == 3 then
					b01 = 1
				end
				if b11 == 3 then
					b11 = 1
				end
			end

			-- angle around 00
			if b11 == b01 and b11 == b10 then
				if percentPosX * percentPosX + percentZ * percentZ > 0.25 then
					biome = b11
				else
					biome = b00
				end

			-- angle around 01
			elseif b00 == b11 and b00 == b10 then
				if percentPosX * percentPosX + (1 - percentZ)^2 > 0.25 then
					biome = b00
				else
					biome = b01
				end

			-- angle around 10
			elseif b00 == b01 and b00 == b11 then
				if percentNegX * percentNegX + percentZ * percentZ > 0.25 then
					biome = b00
				else
					biome = b10
				end

			-- angle around 11
			elseif b00 == b01 and b00 == b10 then
				if percentNegX * percentNegX + (1 - percentZ)^2 > 0.25 then
					biome = b00
				else
					biome = b11
				end

			-- else
			else
				biome = biomes[math.floor(x / GEN_BIOME_STEP + 0.5)][math.floor(z / GEN_BIOME_STEP + 0.5)]
				--biome = getBiome(x + GEN_BIOME_STEP / 2, z + GEN_BIOME_STEP / 2)
			end

			-- normal or trees
			if biome == 1 or biome == 3 then
				if height1 > heightWater then
					-- Grass
					SetBlock(x, height1-1, z, 3)
					SetBlock(x, height1  , z, 2)
				else
					-- Sand
					SetBlock(x, height1-1, z, 12)
					SetBlock(x, height1  , z, 12)

					for y = height1 + 1, heightWater do
						SetBlock(x, y, z, 8)
					end
				end

				-- high
			elseif biome == 2 then
				-- Rock
				SetBlock(x, height1-1, z, 1)
				SetBlock(x, height1  , z, 1)

				for y = height1 + 1, heightWater do
					SetBlock(x, y, z, 8)
				end

			-- sand
			elseif biome == 4 then
				-- Sand
				SetBlock(x, height1-1, z, 12)
				SetBlock(x, height1,   z, 12)

				for y = height1 + 1, heightWater do
					SetBlock(x, y, z, 8)
				end

				-- water
			elseif biome == 5 then
				-- Dirt
				SetBlock(x, height1-1, z, 3)
				SetBlock(x, height1,   z, 3)

				for y = height1 + 1, heightWater do
					SetBlock(x, y, z, 8)
				end
			else
				SetBlock(x, height1-1, z, 4)
				SetBlock(x, height1,   z, 4)
			end
		end
	end
end

local function generateTrees(mapaddr, dx, dy, dz)
	set_debug_threadname('TreesGenerator')

	local map = ffi.cast('char*', mapaddr)
	local size = dx * dy * dz + 4

	local SetBlock = function(x, y, z, id)
		local offset = (y * dz + z) * dx + x + 4
		if offset < size then
			map[offset] = id
		end
	end

	local TREES_COUNT = (dx * dz / 700)*GEN_TREES_COUNT_MULT

	local i = 1
	local fail = 0

	local x, z, baseHeight, baseHeight2
	while i < TREES_COUNT do
		x, z = math.random(6, dx - 6), math.random(6, dz - 6)

		baseHeight = getHeight(x, z)
		if baseHeight > heightWater then
			-- tree
			if getBiome(x, z) == 3 then
				i = i + 1

				baseHeight2 = baseHeight + math.random(4, 6)

				for y = baseHeight + 1, baseHeight2 do
					SetBlock(x, y, z, 17)
				end

				for dx = x - 2, x + 2 do
					for dz = z - 2, z + 2 do
						if dx ~= x or dz ~= z then
							for y = baseHeight2 - 2, baseHeight2 - 1 do
								SetBlock(dx, y, dz, 18)
							end
						end
					end
				end

				for dx = x - 1, x + 1 do
					if dx ~= x then
						for y = baseHeight2, baseHeight2 + 1 do
							SetBlock(dx, y, z, 18)
						end
					end
				end
				for dz = z - 1, z + 1 do
					if dz ~= z then
						for y = baseHeight2, baseHeight2 + 1 do
							SetBlock(x, y, dz, 18)
						end
					end
				end
				SetBlock(x, baseHeight2 + 1, z, 18)

				-- kaktus
			elseif getBiome(x, z) == 4 then
				i = i + 1

				baseHeight2 = baseHeight + math.random(1, 4)

				for y = baseHeight + 1, baseHeight2 do
					SetBlock(x, y, z, 18)
				end

				-- fail
			else
				fail = fail + 1

				if fail > 1000 then
					fail = 0
					break
				end
			end
		else
			fail = fail + 1

			if fail > 1000 then
				fail = 0
				break
			end
		end
	end
end

local function generateHouse(mapaddr, dimx, dimy, dimz)
	set_debug_threadname('HousesGenerator')

	local map = ffi.cast('char*', mapaddr)
	local size = dimx * dimy * dimz + 4

	local SetBlock = function(x, y, z, id)
		local offset = (y * dimz + z) * dimx + x + 4
		if 0 < offset and offset < size then
			map[offset] = id
		end
	end

	local GetBlock = function(x, y, z)
		local offset = (y * dimz + z) * dimx + x + 4
		if 0 < offset and offset < size then
			return map[offset]
		else
			return -1
		end
	end

	local HOUSE_COUNT = dimx * dimz / 70000

	for i = 1, HOUSE_COUNT do
		local startX = math.random(4, dimx - 8)
		local startZ = math.random(4, dimz - 10)
		local endX = startX + math.random(4, 6)
		local endZ = startZ + math.random(6, 8)

		-- Find max height
		local calcel = false

		local maxHeight = 0
		local tempHeight
		for x = startX, endX do
			for z = startZ, endZ do
				tempHeight = getHeight(x, z)
				if tempHeight > maxHeight then
					maxHeight = tempHeight
				end
				if tempHeight < heightWater then
					calcel = true
					break
				end
			end
		end

		if not calcel then
			maxHeight = maxHeight + 1

			-- floor
			for x = startX, endX do
				for z = startZ, endZ do
					for y = getHeight(x, z), maxHeight do
						SetBlock(x, y, z, 4)
					end
				end
			end

			local materials = {4, 20, 5}

			-- walls
			for i = 1, #materials do
				for x = startX, endX do
					SetBlock(x, maxHeight + i, startZ, materials[i])
					SetBlock(x, maxHeight + i, endZ, materials[i])
				end

				for z = startZ, endZ do
					SetBlock(startX, maxHeight + i, z, materials[i])
					SetBlock(endX, maxHeight + i, z, materials[i])
				end

				SetBlock(startX + 2, maxHeight + i, startZ, 0)
			end

			SetBlock(startX + 2, maxHeight + i, startZ, 0)

			local j = 1
			while GetBlock(startX + 2, maxHeight - j, startZ - j) == 0 do
				SetBlock(startX + 2, maxHeight - j, startZ - j, 4)
				j = j + 1
			end

			maxHeight = maxHeight + 4

			for i = -1, math.min(endX - startX, endZ - startZ) / 2 do
				for x = startX + i, endX - i do
					SetBlock(x, maxHeight + i, startZ + i, 5)
					SetBlock(x, maxHeight + i, endZ - i, 5)
				end

				for z = startZ + i, endZ - i do
					SetBlock(startX + i, maxHeight + i, z, 5)
					SetBlock(endX - i, maxHeight + i, z, 5)
				end
			end
		end
	end
end

local function generateOre(mapaddr, dimx, dimy, dimz)
	set_debug_threadname('OreGenerator')

	local map = ffi.cast('char*', mapaddr)
	local size = dimx * dimy * dimz + 4

	local SetBlock = function(x, y, z, id)
		local offset = (y * dimz + z) * dimx + x + 4
		if offset < size then
			map[offset] = id
		end
	end
	local ORE_COUNT = dimx * dimy * dimz / 150 / 64

	local x, y, z, ore
	for i = 1, ORE_COUNT do
		x = math.random(GEN_ORE_VEIN_SIZE, dimx - GEN_ORE_VEIN_SIZE)
		z = math.random(GEN_ORE_VEIN_SIZE, dimz - GEN_ORE_VEIN_SIZE)
		y = math.random(5, heightGrass / 2)

		ore = math.random(14,16)
		for dx = 1, GEN_ORE_VEIN_SIZE do
			for dz = 1, GEN_ORE_VEIN_SIZE do
				for dy = 1, GEN_ORE_VEIN_SIZE do
					if math.random(0, 1) == 1 then
						SetBlock(x + dx, y + dy, z + dz, ore)
					end
				end
			end
		end
	end
end

local function generateCaves(mapaddr, dimx, dimy, dimz)
	set_debug_threadname('CavesGenerator')

	local map = ffi.cast('char*', mapaddr)
	local size = dimx * dimy * dimz + 4

	local SetBlock = function(x, y, z, id)
		local offset = (y * dimz + z) * dimx + x + 4
		if offset < size then
			map[offset] = id
		end
		--map[(y * dimz + z) * dimx + x + 4] = id
	end

	local CAVE_LENGTH = math.random(GEN_CAVE_MIN_LENGTH, GEN_CAVE_MAX_LENGTH)
	local CAVE_RADIUS2 = GEN_CAVE_RADIUS ^ 2

	local CAVE_CHANGE_DIRECTION = math.floor(CAVE_LENGTH / 3)

	local ddx, ddy, ddz, length, directionX, directionY, directionZ

	--[[local directionX = (math.random() - 0.5) * 0.3
	local directionY = (math.random() - 0.5) * 0.1
	local directionZ = (math.random() - 0.5) * 0.3]]--

	local x = math.random(GEN_CAVE_RADIUS, dimx - GEN_CAVE_RADIUS)
	local z = math.random(GEN_CAVE_RADIUS, dimz - GEN_CAVE_RADIUS)
	--y = math.random(heightGrass / 4, heightGrass / 2)
	local y = math.random(10, heightGrass - 20)

	for j = 1, CAVE_LENGTH do
		if j % CAVE_CHANGE_DIRECTION == 1 then
			directionX = (math.random() - 0.5) * 0.6
			directionY = (math.random() - 0.5) * 0.2
			directionZ = (math.random() - 0.5) * 0.6
		end

		ddx = math.random() - 0.5 + directionX
		ddy = (math.random() - 0.5) * 0.4 + directionY
		ddz = math.random() - 0.5 + directionZ

		length = 1--math.sqrt(ddx^2 + ddy^2 + ddz^2)

		x = math.floor(x + ddx * GEN_CAVE_RADIUS / length + 0.5)
		y = math.floor(y + ddy * GEN_CAVE_RADIUS / length + 0.5)
		z = math.floor(z + ddz * GEN_CAVE_RADIUS / length + 0.5)

		for dx = -GEN_CAVE_RADIUS, GEN_CAVE_RADIUS do
			for dz = -GEN_CAVE_RADIUS, GEN_CAVE_RADIUS do
				for dy = -GEN_CAVE_RADIUS, GEN_CAVE_RADIUS do
					if
						dx*dx + dz*dz + dy*dy < CAVE_RADIUS2
						and y + dy > 0
						and 1 < x + dx and x + dx < dimx - 1
						and 1 < z + dz and z + dz < dimz - 1
					then
						SetBlock(x + dx, y + dy, z + dz, (y+dy>heightLava and 0)or 11)
					end
				end
			end
		end
	end
end

local function fillStone(world, dimx, dimz)
	ffi.fill(world.ldata + 4, dimx * dimz, 7)
	ffi.fill(world.ldata + 4 + dimx * dimz, dimx * dimz * (heightStone - 1), 1)
end

local lanelibs = 'math,ffi'

return function(world, seed)
	log.debug('DefaultGenerator: START')
	seed = seed or (os.clock()*os.time())
	local dx, dy, dz = world:getDimensions()
	math.randomseed(seed)

	biomesGenerate(dx, dz)

	heightSet(dy)
	heightMapGenerate(dx, dz)

	fillStone(world, dx, dz)

	local mapaddr = world:getAddr()

	local threads = {}

	local thlimit = config:get('generator-threads-count')

	local terrain_gen = lanes.gen(lanelibs, threadTerrain)
	for i = 0, thlimit-1 do
		startX = math.floor(dx * i / thlimit)
		endX = math.floor(dx * (i + 1) / thlimit) - 1

		table.insert(threads, terrain_gen(mapaddr, dx, dy, dz, startX, endX))
		log.debug(('TerrainGenerator: #%d thread spawned'):format(#threads))
	end
	watchThreads(threads)

	if GEN_ENABLE_ORES then
		local ores_gen = lanes.gen(lanelibs, generateOre)
		table.insert(threads, ores_gen(mapaddr, dx, dy, dz))
		log.debug('OresGenerator: started')
	end

	if #threads == thlimit then
		watchThreads(threads)
	end

	if GEN_ENABLE_TREES then
		local trees_gen = lanes.gen(lanelibs, generateTrees)
		table.insert(threads, trees_gen(mapaddr, dx, dy, dz, seed))
		log.debug('TreesGenerator: started')
	end

	if #threads == thlimit then
		watchThreads(threads)
	end

	if GEN_ENABLE_HOUSES then
		local houses_gen = lanes.gen(lanelibs, generateHouse)
		table.insert(threads, houses_gen(mapaddr, dx, dy, dz))
		log.debug('HousesGenerator: started')
	end

	watchThreads(threads)

	if GEN_ENABLE_CAVES then
		log.debug('CavesGenerator: started')
		local caves_gen = lanes.gen(lanelibs, generateCaves)

		local CAVES_COUNT = dx * dy * dz / 700000
		for i = 1, CAVES_COUNT do
			if i%thlimit == 0 then
				watchThreads(threads)
				log.debug(('CaveGenerator: %d threads done'):format(thlimit))
			end

			table.insert(threads, caves_gen(mapaddr, dx, dy, dz, seed + i))
			log.debug(('CaveGenerator: #%d thread spawned'):format(#threads))
		end
	end

	watchThreads(threads)

	local x, z = math.random(1, dx), math.random(1, dz)
	local y = getHeight(x,z)

	for i = 1, 20 do
		if y < 0 then
			x, z = math.random(1, dx), math.random(1, dz)
			y = getHeight(x,z)
			break
		end
	end

	world:setSpawn(x, y+2, z)
	world:setEnvProp(MEP_SIDESBLOCK, 0)
	world:setEnvProp(MEP_EDGEBLOCK, 8)
	world:setEnvProp(MEP_EDGELEVEL, heightWater + 1)
	world:setEnvProp(MEP_MAPSIDESOFFSET, 0)
	world:setData('isNether', false)
	collectgarbage()
	log.debug('DefaultGenerator: DONE')

	return true
end
