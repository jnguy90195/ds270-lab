-- Owns the authoritative tile grid. Clients never change it directly; they ask PlayerService,
-- which validates the request and then calls into here. Each non-air tile is a Part in Workspace.World.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage.Shared.Config)

local S, D = Config.TileSize, Config.TileDepth

local WorldService = {}

local grid = {}        -- grid[gy][gx] = block id
local parts = {}       -- parts[gy][gx] = Part (nil for air)
local hits = {}        -- "gx,gy" -> hits taken so far
local lastHit = {}     -- "gx,gy" -> os.clock() of the last hit
local folder
local offsetX = math.random() * 1000 -- different noise offset every server start

local function makePart(gx, gy, id)
	local def = Config.Blocks[id]
	local p = Instance.new("Part")
	p.Name = "Tile"
	p.Anchored = true
	p.Size = Vector3.new(S, S, D)
	p.Position = Config.worldPos(gx, gy)
	p.Color = def.color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p:SetAttribute("Id", id)
	p:SetAttribute("GX", gx)
	p:SetAttribute("GY", gy)
	p:SetAttribute("Damage", 0) -- 0..1, the client darkens the tile based on this
	p.Parent = folder
	return p
end

function WorldService.get(gx, gy)
	if not Config.inBounds(gx, gy) then
		return nil
	end
	return grid[gy][gx]
end

function WorldService.hasSolidNeighbor(gx, gy)
	local offsets = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	for _, o in offsets do
		local id = WorldService.get(gx + o[1], gy + o[2])
		if id and id ~= 0 then
			return true
		end
	end
	return false
end

function WorldService.setTile(gx, gy, id)
	grid[gy][gx] = id
	local key = gx .. "," .. gy
	hits[key] = nil
	lastHit[key] = nil
	if parts[gy][gx] then
		parts[gy][gx]:Destroy()
		parts[gy][gx] = nil
	end
	if id ~= 0 then
		parts[gy][gx] = makePart(gx, gy, id)
	end
end

-- Returns the id of the block that broke, or nil if it's still standing.
function WorldService.hit(gx, gy)
	local id = WorldService.get(gx, gy)
	if not id or id == 0 then
		return nil
	end
	local def = Config.Blocks[id]
	if def.hardness == math.huge then
		return nil
	end

	local key = gx .. "," .. gy
	local now = os.clock()
	local count = hits[key] or 0
	if lastHit[key] and now - lastHit[key] > 5 then
		count = 0 -- tile heals if you stop hitting it for a few seconds
	end
	count += 1
	hits[key] = count
	lastHit[key] = now

	local part = parts[gy][gx]
	if part then
		part:SetAttribute("Damage", math.min(count / def.hardness, 1))
	end

	if count >= def.hardness then
		WorldService.setTile(gx, gy, 0)
		return id
	end
	return nil
end

local function surfaceAt(gx)
	if gx <= 8 then
		return Config.SurfaceRow -- flat spawn area
	end
	return Config.SurfaceRow + math.floor(math.noise(gx * 0.08 + offsetX, 0, 0) * 8 + 0.5)
end

local function blockFor(gx, gy)
	local surf = surfaceAt(gx)
	if gy < surf then
		return 0
	end
	if gy == surf then
		return 2
	end
	if gy >= Config.Rows - 1 then
		return 4
	end
	if gy < surf + 4 then
		return 1
	end
	if gy > surf + 2 and math.noise(gx * 0.15 + offsetX, gy * 0.15, 3) > 0.2 then
		return 0 -- caves
	end
	if math.random() < 0.05 then
		return 6
	end
	return 3
end

function WorldService.init()
	folder = Instance.new("Folder")
	folder.Name = "World"
	folder.Parent = Workspace

	for gy = 1, Config.Rows do
		grid[gy] = {}
		parts[gy] = {}
	end

	for gy = 1, Config.Rows do
		for gx = 1, Config.Cols do
			local id = blockFor(gx, gy)
			grid[gy][gx] = id
			if id ~= 0 then
				parts[gy][gx] = makePart(gx, gy, id)
			end
		end
		task.wait() -- spread the build over frames so Studio doesn't freeze
	end

	-- Spawn pad on top of the flat area, column 3.
	local ground = Config.worldPos(3, Config.SurfaceRow)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = Vector3.new(ground.X, ground.Y + S / 2 + 0.5, 0)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = Workspace
end

return WorldService
